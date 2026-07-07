import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/video_service.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/glass_card.dart';
import 'widgets/media_picker.dart';
import 'widgets/tone_selector.dart';

/// Create Screen — Step-by-step wizard
/// Step 1: Product info → Step 2: Upload media → Step 3: Tone → Generate
class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pageController = PageController();

  int _currentStep = 0;
  String _selectedTone = 'inspirational';
  File? _selectedMedia;
  bool _isGenerating = false;

  static const _stepCount = 3;

  @override
  void dispose() {
    _productNameController.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && !_formKey.currentState!.validate()) return;

    if (_currentStep < _stepCount - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _generate();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);

    try {
      // Start the pipeline — VideoService handles:
      // 1. Upload media to Supabase Storage
      // 2. Create project row
      // 3. Call CF Worker (Gemini + Pexels + TTS)
      // 4. Dispatch to Fly.io render worker
      final stream = VideoService.instance.generate(
        productName: _productNameController.text.trim(),
        description: _descriptionController.text.trim(),
        tone: _selectedTone,
        userMedia: _selectedMedia,
      );

      // Listen for the first projectId, then navigate to rendering screen
      await for (final progress in stream) {
        if (progress.projectId != null) {
          if (mounted) {
            context.go('/rendering/${progress.projectId}');
          }
          break;
        }
        if (progress.isFailed) {
          throw Exception(progress.error ?? 'Generation failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
            children: [
              // ── App Bar ──
              _buildAppBar(),

              // ── Progress ──
              _buildStepIndicator(),

              // ── Steps ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                  ],
                ),
              ),

              // ── Bottom CTA ──
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _prevStep,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              'Create Video',
              style: AppTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: List.generate(_stepCount, (i) {
          final isActive = i <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < _stepCount - 1 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isActive ? AppColors.primaryGradient : null,
                color: isActive ? null : AppColors.surfaceElevated,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────
  // Step 1: Product Info
  // ─────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('What are you\npromoting?',
                style: AppTypography.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Tell us about your product — our AI will craft a viral script.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 32),

            // Product name
            Text('Product Name', style: AppTypography.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _productNameController,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'e.g., FocusFlow - Islamic Focus Timer',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter a product name' : null,
            ),

            const SizedBox(height: 24),

            // Description
            Text('Description', style: AppTypography.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              style: AppTypography.bodyLarge,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Describe what your product does, who it\'s for, and what makes it special...',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter a description' : null,
            ),

            const SizedBox(height: 16),

            // Tip
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderColor: AppColors.primary.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Be specific! Include target audience and key features for better AI scripts.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // Step 2: Upload Media
  // ─────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('Upload your\nscreen recording',
              style: AppTypography.displaySmall),
          const SizedBox(height: 8),
          Text(
            'This will appear inside a device mockup in your video. Optional but recommended.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 32),

          MediaPickerWidget(
            selectedFile: _selectedMedia,
            onPicked: (file) => setState(() => _selectedMedia = file),
            onRemoved: () => setState(() => _selectedMedia = null),
          ),

          const SizedBox(height: 24),

          GlassCard(
            padding: const EdgeInsets.all(14),
            borderColor: AppColors.primaryEnd.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.primaryEnd, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vertical videos (9:16) work best. Max ${AppConstants.maxUploadSizeMB}MB.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
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

  // ─────────────────────────────────────
  // Step 3: Tone Selection
  // ─────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('Choose the\nvibe', style: AppTypography.displaySmall),
          const SizedBox(height: 8),
          Text(
            'This sets the tone for your script, voiceover, and B-roll selection.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 32),

          ToneSelector(
            selectedTone: _selectedTone,
            onToneSelected: (tone) =>
                setState(() => _selectedTone = tone),
          ),

          const SizedBox(height: 32),

          // Summary
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Summary', style: AppTypography.titleMedium),
                const SizedBox(height: 16),
                _summaryRow('Product',
                    _productNameController.text.isNotEmpty
                        ? _productNameController.text
                        : '—'),
                _summaryRow('Media',
                    _selectedMedia != null ? 'Uploaded ✓' : 'Skipped'),
                _summaryRow('Tone',
                    '${AppConstants.toneEmojis[_selectedTone] ?? ''} $_selectedTone'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall),
          Text(value, style: AppTypography.titleMedium),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: GradientButton(
        text: _currentStep == _stepCount - 1 ? '✨ Generate Video' : 'Continue',
        icon: _currentStep == _stepCount - 1
            ? Icons.auto_awesome_rounded
            : Icons.arrow_forward_rounded,
        isLoading: _isGenerating,
        onPressed: _isGenerating ? null : _nextStep,
        width: double.infinity,
        gradient: _currentStep == _stepCount - 1
            ? AppColors.accentGradient
            : AppColors.primaryGradient,
      ),
    );
  }
}
