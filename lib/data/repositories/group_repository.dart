import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

class GroupRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  GroupRepository(this._db);

  Future<String> createGroup(String name, String createdBy, String? groupImage, List<String> memberIds) async {
    final groupId = _uuid.v4();
    
    await _db.into(_db.conversations).insert(
      ConversationsCompanion.insert(
        conversationId: groupId,
        type: const Value('group'),
        name: Value(name),
        groupImage: Value(groupImage),
        createdBy: Value(createdBy),
        lastMessageTime: DateTime.now(),
        peerId: createdBy,
      ),
    );

    await _db.into(_db.groupMembers).insert(
      GroupMembersCompanion.insert(
        groupId: groupId,
        userId: createdBy,
        role: const Value('admin'),
        joinedAt: DateTime.now(),
        isHandshakeComplete: const Value(true),
      ),
    );

    for (final memberId in memberIds) {
      if (memberId != createdBy) {
        final exists = await (_db.select(_db.groupMembers)
              ..where((t) => t.groupId.equals(groupId) & t.userId.equals(memberId)))
            .getSingleOrNull();

        if (exists == null) {
          await _db.into(_db.groupMembers).insert(
            GroupMembersCompanion.insert(
              groupId: groupId,
              userId: memberId,
              joinedAt: DateTime.now(),
            ),
          );
        }
      }
    }

    return groupId;
  }

  Future<void> addMember(String groupId, String userId) async {
    final exists = await (_db.select(_db.groupMembers)
          ..where((t) => t.groupId.equals(groupId) & t.userId.equals(userId)))
        .getSingleOrNull();

    if (exists == null) {
      await _db.into(_db.groupMembers).insert(
        GroupMembersCompanion.insert(
          groupId: groupId,
          userId: userId,
          joinedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> removeMember(String groupId, String userId) async {
    await (_db.delete(_db.groupMembers)
          ..where((t) => t.groupId.equals(groupId) & t.userId.equals(userId)))
        .go();
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    return await (_db.select(_db.groupMembers)
          ..where((t) => t.groupId.equals(groupId)))
        .get();
  }

  Future<void> markHandshakeComplete(String groupId, String userId) async {
    await (_db.update(_db.groupMembers)
          ..where((t) => t.groupId.equals(groupId) & t.userId.equals(userId)))
        .write(const GroupMembersCompanion(isHandshakeComplete: Value(true)));
  }

  Future<List<Conversation>> getGroups() async {
    return await (_db.select(_db.conversations)
          ..where((t) => t.type.equals('group'))
          ..orderBy([(t) => OrderingTerm.desc(t.lastMessageTime)]))
        .get();
  }

  Stream<List<Conversation>> watchGroups() {
    return (_db.select(_db.conversations)
          ..where((t) => t.type.equals('group'))
          ..orderBy([(t) => OrderingTerm.desc(t.lastMessageTime)]))
        .watch();
  }
}
