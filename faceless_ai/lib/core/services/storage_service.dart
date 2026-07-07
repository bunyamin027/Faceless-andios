import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import 'supabase_service.dart';

/// Faceless AI — Storage Service
/// Handles file uploads/downloads to Supabase Storage
class StorageService {
  StorageService._();

  static final _uuid = const Uuid();

  /// Upload user media (video/image) to Supabase Storage
  /// Returns the public URL of the uploaded file
  static Future<String> uploadUserMedia(File file) async {
    final ext = file.path.split('.').last;
    final fileName = '${SupabaseService.userId}/${_uuid.v4()}.$ext';

    await SupabaseService.client.storage
        .from(AppConstants.uploadsBucket)
        .upload(
          fileName,
          file,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );

    return SupabaseService.client.storage
        .from(AppConstants.uploadsBucket)
        .getPublicUrl(fileName);
  }

  /// Upload raw bytes (e.g., generated audio)
  static Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String contentType = 'audio/mpeg',
  }) async {
    await SupabaseService.client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            cacheControl: '3600',
            upsert: true,
          ),
        );

    return SupabaseService.client.storage.from(bucket).getPublicUrl(path);
  }

  /// Get a signed URL for temporary access
  static Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresInSec = 3600,
  }) async {
    return SupabaseService.client.storage.from(bucket).createSignedUrl(
          path,
          expiresInSec,
        );
  }

  /// Delete a file from storage
  static Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await SupabaseService.client.storage.from(bucket).remove([path]);
  }

  /// List files in a folder
  static Future<List<FileObject>> listFiles({
    required String bucket,
    String path = '',
  }) async {
    return SupabaseService.client.storage.from(bucket).list(path: path);
  }
}
