import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

class MessageQueueRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  MessageQueueRepository(this._db);

  Future<void> queueMessage(String messageId, String conversationId, String targetUserId) async {
    await _db.into(_db.messageQueue).insert(
      MessageQueueCompanion.insert(
        queueId: _uuid.v4(),
        messageId: messageId,
        conversationId: conversationId,
        targetUserId: targetUserId,
        queuedAt: DateTime.now(),
      ),
    );
  }

  Future<List<MessageQueueData>> getQueuedMessages(String targetUserId) async {
    return await (_db.select(_db.messageQueue)
          ..where((t) => t.targetUserId.equals(targetUserId) & t.status.equals('queued'))
          ..orderBy([(t) => OrderingTerm.asc(t.queuedAt)]))
        .get();
  }

  Future<void> markAsSent(String queueId) async {
    await (_db.update(_db.messageQueue)
          ..where((t) => t.queueId.equals(queueId)))
        .write(const MessageQueueCompanion(status: Value('sent')));
  }

  Future<void> removeFromQueue(String queueId) async {
    await (_db.delete(_db.messageQueue)
          ..where((t) => t.queueId.equals(queueId)))
        .go();
  }

  Future<int> getQueuedCount(String targetUserId) async {
    final query = _db.selectOnly(_db.messageQueue)
      ..addColumns([_db.messageQueue.queueId.count()])
      ..where(_db.messageQueue.targetUserId.equals(targetUserId) & _db.messageQueue.status.equals('queued'));
    
    final result = await query.getSingle();
    return result.read(_db.messageQueue.queueId.count()) ?? 0;
  }

  Stream<int> watchQueuedCount(String targetUserId) {
    final query = _db.selectOnly(_db.messageQueue)
      ..addColumns([_db.messageQueue.queueId.count()])
      ..where(_db.messageQueue.targetUserId.equals(targetUserId) & _db.messageQueue.status.equals('queued'));
    
    return query.watchSingle().map((row) => row.read(_db.messageQueue.queueId.count()) ?? 0);
  }
}
