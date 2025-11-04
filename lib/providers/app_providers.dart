import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/database.dart';
import '../core/crypto/signal_protocol_manager.dart';
import '../core/webrtc/webrtc_manager.dart';
import '../core/signaling/signaling_client.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/message_queue_repository.dart';
import '../core/auth/auth_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final authServiceProvider = Provider<AuthService>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthService(db);
});

final signalProtocolProvider = Provider<SignalProtocolManager>((ref) {
  return SignalProtocolManager();
});

final webrtcProvider = Provider<WebRTCManager>((ref) {
  final webrtc = WebRTCManager();
  ref.onDispose(() {
    webrtc.close();
    webrtc.dispose();
  });
  return webrtc;
});

final signalingProvider = Provider<SignalingClient>((ref) {
  final client = SignalingClient();
  ref.onDispose(() => client.dispose());
  return client;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final crypto = ref.watch(signalProtocolProvider);
  final webrtc = ref.watch(webrtcProvider);
  final signaling = ref.watch(signalingProvider);
  
  final repo = ChatRepository(db, crypto, webrtc, signaling);
  ref.onDispose(() => repo.dispose());
  return repo;
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return GroupRepository(db);
});

final messageQueueProvider = Provider<MessageQueueRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return MessageQueueRepository(db);
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchConversations();
});

final messagesProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchMessages(conversationId);
});

final currentUserIdProvider = NotifierProvider<CurrentUserIdNotifier, String?>(CurrentUserIdNotifier.new);

class CurrentUserIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  
  void setUserId(String userId) => state = userId;
}

final themeProvider = NotifierProvider<ThemeNotifier, bool>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void toggle() => state = !state;
  void setDark(bool isDark) => state = isDark;
}
