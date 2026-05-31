import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class MessageProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final FirestoreService _firestoreService = FirestoreService();

  List<Message> _messages = [];
  List<Message> get messages => _messages;

  StreamSubscription? _messageSubscription;

  // Load messages between two users from local database
  Future<void> loadMessages(String userId1, String userId2) async {
    try {
      _messages = await _databaseService.getMessages(userId1, userId2);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  // Start listening for incoming messages from Firestore
  void startListeningForMessages(String userId) {
    _messageSubscription?.cancel();
    _messageSubscription =
        _firestoreService.streamMessagesForUser(userId).listen(
      (messages) async {
        for (var message in messages) {
          // Save to local database
          await _databaseService.insertMessage(message);
          // Mark as delivered and delete from Firestore
          await _firestoreService.markMessageAsDelivered(message.id);
        }
        // Reload messages from local database
        if (_messages.isNotEmpty) {
          final userId1 = _messages.first.senderId;
          final userId2 = _messages.first.receiverId;
          await loadMessages(userId1, userId2);
        }
      },
      onError: (e) {
        debugPrint('Error listening for messages: $e');
      },
    );
  }

  // Stop listening for messages
  void stopListeningForMessages() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
  }

  // Send text message via Firestore for delivery
  Future<bool> sendTextMessage(
      String senderId, String receiverId, String content) async {
    try {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        timestamp: DateTime.now(),
      );

      // Send to Firestore for delivery
      await _firestoreService.sendMessage(message);

      // Also save to local database for sender
      await _databaseService.insertMessage(message);

      _messages.add(message);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error sending text message: $e');
      return false;
    }
  }

  // Delete message
  Future<bool> deleteMessage(Message message) async {
    try {
      // Delete message from local database
      await _databaseService.deleteMessage(message.id);

      // Remove from local list
      _messages.removeWhere((m) => m.id == message.id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }

  // Mark message as read
  Future<void> markAsRead(String messageId) async {
    try {
      await _databaseService.markMessageAsRead(messageId);

      // Update local message
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = Message(
          id: _messages[index].id,
          senderId: _messages[index].senderId,
          receiverId: _messages[index].receiverId,
          content: _messages[index].content,
          timestamp: _messages[index].timestamp,
          isRead: true,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  // Mark all messages as read
  Future<void> markAllAsRead(String senderId, String receiverId) async {
    try {
      await _databaseService.markAllMessagesAsRead(senderId, receiverId);

      // Update local messages
      _messages = _messages.map((m) {
        if (m.senderId == senderId && m.receiverId == receiverId && !m.isRead) {
          return Message(
            id: m.id,
            senderId: m.senderId,
            receiverId: m.receiverId,
            content: m.content,
            timestamp: m.timestamp,
            isRead: true,
          );
        }
        return m;
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all messages as read: $e');
    }
  }

  // Get unread count
  Future<int> getUnreadCount(String userId) async {
    try {
      return await _databaseService.getUnreadCount(userId);
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // Clear messages (for testing)
  Future<void> clearMessages() async {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopListeningForMessages();
    super.dispose();
  }
}
