import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  final DatabaseService _databaseService = DatabaseService();
  final FirestoreService _firestoreService = FirestoreService();

  // Firebase Authentication (commented out for now)
  // final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  // Get current user ID (from local database)
  String? get currentUserId => _currentUser?.id;
  String? get currentPhoneNumber => _currentUser?.phoneNumber;

  // Initialize and check if user is already logged in
  Future<void> initializeAuth() async {
    try {
      // Load user from local database
      final users = await _databaseService.getAllUsers();
      if (users.isNotEmpty) {
        _currentUser = users.first;
        // Sync to Firestore
        await _firestoreService.createOrUpdateUser(_currentUser!);
        // Set online status
        await _firestoreService.updateUserOnlineStatus(_currentUser!.id, true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
    }
  }

  // ===== FIREBASE PHONE AUTHENTICATION (COMMENTED OUT) =====
  /*
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
  Future<String?> signInWithOTP(String verificationId, String smsCode) async {
    try {
      debugPrint('Attempting to sign in with OTP');
      debugPrint('Verification ID: $verificationId');
      debugPrint('SMS Code: $smsCode');

      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await _auth.signInWithCredential(credential);
      debugPrint('Sign in successful');
      return null; // Success, no error
    } catch (e) {
      debugPrint('Error signing in with OTP: $e');
      return e.toString();
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
  */

  // ===== GOOGLE SIGN-IN (COMMENTED OUT) =====
  /*
  Future<String?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        debugPrint('User canceled Google Sign-In');
        return 'Sign-in was canceled';
      }

      debugPrint('Google user obtained: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint('Google auth obtained');
      debugPrint('Access token: ${googleAuth.accessToken}');
      debugPrint('ID token: ${googleAuth.idToken}');

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Firebase credential created');

      // Sign in to Firebase with the Google credentials
      final firebase_auth.UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      debugPrint('Firebase sign-in successful');
      debugPrint('User ID: ${userCredential.user!.uid}');
      debugPrint('Display name: ${userCredential.user!.displayName}');

      // Check if user exists in Firestore
      final existingUser =
          await _firestoreService.getUserById(userCredential.user!.uid);

      User user;
      if (existingUser != null) {
        user = existingUser;
        user = User(
          id: existingUser.id,
          phoneNumber: existingUser.phoneNumber,
          name: existingUser.name,
          createdAt: existingUser.createdAt,
          lastSeen: DateTime.now(),
          isOnline: true,
        );
        debugPrint('Existing user found in Firestore');
      } else {
        // Create new user with Google account info
        user = User(
          id: userCredential.user!.uid,
          phoneNumber: '', // No phone number for Google Sign-In
          name: userCredential.user!.displayName ?? 'User',
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          isOnline: true,
        );
        debugPrint('Creating new user in Firestore');
      }

      // Save to Firestore
      await _firestoreService.createOrUpdateUser(user);
      debugPrint('User saved to Firestore');

      // Sync to local database
      await _syncUserToLocal(user);
      debugPrint('User synced to local database');

      _currentUser = user;
      notifyListeners();
      debugPrint('Google Sign-In completed successfully');
      return null; // Success, no error
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      debugPrint('Error type: ${e.runtimeType}');
      return e.toString();
    }
  }
  */

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
      // Set offline status before logout
      await _firestoreService.updateUserOnlineStatus(_currentUser!.id, false);
    }
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
