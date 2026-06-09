import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/user.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'findfriend.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Drop old tables and recreate with new schema
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('DROP TABLE IF EXISTS friends');
      await db.execute('DROP TABLE IF EXISTS messages');
      await _onCreate(db, newVersion);
    }
    if (oldVersion < 3) {
      // Add new columns to users table
      await db.execute('ALTER TABLE users ADD COLUMN age INTEGER');
      await db.execute('ALTER TABLE users ADD COLUMN sex TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN location TEXT');
    }
    if (oldVersion < 4) {
      // Make phoneNumber nullable for Google Sign-In users
      // SQLite doesn't support ALTER COLUMN directly, so we recreate the table
      await db.execute('''
        CREATE TABLE users_new (
          id TEXT PRIMARY KEY,
          phoneNumber TEXT,
          name TEXT NOT NULL,
          age INTEGER,
          sex TEXT,
          location TEXT,
          createdAt TEXT NOT NULL,
          lastSeen TEXT,
          isOnline INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        INSERT INTO users_new (id, phoneNumber, name, age, sex, location, createdAt, lastSeen, isOnline)
        SELECT id, phoneNumber, name, age, sex, location, createdAt, lastSeen, isOnline FROM users
      ''');
      await db.execute('DROP TABLE users');
      await db.execute('ALTER TABLE users_new RENAME TO users');
    }
    if (oldVersion < 5) {
      // Add type column to messages table and set default value for existing messages
      await db.execute('ALTER TABLE messages ADD COLUMN type INTEGER DEFAULT 0');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        phoneNumber TEXT,
        name TEXT NOT NULL,
        age INTEGER,
        sex TEXT,
        location TEXT,
        createdAt TEXT NOT NULL,
        lastSeen TEXT,
        isOnline INTEGER DEFAULT 0
      )
    ''');

    // Create friends table
    await db.execute('''
      CREATE TABLE friends (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        friendId TEXT NOT NULL,
        friendName TEXT NOT NULL,
        friendPhoneNumber TEXT NOT NULL,
        friendProfileImagePath TEXT,
        addedAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id),
        FOREIGN KEY (friendId) REFERENCES users(id)
      )
    ''');

    // Create messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        senderId TEXT NOT NULL,
        receiverId TEXT NOT NULL,
        content TEXT NOT NULL,
        type INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        localImagePath TEXT,
        FOREIGN KEY (senderId) REFERENCES users(id),
        FOREIGN KEY (receiverId) REFERENCES users(id)
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_messages_sender ON messages(senderId)');
    await db
        .execute('CREATE INDEX idx_messages_receiver ON messages(receiverId)');
    await db.execute('CREATE INDEX idx_friends_user ON friends(userId)');
  }

  // User operations
  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<User?> getUser(String phoneNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'phoneNumber = ?',
      whereArgs: [phoneNumber],
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // Friend operations
  Future<void> addFriend(Map<String, dynamic> friendData) async {
    final db = await database;
    await db.insert('friends', friendData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    final db = await database;
    return await db.query(
      'friends',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'addedAt DESC',
    );
  }

  Future<void> removeFriend(String userId, String friendId) async {
    final db = await database;
    await db.delete(
      'friends',
      where: 'userId = ? AND friendId = ?',
      whereArgs: [userId, friendId],
    );
  }

  Future<bool> isFriend(String userId, String friendId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'friends',
      where: 'userId = ? AND friendId = ?',
      whereArgs: [userId, friendId],
    );
    return maps.isNotEmpty;
  }

  // Message operations
  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert('messages', message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getMessages(String userId1, String userId2) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where:
          '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)',
      whereArgs: [userId1, userId2, userId2, userId1],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markMessageAsRead(String messageId) async {
    final db = await database;
    await db.update(
      'messages',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markAllMessagesAsRead(String senderId, String receiverId) async {
    final db = await database;
    await db.update(
      'messages',
      {'isRead': 1},
      where: 'senderId = ? AND receiverId = ? AND isRead = 0',
      whereArgs: [senderId, receiverId],
    );
  }

  Future<int> getUnreadCount(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE receiverId = ? AND isRead = 0',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Clear all data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('friends');
    await db.delete('users');
  }
}
