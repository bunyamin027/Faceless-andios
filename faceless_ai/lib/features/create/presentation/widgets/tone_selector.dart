import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';

/// Tone selection grid widget
/// Displays available tones as selectable chips with emojis
class ToneSelector extends StatelessWidget {
  final String selectedTone;
  final ValueChanged<String> onToneSelected;

  const ToneSelector({
    super.key,
    required this.selectedTone,
    required this.onToneSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AppConstants.availableTones.map((tone) {
        final isSelected = tone == selectedTone;
        final emoji = AppConstants.toneEmojis[tone] ?? '🎵';

        return GestureDetector(
          onTap: () => onToneSelected(tone),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected ? AppColors.primaryGradient : null,
              color: isSelected ? null : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : AppColors.glassBorder,
                width: 1,
              ),
              boxShadow: isSelected ? AppColors.primaryGlow(opacity: 0.25) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  tone[0].toUpperCase() + tone.substring(1),
                  style: AppTypography.labelLarge.copyWith(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
