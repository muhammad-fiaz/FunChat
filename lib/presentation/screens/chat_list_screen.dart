import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../data/database/database.dart';
import 'chat_screen.dart';
import 'add_contact_screen.dart';
import 'create_group_screen.dart';
import 'settings_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FunChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'group',
                child: Row(
                  children: [
                    Icon(Icons.group_add),
                    SizedBox(width: 8),
                    Text('New Group'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'group') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          final filtered = conversations.where((c) {
            if (_searchQuery.isEmpty) return true;
            return c.peerId.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddContactScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Contact'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final conv = filtered[index];
              return _buildConversationTile(context, conv);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddContactScreen()),
        ),
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    Conversation conversation,
  ) {
    final time = DateFormat('HH:mm').format(conversation.lastMessageTime);
    final db = ref.read(databaseProvider);

    return Dismissible(
      key: Key(conversation.conversationId),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: const Text('Are you sure you want to delete this chat?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        ref
            .read(chatRepositoryProvider)
            .deleteConversation(conversation.conversationId);
      },
      child: ListTile(
        leading: conversation.type == 'group'
            ? CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: conversation.groupImage != null
                    ? FileImage(File(conversation.groupImage!))
                    : null,
                child: conversation.groupImage == null
                    ? Text(
                        (conversation.name?.isNotEmpty == true
                            ? conversation.name![0].toUpperCase()
                            : 'G'),
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              )
            : FutureBuilder<User?>(
                future:
                    (db.select(db.users)
                          ..where((t) => t.userId.equals(conversation.peerId)))
                        .getSingleOrNull(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  return CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: user?.profileImage != null
                        ? FileImage(File(user!.profileImage!))
                        : null,
                    child: user?.profileImage == null
                        ? Text(
                            conversation.peerId[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  );
                },
              ),
        title: Text(
          conversation.type == 'group'
              ? (conversation.name ?? 'Group Chat')
              : conversation.peerId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          conversation.type == 'group'
              ? '${conversation.unreadCount} members'
              : 'Tap to open chat',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (conversation.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        onTap: () {
          ref
              .read(chatRepositoryProvider)
              .markAsRead(conversation.conversationId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: conversation.conversationId,
                peerId: conversation.peerId,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSearch() {
    showSearch(context: context, delegate: _ChatSearchDelegate(ref));
  }
}

class _ChatSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  _ChatSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      data: (conversations) {
        final filtered = conversations.where((c) {
          return c.peerId.toLowerCase().contains(query.toLowerCase());
        }).toList();

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final conv = filtered[index];
            return ListTile(
              leading: CircleAvatar(child: Text(conv.peerId[0].toUpperCase())),
              title: Text(conv.peerId),
              onTap: () {
                close(context, null);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversationId: conv.conversationId,
                      peerId: conv.peerId,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}
