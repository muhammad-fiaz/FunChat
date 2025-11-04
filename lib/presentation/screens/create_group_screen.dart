import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../providers/app_providers.dart';
import '../../data/database/database.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  String? _groupImagePath;
  final List<String> _selectedMembers = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'group_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      setState(() => _groupImagePath = savedImage.path);
    }
  }

  Future<void> _createGroup() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter group name')),
      );
      return;
    }

    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final currentUserId = ref.read(currentUserIdProvider);
    final groupRepo = ref.read(groupRepositoryProvider);

    await groupRepo.createGroup(
      _nameController.text.trim(),
      currentUserId ?? '',
      _groupImagePath,
      _selectedMembers,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    backgroundImage: _groupImagePath != null ? FileImage(File(_groupImagePath!)) : null,
                    child: _groupImagePath == null
                        ? Icon(Icons.group_add, size: 40, color: Theme.of(context).colorScheme.primary)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    prefixIcon: Icon(Icons.group),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Add Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_selectedMembers.length} selected', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<User>>(
              future: db.select(db.users).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!;
                if (users.isEmpty) {
                  return const Center(child: Text('No contacts available'));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedMembers.contains(user.userId);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedMembers.add(user.userId);
                          } else {
                            _selectedMembers.remove(user.userId);
                          }
                        });
                      },
                      secondary: CircleAvatar(
                        backgroundImage: user.profileImage != null ? FileImage(File(user.profileImage!)) : null,
                        child: user.profileImage == null ? Text(user.displayName[0].toUpperCase()) : null,
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(user.email),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
