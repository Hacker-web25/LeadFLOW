import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  AppUser? _map(User? u) => u == null
      ? null
      : AppUser(
          id: u.id,
          email: u.email ?? '',
          fullName: u.userMetadata?['full_name'] as String?,
        );

  @override
  AppUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Stream<AppUser?> watchUser() {
    late final StreamController<AppUser?> ctrl;
    ctrl = StreamController<AppUser?>.broadcast(
      onListen: () => ctrl.add(_map(_client.auth.currentUser)),
    );
    final sub = _client.auth.onAuthStateChange
        .listen((event) => ctrl.add(_map(event.session?.user)));
    ctrl.onCancel = () => sub.cancel();
    return ctrl.stream;
  }

  @override
  Future<Result<AppUser>> signIn({required String email, required String password}) async {
    try {
      final res = await _client.auth
          .signInWithPassword(email: email.trim(), password: password);
      final user = _map(res.user);
      if (user == null) return const Err(AppFailure('Sign-in failed.'));
      return Ok(user);
    } on AuthException catch (e) {
      return Err(AppFailure(_humanize(e)));
    } catch (e) {
      return Err(AppFailure('Could not sign in. Check your connection.', cause: e));
    }
  }

  @override
  Future<Result<AppUser>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      final user = _map(res.user);
      if (user == null) {
        return const Err(AppFailure(
            'Check your email to confirm your account, then sign in.'));
      }
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'full_name': fullName.trim(),
        });
      } catch (_) {}
      return Ok(user);
    } on AuthException catch (e) {
      return Err(AppFailure(_humanize(e)));
    } catch (e) {
      return Err(AppFailure('Could not create your account.', cause: e));
    }
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      return const Ok(null);
    } catch (e) {
      return Err(AppFailure('Could not send the reset link.', cause: e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Ok(null);
    } catch (e) {
      return Err(AppFailure('Could not sign out.', cause: e));
    }
  }

  String _humanize(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid') && m.contains('credentials')) return 'Wrong email or password.';
    if (m.contains('already registered') || m.contains('user already')) {
      return 'An account with this email already exists.';
    }
    if (m.contains('email not confirmed')) return 'Check your email to confirm your account first.';
    if (m.contains('rate limit')) return 'Too many attempts. Try again shortly.';
    return e.message;
  }
}
