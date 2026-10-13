import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// State for local/demo session when testing without live Supabase cloud instance.
class DemoAuthState {
  final bool isAuthenticated;
  final String role;
  final String email;

  const DemoAuthState({
    this.isAuthenticated = false,
    this.role = 'admin',
    this.email = 'admin@rentify.app',
  });
}

class DemoAuthNotifier extends StateNotifier<DemoAuthState> {
  DemoAuthNotifier() : super(const DemoAuthState());

  void loginAsAdmin({String email = 'admin@rentify.app'}) {
    state = DemoAuthState(isAuthenticated: true, role: 'admin', email: email);
  }

  void loginAsTenant({String email = 'tenant@rentify.app'}) {
    state = DemoAuthState(isAuthenticated: true, role: 'tenant', email: email);
  }

  void logout() {
    state = const DemoAuthState(isAuthenticated: false);
  }
}

final demoAuthProvider =
    StateNotifierProvider<DemoAuthNotifier, DemoAuthState>((ref) {
  return DemoAuthNotifier();
});

/// Watches Supabase's real-time auth state stream.
/// GoRouter reads this to redirect unauthenticated users.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Returns the currently authenticated Supabase user, or null.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user;
});

/// Returns true if either a Supabase session or demo session is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final supabaseAuth = ref.watch(authStateProvider);
  if (supabaseAuth.value?.session != null) return true;
  final demoAuth = ref.watch(demoAuthProvider);
  return demoAuth.isAuthenticated;
});

/// Returns the user's role ('admin' | 'tenant').
final currentRoleProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    return (user.userMetadata?['role'] as String?) ?? 'tenant';
  }
  final demoAuth = ref.watch(demoAuthProvider);
  return demoAuth.role;
});
