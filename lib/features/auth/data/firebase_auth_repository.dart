import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({firebase.FirebaseAuth? auth})
      : _auth = auth ?? firebase.FirebaseAuth.instance;
  final firebase.FirebaseAuth _auth;
  static Future<void>? _googleInitialization;
  static bool _googleReady = false;

  Future<void> _initializeGoogle() async {
    _googleInitialization ??= GoogleSignIn.instance.initialize();
    try {
      await _googleInitialization!;
      _googleReady = true;
    } catch (_) {
      _googleInitialization = null;
      rethrow;
    }
  }
  Stream<firebase.User?> get sessionChanges => _auth.userChanges();
  firebase.User? get currentUser => _auth.currentUser;
  @override
  Future<void> register(String name, String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await result.user?.updateDisplayName(name.trim());
  }
  @override
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }
  @override
  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());
  Future<void> signOut() async {
    // Firebase determina la sesión de MoodMusic, incluso si falla la limpieza de Google.
    await _auth.signOut();
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        debugPrint('Sesión Firebase cerrada; no se pudo limpiar el estado local de Google.');
      }
    }
  }
  Future<void> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay sesión activa');
    await user.updateDisplayName(name.trim());
  }
  @override
  Future<void> signInWithProvider(AuthProvider provider) async {
    try {
      await _initializeGoogle();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw firebase.FirebaseAuthException(code: 'google-platform-unsupported');
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw firebase.FirebaseAuthException(code: 'google-missing-id-token');
      }
      final credential = firebase.GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      debugPrint('Google Sign-In falló: ${error.code.name}');
      throw firebase.FirebaseAuthException(code: 'google-${error.code.name}', message: error.toString());
    } catch (error) {
      debugPrint('Google Sign-In falló con error inesperado: $error');
      rethrow;
    }
  }
}
