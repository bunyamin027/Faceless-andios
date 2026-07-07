import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/supabase_service.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/create/data/models/project_model.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'widgets/project_card.dart';

/// Home Screen — Project list with FAB to create
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  List<ProjectModel>? _projects;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabScale = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _fabController.forward();
    _loadProjects();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;

      final response = await SupabaseService.client
          .from('projects')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final projects = (response as List)
          .map((json) => ProjectModel.fromJson(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.surfaceGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              _buildHeader(),

              // ── Content ──
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),

      // ── FAB ──
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.primaryGlow(opacity: 0.5),
          ),
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/create'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              'New Video',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Faceless AI', style: AppTypography.headlineLarge),
              const SizedBox(height: 4),
              Text('Your video projects', style: AppTypography.bodySmall),
            ],
          ),
          // Profile / Settings
          GlassCard(
            padding: const EdgeInsets.all(10),
            borderRadius: 14,
            onTap: () {
              // TODO: Navigate to settings
              _showLogoutSheet();
            },
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 3,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: ProjectCardShimmer(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Something went wrong', style: AppTypography.headlineSmall),
            const SizedBox(height: 8),
            Text(_error!, style: AppTypography.bodySmall),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _loadProjects,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_projects == null || _projects!.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadProjects,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        itemCount: _projects!.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ProjectCard(
              project: _projects![index],
              onTap: () {
                final project = _projects![index];
                if (project.status == ProjectStatus.completed &&
                    project.videoUrl != null) {
                  context.push('/preview/${project.id}');
                } else if (project.status.isProcessing) {
                  context.push('/rendering/${project.id}');
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.primaryGlow(),
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No videos yet',
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap "New Video" to create your first\nAI-powered product showcase',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text('Settings', style: AppTypography.bodyLarge),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: Text('Sign Out',
                  style: AppTypography.bodyLarge
                      .copyWith(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                context.read<AuthBloc>().add(AuthSignOutRequested());
              },
            ),
          ],
        ),
      ),
    );
  }
}
