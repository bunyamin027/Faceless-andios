import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/services/api_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/supabase_service.dart';
import '../features/create/data/models/project_model.dart';
import '../features/create/data/models/script_model.dart';

/// Faceless AI — Video Service
/// Orchestrates: User Input → CF Worker → Supabase Update
///
/// Architecture: Fire-and-forget pipeline.
/// 1. createProject() — creates project row, returns projectId immediately
/// 2. runPipeline() — runs in background, updates Supabase status
/// 3. RenderingScreen watches Supabase via Realtime/polling for updates
class VideoService {
  VideoService._();
  static final instance = VideoService._();

  final _api = ApiService();

  /// Step 1: Create project in Supabase and return the projectId immediately.
  /// This is fast (~1 second) so the UI can navigate to rendering screen.
  Future<String> createProject({
    required String productName,
    required String description,
    required String tone,
    String? mediaUrl,
  }) async {
    final userId = SupabaseService.userId;
    if (userId == null) {
      throw Exception('User not authenticated. Please sign in again.');
    }

    final projectRes = await SupabaseService.client.from('projects').insert({
      'user_id': userId,
      'title': productName,
      'product_name': productName,
      'product_description': description,
      'tone': tone,
      'user_media_url': mediaUrl,
      'status': 'scripting',
      'render_progress': 0,
    }).select().single();

    return projectRes['id'] as String;
  }

  /// Step 2: Run the full pipeline in the background.
  /// This updates the project in Supabase as it progresses.
  /// The RenderingScreen watches for these updates.
  ///
  /// This method is fire-and-forget — caller doesn't need to await it.
  Future<void> runPipeline({
    required String projectId,
    required String productName,
    required String description,
    required String tone,
    File? userMedia,
    int durationSec = 25,
  }) async {
    try {
      // ── 1. Upload user media (optional) ──
      String? mediaUrl;
      if (userMedia != null) {
        try {
          await _updateProject(projectId, {
            'status': 'scripting',
            'render_progress': 5,
          });
          mediaUrl = await StorageService.uploadUserMedia(userMedia);
          // Update project with media URL
          await _updateProject(projectId, {
            'user_media_url': mediaUrl,
            'render_progress': 10,
          });
        } catch (e) {
          debugPrint('⚠️ Media upload failed (continuing without): $e');
          // Non-blocking: continue without user media
        }
      }

      // ── 2. Call Cloudflare Worker → Gemini + Pexels ──
      await _updateProject(projectId, {
        'status': 'scripting',
        'render_progress': 15,
      });

      late final Map<String, dynamic> payload;
      try {
        final generateRes = await _api.post(
          ApiEndpoints.generateScript,
          data: {
            'product_name': productName,
            'description': description,
            'tone': tone,
            'duration_sec': durationSec,
            'user_media_url': mediaUrl,
          },
        );
        payload = generateRes.data as Map<String, dynamic>;
      } catch (e) {
        debugPrint('❌ Generate API failed: $e');
        await _failProject(projectId, 'Script generation failed. Please check your internet connection and try again.');
        return;
      }

      // ── 3. Save script & render spec to project ──
      await _updateProject(projectId, {
        'script_json': payload['script'],
        'render_spec_json': payload['render_spec'],
        'status': 'rendering',
        'render_progress': 30,
      });

      // Check if worker returned a direct video URL (MVP fast path)
      final directVideoUrl = payload['video_url'] as String?;
      final renderSpec = payload['render_spec'] as Map<String, dynamic>? ?? {};

      // ── 4. Trigger render / fast-complete ──
      try {
        await _api.post(
          ApiEndpoints.triggerRender,
          data: {
            'project_id': projectId,
            'render_spec': {
              ...renderSpec,
              if (directVideoUrl != null) 'video_url': directVideoUrl,
            },
          },
        );
        // The /api/render endpoint updates Supabase directly to 'completed'
        // RenderingScreen will pick up the change via Realtime/polling
      } catch (e) {
        debugPrint('⚠️ Render trigger failed: $e');
        // Fallback: if we have a direct video URL, complete it ourselves
        if (directVideoUrl != null) {
          await _updateProject(projectId, {
            'status': 'completed',
            'render_progress': 100,
            'video_url': directVideoUrl,
          });
        } else {
          await _failProject(projectId, 'Video rendering failed. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('❌ Pipeline unexpected error: $e');
      try {
        await _failProject(projectId, 'Unexpected error: $e');
      } catch (_) {}
    }
  }

  /// Combined convenience method: create project + start pipeline
  /// Returns projectId immediately, pipeline runs in background
  Future<String> startGeneration({
    required String productName,
    required String description,
    required String tone,
    File? userMedia,
    int durationSec = 25,
  }) async {
    // Step 1: Create project (fast, ~1s)
    final projectId = await createProject(
      productName: productName,
      description: description,
      tone: tone,
    );

    // Step 2: Fire-and-forget the pipeline
    // Use unawaited to run in background — don't block the UI
    unawaited(runPipeline(
      projectId: projectId,
      productName: productName,
      description: description,
      tone: tone,
      userMedia: userMedia,
      durationSec: durationSec,
    ));

    return projectId;
  }

  // ─── Helpers ───

  Future<void> _updateProject(String projectId, Map<String, dynamic> updates) async {
    try {
      await SupabaseService.client.from('projects').update({
        ...updates,
      }).eq('id', projectId);
    } catch (e) {
      debugPrint('⚠️ Project update failed: $e');
    }
  }

  Future<void> _failProject(String projectId, String errorMessage) async {
    await _updateProject(projectId, {
      'status': 'failed',
      'error_message': errorMessage,
    });
  }

  /// Regenerate script only (without re-rendering)
  Future<ScriptModel> regenerateScript({
    required String projectId,
    required String productName,
    required String description,
    required String tone,
  }) async {
    final res = await _api.post(
      ApiEndpoints.generateScript,
      data: {
        'product_name': productName,
        'description': description,
        'tone': tone,
      },
    );

    final script = ScriptModel.fromJson(res.data['script']);

    await SupabaseService.client.from('projects').update({
      'script_json': res.data['script'],
      'render_spec_json': res.data['render_spec'],
    }).eq('id', projectId);

    return script;
  }

  /// Fetch project by ID
  Future<ProjectModel> getProject(String projectId) async {
    final res = await SupabaseService.client
        .from('projects')
        .select()
        .eq('id', projectId)
        .single();
    return ProjectModel.fromJson(res);
  }
}

// ─── Progress Model (still used by rendering_screen for display) ───

enum VideoStage {
  uploading,
  scripting,
  rendering,
  completed,
  failed,
}

class VideoProgress {
  final VideoStage stage;
  final int progress;
  final String? projectId;
  final String? videoUrl;
  final String? error;
  final ScriptModel? script;

  const VideoProgress({
    required this.stage,
    required this.progress,
    this.projectId,
    this.videoUrl,
    this.error,
    this.script,
  });

  bool get isComplete => stage == VideoStage.completed;
  bool get isFailed => stage == VideoStage.failed;
  bool get isProcessing => !isComplete && !isFailed;
}
