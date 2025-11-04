import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Users extends Table {
  TextColumn get userId => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();
  TextColumn get publicKey => text()();
  TextColumn get profileImage => text().nullable()();
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  TextColumn get avatar => text().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

class CurrentUser extends Table {
  TextColumn get userId => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();
  TextColumn get passwordHash => text()();
  TextColumn get profileImage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}

class Conversations extends Table {
  TextColumn get conversationId => text()();
  TextColumn get type => text().withDefault(const Constant('direct'))();
  TextColumn get name => text().nullable()();
  TextColumn get groupImage => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get lastMessageTime => dateTime()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  TextColumn get peerId => text()();

  @override
  Set<Column> get primaryKey => {conversationId};
}

class GroupMembers extends Table {
  TextColumn get groupId => text()();
  TextColumn get userId => text()();
  TextColumn get role => text().withDefault(const Constant('member'))();
  DateTimeColumn get joinedAt => dateTime()();
  BoolColumn get isHandshakeComplete => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {groupId, userId};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get recipientId => text()();
  TextColumn get ciphertext => text()();
  TextColumn get iv => text()();
  TextColumn get meta => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get status => text()();
  TextColumn get msgType => text().withDefault(const Constant('text'))();
  TextColumn get replyToId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get messageId => text()();
  TextColumn get type => text()();
  TextColumn get filename => text()();
  IntColumn get size => integer()();
  TextColumn get thumbnail => text().nullable()();
  TextColumn get sha256 => text()();
  TextColumn get storedLocalPath => text()();
  IntColumn get uploadProgress => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Sessions extends Table {
  TextColumn get peerId => text()();
  TextColumn get sessionStateEncrypted => text()();
  DateTimeColumn get lastRotatedAt => dateTime()();
  TextColumn get identityKey => text()();

  @override
  Set<Column> get primaryKey => {peerId};
}

class PendingMessages extends Table {
  TextColumn get messageId => text()();
  TextColumn get targetUserId => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime()();
  BoolColumn get isHandshakeComplete => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {messageId};
}

class MessageQueue extends Table {
  TextColumn get queueId => text()();
  TextColumn get messageId => text()();
  TextColumn get conversationId => text()();
  TextColumn get targetUserId => text()();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  DateTimeColumn get queuedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {queueId};
}

@DriftDatabase(tables: [
  Users,
  CurrentUser,
  Conversations,
  GroupMembers,
  Messages,
  Attachments,
  Sessions,
  PendingMessages,
  MessageQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'funchat.db'));
      return NativeDatabase(file);
    });
  }
}
