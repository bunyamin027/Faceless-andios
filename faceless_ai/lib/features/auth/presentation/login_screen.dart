import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../bloc/auth_bloc.dart';

/// Login / Sign Up Screen
/// Premium dark UI with glassmorphism form
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() => _isSignUp = !_isSignUp);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_isSignUp) {
      context.read<AuthBloc>().add(AuthSignUpRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
          ));
    } else {
      context.read<AuthBloc>().add(AuthSignInRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
        if (state is AuthAuthenticated) {
          context.go('/home');
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F0A1A),
                AppColors.background,
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // ── Logo & Title ──
                    _buildHeader(),

                    const SizedBox(height: 48),

                    // ── Form ──
                    _buildForm(),

                    const SizedBox(height: 24),

                    // ── Submit Button ──
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return GradientButton(
                          text: _isSignUp ? 'Create Account' : 'Sign In',
                          icon: Icons.arrow_forward_rounded,
                          isLoading: state is AuthLoading,
                          onPressed: _submit,
                          width: double.infinity,
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Divider ──
                    _buildDivider(),

                    const SizedBox(height: 20),

                    // ── Google Sign In ──
                    _buildGoogleButton(),

                    const SizedBox(height: 32),

                    // ── Toggle Sign In / Sign Up ──
                    _buildToggle(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Gradient icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.primaryGlow(opacity: 0.4),
          ),
          child: const Icon(
            Icons.movie_creation_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Faceless AI',
          style: AppTypography.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Create viral videos in seconds',
          style: AppTypography.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Name field (sign up only)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isSignUp
                  ? Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: AppTypography.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'Your name',
                            prefixIcon: Icon(Icons.person_outline_rounded,
                                color: AppColors.textTertiary),
                          ),
                          validator: (v) => _isSignUp && (v == null || v.isEmpty)
                              ? 'Enter your name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            // Email
            TextFormField(
              controller: _emailController,
              style: AppTypography.bodyLarge,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined,
                    color: AppColors.textTertiary),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _passwordController,
              style: AppTypography.bodyLarge,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppColors.textTertiary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your password';
                if (v.length < 6) return 'Min. 6 characters';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.glassBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: AppTypography.caption),
        ),
        const Expanded(child: Divider(color: AppColors.glassBorder)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          context.read<AuthBloc>().add(AuthGoogleSignInRequested());
        },
        icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        label: Text(
          'Continue with Google',
          style: AppTypography.labelLarge,
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.glassBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp
              ? 'Already have an account?'
              : "Don't have an account?",
          style: AppTypography.bodySmall,
        ),
        TextButton(
          onPressed: _toggleMode,
          child: Text(
            _isSignUp ? 'Sign In' : 'Sign Up',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
