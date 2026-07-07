import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/create/presentation/create_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/preview/presentation/preview_screen.dart';
import '../../features/create/presentation/rendering_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/result_screen.dart';

/// Faceless AI — App Router (GoRouter)
class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router(AuthBloc authBloc) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/onboarding',
      debugLogDiagnostics: true,

      // Auth redirect logic
      redirect: (context, state) {
        final authState = authBloc.state;
        final isLoginRoute = state.matchedLocation == '/login';
        final isOnboarding = state.matchedLocation == '/onboarding';

        if (authState is AuthUnauthenticated) {
          if (isOnboarding) return null;
          return '/login';
        }

        if (authState is AuthAuthenticated) {
          if (isLoginRoute || isOnboarding) return '/';
        }

        return null;
      },

      // Listen to auth changes
      refreshListenable: GoRouterRefreshStream(authBloc.stream),

      routes: [
        // ── Onboarding ──
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),

        // ── Auth ──
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),

        // ── Command Center (primary) ──
        GoRoute(
          path: '/',
          name: 'command-center',
          builder: (context, state) => const CommandCenterScreen(),
        ),

        // ── Projects List ──
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),

        // ── Create ──
        GoRoute(
          path: '/create',
          name: 'create',
          builder: (context, state) => const CreateScreen(),
        ),

        // ── Rendering ──
        GoRoute(
          path: '/rendering/:projectId',
          name: 'rendering',
          builder: (context, state) {
            final projectId = state.pathParameters['projectId']!;
            return RenderingScreen(projectId: projectId);
          },
        ),

        // ── Preview ──
        GoRoute(
          path: '/preview/:projectId',
          name: 'preview',
          builder: (context, state) {
            final projectId = state.pathParameters['projectId']!;
            return PreviewScreen(projectId: projectId);
          },
        ),

        // ── Result (immersive video player) ──
        GoRoute(
          path: '/result',
          name: 'result',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return ResultScreen(
              videoUrl: extra['video_url'] as String? ?? '',
              projectId: extra['project_id'] as String?,
              productName: extra['product_name'] as String?,
              tone: extra['tone'] as String?,
            );
          },
        ),
      ],
    );
  }
}

/// Converts a Stream into a Listenable for GoRouter refresh
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream stream) {
    stream.listen((_) => notifyListeners());
  }
}
