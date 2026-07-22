import 'dart:async';

import '../../../core/utils/result.dart';
import '../domain/auth_repository.dart';

/// In-memory auth used when Supabase isn't configured. Accepts any
/// email/password so the flow is fully exercisable offline.
class DemoAuthRepository implements AuthRepository {
  final _ctrl = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchUser() {
    Future.microtask(() => _ctrl.add(_user));
    return _ctrl.stream;
  }

  @override
  Future<Result<AppUser>> signIn({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _user = AppUser(id: 'demo-user', email: email.trim(), fullName: 'Demo User');
    _ctrl.add(_user);
    return Ok(_user!);
  }

  @override
  Future<Result<AppUser>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _user = AppUser(id: 'demo-user', email: email.trim(), fullName: fullName.trim());
    _ctrl.add(_user);
    return Ok(_user!);
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async => const Ok(null);

  @override
  Future<Result<void>> signOut() async {
    _user = null;
    _ctrl.add(null);
    return const Ok(null);
  }
}
