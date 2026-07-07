import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Faceless AI — Make.com Automation Service
/// Sends video URL + caption + platform flags to a Make.com webhook
/// for auto-publishing to TikTok, Instagram Reels, YouTube Shorts, etc.
class AutomationService {
  AutomationService._();
  static final instance = AutomationService._();

  static String get _webhookUrl => dotenv.env['MAKE_WEBHOOK_URL'] ?? '';

  static const _timeout = Duration(seconds: 15);

  final _dio = Dio(BaseOptions(
    connectTimeout: _timeout,
    receiveTimeout: _timeout,
    sendTimeout: _timeout,
  ));

  /// Trigger auto-publish workflow on Make.com
  ///
  /// [videoUrl] — Public URL of the rendered MP4
  /// [caption] — AI-generated caption with hashtags
  /// [platforms] — Set of target platforms to publish to
  /// [metadata] — Optional extra fields (product name, tone, etc.)
  ///
  /// Returns `true` if webhook accepted (HTTP 200), `false` otherwise.
  Future<AutomationResult> publish({
    required String videoUrl,
    required String caption,
    required Set<PublishPlatform> platforms,
    Map<String, dynamic>? metadata,
  }) async {
    if (platforms.isEmpty) {
      return const AutomationResult(
        success: false,
        message: 'No platforms selected',
      );
    }

    final payload = {
      'video_url': videoUrl,
      'caption': caption,
      'platforms': platforms.map((p) => p.id).toList(),
      'hashtags': _extractHashtags(caption),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (metadata != null) ...metadata,
    };

    try {
      final response = await _dio.post(
        _webhookUrl,
        data: jsonEncode(payload),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        return AutomationResult(
          success: true,
          message: 'Published to ${platforms.length} platform(s)',
          platforms: platforms,
        );
      }

      return AutomationResult(
        success: false,
        message: 'Webhook returned ${response.statusCode}',
      );
    } on DioException catch (e) {
      final msg = switch (e.type) {
        DioExceptionType.connectionTimeout => 'Connection timed out',
        DioExceptionType.sendTimeout => 'Request timed out',
        DioExceptionType.receiveTimeout => 'Server did not respond',
        DioExceptionType.connectionError => 'No internet connection',
        _ => 'Network error: ${e.message}',
      };
      return AutomationResult(success: false, message: msg);
    } catch (e) {
      return AutomationResult(
        success: false,
        message: 'Unexpected error: $e',
      );
    }
  }

  /// Generate AI-style caption with hashtags
  static String generateCaption({
    required String productName,
    required String tone,
  }) {
    final hashtags = [
      '#$productName'.replaceAll(' ', ''),
      '#AI',
      '#ProductShowcase',
      '#Viral',
      '#FacelessAI',
      if (tone == 'inspirational') '#Motivation',
      if (tone == 'energetic') '#Energy',
      if (tone == 'professional') '#Business',
      if (tone == 'dramatic') '#Cinematic',
      if (tone == 'luxurious') '#Premium',
    ];
    return '🎬 Check out $productName — made with AI ✨\n\n${hashtags.join(' ')}';
  }

  List<String> _extractHashtags(String text) {
    final regex = RegExp(r'#\w+');
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }
}

// ─── Models ───

enum PublishPlatform {
  tiktok('tiktok', 'TikTok', '🎵'),
  instagram('instagram', 'Instagram Reels', '📸'),
  youtube('youtube', 'YouTube Shorts', '▶️'),
  twitter('twitter', 'X / Twitter', '🐦');

  final String id;
  final String label;
  final String emoji;
  const PublishPlatform(this.id, this.label, this.emoji);
}

class AutomationResult {
  final bool success;
  final String message;
  final Set<PublishPlatform>? platforms;

  const AutomationResult({
    required this.success,
    required this.message,
    this.platforms,
  });
}
