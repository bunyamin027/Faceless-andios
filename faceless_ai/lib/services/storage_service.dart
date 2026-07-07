import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Faceless AI — Raw Media Storage Service
/// Uploads user-picked files to Supabase 'raw_media' bucket
/// Returns a public URL for downstream processing (CF Worker → FFmpeg)
class RawMediaStorageService {
  RawMediaStorageService._();
  static final instance = RawMediaStorageService._();

  static const _bucket = 'raw_media';
  static final _uuid = const Uuid();
  static SupabaseClient get _client => Supabase.instance.client;

  /// Upload a local [File] → Supabase Storage → public URL
  ///
  /// Path format: `{user_id}/{uuid}.{ext}`
  /// Throws [StorageUploadException] on failure.
  Future<String> upload(File file) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const StorageUploadException('Not authenticated');

    final ext = file.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      throw StorageUploadException('Unsupported file type: .$ext');
    }

    final fileSize = await file.length();
    if (fileSize > _maxFileSizeBytes) {
      throw StorageUploadException(
        'File too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Max: ${_maxFileSizeMB}MB.',
      );
    }

    final remotePath = '$userId/${_uuid.v4()}.$ext';

    try {
      await _client.storage.from(_bucket).upload(
            remotePath,
            file,
            fileOptions: FileOptions(
              contentType: _mimeType(ext),
              cacheControl: '3600',
              upsert: false,
            ),
          );

      return _client.storage.from(_bucket).getPublicUrl(remotePath);
    } on StorageException catch (e) {
      throw StorageUploadException('Upload failed: ${e.message}');
    } catch (e) {
      throw StorageUploadException('Unexpected error: $e');
    }
  }

  /// Delete a previously uploaded file by its public URL
  Future<void> delete(String publicUrl) async {
    final uri = Uri.parse(publicUrl);
    // Extract path after /object/public/raw_media/
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_bucket);
    if (bucketIndex < 0 || bucketIndex + 1 >= segments.length) return;

    final remotePath = segments.sublist(bucketIndex + 1).join('/');
    try {
      await _client.storage.from(_bucket).remove([remotePath]);
    } catch (_) {
      // Best-effort deletion — don't crash the app
    }
  }

  // ─── Constraints ───

  static const int _maxFileSizeMB = 50;
  static const int _maxFileSizeBytes = _maxFileSizeMB * 1024 * 1024;

  static const _allowedExtensions = {
    'mp4', 'mov', 'avi', 'webm', 'mkv', // video
    'jpg', 'jpeg', 'png', 'webp', 'heic', // image
  };

  static String _mimeType(String ext) => switch (ext) {
        'mp4' => 'video/mp4',
        'mov' => 'video/quicktime',
        'avi' => 'video/x-msvideo',
        'webm' => 'video/webm',
        'mkv' => 'video/x-matroska',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'application/octet-stream',
      };
}

/// Typed exception for storage upload errors
class StorageUploadException implements Exception {
  final String message;
  const StorageUploadException(this.message);

  @override
  String toString() => 'StorageUploadException: $message';
}
