import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/entities/prayer_times.dart';

/// SQLite database helper for local caching
class DatabaseHelper {
  static Database? _database;
  static const String _dbName = 'iqamah.db';
  static const int _dbVersion = 1;

  // Table names
  static const String tableMosques = 'mosques';
  static const String tablePrayerTimes = 'prayer_times';
  static const String tableFavorites = 'favorites';

  // Singleton
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Mosques table
    await db.execute('''
      CREATE TABLE $tableMosques (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        city TEXT,
        country TEXT,
        latitude REAL,
        longitude REAL,
        is_favorite INTEGER DEFAULT 0,
        last_accessed INTEGER,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Prayer times table
    await db.execute('''
      CREATE TABLE $tablePrayerTimes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mosque_id TEXT NOT NULL,
        date TEXT NOT NULL,
        data TEXT NOT NULL,
        cached_at INTEGER DEFAULT (strftime('%s', 'now')),
        FOREIGN KEY (mosque_id) REFERENCES $tableMosques(id) ON DELETE CASCADE,
        UNIQUE(mosque_id, date)
      )
    ''');

    // Favorites table (for ordering and quick access)
    await db.execute('''
      CREATE TABLE $tableFavorites (
        mosque_id TEXT PRIMARY KEY,
        is_active INTEGER DEFAULT 0,
        travel_time_seconds INTEGER DEFAULT 0,
        custom_rakah_duration INTEGER,
        added_at INTEGER DEFAULT (strftime('%s', 'now')),
        FOREIGN KEY (mosque_id) REFERENCES $tableMosques(id) ON DELETE CASCADE
      )
    ''');

    // Index for faster lookups
    await db.execute(
      'CREATE INDEX idx_prayer_times_lookup ON $tablePrayerTimes(mosque_id, date)'
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations here
  }

  // Mosque operations
  Future<void> insertMosque(Mosque mosque) async {
    final db = await database;
    await db.insert(
      tableMosques,
      {
        'id': mosque.id,
        'name': mosque.name,
        'address': mosque.address,
        'city': mosque.city,
        'country': mosque.country,
        'latitude': mosque.latitude,
        'longitude': mosque.longitude,
        'is_favorite': mosque.isFavorite ? 1 : 0,
        'last_accessed': mosque.lastAccessed?.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Mosque?> getMosque(String id) async {
    final db = await database;
    final results = await db.query(
      tableMosques,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return _mapMosque(results.first);
  }

  Future<List<Mosque>> getFavoriteMosques() async {
    final db = await database;
    final results = await db.query(
      tableMosques,
      where: 'is_favorite = 1',
      orderBy: 'last_accessed DESC',
    );

    return results.map(_mapMosque).toList();
  }

  Future<Mosque?> getActiveMosque() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT m.* FROM $tableMosques m
      INNER JOIN $tableFavorites f ON m.id = f.mosque_id
      WHERE f.is_active = 1
      LIMIT 1
    ''');

    if (results.isEmpty) return null;
    return _mapMosque(results.first);
  }

  Future<void> setFavorite(String mosqueId, bool favorite) async {
    final db = await database;
    await db.update(
      tableMosques,
      {'is_favorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [mosqueId],
    );

    if (favorite) {
      await db.insert(
        tableFavorites,
        {'mosque_id': mosqueId, 'is_active': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.delete(
        tableFavorites,
        where: 'mosque_id = ?',
        whereArgs: [mosqueId],
      );
    }
  }

  Future<void> setActiveMosque(String mosqueId) async {
    final db = await database;
    
    // Clear existing active
    await db.update(
      tableFavorites,
      {'is_active': 0},
    );
    
    // Set new active
    await db.update(
      tableFavorites,
      {'is_active': 1},
      where: 'mosque_id = ?',
      whereArgs: [mosqueId],
    );

    // Update last accessed
    await db.update(
      tableMosques,
      {
        'last_accessed': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [mosqueId],
    );
  }

  // Prayer times operations
  Future<void> cachePrayerTimes(PrayerTimes times) async {
    final db = await database;
    final dateStr = '${times.date.year}-${times.date.month.toString().padLeft(2, '0')}-${times.date.day.toString().padLeft(2, '0')}';

    await db.insert(
      tablePrayerTimes,
      {
        'mosque_id': times.mosqueId,
        'date': dateStr,
        'data': _serializePrayerTimes(times),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PrayerTimes?> getCachedPrayerTimes(String mosqueId, DateTime date) async {
    final db = await database;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final results = await db.query(
      tablePrayerTimes,
      where: 'mosque_id = ? AND date = ?',
      whereArgs: [mosqueId, dateStr],
    );

    if (results.isEmpty) return null;
    return _deserializePrayerTimes(results.first['data'] as String);
  }

  Future<bool> hasCachedPrayerTimes(String mosqueId, DateTime date) async {
    final db = await database;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final results = await db.query(
      tablePrayerTimes,
      columns: ['id'],
      where: 'mosque_id = ? AND date = ?',
      whereArgs: [mosqueId, dateStr],
    );

    return results.isNotEmpty;
  }

  Future<void> clearOldCache({int daysToKeep = 7}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    
    await db.delete(
      tablePrayerTimes,
      where: 'cached_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }

  // User settings per mosque
  Future<void> setTravelTime(String mosqueId, int seconds) async {
    final db = await database;
    await db.insert(
      tableFavorites,
      {'mosque_id': mosqueId, 'travel_time_seconds': seconds},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getTravelTime(String mosqueId) async {
    final db = await database;
    final results = await db.query(
      tableFavorites,
      columns: ['travel_time_seconds'],
      where: 'mosque_id = ?',
      whereArgs: [mosqueId],
    );

    if (results.isEmpty) return 0;
    return results.first['travel_time_seconds'] as int? ?? 0;
  }

  Mosque _mapMosque(Map<String, dynamic> row) {
    return Mosque(
      id: row['id'] as String,
      name: row['name'] as String,
      address: row['address'] as String?,
      city: row['city'] as String?,
      country: row['country'] as String?,
      latitude: row['latitude'] as double?,
      longitude: row['longitude'] as double?,
      isFavorite: (row['is_favorite'] as int? ?? 0) == 1,
      lastAccessed: row['last_accessed'] != null
        ? DateTime.fromMillisecondsSinceEpoch(row['last_accessed'] as int)
        : null,
    );
  }

  String _serializePrayerTimes(PrayerTimes times) {
    return jsonEncode(times.toJson());
  }

  PrayerTimes _deserializePrayerTimes(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return PrayerTimes.fromJson(json);
    } catch (e) {
      throw DatabaseException('Failed to deserialize prayer times: $e');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
