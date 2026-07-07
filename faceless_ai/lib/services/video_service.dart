import 'dart:async';
import 'dart:io';


import '../core/constants/api_endpoints.dart';
import '../core/services/api_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/supabase_service.dart';
import '../core/services/realtime_service.dart';
import '../features/create/data/models/project_model.dart';
import '../features/create/data/models/script_model.dart';

/// Faceless AI — Video Service
/// Orchestrates: User Input → CF Worker → Render Worker → Final MP4
class VideoService {
  VideoService._();
  static final instance = VideoService._();

  final _api = ApiService();

  /// Full pipeline: create project → generate script → trigger render
  /// Returns a Stream of progress updates
  Stream<VideoProgress> generate({
    required String productName,
    required String description,
    required String tone,
    File? userMedia,
    int durationSec = 25,
  }) async* {
    yield const VideoProgress(stage: VideoStage.uploading, progress: 0);

    // ── 1. Upload user media to Supabase Storage ──
    String? mediaUrl;
    if (userMedia != null) {
      yield const VideoProgress(stage: VideoStage.uploading, progress: 10);
      mediaUrl = await StorageService.uploadUserMedia(userMedia);
    }

    // ── 2. Create project row in Supabase ──
    yield const VideoProgress(stage: VideoStage.scripting, progress: 15);

    final userId = SupabaseService.userId!;
    final projectRes = await SupabaseService.client.from('projects').insert({
      'user_id': userId,
      'title': productName,
      'product_name': productName,
      'product_description': description,
      'tone': tone,
      'user_media_url': mediaUrl,
      'status': 'scripting',
    }).select().single();

    final projectId = projectRes['id'] as String;

    // ── 3. Call Cloudflare Worker → Gemini + Pexels + TTS ──
    yield VideoProgress(
      stage: VideoStage.scripting,
      progress: 20,
      projectId: projectId,
    );

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

    final payload = generateRes.data as Map<String, dynamic>;
    final script = ScriptModel.fromJson(payload['script']);
    final renderSpec = payload['render_spec'] as Map<String, dynamic>;

    // Save script to project
    await SupabaseService.client.from('projects').update({
      'script_json': payload['script'],
      'render_spec_json': renderSpec,
      'status': 'rendering',
      'render_progress': 30,
    }).eq('id', projectId);

    yield VideoProgress(
      stage: VideoStage.rendering,
      progress: 30,
      projectId: projectId,
      script: script,
    );

    // ── 4. Trigger Fly.io render worker ──
    await _api.post(
      ApiEndpoints.triggerRender,
      data: {
        'project_id': projectId,
        'render_spec': renderSpec,
        'callback_url':
            '${SupabaseService.client.rest.url}/projects',
      },
    );

    // ── 5. Stream progress via Supabase Realtime ──
    yield* RealtimeService.watchProject(projectId).map((data) {
      final status = data['status'] as String? ?? 'rendering';
      final progress = data['render_progress'] as int? ?? 30;
      final videoUrl = data['video_url'] as String?;
      final error = data['error_message'] as String?;

      if (status == 'completed' && videoUrl != null) {
        return VideoProgress(
          stage: VideoStage.completed,
          progress: 100,
          projectId: projectId,
          videoUrl: videoUrl,
        );
      } else if (status == 'failed') {
        return VideoProgress(
          stage: VideoStage.failed,
          progress: progress,
          projectId: projectId,
          error: error ?? 'Render failed',
        );
      } else {
        return VideoProgress(
          stage: VideoStage.rendering,
          progress: progress,
          projectId: projectId,
        );
      }
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

  /// Cancel listening
  Future<void> cancelWatch() => RealtimeService.stopWatching();
}

// ─── Progress Model ───

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
