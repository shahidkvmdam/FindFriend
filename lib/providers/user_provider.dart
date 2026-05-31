import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  final DatabaseService _databaseService = DatabaseService();
  final FirestoreService _firestoreService = FirestoreService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  // Get current Firebase user
  String? get currentFirebaseUserId => _auth.currentUser?.uid;
  String? get currentPhoneNumber => _auth.currentUser?.phoneNumber;

  // Initialize and check if user is already logged in
  Future<void> initializeAuth() async {
    try {
      _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) async {
        if (firebaseUser != null) {
          // User is logged in with Firebase, load user data from Firestore
          try {
            final firestoreUser =
                await _firestoreService.getUserById(firebaseUser.uid);
            if (firestoreUser != null) {
              _currentUser = firestoreUser;
              // Also sync to local database
              await _syncUserToLocal(firestoreUser);
              // Set online status
              await _firestoreService.updateUserOnlineStatus(
                  firebaseUser.uid, true);
              notifyListeners();
            }
          } catch (e) {
            debugPrint('Error loading user from Firestore: $e');
          }
        } else {
          _currentUser = null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Error initializing auth: $e');
    }
  }

  // Sync user data to local database
  Future<void> _syncUserToLocal(User user) async {
    final existingUser = await _databaseService.getUser(user.phoneNumber);
    if (existingUser != null) {
      await _databaseService.updateUser(user);
    } else {
      await _databaseService.insertUser(user);
    }
  }

  // Verify phone number and send OTP
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(String verificationId) onCodeSent,
    Function(String errorMessage) onError,
  ) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted:
            (firebase_auth.PhoneAuthCredential credential) async {
          // Auto-retrieval or instant verification
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle timeout
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // Sign in with OTP
  Future<bool> signInWithOTP(String verificationId, String smsCode) async {
    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint('Error signing in with OTP: $e');
      return false;
    }
  }

  // Create or update user profile after successful authentication
  Future<bool> createOrUpdateUserProfile(String name) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return false;

    try {
      final phoneNumber = firebaseUser.phoneNumber;
      if (phoneNumber == null) return false;

      // Check if user already exists in Firestore
      final existingUser =
          await _firestoreService.getUserById(firebaseUser.uid);

      User user;
      if (existingUser != null) {
        // Update existing user
        user = User(
          id: existingUser.id,
          phoneNumber: phoneNumber,
          name: name,
          createdAt: existingUser.createdAt,
          lastSeen: existingUser.lastSeen,
          isOnline: true,
        );
      } else {
        // Create new user
        user = User(
          id: firebaseUser.uid,
          phoneNumber: phoneNumber,
          name: name,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          isOnline: true,
        );
      }

      // Save to Firestore
      await _firestoreService.createOrUpdateUser(user);

      // Sync to local database
      await _syncUserToLocal(user);

      _currentUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error creating/updating user profile: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    if (_currentUser != null) {
      // Set offline status before logout
      await _firestoreService.updateUserOnlineStatus(_currentUser!.id, false);
    }
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // Update user profile
  Future<bool> updateProfile(String name) async {
    if (_currentUser == null) return false;

    try {
      final updatedUser = User(
        id: _currentUser!.id,
        phoneNumber: _currentUser!.phoneNumber,
        name: name,
        createdAt: _currentUser!.createdAt,
        lastSeen: _currentUser!.lastSeen,
        isOnline: _currentUser!.isOnline,
      );

      // Update Firestore
      await _firestoreService.createOrUpdateUser(updatedUser);

      // Update local database
      await _databaseService.updateUser(updatedUser);

      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  // Get user by phone number (for finding friends)
  Future<User?> getUserByPhone(String phoneNumber) async {
    try {
      // Try Firestore first
      final firestoreUser = await _firestoreService.getUserByPhone(phoneNumber);
      if (firestoreUser != null) {
        return firestoreUser;
      }

      // Fallback to local database
      return await _databaseService.getUser(phoneNumber);
    } catch (e) {
      debugPrint('Error getting user by phone: $e');
      return null;
    }
  }

  // Update online status
  Future<void> setOnlineStatus(bool isOnline) async {
    if (_currentUser == null) return;

    try {
      await _firestoreService.updateUserOnlineStatus(
          _currentUser!.id, isOnline);

      final updatedUser = User(
        id: _currentUser!.id,
        phoneNumber: _currentUser!.phoneNumber,
        name: _currentUser!.name,
        createdAt: _currentUser!.createdAt,
        lastSeen: DateTime.now(),
        isOnline: isOnline,
      );

      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // Update last seen
  Future<void> updateLastSeen() async {
    if (_currentUser == null) return;

    try {
      await _firestoreService.updateUserLastSeen(_currentUser!.id);
    } catch (e) {
      debugPrint('Error updating last seen: $e');
    }
  }
}
