import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

// ═══════════════════════════════════════════
// Events
// ═══════════════════════════════════════════

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String? displayName;
  const AuthSignUpRequested({
    required this.email,
    required this.password,
    this.displayName,
  });
  @override
  List<Object?> get props => [email, password, displayName];
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthSignInRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthGoogleSignInRequested extends AuthEvent {}

class AuthAppleSignInRequested extends AuthEvent {}

class AuthSignOutRequested extends AuthEvent {}

// ═══════════════════════════════════════════
// States
// ═══════════════════════════════════════════

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user.id];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════
// BLoC
// ═══════════════════════════════════════════

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckAuth);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthSignInRequested>(_onSignIn);
    on<AuthGoogleSignInRequested>(_onGoogleSignIn);
    on<AuthAppleSignInRequested>(_onAppleSignIn);
    on<AuthSignOutRequested>(_onSignOut);

    // Listen to auth state changes
    SupabaseService.authStateChanges.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        if (SupabaseService.currentUser != null) {
          add(AuthCheckRequested());
        }
      } else if (event == AuthChangeEvent.signedOut) {
        add(AuthCheckRequested());
      }
    });
  }

  Future<void> _onCheckAuth(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = SupabaseService.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await SupabaseService.signUp(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );

      if (response.user != null) {
        emit(AuthAuthenticated(response.user!));
      } else {
        emit(const AuthError('Sign up failed. Please check your email.'));
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await SupabaseService.signIn(
        email: event.email,
        password: event.password,
      );

      if (response.user != null) {
        emit(AuthAuthenticated(response.user!));
      } else {
        emit(const AuthError('Invalid email or password.'));
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onGoogleSignIn(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await SupabaseService.signInWithGoogle();
      // Auth state change listener will handle the rest
    } catch (e) {
      emit(AuthError('Google sign-in failed: $e'));
    }
  }

  Future<void> _onAppleSignIn(
    AuthAppleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await SupabaseService.signInWithApple();
      if (response.user != null) {
        emit(AuthAuthenticated(response.user!));
      } else {
        emit(const AuthError('Apple sign-in failed.'));
      }
    } catch (e) {
      emit(AuthError('Apple sign-in failed: $e'));
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await SupabaseService.signOut();
    emit(AuthUnauthenticated());
  }
}
