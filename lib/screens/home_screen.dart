import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/message_provider.dart';
import '../services/firestore_service.dart';
import 'profile_screen.dart';
import 'add_friend_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, bool> _friendOnlineStatus = {};
  final Map<String, StreamSubscription?> _friendSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _startMessageListening();
  }

  @override
  void dispose() {
    _stopMessageListening();
    _cancelFriendSubscriptions();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (userProvider.currentUser != null) {
      await friendProvider.loadFriends(userProvider.currentUser!.id);
      _startListeningToFriends();
    }
  }

  void _startListeningToFriends() {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    // Cancel existing subscriptions
    _cancelFriendSubscriptions();

    for (var friend in friendProvider.friends) {
      final friendId = friend['friendId'] as String;
      _friendSubscriptions[friendId] =
          _firestoreService.streamUserById(friendId).listen((user) {
        if (user != null && mounted) {
          setState(() {
            _friendOnlineStatus[friendId] = user.isOnline;
          });
        }
      });
    }
  }

  void _cancelFriendSubscriptions() {
    for (var subscription in _friendSubscriptions.values) {
      subscription?.cancel();
    }
    _friendSubscriptions.clear();
  }

  void _startMessageListening() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);

    if (userProvider.currentUser != null) {
      messageProvider.startListeningForMessages(userProvider.currentUser!.id);
    }
  }

  void _stopMessageListening() {
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);
    messageProvider.stopListeningForMessages();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final friendProvider = Provider.of<FriendProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FindFriend'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _stopMessageListening();
              await userProvider.logout();
            },
          ),
        ],
      ),
      body: friendProvider.friends.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No friends yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add friends to start chatting',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: friendProvider.friends.length,
              itemBuilder: (context, index) {
                final friend = friendProvider.friends[index];
                final friendId = friend['friendId'] as String;
                final isOnline = _friendOnlineStatus[friendId] ?? false;

                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        child: Text(friend['friendName'][0].toUpperCase()),
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(friend['friendName']),
                  subtitle: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.grey,
                      fontWeight:
                          isOnline ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            friendId: friend['friendId'],
                            friendName: friend['friendName'],
                            friendPhoneNumber: friend['friendPhoneNumber'],
                          ),
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          friendId: friend['friendId'],
                          friendName: friend['friendName'],
                          friendPhoneNumber: friend['friendPhoneNumber'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                    builder: (context) => const AddFriendScreen()),
              )
              .then((_) => _loadFriends());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
