import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../providers/app_providers.dart';
import '../../data/database/database.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final _userIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Contact'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter User ID',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userIdController,
              decoration: InputDecoration(
                hintText: 'user@example.com',
                prefixIcon: const Icon(Icons.person),
                errorText: _errorMessage,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addContact(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _addContact,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Contact'),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'How it works:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.search,
              'Enter the User ID of the person you want to chat with',
            ),
            _buildInfoItem(
              Icons.security,
              'A secure end-to-end encrypted connection will be established',
            ),
            _buildInfoItem(
              Icons.chat,
              'Start chatting privately with your contact',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addContact() async {
    final userId = _userIdController.text.trim();
    
    if (userId.isEmpty) {
      setState(() => _errorMessage = 'Please enter a User ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final signaling = ref.read(signalingProvider);
      final userInfo = await signaling.lookupUser(userId);
      
      final crypto = ref.read(signalProtocolProvider);
      await crypto.processPreKeyBundle(userId, userInfo['preKeyBundle']);

      final db = ref.read(databaseProvider);
      await db.into(db.users).insert(
        UsersCompanion.insert(
          userId: userId,
          email: userInfo['email'] ?? userId,
          displayName: userInfo['displayName'] ?? userId,
          publicKey: userInfo['preKeyBundle']['identityKey'],
          profileImage: Value(userInfo['profileImage']),
        ),
        mode: InsertMode.insertOrReplace,
      );

      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.initializeConnection(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact $userId added successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add contact: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
}
