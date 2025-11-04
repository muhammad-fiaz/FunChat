import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../data/database/database.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String peerId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.peerId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Conversation?>(
          future:
              (db.select(db.conversations)..where(
                    (t) => t.conversationId.equals(widget.conversationId),
                  ))
                  .getSingleOrNull(),
          builder: (context, snapshot) {
            final conversation = snapshot.data;
            if (conversation == null) {
              return const Text('Loading...');
            }

            final isGroup = conversation.type == 'group';
            final displayName = isGroup
                ? (conversation.name ?? 'Group Chat')
                : widget.peerId;
            final avatarText = isGroup
                ? (conversation.name?.isNotEmpty == true
                      ? conversation.name![0].toUpperCase()
                      : 'G')
                : widget.peerId[0].toUpperCase();

            return Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage: isGroup && conversation.groupImage != null
                      ? FileImage(File(conversation.groupImage!))
                      : null,
                  child:
                      (isGroup && conversation.groupImage == null) || !isGroup
                      ? Text(
                          avatarText,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontSize: 16)),
                      Text(
                        isGroup ? 'Group' : 'Online',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptions(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
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
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == 'me';
                    return FutureBuilder<Conversation?>(
                      future:
                          (db.select(db.conversations)..where(
                                (t) => t.conversationId.equals(
                                  widget.conversationId,
                                ),
                              ))
                              .getSingleOrNull(),
                      builder: (context, snapshot) {
                        final conversation = snapshot.data;
                        final isGroup = conversation?.type == 'group';
                        return _buildMessageBubble(message, isMe, isGroup);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, bool isGroup) {
    final time = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isGroup && !isMe)
              FutureBuilder<User?>(
                future:
                    (ref
                            .read(databaseProvider)
                            .select(ref.read(databaseProvider).users)
                          ..where((t) => t.userId.equals(message.senderId)))
                        .getSingleOrNull(),
                builder: (context, snapshot) {
                  final sender = snapshot.data;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      sender?.displayName ?? message.senderId,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isMe
                            ? Colors.white70
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            Text(
              'Encrypted message',
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == 'delivered'
                        ? Icons.done_all
                        : message.status == 'sent'
                        ? Icons.done
                        : message.status == 'queued'
                        ? Icons.schedule
                        : Icons.access_time,
                    size: 14,
                    color: message.status == 'queued'
                        ? Colors.orange
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: () => _showAttachmentOptions(),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: InputBorder.none,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(
                Icons.send,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.conversationId, widget.peerId, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.purple),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Chat'),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Chat'),
                    content: const Text(
                      'Are you sure you want to delete this chat?',
                    ),
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
                if (confirm == true) {
                  await ref
                      .read(chatRepositoryProvider)
                      .deleteConversation(widget.conversationId);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) Navigator.pop(context);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
