import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import '../models/fellowship_model.dart';
import '../models/fellowship_report_model.dart';
import '../models/sunday_bus_report_model.dart';
import '../models/constituency_model.dart';

/// Local database service for offline data storage and caching
/// Implements priority-based caching with TTL for church management data
class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;
  static const String _databaseName = 'flcms_local.db';
  static const int _databaseVersion = 1;

  // Cache TTL settings (in hours)
  static const Map<String, int> _cacheTTL = {
    'users': 24, // User data cached for 24 hours
    'fellowships': 12, // Fellowship data cached for 12 hours
    'constituencies': 24, // Constituency data cached for 24 hours
    'reports': 48, // Reports cached for 48 hours
    'bus_reports': 48, // Bus reports cached for 48 hours
  };

  // Cache size limits (number of records)
  static const Map<String, int> _cacheLimits = {
    'users': 1000,
    'fellowships': 500,
    'constituencies': 100,
    'reports': 200,
    'bus_reports': 100,
  };

  /// Initialize the local database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize SQLite database with all required tables
  Future<Database> _initDatabase() async {
    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, _databaseName);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createTables,
        onUpgrade: _upgradeDatabase,
      );
    } catch (e) {
      debugPrint('Error initializing local database: $e');
      rethrow;
    }
  }

  /// Create all required tables
  Future<void> _createTables(Database db, int version) async {
    // Cache metadata table
    await db.execute('''
      CREATE TABLE cache_metadata (
        key TEXT PRIMARY KEY,
        cached_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        data_size INTEGER DEFAULT 0
      )
    ''');

    // Users cache table
    await db.execute('''
      CREATE TABLE cached_users (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        priority INTEGER DEFAULT 0
      )
    ''');

    // Fellowships cache table
    await db.execute('''
      CREATE TABLE cached_fellowships (
        id TEXT PRIMARY KEY,
        constituency_id TEXT,
        pastor_id TEXT,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        priority INTEGER DEFAULT 0
      )
    ''');

    // Constituencies cache table
    await db.execute('''
      CREATE TABLE cached_constituencies (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        priority INTEGER DEFAULT 0
      )
    ''');

    // Fellowship reports cache table
    await db.execute('''
      CREATE TABLE cached_fellowship_reports (
        id TEXT PRIMARY KEY,
        fellowship_id TEXT,
        pastor_id TEXT,
        report_date INTEGER,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        priority INTEGER DEFAULT 0
      )
    ''');

    // Bus reports cache table
    await db.execute('''
      CREATE TABLE cached_bus_reports (
        id TEXT PRIMARY KEY,
        constituency_id TEXT,
        report_date INTEGER,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        priority INTEGER DEFAULT 0
      )
    ''');

    // Create indices for better query performance
    await _createIndices(db);

    debugPrint('Local database tables created successfully');
  }

  /// Create database indices for better performance
  Future<void> _createIndices(Database db) async {
    await db.execute(
      'CREATE INDEX idx_fellowships_constituency ON cached_fellowships(constituency_id)',
    );
    await db.execute(
      'CREATE INDEX idx_fellowships_pastor ON cached_fellowships(pastor_id)',
    );
    await db.execute(
      'CREATE INDEX idx_reports_fellowship ON cached_fellowship_reports(fellowship_id)',
    );
    await db.execute(
      'CREATE INDEX idx_reports_pastor ON cached_fellowship_reports(pastor_id)',
    );
    await db.execute(
      'CREATE INDEX idx_reports_date ON cached_fellowship_reports(report_date)',
    );
    await db.execute(
      'CREATE INDEX idx_bus_reports_constituency ON cached_bus_reports(constituency_id)',
    );
    await db.execute(
      'CREATE INDEX idx_bus_reports_date ON cached_bus_reports(report_date)',
    );
  }

  /// Handle database upgrades
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Handle future database schema upgrades
    debugPrint('Database upgrade from version $oldVersion to $newVersion');
  }

  // ==================== USER CACHING ====================

  /// Cache user data
  Future<void> cacheUser(UserModel user, {int priority = 0}) async {
    try {
      final db = await database;
      await db.insert('cached_users', {
        'id': user.id,
        'data': jsonEncode(user.toFirestore()),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'priority': priority,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _updateCacheMetadata('users');
    } catch (e) {
      debugPrint('Error caching user: $e');
    }
  }

  /// Get cached user
  Future<UserModel?> getCachedUser(String userId) async {
    try {
      final db = await database;
      final result = await db.query(
        'cached_users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (result.isNotEmpty) {
        final data = result.first;
        final userData = jsonDecode(data['data'] as String);
        return UserModel.fromFirestore(userData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached user: $e');
      return null;
    }
  }

  /// Get all cached users
  Future<List<UserModel>> getAllCachedUsers() async {
    try {
      final db = await database;
      final result = await db.query(
        'cached_users',
        orderBy: 'priority DESC, cached_at DESC',
      );

      return result.map((data) {
        final userData = jsonDecode(data['data'] as String);
        return UserModel.fromFirestore(userData);
      }).toList();
    } catch (e) {
      debugPrint('Error getting all cached users: $e');
      return [];
    }
  }

  // ==================== FELLOWSHIP CACHING ====================

  /// Cache fellowship data
  Future<void> cacheFellowship(
    FellowshipModel fellowship, {
    int priority = 0,
  }) async {
    try {
      final db = await database;
      await db.insert('cached_fellowships', {
        'id': fellowship.id,
        'constituency_id': fellowship.constituencyId,
        'pastor_id': fellowship.pastorId,
        'data': jsonEncode(fellowship.toFirestore()),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'priority': priority,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _updateCacheMetadata('fellowships');
    } catch (e) {
      debugPrint('Error caching fellowship: $e');
    }
  }

  /// Get cached fellowships by pastor
  Future<List<FellowshipModel>> getCachedFellowshipsByPastor(
    String pastorId,
  ) async {
    try {
      final db = await database;
      final result = await db.query(
        'cached_fellowships',
        where: 'pastor_id = ?',
        whereArgs: [pastorId],
        orderBy: 'priority DESC, cached_at DESC',
      );

      return result.map((data) {
        final fellowshipData = jsonDecode(data['data'] as String);
        return FellowshipModel.fromFirestore(fellowshipData);
      }).toList();
    } catch (e) {
      debugPrint('Error getting cached fellowships by pastor: $e');
      return [];
    }
  }

  /// Get cached fellowships by constituency
  Future<List<FellowshipModel>> getCachedFellowshipsByConstituency(
    String constituencyId,
  ) async {
    try {
      final db = await database;
      final result = await db.query(
        'cached_fellowships',
        where: 'constituency_id = ?',
        whereArgs: [constituencyId],
        orderBy: 'priority DESC, cached_at DESC',
      );

      return result.map((data) {
        final fellowshipData = jsonDecode(data['data'] as String);
        return FellowshipModel.fromFirestore(fellowshipData);
      }).toList();
    } catch (e) {
      debugPrint('Error getting cached fellowships by constituency: $e');
      return [];
    }
  }

  // ==================== CONSTITUENCY CACHING ====================

  /// Cache constituency data
  Future<void> cacheConstituency(
    ConstituencyModel constituency, {
    int priority = 0,
  }) async {
    try {
      final db = await database;
      await db.insert('cached_constituencies', {
        'id': constituency.id,
        'data': jsonEncode(constituency.toFirestore()),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'priority': priority,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _updateCacheMetadata('constituencies');
    } catch (e) {
      debugPrint('Error caching constituency: $e');
    }
  }

  /// Get all cached constituencies
  Future<List<ConstituencyModel>> getAllCachedConstituencies() async {
    try {
      final db = await database;
      final result = await db.query(
        'cached_constituencies',
        orderBy: 'priority DESC, cached_at DESC',
      );

      return result.map((data) {
        final constituencyData = jsonDecode(data['data'] as String);
        return ConstituencyModel.fromFirestore(constituencyData);
      }).toList();
    } catch (e) {
      debugPrint('Error getting all cached constituencies: $e');
      return [];
    }
  }

  // ==================== REPORT CACHING ====================

  /// Cache fellowship report
  Future<void> cacheFellowshipReport(
    FellowshipReportModel report, {
    int priority = 0,
  }) async {
    try {
      final db = await database;
      await db.insert('cached_fellowship_reports', {
        'id': report.id,
        'fellowship_id': report.fellowshipId,
        'pastor_id': report.pastorId,
        'report_date': report.reportDate.millisecondsSinceEpoch,
        'data': jsonEncode(report.toFirestore()),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'priority': priority,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _updateCacheMetadata('reports');
    } catch (e) {
      debugPrint('Error caching fellowship report: $e');
    }
  }

  /// Get cached fellowship reports
  Future<List<FellowshipReportModel>> getCachedFellowshipReports({
    String? fellowshipId,
    String? pastorId,
    int limit = 50,
  }) async {
    try {
      final db = await database;
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (fellowshipId != null) {
        whereClause = 'fellowship_id = ?';
        whereArgs.add(fellowshipId);
      } else if (pastorId != null) {
        whereClause = 'pastor_id = ?';
        whereArgs.add(pastorId);
      }

      final result = await db.query(
        'cached_fellowship_reports',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'report_date DESC, priority DESC',
        limit: limit,
      );

      return result.map((data) {
        final reportData = jsonDecode(data['data'] as String);
        return FellowshipReportModel.fromFirestore(reportData);
      }).toList();
    } catch (e) {
      debugPrint('Error getting cached fellowship reports: $e');
      return [];
    }
  }

  /// Cache bus report
  Future<void> cacheBusReport(
    SundayBusReportModel report, {
    int priority = 0,
  }) async {
    try {
      final db = await database;
      await db.insert('cached_bus_reports', {
        'id': report.id,
        'constituency_id': report.constituencyId,
        'report_date': report.reportDate.millisecondsSinceEpoch,
        'data': jsonEncode(report.toFirestore()),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'priority': priority,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _updateCacheMetadata('bus_reports');
    } catch (e) {
      debugPrint('Error caching bus report: $e');
    }
  }

  /// Get cached bus reports
  Future<List<SundayBusReportModel>> getCachedBusReports({
    String? constituencyId,
    int limit = 50,
  }) async {
    try {
      final db = await database;
      final result = await db.query(
        'cached_bus_reports',
        where: constituencyId != null ? 'constituency_id = ?' : null,
        whereArgs: constituencyId != null ? [constituencyId] : null,
        orderBy: 'report_date DESC, priority DESC',
        limit: limit,
      );

      return result.map((data) {
        final reportData = jsonDecode(data['data'] as String);
        return SundayBusReportModel.fromFirestore(reportData);
      }).toList();
    } catch (e) {
      debugPrint('Error getting cached bus reports: $e');
      return [];
    }
  }

  // ==================== CACHE MANAGEMENT ====================

  /// Update cache metadata
  Future<void> _updateCacheMetadata(String cacheType) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ttlHours = _cacheTTL[cacheType] ?? 24;
      final expiresAt = now + (ttlHours * 60 * 60 * 1000);

      await db.insert('cache_metadata', {
        'key': cacheType,
        'cached_at': now,
        'expires_at': expiresAt,
        'data_size': await _getCacheSize(cacheType),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Error updating cache metadata: $e');
    }
  }

  /// Get cache size for a specific type
  Future<int> _getCacheSize(String cacheType) async {
    try {
      final db = await database;
      final tableName = 'cached_$cacheType';
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  /// Clean expired cache entries
  Future<void> cleanExpiredCache() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Clean expired cache based on TTL
      for (final cacheType in _cacheTTL.keys) {
        final ttlHours = _cacheTTL[cacheType]!;
        final expiredTime = now - (ttlHours * 60 * 60 * 1000);

        await db.delete(
          'cached_$cacheType',
          where: 'cached_at < ?',
          whereArgs: [expiredTime],
        );
      }

      // Enforce cache size limits
      await _enforceCacheLimits();

      debugPrint('Expired cache cleaned successfully');
    } catch (e) {
      debugPrint('Error cleaning expired cache: $e');
    }
  }

  /// Enforce cache size limits
  Future<void> _enforceCacheLimits() async {
    try {
      final db = await database;

      for (final entry in _cacheLimits.entries) {
        final cacheType = entry.key;
        final limit = entry.value;
        final tableName = 'cached_$cacheType';

        final count = await _getCacheSize(cacheType);
        if (count > limit) {
          // Remove oldest, lowest priority entries
          await db.delete(
            tableName,
            where:
                'id IN (SELECT id FROM $tableName ORDER BY priority ASC, cached_at ASC LIMIT ?)',
            whereArgs: [count - limit],
          );
        }
      }
    } catch (e) {
      debugPrint('Error enforcing cache limits: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      final db = await database;

      for (final cacheType in _cacheTTL.keys) {
        await db.delete('cached_$cacheType');
      }

      await db.delete('cache_metadata');

      debugPrint('All cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, int>> getCacheStatistics() async {
    try {
      final db = await database;
      final stats = <String, int>{};

      for (final cacheType in _cacheTTL.keys) {
        stats[cacheType] = await _getCacheSize(cacheType);
      }

      return stats;
    } catch (e) {
      debugPrint('Error getting cache statistics: $e');
      return {};
    }
  }

  /// Check if specific cache is expired
  Future<bool> isCacheExpired(String cacheType) async {
    try {
      final db = await database;
      final result = await db.query(
        'cache_metadata',
        where: 'key = ?',
        whereArgs: [cacheType],
      );

      if (result.isNotEmpty) {
        final expiresAt = result.first['expires_at'] as int;
        return DateTime.now().millisecondsSinceEpoch > expiresAt;
      }

      return true; // Consider expired if no metadata found
    } catch (e) {
      debugPrint('Error checking cache expiration: $e');
      return true;
    }
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
