import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../data/database/database.dart';

class AuthService {
  final AppDatabase _db;

  AuthService(this._db);

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<String?> signUp(String email, String password, String displayName, String? profileImage) async {
    final existing = await (_db.select(_db.currentUser)..where((t) => t.email.equals(email))).getSingleOrNull();
    
    if (existing != null) {
      return 'exists';
    }

    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final passwordHash = _hashPassword(password);

    try {
      await _db.into(_db.currentUser).insert(
        CurrentUserCompanion.insert(
          userId: userId,
          email: email,
          displayName: displayName,
          passwordHash: passwordHash,
          profileImage: Value(profileImage),
          createdAt: DateTime.now(),
        ),
      );
      return null;
    } catch (e) {
      return 'error';
    }
  }

  Future<CurrentUserData?> signIn(String email, String password) async {
    final passwordHash = _hashPassword(password);
    
    final user = await (_db.select(_db.currentUser)
          ..where((t) => t.email.equals(email) & t.passwordHash.equals(passwordHash)))
        .getSingleOrNull();

    return user;
  }

  Future<CurrentUserData?> getCurrentUser() async {
    return await _db.select(_db.currentUser).getSingleOrNull();
  }

  Future<void> signOut() async {
    await _db.delete(_db.currentUser).go();
  }

  Future<void> updateProfile(String userId, String displayName, String? profileImage) async {
    await (_db.update(_db.currentUser)..where((t) => t.userId.equals(userId)))
        .write(CurrentUserCompanion(
      displayName: Value(displayName),
      profileImage: Value(profileImage),
    ));
  }
}
