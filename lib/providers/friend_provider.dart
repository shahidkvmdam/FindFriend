import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class FriendProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> get friends => _friends;

  // Load friends for a user
  Future<void> loadFriends(String userId) async {
    try {
      _friends = await _databaseService.getFriends(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading friends: $e');
    }
  }

  // Add friend
  Future<bool> addFriend(String userId, Map<String, dynamic> friendData) async {
    try {
      // Check if already friends
      final isAlreadyFriend = await _databaseService.isFriend(userId, friendData['friendId']);
      if (isAlreadyFriend) {
        return false;
      }

      final friendWithTimestamp = {
        ...friendData,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': userId,
        'addedAt': DateTime.now().toIso8601String(),
      };

      await _databaseService.addFriend(friendWithTimestamp);
      await loadFriends(userId);
      return true;
    } catch (e) {
      debugPrint('Error adding friend: $e');
      return false;
    }
  }

  // Remove friend
  Future<bool> removeFriend(String userId, String friendId) async {
    try {
      await _databaseService.removeFriend(userId, friendId);
      await loadFriends(userId);
      return true;
    } catch (e) {
      debugPrint('Error removing friend: $e');
      return false;
    }
  }

  // Check if user is friend
  Future<bool> isFriend(String userId, String friendId) async {
    try {
      return await _databaseService.isFriend(userId, friendId);
    } catch (e) {
      debugPrint('Error checking friendship: $e');
      return false;
    }
  }

  // Clear friends (for testing)
  Future<void> clearFriends() async {
    _friends.clear();
    notifyListeners();
  }
}
