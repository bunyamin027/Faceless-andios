import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../services/automation_service.dart';

/// ═══════════════════════════════════════════════════════════════════
/// FACELESS AI — IMMERSIVE RESULT SCREEN
/// Full-screen TikTok-style vertical video with floating action panel.
/// ═══════════════════════════════════════════════════════════════════

class ResultScreen extends StatefulWidget {
  final String videoUrl;
  final String? projectId;
  final String? productName;
  final String? tone;

  const ResultScreen({
    super.key,
    required this.videoUrl,
    this.projectId,
    this.productName,
    this.tone,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _initialized = false;
  bool _showControls = true;
  bool _isSaving = false;
  bool _isPublishing = false;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _actionPulse;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Lock to immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _actionPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    try {
      await _videoController.initialize();
      _videoController.setLooping(true);
      _videoController.play();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        setState(() => _initialized = false);
        _showToast('Failed to load video', isError: true);
      }
    }

    _videoController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _videoController.dispose();
    _fadeController.dispose();
    _actionPulse.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      // Download MP4 to temp
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/faceless_${DateTime.now().millisecondsSinceEpoch}.mp4';

      await Dio().download(
        widget.videoUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            // Could show download progress here
          }
        },
      );

      // Save to gallery
      await Gal.putVideo(filePath, album: 'Faceless AI');

      // Clean up temp file
      try {
        await File(filePath).delete();
      } catch (_) {}

      if (mounted) {
        _showToast('Saved to gallery ✓');
      }
    } catch (e) {
      if (mounted) {
        _showToast('Save failed: ${e.toString().split(':').last.trim()}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _autoPublish() async {
    if (_isPublishing) return;
    HapticFeedback.mediumImpact();

    // Show platform picker
    final platforms = await _showPlatformPicker();
    if (platforms == null || platforms.isEmpty) return;

    setState(() => _isPublishing = true);

    final caption = AutomationService.generateCaption(
      productName: widget.productName ?? 'My Product',
      tone: widget.tone ?? 'inspirational',
    );

    final result = await AutomationService.instance.publish(
      videoUrl: widget.videoUrl,
      caption: caption,
      platforms: platforms,
      metadata: {
        'project_id': widget.projectId,
        'product_name': widget.productName,
      },
    );

    if (mounted) {
      setState(() => _isPublishing = false);
      if (result.success) {
        _showToast('🚀 ${result.message}');
      } else {
        _showToast(result.message, isError: true);
      }
    }
  }

  Future<void> _shareVideo() async {
    HapticFeedback.lightImpact();
    Share.share(
      '🎬 Made with Faceless AI\n${widget.videoUrl}',
    );
  }

  void _togglePlayPause() {
    HapticFeedback.selectionClick();
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          onDoubleTap: _togglePlayPause,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Video Layer ──
              _buildVideoLayer(),

              // ── Buffering Indicator ──
              if (_initialized && _videoController.value.isBuffering)
                const Center(child: _NeonSpinner()),

              // ── Loading State ──
              if (!_initialized) _buildLoadingState(),

              // ── Controls Overlay ──
              if (_showControls && _initialized) ...[
                _buildTopBar(),
                _buildBottomOverlay(),
                _buildActionPanel(),
              ],

              // ── Play/Pause Flash ──
              if (_initialized && !_videoController.value.isPlaying && _showControls)
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 36),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Video Layer ───

  Widget _buildVideoLayer() {
    if (!_initialized) return const SizedBox.expand();

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController.value.aspectRatio,
        child: VideoPlayer(_videoController),
      ),
    );
  }

  // ─── Loading State ───

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _NeonSpinner(),
            const SizedBox(height: 24),
            Text('Loading your masterpiece…',
                style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ───

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          8,
          MediaQuery.of(context).padding.top + 4,
          16,
          12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            _GlassAction(
              icon: Icons.arrow_back_rounded,
              onTap: () {
                context.canPop() ? context.pop() : context.go('/');
              },
            ),
            const Spacer(),
            // "AI Generated" badge
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: AppColors.primaryEnd, size: 14),
                      const SizedBox(width: 6),
                      Text('AI Generated',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primaryEnd,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Overlay (progress bar + info) ───

  Widget _buildBottomOverlay() {
    final position = _videoController.value.position;
    final duration = _videoController.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20, 20, 90, // 90 right for action panel
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.3),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product name
            if (widget.productName != null)
              Text(
                widget.productName!,
                style: AppTypography.headlineSmall.copyWith(
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              'Made with Faceless AI ✨',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),

            // Progress scrubber
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryEnd,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Time
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(duration),
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Floating Action Panel (right side, TikTok-style) ───

  Widget _buildActionPanel() {
    return Positioned(
      right: 12,
      bottom: MediaQuery.of(context).padding.bottom + 80,
      child: AnimatedBuilder(
        animation: _actionPulse,
        builder: (_, __) {
          return Column(
            children: [
              // Save to Gallery
              _ActionButton(
                icon: Icons.download_rounded,
                label: 'Save',
                isLoading: _isSaving,
                onTap: _saveToGallery,
              ),
              const SizedBox(height: 20),

              // Auto Publish
              _ActionButton(
                icon: Icons.rocket_launch_rounded,
                label: 'Publish',
                isLoading: _isPublishing,
                glowColor: AppColors.primaryEnd,
                glowIntensity: _actionPulse.value,
                onTap: _autoPublish,
              ),
              const SizedBox(height: 20),

              // Share
              _ActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: _shareVideo,
              ),
              const SizedBox(height: 20),

              // Create another
              _ActionButton(
                icon: Icons.add_rounded,
                label: 'New',
                onTap: () => context.go('/'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Platform Picker ───

  Future<Set<PublishPlatform>?> _showPlatformPicker() async {
    final selected = <PublishPlatform>{};

    return showModalBottomSheet<Set<PublishPlatform>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Publish To', style: AppTypography.headlineSmall),
              const SizedBox(height: 6),
              Text('Select platforms for auto-publishing',
                  style: AppTypography.bodySmall),
              const SizedBox(height: 20),

              ...PublishPlatform.values.map((p) {
                final isActive = selected.contains(p);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => setSheetState(() {
                      isActive ? selected.remove(p) : selected.add(p);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.glassBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(p.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 14),
                          Text(p.label, style: AppTypography.titleMedium),
                          const Spacer(),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isActive
                                ? const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primary, size: 22)
                                : Icon(Icons.circle_outlined,
                                    color: AppColors.textDisabled, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Confirm
              GestureDetector(
                onTap: selected.isNotEmpty
                    ? () => Navigator.pop(ctx, selected)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: selected.isNotEmpty
                        ? AppColors.primaryGradient
                        : null,
                    color: selected.isNotEmpty
                        ? null
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      selected.isNotEmpty
                          ? '🚀 Publish to ${selected.length} platform(s)'
                          : 'Select platforms',
                      style: AppTypography.labelLarge.copyWith(
                        color: selected.isNotEmpty
                            ? Colors.white
                            : AppColors.textDisabled,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Toast ───

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: isError ? AppColors.error : AppColors.success,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: AppTypography.labelLarge),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: (isError ? AppColors.error : AppColors.success)
                .withValues(alpha: 0.3),
          ),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

// ═══════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════════════════════

/// TikTok-style floating action button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final Color? glowColor;
  final double glowIntensity;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.glowColor,
    this.glowIntensity = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
              boxShadow: glowColor != null
                  ? [
                      BoxShadow(
                        color: glowColor!.withValues(alpha: glowIntensity * 0.4),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass icon button (top bar)
class _GlassAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassAction({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Neon-styled loading spinner
class _NeonSpinner extends StatelessWidget {
  const _NeonSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: const AlwaysStoppedAnimation(AppColors.primaryEnd),
        backgroundColor: AppColors.primaryEnd.withValues(alpha: 0.15),
      ),
    );
  }
}
