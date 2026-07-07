import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../create/data/models/project_model.dart';

/// Preview Screen — Full-screen video player with share options
class PreviewScreen extends StatefulWidget {
  final String projectId;

  const PreviewScreen({super.key, required this.projectId});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _controller;
  ProjectModel? _project;
  bool _isLoading = true;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    try {
      final response = await SupabaseService.client
          .from('projects')
          .select()
          .eq('id', widget.projectId)
          .single();

      final project = ProjectModel.fromJson(response);
      setState(() {
        _project = project;
      });

      if (project.videoUrl != null) {
        _initVideoPlayer(project.videoUrl!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initVideoPlayer(String url) async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller!.initialize();
    _controller!.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() => _isLoading = false);
    _controller!.play();
    _controller!.setLooping(true);
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _shareVideo() {
    if (_project?.videoUrl == null) return;
    Share.share(
      '🎬 Check out this video I made with Faceless AI!\n${_project!.videoUrl}',
    );
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share to', style: AppTypography.headlineSmall),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _shareOption(Icons.share_rounded, 'Share', _shareVideo),
                _shareOption(Icons.download_rounded, 'Save', () {
                  Navigator.pop(ctx);
                  // TODO: Download to gallery
                }),
                _shareOption(Icons.link_rounded, 'Copy Link', () {
                  Navigator.pop(ctx);
                  // TODO: Copy link
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(icon, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTypography.labelSmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video ──
            if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_rounded,
                        color: AppColors.textTertiary, size: 48),
                    const SizedBox(height: 16),
                    Text('Video not available',
                        style: AppTypography.bodyMedium),
                  ],
                ),
              ),

            // ── Controls Overlay ──
            if (_showControls) ...[
              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    MediaQuery.of(context).padding.top + 8,
                    16,
                    16,
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
                      IconButton(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          _project?.title ?? 'Preview',
                          style: AppTypography.headlineSmall,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),

              // Play/Pause center button
              if (_controller != null && _controller!.value.isInitialized)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: AnimatedOpacity(
                      opacity:
                          _controller!.value.isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ),

              // Bottom bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      if (_controller != null &&
                          _controller!.value.isInitialized)
                        VideoProgressIndicator(
                          _controller!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: AppColors.primary,
                            bufferedColor: AppColors.surfaceElevated,
                            backgroundColor: AppColors.glassBorder,
                          ),
                          padding:
                              const EdgeInsets.only(bottom: 20),
                        ),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: GradientButton(
                              text: 'Share',
                              icon: Icons.share_rounded,
                              onPressed: _showShareSheet,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GlassCard(
                            padding: const EdgeInsets.all(14),
                            borderRadius: 14,
                            onTap: () {
                              // TODO: Download
                            },
                            child: const Icon(
                              Icons.download_rounded,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
