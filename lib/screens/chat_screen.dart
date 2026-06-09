import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../providers/user_provider.dart';
import '../providers/message_provider.dart';

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendPhoneNumber;

  const ChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.friendPhoneNumber,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startListening();
    // Listen for message changes to auto-scroll
    final messageProvider = Provider.of<MessageProvider>(context, listen: false);
    messageProvider.addListener(_onMessagesChanged);
  }

  void _onMessagesChanged() {
    // Scroll to bottom when messages are updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _startListening() {
    debugPrint('_startListening called');
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);

    debugPrint('currentUser: ${userProvider.currentUser}');
    if (userProvider.currentUser != null) {
      debugPrint('Starting message listening for userId: ${userProvider.currentUser!.id}');
      messageProvider.startListeningForMessages(userProvider.currentUser!.id);
    } else {
      debugPrint('currentUser is null, cannot start listening');
    }
  }

  Future<void> _loadMessages() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);

    if (userProvider.currentUser != null) {
      await messageProvider.loadMessages(
        userProvider.currentUser!.id,
        widget.friendId,
      );
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);

    if (userProvider.currentUser == null) return;

    setState(() => _isLoading = true);

    final success = await messageProvider.sendTextMessage(
      userProvider.currentUser!.id,
      widget.friendId,
      _messageController.text.trim(),
    );

    if (success) {
      _messageController.clear();
      // Reload messages to ensure they're displayed
      await _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message. Firebase may not be configured.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  Future<void> _deleteMessage(Message message) async {
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
            'This will permanently delete this message. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await messageProvider.deleteMessage(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final messageProvider = Provider.of<MessageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.friendName),
            Text(
              widget.friendPhoneNumber,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messageProvider.messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Start a conversation!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messageProvider.messages.length,
                    itemBuilder: (context, index) {
                      final message = messageProvider.messages[index];
                      final isMe =
                          message.senderId == userProvider.currentUser?.id;

                      return GestureDetector(
                        onLongPress: () => _deleteMessage(message),
                        child: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            constraints: const BoxConstraints(
                              maxWidth: 280,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.content,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        isMe ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);
    messageProvider.removeListener(_onMessagesChanged);
    messageProvider.stopListeningForMessages();
    super.dispose();
  }
}
