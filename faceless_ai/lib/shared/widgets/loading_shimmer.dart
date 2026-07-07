import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/app_colors.dart';

/// Shimmer loading placeholder
/// Shows an animated skeleton while content loads
class LoadingShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets? margin;

  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 48,
    this.borderRadius = 12,
    this.margin,
  });

  /// Card-shaped shimmer for project cards
  factory LoadingShimmer.card() => const LoadingShimmer(height: 120);

  /// Text-line shaped shimmer
  factory LoadingShimmer.line({double width = 200}) =>
      LoadingShimmer(height: 16, width: width, borderRadius: 8);

  /// Circle shimmer for avatars
  factory LoadingShimmer.circle({double size = 48}) =>
      LoadingShimmer(width: size, height: size, borderRadius: size / 2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Shimmer(
        gradient: AppColors.shimmerGradient,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}

/// A shimmer placeholder for a full project card
class ProjectCardShimmer extends StatelessWidget {
  const ProjectCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Shimmer(
        gradient: AppColors.shimmerGradient,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Container(
              width: 180,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Container(
              width: 120,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
