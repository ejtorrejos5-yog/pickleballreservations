import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

import '../core/constants/app_constants.dart';
import '../services/mock_database.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = true;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthProvider() {
    if (AppConstants.isMockMode) {
      _initMock();
    } else {
      _authService.authStateChanges.listen(_onAuthStateChanged);
    }
  }

  void _initMock() {
    MockDatabase.authController.stream.listen((mockUser) {
      _currentUser = mockUser;
      _isLoading = false;
      notifyListeners();
    });
    // Trigger initial publish
    MockDatabase.publishAll();
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    } else {
      try {
        _currentUser = await _authService.getUserModel(firebaseUser.uid);
      } catch (e) {
        // Firestore permission-denied or network issue — stay logged out
        _error = _mapGenericError(e.toString());
        _currentUser = null;
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Sign In ─────────────────────────────────────────────────────────────────
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _error = null;
    notifyListeners();
    try {
      _currentUser = await _authService.signIn(email: email, password: password);
      notifyListeners();
      return _currentUser != null;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _error = _mapGenericError(e.toString());
      notifyListeners();
      return false;
    }
  }

  // ─── Sign Up ─────────────────────────────────────────────────────────────────
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    _error = null;
    notifyListeners();
    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _error = _mapGenericError(e.toString());
      notifyListeners();
      return false;
    }
  }

  // ─── Sign Out ────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  void enableDemoMode() {
    AppConstants.isMockMode = true;
    MockDatabase.init();
    MockDatabase.currentUser = MockDatabase.users[0]; // Auto-login as EJ Torrejos (Admin)
    _initMock();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─── Error Mapping ────────────────────────────────────────────────────────────
  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Console.';
      case 'invalid-api-key':
      case 'app-not-authorized':
        return '⚙️ Firebase is not configured. Run: flutterfire configure';
      default:
        return 'Authentication failed (code: $code). Check Firebase setup.';
    }
  }

  /// Maps generic (non-FirebaseAuthException) errors
  String _mapGenericError(String message) {
    if (message.contains('permission-denied') ||
        message.contains('Missing or insufficient permissions')) {
      return '🔒 Firestore permission denied. Open Firebase Console → Firestore → Rules and allow authenticated access.';
    }
    if (message.contains('ApiException') ||
        message.contains('CONFIGURATION_NOT_FOUND') ||
        message.contains('invalid_grant') ||
        message.contains('API key')) {
      return '⚙️ Firebase is not configured yet. Run: flutterfire configure';
    }
    if (message.contains('network') || message.contains('SocketException')) {
      return 'Network error. Check your internet connection.';
    }
    if (message.contains('XMLHttpRequest') || message.contains('Failed to fetch')) {
      return '⚙️ Firebase not configured. Replace placeholder keys in firebase_options.dart';
    }
    return 'Error: $message';
  }
}
