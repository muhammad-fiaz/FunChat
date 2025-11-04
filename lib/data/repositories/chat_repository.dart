import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../core/crypto/signal_protocol_manager.dart';
import '../../core/webrtc/webrtc_manager.dart';
import '../../core/signaling/signaling_client.dart';
import 'group_repository.dart';

class ChatRepository {
  final AppDatabase _db;
  final SignalProtocolManager _crypto;
  // ignore: unused_field
  final WebRTCManager _webrtc;
  final SignalingClient _signaling;
  final Map<String, WebRTCManager> _activeConnections = {};
  final _uuid = const Uuid();

  ChatRepository(this._db, this._crypto, this._webrtc, this._signaling);

  Future<void> initializeConnection(String peerId) async {
    if (_activeConnections.containsKey(peerId)) return;

    final webrtc = WebRTCManager();
    await webrtc.initialize();

    webrtc.onIceCandidate = (candidate) {
      _signaling.sendIceCandidate(peerId, jsonEncode(candidate.toMap()));
    };

    webrtc.messageStream.listen((message) {
      _handleIncomingMessage(peerId, message);
    });

    _activeConnections[peerId] = webrtc;

    final offer = await webrtc.createOffer();
    await _signaling.sendOffer(peerId, offer);
  }

  Future<void> handleOffer(String peerId, String offer) async {
    final webrtc = WebRTCManager();
    await webrtc.initialize();

    webrtc.onIceCandidate = (candidate) {
      _signaling.sendIceCandidate(peerId, jsonEncode(candidate.toMap()));
    };

    webrtc.messageStream.listen((message) {
      _handleIncomingMessage(peerId, message);
    });

    final answer = await webrtc.createAnswer(offer);
    await _signaling.sendAnswer(peerId, answer);

    _activeConnections[peerId] = webrtc;
  }

  Future<void> handleAnswer(String peerId, String answer) async {
    final webrtc = _activeConnections[peerId];
    if (webrtc != null) {
      await webrtc.setRemoteDescription(answer);
    }
  }

  Future<void> handleIceCandidate(String peerId, String candidate) async {
    final webrtc = _activeConnections[peerId];
    if (webrtc != null) {
      await webrtc.addIceCandidate(candidate);
    }
  }

  Future<String> sendMessage(
    String conversationId,
    String peerId,
    String text,
  ) async {
    final messageId = _uuid.v4();

    // Get conversation to check if it's a group
    final conversation = await (_db.select(
      _db.conversations,
    )..where((t) => t.conversationId.equals(conversationId))).getSingle();

    if (conversation.type == 'group') {
      // For group messages, send to all members
      final groupMembers = await GroupRepository(
        _db,
      ).getGroupMembers(conversationId);
      final memberIds = groupMembers.map((m) => m.userId).toList();

      // Store message for each recipient
      for (final memberId in memberIds) {
        if (memberId == 'me') continue; // Don't send to self

        final ciphertext = await _crypto.encryptMessage(memberId, text);

        await _db
            .into(_db.messages)
            .insert(
              MessagesCompanion.insert(
                id: '${messageId}_$memberId', // Unique ID per recipient
                conversationId: conversationId,
                senderId: 'me',
                recipientId: memberId,
                ciphertext: ciphertext,
                iv: '',
                timestamp: DateTime.now(),
                status: 'queued',
              ),
            );

        final webrtc = _activeConnections[memberId];
        if (webrtc != null) {
          webrtc.sendMessage({
            'type': 'msg',
            'id': '${messageId}_$memberId',
            'conversationId': conversationId,
            'payload': ciphertext,
            'timestamp': DateTime.now().toIso8601String(),
          });

          await (_db.update(_db.messages)
                ..where((t) => t.id.equals('${messageId}_$memberId')))
              .write(const MessagesCompanion(status: Value('sent')));
        } else {
          await _db
              .into(_db.messageQueue)
              .insert(
                MessageQueueCompanion.insert(
                  queueId: _uuid.v4(),
                  messageId: '${messageId}_$memberId',
                  conversationId: conversationId,
                  targetUserId: memberId,
                  queuedAt: DateTime.now(),
                ),
              );
          await _db
              .into(_db.pendingMessages)
              .insert(
                PendingMessagesCompanion.insert(
                  messageId: '${messageId}_$memberId',
                  targetUserId: memberId,
                  nextRetryAt: DateTime.now().add(const Duration(seconds: 30)),
                ),
              );
        }
      }
    } else {
      // Direct message - existing logic
      final ciphertext = await _crypto.encryptMessage(peerId, text);

      await _db
          .into(_db.messages)
          .insert(
            MessagesCompanion.insert(
              id: messageId,
              conversationId: conversationId,
              senderId: 'me',
              recipientId: peerId,
              ciphertext: ciphertext,
              iv: '',
              timestamp: DateTime.now(),
              status: 'queued',
            ),
          );

      final webrtc = _activeConnections[peerId];
      if (webrtc != null) {
        webrtc.sendMessage({
          'type': 'msg',
          'id': messageId,
          'conversationId': conversationId,
          'payload': ciphertext,
          'timestamp': DateTime.now().toIso8601String(),
        });

        await (_db.update(_db.messages)..where((t) => t.id.equals(messageId)))
            .write(const MessagesCompanion(status: Value('sent')));
      } else {
        await _db
            .into(_db.messageQueue)
            .insert(
              MessageQueueCompanion.insert(
                queueId: _uuid.v4(),
                messageId: messageId,
                conversationId: conversationId,
                targetUserId: peerId,
                queuedAt: DateTime.now(),
              ),
            );
        await _db
            .into(_db.pendingMessages)
            .insert(
              PendingMessagesCompanion.insert(
                messageId: messageId,
                targetUserId: peerId,
                nextRetryAt: DateTime.now().add(const Duration(seconds: 30)),
              ),
            );
      }
    }

    await (_db.update(_db.conversations)
          ..where((t) => t.conversationId.equals(conversationId)))
        .write(ConversationsCompanion(lastMessageTime: Value(DateTime.now())));

    return messageId;
  }

  Future<void> _handleIncomingMessage(
    String peerId,
    Map<String, dynamic> message,
  ) async {
    if (message['type'] == 'msg') {
      await _crypto.decryptMessage(peerId, message['payload']);
      final messageId = message['id'];
      final conversationId = message['conversationId'] as String?;

      String finalConversationId;
      if (conversationId != null) {
        // Group message - use the provided conversationId
        finalConversationId = conversationId;
      } else {
        // Direct message - find or create conversation
        final existing = await (_db.select(
          _db.conversations,
        )..where((t) => t.peerId.equals(peerId))).getSingleOrNull();

        if (existing != null) {
          finalConversationId = existing.conversationId;
        } else {
          finalConversationId = _uuid.v4();
          await _db
              .into(_db.conversations)
              .insert(
                ConversationsCompanion.insert(
                  conversationId: finalConversationId,
                  lastMessageTime: DateTime.now(),
                  peerId: peerId,
                ),
              );
        }
      }

      await _db
          .into(_db.messages)
          .insert(
            MessagesCompanion.insert(
              id: messageId,
              conversationId: finalConversationId,
              senderId: peerId,
              recipientId: 'me',
              ciphertext: message['payload'],
              iv: '',
              timestamp: DateTime.parse(message['timestamp']),
              status: 'delivered',
            ),
          );

      // Get current conversation to update unread count
      final conversation =
          await (_db.select(_db.conversations)
                ..where((t) => t.conversationId.equals(finalConversationId)))
              .getSingle();

      await (_db.update(
        _db.conversations,
      )..where((t) => t.conversationId.equals(finalConversationId))).write(
        ConversationsCompanion(
          lastMessageTime: Value(DateTime.now()),
          unreadCount: Value(conversation.unreadCount + 1),
        ),
      );
    }
  }

  Stream<List<Conversation>> watchConversations() {
    return (_db.select(
      _db.conversations,
    )..orderBy([(t) => OrderingTerm.desc(t.lastMessageTime)])).watch();
  }

  Stream<List<Message>> watchMessages(String conversationId) {
    return (_db.select(_db.messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .watch();
  }

  Future<void> markAsRead(String conversationId) async {
    await (_db.update(_db.conversations)
          ..where((t) => t.conversationId.equals(conversationId)))
        .write(const ConversationsCompanion(unreadCount: Value(0)));
  }

  Future<void> deleteConversation(String conversationId) async {
    await (_db.delete(
      _db.messages,
    )..where((t) => t.conversationId.equals(conversationId))).go();
    await (_db.delete(
      _db.conversations,
    )..where((t) => t.conversationId.equals(conversationId))).go();
  }

  void dispose() {
    for (var webrtc in _activeConnections.values) {
      webrtc.close();
      webrtc.dispose();
    }
    _activeConnections.clear();
  }
}
