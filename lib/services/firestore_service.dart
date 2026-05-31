import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/message.dart';

class FirestoreService {
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference _messagesCollection =
      FirebaseFirestore.instance.collection('messages');

  // Create or update user in Firestore
  Future<void> createOrUpdateUser(User user) async {
    try {
      await _usersCollection.doc(user.id).set({
        'id': user.id,
        'phoneNumber': user.phoneNumber,
        'name': user.name,
        'createdAt': user.createdAt.toIso8601String(),
        'lastSeen': DateTime.now().toIso8601String(),
        'isOnline': true,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to create/update user: $e');
    }
  }

  // Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return User.fromMap(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Get user by phone number
  Future<User?> getUserByPhone(String phoneNumber) async {
    try {
      final querySnapshot = await _usersCollection
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        return User.fromMap(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user by phone: $e');
    }
  }

  // Update user online status
  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _usersCollection.doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update online status: $e');
    }
  }

  // Update user last seen
  Future<void> updateUserLastSeen(String userId) async {
    try {
      await _usersCollection.doc(userId).update({
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update last seen: $e');
    }
  }

  // Stream user by ID (for real-time updates)
  Stream<User?> streamUserById(String userId) {
    return _usersCollection.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return User.fromMap(data);
      }
      return null;
    });
  }

  // Stream users by phone number (for friend finding)
  Stream<User?> streamUserByPhone(String phoneNumber) {
    return _usersCollection
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        return User.fromMap(data);
      }
      return null;
    });
  }

  // Send message to Firestore (temporary storage for delivery)
  Future<void> sendMessage(Message message) async {
    try {
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      await _messagesCollection.doc(messageId).set({
        'id': messageId,
        'senderId': message.senderId,
        'receiverId': message.receiverId,
        'content': message.content,
        'timestamp': message.timestamp.toIso8601String(),
        'isRead': message.isRead,
        'delivered': false,
      });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Mark message as delivered and delete from Firestore
  Future<void> markMessageAsDelivered(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).update({'delivered': true});
      // Delete message after marking as delivered for privacy
      await _messagesCollection.doc(messageId).delete();
    } catch (e) {
      throw Exception('Failed to mark message as delivered: $e');
    }
  }

  // Stream messages for a specific user (real-time message delivery)
  Stream<List<Message>> streamMessagesForUser(String userId) {
    return _messagesCollection
        .where('receiverId', isEqualTo: userId)
        .where('delivered', isEqualTo: false)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Message(
          id: data['id'] as String,
          senderId: data['senderId'] as String,
          receiverId: data['receiverId'] as String,
          content: data['content'] as String,
          timestamp: DateTime.parse(data['timestamp'] as String),
          isRead: data['isRead'] as bool? ?? false,
        );
      }).toList();
    });
  }

  // Delete all messages for a user (cleanup)
  Future<void> deleteMessagesForUser(String userId) async {
    try {
      final querySnapshot = await _messagesCollection
          .where('receiverId', isEqualTo: userId)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete messages: $e');
    }
  }
}
