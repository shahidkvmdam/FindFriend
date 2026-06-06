import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/friend_provider.dart';
import '../models/user.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _searchPhoneController = TextEditingController();
  final _searchFormKey = GlobalKey<FormState>();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchPhoneController.dispose();
    super.dispose();
  }

  Future<void> _searchAndAddFriend() async {
    if (!_searchFormKey.currentState!.validate()) return;

    setState(() => _isSearching = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final friendProvider =
          Provider.of<FriendProvider>(context, listen: false);

      // Check if current user is logged in
      if (userProvider.currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please register your phone number first')),
          );
        }
        return;
      }

      // Search for user by phone number
      final searchPhone = '+91${_searchPhoneController.text}';

      final result = await userProvider.getUserByPhone(searchPhone);

      if (result['success'] == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${result['error']}. Searched for: $searchPhone'),
                duration: const Duration(seconds: 5)),
          );
        }
        return;
      }

      final foundUser = result['user'] as User;
      final source = result['source'] as String;

      // Check if trying to add yourself
      if (foundUser.id == userProvider.currentUser!.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You cannot add yourself as a friend')),
          );
        }
        return;
      }

      // Add friend
      final friendData = {
        'friendId': foundUser.id,
        'friendName': foundUser.name,
        'friendPhoneNumber': foundUser.phoneNumber,
      };

      final success = await friendProvider.addFriend(
        userProvider.currentUser!.id,
        friendData,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${foundUser.name} added as friend (from $source)')),
        );
        _searchPhoneController.clear();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already friends with this user')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Friend'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Form(
              key: _searchFormKey,
              child: Column(
                children: [
                  const Icon(
                    Icons.search,
                    size: 60,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Find friends by phone number',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _searchPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Friend\'s Phone Number',
                      hintText: 'Enter friend\'s phone number',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      if (value.length < 10) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _searchAndAddFriend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: _isSearching
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Add Friend'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
