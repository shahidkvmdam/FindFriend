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

  // Get current user ID (from local database)
  String? get currentUserId => _currentUser?.id;
  String? get currentPhoneNumber => _currentUser?.phoneNumber;

  // Initialize and check if user is already logged in
  Future<void> initializeAuth() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final user = await _firestoreService.getUserById(firebaseUser.uid);
        if (user != null) {
          _currentUser = user;
          await _firestoreService.updateUserOnlineStatus(user.id, true);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
    }
  }

  // Verify phone number and send OTP
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(String verificationId, int? resendToken) onCodeSent,
    Function(String errorMessage) onError,
  ) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted:
            (firebase_auth.PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // Sign in with OTP and load/create profile
  Future<Map<String, dynamic>> signInWithOTP(
      String verificationId, String smsCode) async {
    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final result = await _auth.signInWithCredential(credential);
      final firebaseUser = result.user;
      if (firebaseUser == null) {
        return {'success': false, 'error': 'Sign-in failed'};
      }

      final existingUser =
          await _firestoreService.getUserById(firebaseUser.uid);
      if (existingUser != null) {
        _currentUser = existingUser;
        await _firestoreService.updateUserOnlineStatus(existingUser.id, true);
        notifyListeners();
        return {'success': true, 'isNewUser': false};
      }

      return {'success': true, 'isNewUser': true};
    } catch (e) {
      debugPrint('Error signing in with OTP: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Create or update user profile after successful authentication
  Future<String?> createOrUpdateUserProfile(String name) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return 'Not authenticated';

    try {
      final phoneNumber = firebaseUser.phoneNumber;
      if (phoneNumber == null) return 'Phone number not available';

      final user = User(
        id: firebaseUser.uid,
        phoneNumber: phoneNumber,
        name: name,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      await _firestoreService.createOrUpdateUser(user);
      await _databaseService.insertUser(user);

      _currentUser = user;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Error creating/updating user profile: $e');
      return e.toString();
    }
  }

  // ===== LOCAL AUTHENTICATION (CURRENTLY ACTIVE) =====

  // Register user with phone number (local authentication)
  Future<Map<String, dynamic>> registerUser(
      String phoneNumber, String name) async {
    try {
      // Generate a unique ID based on phone number
      final userId = 'user_${phoneNumber.replaceAll('+', '')}';

      // Check if user already exists
      final existingUser = await _databaseService.getUser(phoneNumber);

      User user;
      if (existingUser != null) {
        // Update existing user
        user = User(
          id: existingUser.id,
          phoneNumber: phoneNumber,
          name: name,
          createdAt: existingUser.createdAt,
          lastSeen: DateTime.now(),
          isOnline: true,
        );
        // Update local database
        await _databaseService.updateUser(user);
      } else {
        // Create new user
        user = User(
          id: userId,
          phoneNumber: phoneNumber,
          name: name,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          isOnline: true,
        );
        // Save to local database
        await _databaseService.insertUser(user);
      }

      // Save to Firestore
      await _firestoreService.createOrUpdateUser(user);

      _currentUser = user;
      notifyListeners();
      return {'success': true, 'error': null};
    } catch (e) {
      debugPrint('Error registering user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Login user with phone number (local authentication)
  Future<bool> loginUser(String phoneNumber) async {
    try {
      // Check if user exists in local database
      final user = await _databaseService.getUser(phoneNumber);
      if (user == null) {
        return false; // User not found
      }

      // Update last seen and online status
      final updatedUser = User(
        id: user.id,
        phoneNumber: user.phoneNumber,
        name: user.name,
        createdAt: user.createdAt,
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      // Update local database
      await _databaseService.updateUser(updatedUser);

      // Update Firestore
      await _firestoreService.createOrUpdateUser(updatedUser);
      await _firestoreService.updateUserOnlineStatus(updatedUser.id, true);

      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error logging in user: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    if (_currentUser != null) {
      await _firestoreService.updateUserOnlineStatus(_currentUser!.id, false);
    }
    _currentUser = null;
    await _auth.signOut();
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
  Future<Map<String, dynamic>> getUserByPhone(String phoneNumber) async {
    try {
      // Try Firestore first
      final firestoreUser = await _firestoreService.getUserByPhone(phoneNumber);
      if (firestoreUser != null) {
        return {'success': true, 'user': firestoreUser, 'source': 'Firestore'};
      }

      // Fallback to local database
      final localUser = await _databaseService.getUser(phoneNumber);
      if (localUser != null) {
        return {'success': true, 'user': localUser, 'source': 'Local'};
      }

      return {
        'success': false,
        'error': 'User not found in Firestore or local database'
      };
    } catch (e) {
      debugPrint('Error getting user by phone: $e');
      return {'success': false, 'error': e.toString()};
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
