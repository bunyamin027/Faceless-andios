import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/animated_progress.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/models/project_model.dart';

/// Rendering Screen — Shows real-time video generation progress
class RenderingScreen extends StatefulWidget {
  final String projectId;

  const RenderingScreen({super.key, required this.projectId});

  @override
  State<RenderingScreen> createState() => _RenderingScreenState();
}

class _RenderingScreenState extends State<RenderingScreen>
    with TickerProviderStateMixin {
  ProjectModel? _project;
  StreamSubscription? _subscription;
  Timer? _timeoutTimer;
  Timer? _pollTimer;

  late AnimationController _dotController;

  // Status messages
  static const _statusMessages = {
    'scripting': [
      'AI is writing your script...',
      'Crafting the perfect hook...',
      'Generating viral-worthy scenes...',
    ],
    'fetching': [
      'Finding stunning B-Roll footage...',
      'Generating voiceover audio...',
      'Preparing visual assets...',
    ],
    'rendering': [
      'Composing video layers...',
      'Applying blur effects...',
      'Adding animated text...',
      'Finalizing your masterpiece...',
    ],
  };

  int _messageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _loadProject();
    _startRealtimeListener();
    _startMessageRotation();
    _startTimeout();
    _startPolling();
  }

  @override
  void dispose() {
    _dotController.dispose();
    _subscription?.cancel();
    _messageTimer?.cancel();
    _timeoutTimer?.cancel();
    _pollTimer?.cancel();
    RealtimeService.stopWatching();
    super.dispose();
  }

  Future<void> _loadProject() async {
    try {
      final response = await SupabaseService.client
          .from('projects')
          .select()
          .eq('id', widget.projectId)
          .single();

      if (mounted) {
        setState(() {
          _project = ProjectModel.fromJson(response);
        });

        // If already completed, navigate
        if (_project!.status == ProjectStatus.completed &&
              _project!.videoUrl != null) {
          _timeoutTimer?.cancel();
          _pollTimer?.cancel();
          context.go('/preview/${widget.projectId}');
        } else if (_project!.status == ProjectStatus.failed) {
          _showErrorDialog(_project!.errorMessage ?? 'Video generation failed');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load project: $e');
    }
  }

  void _startRealtimeListener() {
    _subscription = RealtimeService.watchProject(widget.projectId).listen(
      (data) {
        if (mounted) {
          final updated = ProjectModel.fromJson(data);
          setState(() => _project = updated);

          if (updated.status == ProjectStatus.completed &&
              updated.videoUrl != null) {
            _timeoutTimer?.cancel();
            _pollTimer?.cancel();
            context.go('/preview/${widget.projectId}');
          } else if (updated.status == ProjectStatus.failed) {
            _timeoutTimer?.cancel();
            _pollTimer?.cancel();
            _showErrorDialog(updated.errorMessage ?? 'Unknown error');
          }
        }
      },
    );
  }

  /// Timeout: if no result after 2 minutes, show error
  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(minutes: 2), () {
      if (mounted && (_project == null || _project!.status.isProcessing)) {
        _showErrorDialog(
          'Video generation is taking too long. Please try again with a simpler description.',
        );
      }
    });
  }

  /// Polling fallback: check project status every 10 seconds
  /// In case Supabase Realtime misses an update
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadProject();
    });
  }

  void _startMessageRotation() {
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _messageIndex++);
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rendering Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_project?.renderProgress ?? 0) / 100;
    final status = _project?.status.value ?? 'scripting';
    final messages = _statusMessages[status] ?? _statusMessages['scripting']!;
    final message = messages[_messageIndex % messages.length];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F0A1A),
              AppColors.background,
              Color(0xFF0A0F14),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back to home
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: IconButton(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),

              const Spacer(),

              // ── Progress Circle ──
              AnimatedProgress(
                progress: progress,
                size: 160,
                strokeWidth: 8,
                label: _project?.status.displayLabel,
              ),

              const SizedBox(height: 48),

              // ── Status Message ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  message,
                  key: ValueKey(message),
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // ── Pipeline Steps ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    _buildPipelineStep(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Script Generation',
                      isActive: status == 'scripting',
                      isComplete:
                          status == 'fetching' || status == 'rendering' || _project?.status == ProjectStatus.completed,
                    ),
                    _buildPipelineStep(
                      icon: Icons.cloud_download_rounded,
                      label: 'Asset Fetching',
                      isActive: status == 'fetching',
                      isComplete: status == 'rendering' || _project?.status == ProjectStatus.completed,
                    ),
                    _buildPipelineStep(
                      icon: Icons.movie_creation_rounded,
                      label: 'Video Rendering',
                      isActive: status == 'rendering',
                      isComplete: _project?.status == ProjectStatus.completed,
                      isLast: true,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Tip
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.coffee_rounded,
                          color: AppColors.textTertiary, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This usually takes 30–60 seconds. You can close this screen — we\'ll notify you when it\'s ready.',
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineStep({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isComplete,
    bool isLast = false,
  }) {
    final color = isComplete
        ? AppColors.success
        : isActive
            ? AppColors.primary
            : AppColors.textDisabled;

    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isComplete ? Icons.check_rounded : icon,
                color: color,
                size: 18,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: isComplete
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.surfaceElevated,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: isActive || isComplete
                  ? AppColors.textPrimary
                  : AppColors.textDisabled,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
