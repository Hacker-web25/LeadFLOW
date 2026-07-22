import 'package:flutter/foundation.dart';

import '../../../core/utils/result.dart';

/// Signed-in user identity — the app only needs id, email, name.
@immutable
class AppUser {
  const AppUser({required this.id, required this.email, this.fullName});
  final String id;
  final String email;
  final String? fullName;
}

/// Contract for authentication. Presentation depends only on this.
abstract interface class AuthRepository {
  Stream<AppUser?> watchUser();
  AppUser? get currentUser;

  Future<Result<AppUser>> signIn({required String email, required String password});
  Future<Result<AppUser>> signUp({
    required String email,
    required String password,
    required String fullName,
  });
  Future<Result<void>> sendPasswordReset(String email);
  Future<Result<void>> signOut();
}
