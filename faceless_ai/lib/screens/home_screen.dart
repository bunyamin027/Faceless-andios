import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../services/video_service.dart';

/// ═══════════════════════════════════════════════════════════════════
/// FACELESS AI — COMMAND CENTER
/// A single-screen futuristic experience for generating videos.
/// Deep dark aesthetic with neon accent particles and glass panels.
/// ═══════════════════════════════════════════════════════════════════

class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen>
    with TickerProviderStateMixin {
  final _promptController = TextEditingController();
  final _promptFocus = FocusNode();

  File? _selectedMedia;
  bool _isVideo = false;

  // Pipeline state
  _PipelineState _state = _PipelineState.idle;
  String _statusText = '';

  // Animations
  late AnimationController _pulseController;
  late AnimationController _orbController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnim;
  late Animation<double> _orbAnim;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _orbAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(_orbController);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocus.dispose();
    _pulseController.dispose();
    _orbController.dispose();
    _progressController.dispose();

    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // MEDIA PICKER
  // ─────────────────────────────────────────────────────────────

  Future<void> _pickMedia() async {
    HapticFeedback.mediumImpact();
    final picker = ImagePicker();

    final source = await showModalBottomSheet<_MediaChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MediaSourceSheet(),
    );

    if (source == null) return;

    XFile? picked;
    if (source == _MediaChoice.video) {
      picked = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
    } else if (source == _MediaChoice.camera) {
      picked = await picker.pickVideo(source: ImageSource.camera);
    } else {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    }

    if (picked != null && mounted) {
      setState(() {
        _selectedMedia = File(picked!.path);
        _isVideo = source != _MediaChoice.image;
      });
    }
  }

  void _removeMedia() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedMedia = null;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // GENERATE PIPELINE
  // ─────────────────────────────────────────────────────────────

  Future<void> _startGeneration() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _shake();
      return;
    }

    HapticFeedback.heavyImpact();
    _promptFocus.unfocus();
    setState(() {
      _state = _PipelineState.generating;
      _statusText = 'Creating your video…';
    });
    _animateProgress(0.15);

    try {
      // Creates project in Supabase (~1s) and starts the pipeline
      // (Gemini + Pexels + render) in the background.
      // Pipeline updates Supabase status as it progresses.
      final projectId = await VideoService.instance.startGeneration(
        productName: prompt.split(' ').take(4).join(' '),
        description: prompt,
        tone: 'inspirational',
        userMedia: _selectedMedia,
      );

      if (mounted) {
        setState(() {
          _statusText = 'Redirecting…';
        });
        _animateProgress(0.3);

        // Navigate to rendering screen — it watches Supabase for updates
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          context.push('/rendering/$projectId');
          _reset();
        }
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _state = _PipelineState.error;
          _statusText = e.toString().replaceAll('Exception: ', '');
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _reset();
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _state = _PipelineState.idle;
      _statusText = '';
    });
  }

  void _animateProgress(double target) {
    _progressAnim = Tween<double>(
      begin: _progressAnim.value,
      end: target.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
    _progressController
      ..reset()
      ..forward();
  }

  void _shake() {
    HapticFeedback.mediumImpact();
    // Visual feedback — the prompt field will show error via validator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Describe your product first',
            style: AppTypography.labelLarge),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  bool get _isProcessing => _state != _PipelineState.idle &&
      _state != _PipelineState.completed &&
      _state != _PipelineState.error;

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Animated Background ──
          _AnimatedBackground(orbAnim: _orbAnim, pulseAnim: _pulseAnim),

          // ── Content ──
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildHeroSection(),
                        const SizedBox(height: 32),
                        _buildPromptField(),
                        const SizedBox(height: 20),
                        _buildMediaSection(),
                        const SizedBox(height: 28),
                        if (_isProcessing) _buildProgressPanel(),
                        if (!_isProcessing) _buildGenerateButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // Neon dot
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryEnd,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryEnd.withValues(alpha: _pulseAnim.value * 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('FACELESS', style: AppTypography.titleSmall.copyWith(
            letterSpacing: 3,
            color: AppColors.textTertiary,
            fontSize: 11,
          )),
          const Spacer(),
          // Projects button
          _GlassIconButton(
            icon: Icons.folder_outlined,
            onTap: () => context.push('/home'),
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            icon: Icons.person_outline_rounded,
            onTap: () {/* Settings */},
          ),
        ],
      ),
    );
  }

  // ─── Hero Section ───

  Widget _buildHeroSection() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
          child: Text(
            'Create Magic',
            style: AppTypography.displayLarge.copyWith(
              color: Colors.white,
              fontSize: 36,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Describe your product. AI handles the rest.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }

  // ─── Prompt Field ───

  Widget _buildPromptField() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: _promptFocus.hasFocus
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.glassBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _promptFocus.hasFocus
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.glassBorder,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _promptController,
            focusNode: _promptFocus,
            style: AppTypography.bodyLarge.copyWith(fontSize: 15),
            maxLines: 4,
            minLines: 3,
            enabled: !_isProcessing,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'An Islamic focus timer that helps Muslims stay productive during Ramadan…',
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textDisabled,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
    );
  }

  // ─── Media Section ───

  Widget _buildMediaSection() {
    if (_selectedMedia != null) {
      return _buildMediaPreview();
    }
    return _buildMediaPicker();
  }

  Widget _buildMediaPicker() {
    return GestureDetector(
      onTap: _isProcessing ? null : _pickMedia,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryStart.withValues(alpha: 0.15),
                        AppColors.primaryEnd.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.primaryEnd, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attach Screen Recording',
                          style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text('Optional • Appears in device mockup',
                          style: AppTypography.caption),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textDisabled, size: 20),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _isVideo
                      ? Container(
                          color: AppColors.surfaceElevated,
                          child: const Icon(Icons.play_circle_filled_rounded,
                              color: AppColors.primary, size: 28),
                        )
                      : Image.file(
                          _selectedMedia!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surfaceElevated,
                            child: const Icon(Icons.image_rounded,
                                color: AppColors.primaryEnd, size: 24),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Media attached',
                        style: AppTypography.titleMedium.copyWith(
                            color: AppColors.success)),
                    const SizedBox(height: 2),
                    Text(
                      _selectedMedia!.path.split('/').last,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _GlassIconButton(
                icon: Icons.close_rounded,
                onTap: _isProcessing ? null : _removeMedia,
                size: 32,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Generate Button ───

  Widget _buildGenerateButton() {
    final hasPrompt = _promptController.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: hasPrompt ? _startGeneration : _shake,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: hasPrompt
                  ? AppColors.primaryGradient
                  : null,
              color: hasPrompt ? null : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              boxShadow: hasPrompt
                  ? [
                      BoxShadow(
                        color: AppColors.primaryStart
                            .withValues(alpha: _pulseAnim.value * 0.35),
                        blurRadius: 28,
                        spreadRadius: -4,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: hasPrompt ? Colors.white : AppColors.textDisabled,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Generate Video',
                    style: AppTypography.labelLarge.copyWith(
                      color: hasPrompt ? Colors.white : AppColors.textDisabled,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Progress Panel (during generation) ───

  Widget _buildProgressPanel() {
    final isError = _state == _PipelineState.error;

    return AnimatedBuilder(
      animation: _progressController,
      builder: (_, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isError
                    ? AppColors.error.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isError
                      ? AppColors.error.withValues(alpha: 0.3)
                      : AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  // ── Animated orb ──
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!isError)
                          AnimatedBuilder(
                            animation: _orbAnim,
                            builder: (_, __) {
                              return Transform.rotate(
                                angle: _orbAnim.value,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        AppColors.primaryStart.withValues(alpha: 0),
                                        AppColors.primaryEnd,
                                        AppColors.primaryStart.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            boxShadow: [
                              BoxShadow(
                                color: (isError ? AppColors.error : AppColors.primary)
                                    .withValues(alpha: 0.3),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Icon(
                            isError
                                ? Icons.error_outline_rounded
                                : _stageIcon,
                            color: isError ? AppColors.error : AppColors.primaryEnd,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Status text ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText,
                      key: ValueKey(_statusText),
                      style: AppTypography.titleMedium.copyWith(
                        color: isError ? AppColors.error : AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Progress bar ──
                  if (!isError)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressAnim.value,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryEnd,
                        ),
                        minHeight: 4,
                      ),
                    ),

                  if (!isError) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${(_progressAnim.value * 100).round()}%',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryEnd,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData get _stageIcon => switch (_state) {
        _PipelineState.uploading => Icons.cloud_upload_rounded,
        _PipelineState.generating => Icons.auto_awesome_rounded,
        _PipelineState.rendering => Icons.movie_creation_rounded,
        _PipelineState.completed => Icons.check_circle_rounded,
        _ => Icons.auto_awesome_rounded,
      };
}

// ═══════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════════════════════

enum _PipelineState { idle, uploading, generating, rendering, completed, error }
enum _MediaChoice { video, camera, image }

// ─── Animated Background with floating orbs ───

class _AnimatedBackground extends StatelessWidget {
  final Animation<double> orbAnim;
  final Animation<double> pulseAnim;

  const _AnimatedBackground({required this.orbAnim, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([orbAnim, pulseAnim]),
      builder: (_, __) {
        final angle = orbAnim.value;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF06060C),
                Color(0xFF0A0A14),
                Color(0xFF08081A),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Floating neon orb 1
              Positioned(
                top: 120 + math.sin(angle) * 30,
                right: -40 + math.cos(angle * 0.7) * 20,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryStart.withValues(alpha: 0.08 * pulseAnim.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Floating neon orb 2
              Positioned(
                bottom: 200 + math.cos(angle * 1.3) * 40,
                left: -60 + math.sin(angle * 0.5) * 30,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryEnd.withValues(alpha: 0.06 * pulseAnim.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Subtle grid lines
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: 0.03,
                  child: Column(
                    children: List.generate(20, (i) => Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 39),
                      color: Colors.white,
                    )),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Glass Icon Button ───

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _GlassIconButton({
    required this.icon,
    this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(icon, color: AppColors.textTertiary, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}

// ─── Media Source Bottom Sheet ───

class _MediaSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Attach Media', style: AppTypography.headlineSmall),
          const SizedBox(height: 20),
          _sourceOption(
            context,
            icon: Icons.video_library_rounded,
            label: 'Video from Gallery',
            subtitle: 'Screen recording or product demo',
            color: AppColors.primaryEnd,
            choice: _MediaChoice.video,
          ),
          const SizedBox(height: 12),
          _sourceOption(
            context,
            icon: Icons.videocam_rounded,
            label: 'Record Video',
            subtitle: 'Capture a new demo right now',
            color: AppColors.primary,
            choice: _MediaChoice.camera,
          ),
          const SizedBox(height: 12),
          _sourceOption(
            context,
            icon: Icons.photo_rounded,
            label: 'Image from Gallery',
            subtitle: 'Screenshot or product photo',
            color: AppColors.accent,
            choice: _MediaChoice.image,
          ),
        ],
      ),
    );
  }

  Widget _sourceOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required _MediaChoice choice,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, choice),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textDisabled, size: 18),
          ],
        ),
      ),
    );
  }
}
