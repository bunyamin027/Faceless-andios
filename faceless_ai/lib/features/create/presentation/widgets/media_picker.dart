import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Media picker widget for uploading screen recordings / images
class MediaPickerWidget extends StatelessWidget {
  final File? selectedFile;
  final ValueChanged<File> onPicked;
  final VoidCallback onRemoved;

  const MediaPickerWidget({
    super.key,
    this.selectedFile,
    required this.onPicked,
    required this.onRemoved,
  });

  Future<void> _pickMedia(BuildContext context) async {
    final picker = ImagePicker();

    // Show bottom sheet for source selection
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
              ),
              title: Text('Gallery', style: AppTypography.bodyLarge),
              subtitle: Text('Pick from photos or videos',
                  style: AppTypography.bodySmall),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryEnd.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.videocam_rounded,
                    color: AppColors.primaryEnd),
              ),
              title: Text('Camera', style: AppTypography.bodyLarge),
              subtitle: Text('Record a new video',
                  style: AppTypography.bodySmall),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? pickedFile = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );

    if (pickedFile != null) {
      onPicked(File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (selectedFile != null) {
      return _buildSelected(context);
    }
    return _buildUploadArea(context);
  }

  Widget _buildUploadArea(BuildContext context) {
    return GlassCard(
      onTap: () => _pickMedia(context),
      padding: const EdgeInsets.all(32),
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.cloud_upload_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Upload Screen Recording',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to select a video from gallery\nor record a new one',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.glassBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'MP4, MOV • Max 2 min',
              style: AppTypography.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelected(BuildContext context) {
    final fileName = selectedFile!.path.split('/').last;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.success.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Video Selected',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileName,
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemoved,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
