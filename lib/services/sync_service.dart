import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:workmanager/workmanager.dart';  // Temporarily commented for build compatibility

import '../utils/enums.dart';

/// Service responsible for handling offline data synchronization
/// Manages network connectivity, queues offline actions, and syncs when online
class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // Core services
  late SharedPreferences _prefs;
  late Connectivity _connectivity;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State management
  bool _isOnline = false;
  bool _isSyncing = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Queue management
  final List<PendingAction> _pendingActions = [];

  // Constants
  static const String _queueKey = 'pending_actions_queue';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _offlineIndicatorKey = 'show_offline_indicator';

  // Getters
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  bool get hasPendingActions => _pendingActions.isNotEmpty;
  int get pendingActionsCount => _pendingActions.length;
  List<PendingAction> get pendingActions => List.unmodifiable(_pendingActions);

  /// Initialize the sync service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _connectivity = Connectivity();

      // Check initial connectivity
      await _checkConnectivity();

      // Load pending actions from storage
      await _loadPendingActions();

      // Start monitoring connectivity
      _startConnectivityMonitoring();

      // Initialize background sync (if supported)
      await _initializeBackgroundSync();

      debugPrint('SyncService initialized - Online: $_isOnline');
    } catch (e) {
      debugPrint('Error initializing SyncService: $e');
    }
  }

  /// Dispose and cleanup resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (!wasOnline && _isOnline) {
        // Just came online - trigger sync
        debugPrint('Device came online, triggering sync...');
        await syncPendingActions();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
    }
  }

  /// Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      debugPrint('Connectivity changed: ${result.name} (online: $_isOnline)');

      if (!wasOnline && _isOnline) {
        // Just came online - trigger sync
        syncPendingActions();
      }

      notifyListeners();
    });
  }

  /// Initialize background sync using WorkManager
  Future<void> _initializeBackgroundSync() async {
    try {
      // Temporarily disabled for build compatibility
      // await Workmanager().initialize(callbackDispatcher);

      // Register periodic sync task
      // await Workmanager().registerPeriodicTask(
      //   "sync_task",
      //   "syncPendingActions",
      //   frequency: const Duration(
      //     hours: 1,
      //   ), // Sync every hour when app is backgrounded
      //   constraints: Constraints(networkType: NetworkType.connected),
      // );

      debugPrint('Background sync temporarily disabled');
    } catch (e) {
      debugPrint('Error initializing background sync: $e');
    }
  }

  /// Add an action to the pending queue
  Future<void> queueAction(PendingAction action) async {
    try {
      _pendingActions.add(action);
      await _savePendingActions();

      // Try to sync immediately if online
      if (_isOnline && !_isSyncing) {
        syncPendingActions();
      }

      notifyListeners();
      debugPrint('Action queued: ${action.type}');
    } catch (e) {
      debugPrint('Error queueing action: $e');
    }
  }

  /// Sync all pending actions
  Future<void> syncPendingActions() async {
    if (_isSyncing || !_isOnline || _pendingActions.isEmpty) {
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint(
        'Starting sync of ${_pendingActions.length} pending actions...',
      );

      final List<PendingAction> successfulActions = [];
      final List<PendingAction> failedActions = [];

      for (final action in _pendingActions) {
        try {
          await _executeAction(action);
          successfulActions.add(action);
          debugPrint('Successfully synced action: ${action.type}');
        } catch (e) {
          debugPrint('Failed to sync action ${action.type}: $e');
          failedActions.add(action);
        }
      }

      // Remove successful actions from queue
      for (final action in successfulActions) {
        _pendingActions.remove(action);
      }

      // Save updated queue
      await _savePendingActions();

      // Update last sync timestamp
      await _prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint(
        'Sync completed. Success: ${successfulActions.length}, Failed: ${failedActions.length}',
      );
    } catch (e) {
      debugPrint('Error during sync: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Execute a specific pending action
  Future<void> _executeAction(PendingAction action) async {
    switch (action.type) {
      case ActionType.createDocument:
        await _createDocument(action);
        break;
      case ActionType.updateDocument:
        await _updateDocument(action);
        break;
      case ActionType.deleteDocument:
        await _deleteDocument(action);
        break;
      case ActionType.uploadFile:
        await _uploadFile(action);
        break;
    }
  }

  /// Create a document in Firestore
  Future<void> _createDocument(PendingAction action) async {
    await _firestore
        .collection(action.collection!)
        .doc(action.documentId)
        .set(action.data!);
  }

  /// Update a document in Firestore
  Future<void> _updateDocument(PendingAction action) async {
    await _firestore
        .collection(action.collection!)
        .doc(action.documentId!)
        .update(action.data!);
  }

  /// Delete a document from Firestore
  Future<void> _deleteDocument(PendingAction action) async {
    await _firestore
        .collection(action.collection!)
        .doc(action.documentId!)
        .delete();
  }

  /// Upload a file to Firebase Storage
  Future<void> _uploadFile(PendingAction action) async {
    // TODO: Implement file upload logic with Firebase Storage
    // This would handle receipt images and other file uploads
    debugPrint('File upload not yet implemented: ${action.filePath}');
  }

  /// Load pending actions from local storage
  Future<void> _loadPendingActions() async {
    try {
      final String? queueJson = _prefs.getString(_queueKey);
      if (queueJson != null) {
        final List<dynamic> queueList = jsonDecode(queueJson);
        _pendingActions.clear();
        _pendingActions.addAll(
          queueList.map((item) => PendingAction.fromJson(item)),
        );
        debugPrint('Loaded ${_pendingActions.length} pending actions');
      }
    } catch (e) {
      debugPrint('Error loading pending actions: $e');
    }
  }

  /// Save pending actions to local storage
  Future<void> _savePendingActions() async {
    try {
      final String queueJson = jsonEncode(
        _pendingActions.map((action) => action.toJson()).toList(),
      );
      await _prefs.setString(_queueKey, queueJson);
    } catch (e) {
      debugPrint('Error saving pending actions: $e');
    }
  }

  /// Get last sync timestamp
  DateTime? getLastSyncTime() {
    final int? timestamp = _prefs.getInt(_lastSyncKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Clear all pending actions (use with caution)
  Future<void> clearPendingActions() async {
    _pendingActions.clear();
    await _savePendingActions();
    notifyListeners();
  }

  /// Force sync (for manual trigger)
  Future<void> forcSync() async {
    await _checkConnectivity();
    if (_isOnline) {
      await syncPendingActions();
    }
  }

  /// Get detailed sync status information
  Map<String, dynamic> getSyncStatus() {
    return {
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'pendingActionsCount': _pendingActions.length,
      'lastSyncTime': getLastSyncTime(),
      'pendingActionTypes':
          _pendingActions.map((action) => action.type.name).toList(),
    };
  }

  /// Get pending actions summary by type
  Map<String, int> getPendingActionsSummary() {
    final summary = <String, int>{};
    for (final action in _pendingActions) {
      final type = action.type.name;
      summary[type] = (summary[type] ?? 0) + 1;
    }
    return summary;
  }

  /// Check if sync is needed (has pending actions and is online)
  bool get needsSync => _isOnline && _pendingActions.isNotEmpty && !_isSyncing;

  /// Start automatic sync monitoring
  void startAutoSync() {
    // Auto-sync every 30 seconds if needed
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (needsSync) {
        syncPendingActions();
      }
    });
  }

  /// Retry failed sync actions with exponential backoff
  Future<void> retryFailedActions() async {
    if (!_isOnline || _isSyncing) return;

    // For now, just retry all actions
    // In a more sophisticated implementation, we'd track failed actions separately
    await syncPendingActions();
  }
}

/// Represents a pending action to be synced when online
class PendingAction {
  final String id;
  final ActionType type;
  final String? collection;
  final String? documentId;
  final Map<String, dynamic>? data;
  final String? filePath;
  final DateTime createdAt;

  PendingAction({
    required this.id,
    required this.type,
    this.collection,
    this.documentId,
    this.data,
    this.filePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'collection': collection,
      'documentId': documentId,
      'data': data,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'],
      type: ActionType.values.firstWhere((e) => e.name == json['type']),
      collection: json['collection'],
      documentId: json['documentId'],
      data: json['data'],
      filePath: json['filePath'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

/// Types of actions that can be queued for sync
enum ActionType { createDocument, updateDocument, deleteDocument, uploadFile }

/// Background task callback for WorkManager
// Temporarily commented for build compatibility
/*
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('Background sync task executed: $task');

      // Initialize sync service in background
      final syncService = SyncService();
      await syncService.initialize();

      // Perform sync if online
      if (syncService.isOnline) {
        await syncService.syncPendingActions();
      }

      return Future.value(true);
    } catch (e) {
      debugPrint('Background sync failed: $e');
      return Future.value(false);
    }
  });
}
*/
