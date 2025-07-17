import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/conflict_model.dart';

import '../utils/enums.dart';
import 'firestore_service.dart';

/// Service for handling data conflict detection and resolution
///
/// This service provides comprehensive conflict detection and resolution
/// capabilities for the FLCMS offline synchronization system.
class ConflictResolutionService extends ChangeNotifier {
  static final ConflictResolutionService _instance =
      ConflictResolutionService._internal();
  factory ConflictResolutionService() => _instance;
  ConflictResolutionService._internal();

  final FirestoreService _firestore = FirestoreService();
  final Uuid _uuid = const Uuid();

  // Conflict tracking
  final List<ConflictData> _activeConflicts = [];
  final Map<String, ConflictData> _conflictRegistry = {};

  // Conflict resolution callbacks
  final Map<String, Function> _resolutionCallbacks = {};

  /// Get all active conflicts
  List<ConflictData> get activeConflicts => List.unmodifiable(_activeConflicts);

  /// Get conflict count
  int get conflictCount => _activeConflicts.length;

  /// Check if there are any unresolved conflicts
  bool get hasConflicts => _activeConflicts.isNotEmpty;

  /// Get conflicts for a specific collection
  List<ConflictData> getConflictsForCollection(String collection) {
    return _activeConflicts.where((c) => c.collection == collection).toList();
  }

  /// Get conflict by document ID
  ConflictData? getConflictByDocumentId(String documentId) {
    return _conflictRegistry[documentId];
  }

  // ==================== CONFLICT DETECTION ====================

  /// Detect conflicts between local and remote data
  Future<ConflictData?> detectConflict({
    required String documentId,
    required String collection,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
  }) async {
    try {
      debugPrint('Detecting conflict for $collection/$documentId');

      // If local data is newer than remote, no conflict
      if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
        debugPrint('Local data is newer, no conflict');
        return null;
      }

      // If remote data is newer than local, potential conflict
      if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
        debugPrint('Remote data is newer, checking for conflicts');

        final conflictType = _analyzeConflictType(
          localData,
          remoteData,
          collection,
        );

        if (conflictType != ConflictType.none) {
          final conflict = ConflictData(
            id: _uuid.v4(),
            documentId: documentId,
            collection: collection,
            conflictType: conflictType,
            localData: localData,
            remoteData: remoteData,
            localUpdatedAt: localUpdatedAt,
            remoteUpdatedAt: remoteUpdatedAt,
            suggestedStrategy: _suggestResolutionStrategy(
              conflictType,
              collection,
            ),
            conflictDetectedAt: DateTime.now(),
          );

          await _storeConflict(conflict);
          return conflict;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error detecting conflict: $e');
      return null;
    }
  }

  /// Analyze the type of conflict between local and remote data
  ConflictType _analyzeConflictType(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
    String collection,
  ) {
    final criticalFields = _getCriticalFieldsForCollection(collection);
    bool hasCriticalConflict = false;
    bool hasMinorConflict = false;

    // Compare each field
    for (final key in {...localData.keys, ...remoteData.keys}) {
      final localValue = localData[key];
      final remoteValue = remoteData[key];

      if (localValue != remoteValue) {
        if (criticalFields.contains(key)) {
          hasCriticalConflict = true;
          debugPrint('Critical conflict detected in field: $key');
        } else {
          hasMinorConflict = true;
          debugPrint('Minor conflict detected in field: $key');
        }
      }
    }

    if (hasCriticalConflict) {
      return ConflictType.critical;
    } else if (hasMinorConflict) {
      return ConflictType.minor;
    }

    return ConflictType.none;
  }

  /// Get critical fields for a collection
  List<String> _getCriticalFieldsForCollection(String collection) {
    switch (collection) {
      case 'fellowship_reports':
        return [
          'attendanceCount',
          'offeringAmount',
          'isApproved',
          'approvedBy',
          'approvedAt',
        ];
      case 'sunday_bus_reports':
        return [
          'attendanceList',
          'attendanceCount',
          'offering',
          'busCost',
          'driverName',
          'driverPhone',
          'isApproved',
        ];
      case 'users':
        return ['email', 'role', 'status', 'constituencyId', 'fellowshipId'];
      case 'fellowships':
        return ['name', 'pastorId', 'leaderId', 'status'];
      case 'constituencies':
        return ['name', 'pastorId', 'status'];
      default:
        return [];
    }
  }

  /// Suggest resolution strategy based on conflict type and collection
  ConflictResolutionStrategy _suggestResolutionStrategy(
    ConflictType conflictType,
    String collection,
  ) {
    switch (conflictType) {
      case ConflictType.critical:
        // Critical conflicts require user intervention
        return ConflictResolutionStrategy.userChoice;

      case ConflictType.minor:
        // For reports, try to merge fields
        if (collection.contains('reports')) {
          return ConflictResolutionStrategy.mergeFields;
        }
        // For other data, use last write wins
        return ConflictResolutionStrategy.lastWriteWins;

      case ConflictType.structural:
        // Structural conflicts need careful handling
        return ConflictResolutionStrategy.userChoice;

      case ConflictType.none:
        return ConflictResolutionStrategy.lastWriteWins;
    }
  }

  // ==================== CONFLICT RESOLUTION ====================

  /// Resolve conflict using the specified strategy
  Future<Map<String, dynamic>> resolveConflict(
    ConflictData conflict,
    ConflictResolutionStrategy strategy, {
    Map<String, dynamic>? userChoiceData,
    String? resolvedBy,
  }) async {
    try {
      debugPrint(
        'Resolving conflict ${conflict.id} using strategy: ${strategy.value}',
      );

      Map<String, dynamic> resolvedData;

      switch (strategy) {
        case ConflictResolutionStrategy.lastWriteWins:
          resolvedData = await _resolveLastWriteWins(conflict);
          break;

        case ConflictResolutionStrategy.mergeFields:
          resolvedData = await _resolveMergeFields(conflict);
          break;

        case ConflictResolutionStrategy.userChoice:
          if (userChoiceData == null) {
            throw Exception(
              'User choice data required for user choice strategy',
            );
          }
          resolvedData = userChoiceData;
          break;

        case ConflictResolutionStrategy.keepLocal:
          resolvedData = conflict.localData;
          break;

        case ConflictResolutionStrategy.keepRemote:
          resolvedData = conflict.remoteData;
          break;
      }

      // Mark conflict as resolved
      final resolvedConflict = conflict.copyWithResolution(
        resolvedBy: resolvedBy ?? 'system',
        resolvedStrategy: strategy,
        resolvedData: resolvedData,
      );

      await _updateStoredConflict(resolvedConflict);
      await _removeActiveConflict(conflict.id);

      debugPrint('Conflict ${conflict.id} resolved successfully');
      notifyListeners();

      return resolvedData;
    } catch (e) {
      debugPrint('Error resolving conflict: $e');
      rethrow;
    }
  }

  /// Resolve using last-write-wins strategy
  Future<Map<String, dynamic>> _resolveLastWriteWins(
    ConflictData conflict,
  ) async {
    // Remote data is considered "last write" since it has newer timestamp
    return conflict.remoteData;
  }

  /// Resolve using field merging strategy
  Future<Map<String, dynamic>> _resolveMergeFields(
    ConflictData conflict,
  ) async {
    final mergedData = <String, dynamic>{};
    final criticalFields = _getCriticalFieldsForCollection(conflict.collection);

    // Start with remote data as base
    mergedData.addAll(conflict.remoteData);

    // For non-critical fields, prefer local changes if they exist
    for (final key in conflict.localData.keys) {
      if (!criticalFields.contains(key)) {
        // Use local value if it's different from the original
        mergedData[key] = conflict.localData[key];
      }
    }

    // For critical fields, always use remote data (safer)
    for (final field in criticalFields) {
      if (conflict.remoteData.containsKey(field)) {
        mergedData[field] = conflict.remoteData[field];
      }
    }

    return mergedData;
  }

  // ==================== CONFLICT STORAGE ====================

  /// Store conflict data locally
  Future<void> _storeConflict(ConflictData conflict) async {
    try {
      _activeConflicts.add(conflict);
      _conflictRegistry[conflict.documentId] = conflict;

      final prefs = await SharedPreferences.getInstance();
      final conflictsJson = _activeConflicts.map((c) => c.toMap()).toList();
      await prefs.setString('active_conflicts', jsonEncode(conflictsJson));

      debugPrint('Stored conflict: ${conflict.id}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error storing conflict: $e');
    }
  }

  /// Update stored conflict data
  Future<void> _updateStoredConflict(ConflictData conflict) async {
    try {
      final index = _activeConflicts.indexWhere((c) => c.id == conflict.id);
      if (index != -1) {
        _activeConflicts[index] = conflict;
        _conflictRegistry[conflict.documentId] = conflict;

        final prefs = await SharedPreferences.getInstance();
        final conflictsJson = _activeConflicts.map((c) => c.toMap()).toList();
        await prefs.setString('active_conflicts', jsonEncode(conflictsJson));
      }
    } catch (e) {
      debugPrint('Error updating stored conflict: $e');
    }
  }

  /// Remove conflict from active list
  Future<void> _removeActiveConflict(String conflictId) async {
    try {
      _activeConflicts.removeWhere((c) => c.id == conflictId);

      // Remove from registry by finding the document ID
      String? documentIdToRemove;
      for (final entry in _conflictRegistry.entries) {
        if (entry.value.id == conflictId) {
          documentIdToRemove = entry.key;
          break;
        }
      }
      if (documentIdToRemove != null) {
        _conflictRegistry.remove(documentIdToRemove);
      }

      final prefs = await SharedPreferences.getInstance();
      final conflictsJson = _activeConflicts.map((c) => c.toMap()).toList();
      await prefs.setString('active_conflicts', jsonEncode(conflictsJson));

      debugPrint('Removed active conflict: $conflictId');
    } catch (e) {
      debugPrint('Error removing active conflict: $e');
    }
  }

  /// Load stored conflicts on startup
  Future<void> loadStoredConflicts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conflictsJson = prefs.getString('active_conflicts');

      if (conflictsJson != null) {
        final conflictsList = jsonDecode(conflictsJson) as List;
        _activeConflicts.clear();
        _conflictRegistry.clear();

        for (final conflictMap in conflictsList) {
          final conflict = ConflictData.fromMap(conflictMap);
          _activeConflicts.add(conflict);
          _conflictRegistry[conflict.documentId] = conflict;
        }

        debugPrint('Loaded ${_activeConflicts.length} stored conflicts');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading stored conflicts: $e');
    }
  }

  /// Clear all resolved conflicts older than specified days
  Future<void> cleanupResolvedConflicts({int olderThanDays = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));

      _activeConflicts.removeWhere(
        (conflict) =>
            conflict.isResolved &&
            conflict.resolvedAt != null &&
            conflict.resolvedAt!.isBefore(cutoffDate),
      );

      // Update storage
      final prefs = await SharedPreferences.getInstance();
      final conflictsJson = _activeConflicts.map((c) => c.toMap()).toList();
      await prefs.setString('active_conflicts', jsonEncode(conflictsJson));

      debugPrint('Cleaned up old resolved conflicts');
      notifyListeners();
    } catch (e) {
      debugPrint('Error cleaning up resolved conflicts: $e');
    }
  }

  // ==================== CONFLICT STATISTICS ====================

  /// Get conflict statistics
  Map<String, dynamic> getConflictStatistics() {
    final stats = <String, dynamic>{};

    stats['total_conflicts'] = _activeConflicts.length;
    stats['critical_conflicts'] =
        _activeConflicts.where((c) => c.isCritical).length;
    stats['conflicts_by_collection'] = <String, int>{};
    stats['conflicts_by_age'] = <String, int>{
      'under_1_hour': 0,
      'under_1_day': 0,
      'over_1_day': 0,
    };

    for (final conflict in _activeConflicts) {
      // Count by collection
      final collection = conflict.collection;
      stats['conflicts_by_collection'][collection] =
          (stats['conflicts_by_collection'][collection] ?? 0) + 1;

      // Count by age
      final ageInMinutes = conflict.ageInMinutes;
      if (ageInMinutes < 60) {
        stats['conflicts_by_age']['under_1_hour']++;
      } else if (ageInMinutes < 1440) {
        // 24 hours
        stats['conflicts_by_age']['under_1_day']++;
      } else {
        stats['conflicts_by_age']['over_1_day']++;
      }
    }

    return stats;
  }

  /// Register a callback for conflict resolution UI
  void registerResolutionCallback(String conflictId, Function callback) {
    _resolutionCallbacks[conflictId] = callback;
  }

  /// Unregister resolution callback
  void unregisterResolutionCallback(String conflictId) {
    _resolutionCallbacks.remove(conflictId);
  }

  /// Trigger resolution callback
  void triggerResolutionCallback(String conflictId) {
    final callback = _resolutionCallbacks[conflictId];
    if (callback != null) {
      callback();
    }
  }

  /// Dispose of the service
  @override
  void dispose() {
    _activeConflicts.clear();
    _conflictRegistry.clear();
    _resolutionCallbacks.clear();
    super.dispose();
  }
}
