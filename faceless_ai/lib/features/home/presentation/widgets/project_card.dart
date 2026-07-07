import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../create/data/models/project_model.dart';

/// Project card for the home screen list
class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback? onTap;

  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thumbnail / Placeholder ──
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              image: project.thumbnailUrl != null
                  ? DecorationImage(
                      image: NetworkImage(project.thumbnailUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: project.thumbnailUrl == null
                ? Center(
                    child: Icon(
                      _statusIcon,
                      color: AppColors.textTertiary,
                      size: 40,
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 14),

          // ── Title + Status ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: AppTypography.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.productName,
                      style: AppTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(),
            ],
          ),

          // ── Progress bar (if rendering) ──
          if (project.status.isProcessing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: project.renderProgress / 100,
                backgroundColor: AppColors.surfaceElevated,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${project.status.displayLabel} (${project.renderProgress}%)',
              style: AppTypography.caption.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        project.status.displayLabel,
        style: AppTypography.labelSmall.copyWith(
          color: _statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (project.status) {
      case ProjectStatus.draft:
        return AppColors.statusDraft;
      case ProjectStatus.scripting:
      case ProjectStatus.fetching:
      case ProjectStatus.rendering:
        return AppColors.statusProcessing;
      case ProjectStatus.completed:
        return AppColors.statusCompleted;
      case ProjectStatus.failed:
        return AppColors.statusFailed;
    }
  }

  IconData get _statusIcon {
    switch (project.status) {
      case ProjectStatus.draft:
        return Icons.edit_note_rounded;
      case ProjectStatus.scripting:
        return Icons.auto_awesome_rounded;
      case ProjectStatus.fetching:
        return Icons.cloud_download_rounded;
      case ProjectStatus.rendering:
        return Icons.movie_creation_rounded;
      case ProjectStatus.completed:
        return Icons.play_circle_rounded;
      case ProjectStatus.failed:
        return Icons.error_outline_rounded;
    }
  }
}
