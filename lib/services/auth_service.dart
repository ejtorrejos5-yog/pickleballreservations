import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';
import 'mock_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Auth State ──────────────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  // ─── Sign In ─────────────────────────────────────────────────────────────────
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    if (AppConstants.isMockMode) {
      final emailClean = email.trim().toLowerCase();
      final match = MockDatabase.users.firstWhere(
        (u) => u.email.toLowerCase() == emailClean,
        orElse: () {
          final newMock = UserModel(
            uid: 'mock_${DateTime.now().millisecondsSinceEpoch}',
            name: emailClean.split('@')[0],
            email: emailClean,
            role: emailClean.contains('admin') ? AppConstants.roleAdmin : AppConstants.rolePlayer,
          );
          MockDatabase.users.add(newMock);
          return newMock;
        },
      );
      MockDatabase.currentUser = match;
      MockDatabase.publishAll();
      return match;
    }

    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (cred.user == null) return null;
    return getUserModel(cred.user!.uid);
  }

  // ─── Sign Up ─────────────────────────────────────────────────────────────────
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
    String role = AppConstants.rolePlayer,
  }) async {
    if (AppConstants.isMockMode) {
      final cleanEmail = email.trim().toLowerCase();
      if (MockDatabase.users.any((u) => u.email.toLowerCase() == cleanEmail)) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use by another account.',
        );
      }
      final model = UserModel(
        uid: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        email: cleanEmail,
        role: cleanEmail.contains('admin') ? AppConstants.roleAdmin : role,
        phone: phone?.trim(),
      );
      MockDatabase.users.add(model);
      MockDatabase.currentUser = model;
      MockDatabase.publishAll();
      return model;
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(name);

    final cleanEmail = email.trim().toLowerCase();
    final model = UserModel(
      uid: user.uid,
      name: name.trim(),
      email: cleanEmail,
      role: cleanEmail.contains('admin') ? AppConstants.roleAdmin : role,
      phone: phone?.trim(),
    );
    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(model.toFirestore());
    return model;
  }

  // ─── Sign Out ────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    if (AppConstants.isMockMode) {
      MockDatabase.currentUser = null;
      MockDatabase.publishAll();
      return;
    }
    await _auth.signOut();
  }

  // ─── User Data ───────────────────────────────────────────────────────────────
  Future<UserModel?> getUserModel(String uid) async {
    if (AppConstants.isMockMode) {
      for (final u in MockDatabase.users) {
        if (u.uid == uid) return u;
      }
      return null;
    }

    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<void> updateUserProfile(UserModel user) async {
    if (AppConstants.isMockMode) {
      final index = MockDatabase.users.indexWhere((u) => u.uid == user.uid);
      if (index != -1) {
        MockDatabase.users[index] = user;
        if (MockDatabase.currentUser?.uid == user.uid) {
          MockDatabase.currentUser = user;
        }
        MockDatabase.publishAll();
      }
      return;
    }
    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update(user.toFirestore());
  }

  Future<void> changePassword(String newPassword) async {
    if (AppConstants.isMockMode) return;
    await _auth.currentUser!.updatePassword(newPassword);
  }
}
