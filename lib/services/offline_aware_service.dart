import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'firestore_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';
import 'conflict_resolution_service.dart';
import 'permissions_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';
import '../models/fellowship_model.dart';
import '../models/constituency_model.dart';
import '../models/fellowship_report_model.dart';
import '../models/sunday_bus_report_model.dart';
import '../models/conflict_model.dart';
import '../utils/enums.dart';

/// Service that provides offline-aware data operations
/// Intelligently handles online/offline scenarios with local caching and conflict resolution
class OfflineAwareService {
  static final OfflineAwareService _instance = OfflineAwareService._internal();
  factory OfflineAwareService() => _instance;
  OfflineAwareService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final SyncService _syncService = SyncService();
  final ConflictResolutionService _conflictService =
      ConflictResolutionService();
  final PermissionsService _permissionsService = PermissionsService();
  final AuthService _authService = AuthService();
  final Connectivity _connectivity = Connectivity();
  final Uuid _uuid = const Uuid();

  /// Check if device is currently online
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Get conflict service instance for external access
  ConflictResolutionService get conflictService => _conflictService;

  // ================== ROLE-BASED ACCESS CONTROL ==================

  /// Get current user for role validation
  Future<UserModel?> _getCurrentUser() async {
    return await _authService.getCurrentUserData();
  }

  /// Validate if current user can access fellowship data
  Future<bool> _canAccessFellowship(String fellowshipId) async {
    final user = await _getCurrentUser();
    if (user == null) return false;

    switch (user.role) {
      case UserRole.bishop:
        return true; // Bishop can access all fellowships
      case UserRole.pastor:
        // Pastor can access fellowships in their constituency
        // This would require checking fellowship's constituency
        return true; // Simplified for now - full implementation would check constituency
      case UserRole.treasurer:
        return true; // Treasurer can view all fellowship data for financial oversight
      case UserRole.leader:
        // Leader can only access their own fellowship
        return user.fellowshipId == fellowshipId;
    }
  }

  /// Validate if current user can access constituency data
  Future<bool> _canAccessConstituency(String constituencyId) async {
    final user = await _getCurrentUser();
    if (user == null) return false;

    switch (user.role) {
      case UserRole.bishop:
        return true; // Bishop can access all constituencies
      case UserRole.pastor:
        // Pastor can only access their own constituency
        return user.constituencyId == constituencyId;
      case UserRole.treasurer:
        return true; // Treasurer can access all constituency data for financial oversight
      case UserRole.leader:
        // Leader can access constituency data if their fellowship is in that constituency
        // This would require checking fellowship's constituency
        return true; // Simplified for now
    }
  }

  /// Filter fellowships based on user role and permissions
  Future<List<FellowshipModel>> _filterFellowshipsByRole(
    List<FellowshipModel> fellowships,
  ) async {
    final user = await _getCurrentUser();
    if (user == null) return [];

    switch (user.role) {
      case UserRole.bishop:
        return fellowships; // Bishop can see all fellowships
      case UserRole.pastor:
        // Pastor can see fellowships in their constituency
        return fellowships
            .where((f) => f.constituencyId == user.constituencyId)
            .toList();
      case UserRole.treasurer:
        return fellowships; // Treasurer can see all fellowships for financial oversight
      case UserRole.leader:
        // Leader can only see their own fellowship
        return fellowships.where((f) => f.id == user.fellowshipId).toList();
    }
  }

  /// Filter reports based on user role and permissions
  Future<List<FellowshipReportModel>> _filterReportsByRole(
    List<FellowshipReportModel> reports,
  ) async {
    final user = await _getCurrentUser();
    if (user == null) return [];

    switch (user.role) {
      case UserRole.bishop:
        return reports; // Bishop can see all reports
      case UserRole.pastor:
        // Pastor can see reports from fellowships in their constituency
        final allowedFellowships = await _getAllowedFellowshipIds();
        return reports
            .where((r) => allowedFellowships.contains(r.fellowshipId))
            .toList();
      case UserRole.treasurer:
        return reports; // Treasurer can see all reports for financial oversight
      case UserRole.leader:
        // Leader can only see their own fellowship reports
        return reports
            .where((r) => r.fellowshipId == user.fellowshipId)
            .toList();
    }
  }

  /// Filter bus reports based on user role and permissions
  Future<List<SundayBusReportModel>> _filterBusReportsByRole(
    List<SundayBusReportModel> reports,
  ) async {
    final user = await _getCurrentUser();
    if (user == null) return [];

    switch (user.role) {
      case UserRole.bishop:
        return reports; // Bishop can see all bus reports
      case UserRole.pastor:
        // Pastor can see bus reports from their constituency
        return reports
            .where((r) => r.constituencyId == user.constituencyId)
            .toList();
      case UserRole.treasurer:
        return reports; // Treasurer can see all bus reports for financial oversight
      case UserRole.leader:
        // Leader can see bus reports from their constituency
        return reports
            .where((r) => r.constituencyId == user.constituencyId)
            .toList();
    }
  }

  /// Get fellowship IDs that the current user is allowed to access
  Future<List<String>> _getAllowedFellowshipIds() async {
    final user = await _getCurrentUser();
    if (user == null) return [];

    switch (user.role) {
      case UserRole.bishop:
        // Bishop can access all fellowships - get from constituency fellowships for all constituencies
        final constituencies = await _localDb.getAllCachedConstituencies();
        final fellowshipIds = <String>[];
        for (final constituency in constituencies) {
          final fellowships = await _localDb.getCachedFellowshipsByConstituency(
            constituency.id,
          );
          fellowshipIds.addAll(fellowships.map((f) => f.id));
        }
        return fellowshipIds;
      case UserRole.pastor:
        // Pastor can access fellowships in their constituency
        if (user.constituencyId != null) {
          final fellowships = await _localDb.getCachedFellowshipsByConstituency(
            user.constituencyId!,
          );
          return fellowships.map((f) => f.id).toList();
        }
        return [];
      case UserRole.treasurer:
        // Treasurer can access all fellowships - same as bishop
        final constituencies = await _localDb.getAllCachedConstituencies();
        final fellowshipIds = <String>[];
        for (final constituency in constituencies) {
          final fellowships = await _localDb.getCachedFellowshipsByConstituency(
            constituency.id,
          );
          fellowshipIds.addAll(fellowships.map((f) => f.id));
        }
        return fellowshipIds;
      case UserRole.leader:
        // Leader can only access their own fellowship
        return user.fellowshipId != null ? [user.fellowshipId!] : [];
    }
  }

  // ================== USER OPERATIONS ==================

  /// Get users by role with offline-aware caching
  Stream<List<UserModel>> getUsersByRole(UserRole role) async* {
    try {
      // Emit cached data first for immediate response
      final cachedUsers = await _localDb.getAllCachedUsers();
      final filteredCached =
          cachedUsers.where((user) => user.role == role).toList();

      if (filteredCached.isNotEmpty) {
        yield filteredCached;
      }

      // Try to get fresh data if online
      if (await isOnline) {
        try {
          await for (final users in _firestoreService.getUsersByRole(role)) {
            // Cache the fresh data
            for (final user in users) {
              await _localDb.cacheUser(user);
            }
            yield users;
          }
        } catch (e) {
          debugPrint('Error fetching online users: $e');
          // If we haven't yielded cached data yet, do it now
          if (filteredCached.isEmpty) {
            yield await _localDb.getAllCachedUsers().then(
              (users) => users.where((user) => user.role == role).toList(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error in getUsersByRole: $e');
      yield [];
    }
  }

  /// Get single user by ID
  Future<UserModel?> getUser(String userId) async {
    try {
      // Check cache first for better performance
      final cachedUser = await _localDb.getCachedUser(userId);

      // Try to get fresh data if online
      if (await isOnline) {
        try {
          final user = await _firestoreService.getUser(userId);
          if (user != null) {
            await _localDb.cacheUser(user);
          }
          return user;
        } catch (e) {
          debugPrint('Error fetching online user: $e');
          return cachedUser; // Return cached version if available
        }
      }

      return cachedUser;
    } catch (e) {
      debugPrint('Error in getUser: $e');
      return null;
    }
  }

  /// Create user (offline-aware)
  Future<bool> createUser(UserModel user) async {
    try {
      if (await isOnline) {
        try {
          await _firestoreService.createUser(user);
          await _localDb.cacheUser(user);
          return true;
        } catch (e) {
          debugPrint('Error creating user online: $e');
          // Queue for later sync
          await _queueUserCreate(user);
          await _localDb.cacheUser(user);
          return true;
        }
      } else {
        // Offline - queue for sync and update cache
        await _queueUserCreate(user);
        await _localDb.cacheUser(user);
        return true;
      }
    } catch (e) {
      debugPrint('Error in createUser: $e');
      return false;
    }
  }

  /// Update user status (offline-aware)
  Future<bool> updateUserStatus(String userId, Status status) async {
    try {
      if (await isOnline) {
        try {
          await _firestoreService.updateUserStatus(userId, status);
          // Update cache
          final cachedUser = await _localDb.getCachedUser(userId);
          if (cachedUser != null) {
            final updatedUser = cachedUser.copyWith(status: status);
            await _localDb.cacheUser(updatedUser);
          }
          return true;
        } catch (e) {
          debugPrint('Error updating user status online: $e');
          await _queueUserStatusUpdate(userId, status);
          return true;
        }
      } else {
        // Offline - queue for sync
        await _queueUserStatusUpdate(userId, status);
        return true;
      }
    } catch (e) {
      debugPrint('Error in updateUserStatus: $e');
      return false;
    }
  }

  // ================== FELLOWSHIP OPERATIONS ==================

  /// Get fellowships by pastor with offline-aware caching and role-based filtering
  Future<List<FellowshipModel>> getFellowshipsByPastor(String pastorId) async {
    try {
      // Check permission before proceeding
      if (!await _permissionsService.canManageLeaders()) {
        debugPrint(
          'User does not have permission to view fellowships by pastor',
        );
        return [];
      }

      List<FellowshipModel> fellowships = [];

      // Try online first if available
      if (await isOnline) {
        try {
          fellowships =
              await _firestoreService.getFellowshipsByPastor(pastorId).first;

          // Cache the fresh data
          for (final fellowship in fellowships) {
            await _localDb.cacheFellowship(fellowship);
          }
        } catch (e) {
          debugPrint('Error fetching online fellowships: $e');
          // Fall back to cached data
          fellowships = await _localDb.getCachedFellowshipsByPastor(pastorId);
        }
      } else {
        // Use cached data when offline
        fellowships = await _localDb.getCachedFellowshipsByPastor(pastorId);
      }

      // Apply role-based filtering
      return await _filterFellowshipsByRole(fellowships);
    } catch (e) {
      debugPrint('Error in getFellowshipsByPastor: $e');
      return [];
    }
  }

  /// Get fellowships by constituency with offline-aware caching and role-based filtering
  Future<List<FellowshipModel>> getFellowshipsByConstituency(
    String constituencyId,
  ) async {
    try {
      // Check permission before proceeding
      if (!await _canAccessConstituency(constituencyId)) {
        debugPrint(
          'User does not have permission to access constituency: $constituencyId',
        );
        return [];
      }

      List<FellowshipModel> fellowships = [];

      // Try online first if available
      if (await isOnline) {
        try {
          fellowships =
              await _firestoreService
                  .getFellowshipsByConstituency(constituencyId)
                  .first;

          // Cache the fresh data
          for (final fellowship in fellowships) {
            await _localDb.cacheFellowship(fellowship);
          }
        } catch (e) {
          debugPrint('Error fetching online fellowships: $e');
          // Fall back to cached data
          fellowships = await _localDb.getCachedFellowshipsByConstituency(
            constituencyId,
          );
        }
      } else {
        // Use cached data when offline
        fellowships = await _localDb.getCachedFellowshipsByConstituency(
          constituencyId,
        );
      }

      // Apply role-based filtering
      return await _filterFellowshipsByRole(fellowships);
    } catch (e) {
      debugPrint('Error in getFellowshipsByConstituency: $e');
      return [];
    }
  }

  /// Create fellowship (offline-aware)
  Future<String?> createFellowship(FellowshipModel fellowship) async {
    try {
      if (await isOnline) {
        try {
          final fellowshipId = await _firestoreService.createFellowship(
            fellowship,
          );
          final fellowshipWithId = fellowship.copyWith(id: fellowshipId);
          await _localDb.cacheFellowship(fellowshipWithId);
          return fellowshipId;
        } catch (e) {
          debugPrint('Error creating fellowship online: $e');
          // Queue for sync and return temp ID
          final tempId = _uuid.v4();
          final fellowshipWithId = fellowship.copyWith(id: tempId);
          await _queueFellowshipCreate(fellowshipWithId);
          await _localDb.cacheFellowship(fellowshipWithId);
          return tempId;
        }
      } else {
        // Offline - queue for sync
        final tempId = _uuid.v4();
        final fellowshipWithId = fellowship.copyWith(id: tempId);
        await _queueFellowshipCreate(fellowshipWithId);
        await _localDb.cacheFellowship(fellowshipWithId);
        return tempId;
      }
    } catch (e) {
      debugPrint('Error in createFellowship: $e');
      return null;
    }
  }

  /// Update fellowship (offline-aware)
  Future<bool> updateFellowship(
    String fellowshipId,
    Map<String, dynamic> updates,
  ) async {
    try {
      if (await isOnline) {
        try {
          await _firestoreService.updateFellowship(fellowshipId, updates);
          // Update cache if available
          final cachedFellowship = await _getCachedFellowshipById(fellowshipId);
          if (cachedFellowship != null) {
            // Create updated fellowship (simplified)
            await _localDb.cacheFellowship(cachedFellowship);
          }
          return true;
        } catch (e) {
          debugPrint('Error updating fellowship online: $e');
          await _queueFellowshipUpdate(fellowshipId, updates);
          return true;
        }
      } else {
        // Offline - queue for sync
        await _queueFellowshipUpdate(fellowshipId, updates);
        return true;
      }
    } catch (e) {
      debugPrint('Error in updateFellowship: $e');
      return false;
    }
  }

  // ================== CONSTITUENCY OPERATIONS ==================

  /// Get all constituencies with offline-aware caching
  Future<List<ConstituencyModel>> getAllConstituencies() async {
    try {
      // For now, return cached data since FirestoreService doesn't have getConstituencies
      return await _localDb.getAllCachedConstituencies();
    } catch (e) {
      debugPrint('Error in getAllConstituencies: $e');
      return [];
    }
  }

  // ================== REPORT OPERATIONS ==================

  /// Submit fellowship report (offline-aware with conflict detection)
  Future<String?> submitFellowshipReport(FellowshipReportModel report) async {
    try {
      if (await isOnline) {
        try {
          // Check for existing report with same fellowship and date
          final existingReports =
              await _firestoreService
                  .getFellowshipReports(
                    fellowshipId: report.fellowshipId,
                    limit: 10,
                  )
                  .first;

          // Look for potential conflicts (same fellowship, same report date)
          final potentialConflict =
              existingReports
                  .where(
                    (r) =>
                        r.fellowshipId == report.fellowshipId &&
                        _isSameDay(r.reportDate, report.reportDate),
                  )
                  .firstOrNull;

          if (potentialConflict != null) {
            // Detect and handle conflict
            final conflict = await _detectReportConflict(
              report,
              potentialConflict,
              'fellowship_reports',
            );

            if (conflict != null) {
              // Handle conflict using configured strategy
              final resolvedData = await _conflictService.resolveConflict(
                conflict,
                conflict.suggestedStrategy,
                resolvedBy: 'system_auto',
              );

              // Create resolved report
              final resolvedReport = report.copyWithResolvedConflict(
                resolvedData: resolvedData,
                serverTimestamp: DateTime.now(),
              );

              // Update existing report instead of creating new one
              await _firestoreService.approveFellowshipReport(
                potentialConflict.id,
                resolvedData['approvedBy'] ?? 'system',
              );

              await _localDb.cacheFellowshipReport(resolvedReport);
              return potentialConflict.id;
            }
          }

          // No conflict - proceed with normal submission
          final reportWithSyncInfo = report.copyWith(
            version: report.version + 1,
            localUpdatedAt: DateTime.now(),
            syncStatus: SyncStatus.syncing,
          );

          final reportId = await _firestoreService.submitFellowshipReport(
            reportWithSyncInfo,
          );

          final reportWithId = reportWithSyncInfo.copyWith(
            id: reportId,
            lastUpdatedServer: DateTime.now(),
            syncStatus: SyncStatus.synced,
          );

          await _localDb.cacheFellowshipReport(reportWithId);
          return reportId;
        } catch (e) {
          debugPrint('Error submitting report online: $e');
          // Queue for sync with pending status
          final tempId = _uuid.v4();
          final reportWithId = report.copyWithLocalUpdate().copyWith(
            id: tempId,
          );
          await _queueReportSubmission(reportWithId);
          await _localDb.cacheFellowshipReport(reportWithId);
          return tempId;
        }
      } else {
        // Offline - queue for sync with pending status
        final tempId = _uuid.v4();
        final reportWithId = report.copyWithLocalUpdate().copyWith(id: tempId);
        await _queueReportSubmission(reportWithId);
        await _localDb.cacheFellowshipReport(reportWithId);
        return tempId;
      }
    } catch (e) {
      debugPrint('Error in submitFellowshipReport: $e');
      return null;
    }
  }

  /// Submit bus report (offline-aware with conflict detection)
  Future<String?> submitBusReport(SundayBusReportModel report) async {
    try {
      if (await isOnline) {
        try {
          // Check for existing bus report with same constituency and date
          final existingReports =
              await _firestoreService
                  .getBusReports(
                    constituencyId: report.constituencyId,
                    limit: 10,
                  )
                  .first;

          // Look for potential conflicts (same constituency, same report date)
          final potentialConflict =
              existingReports
                  .where(
                    (r) =>
                        r.constituencyId == report.constituencyId &&
                        _isSameDay(r.reportDate, report.reportDate),
                  )
                  .firstOrNull;

          if (potentialConflict != null) {
            // Detect and handle conflict
            final conflict = await _detectBusReportConflict(
              report,
              potentialConflict,
              'sunday_bus_reports',
            );

            if (conflict != null) {
              // Handle conflict using configured strategy
              final resolvedData = await _conflictService.resolveConflict(
                conflict,
                conflict.suggestedStrategy,
                resolvedBy: 'system_auto',
              );

              // Create resolved report
              final resolvedReport = report.copyWithResolvedConflict(
                resolvedData: resolvedData,
                serverTimestamp: DateTime.now(),
              );

              // Update existing report instead of creating new one
              await _firestoreService.approveBusReport(
                potentialConflict.id,
                resolvedData['approvedBy'] ?? 'system',
              );

              await _localDb.cacheBusReport(resolvedReport);
              return potentialConflict.id;
            }
          }

          // No conflict - proceed with normal submission
          final reportWithSyncInfo = report.copyWith(
            version: report.version + 1,
            localUpdatedAt: DateTime.now(),
            syncStatus: SyncStatus.syncing,
          );

          final reportId = await _firestoreService.submitBusReport(
            reportWithSyncInfo,
          );

          final reportWithId = reportWithSyncInfo.copyWith(
            id: reportId,
            lastUpdatedServer: DateTime.now(),
            syncStatus: SyncStatus.synced,
          );

          await _localDb.cacheBusReport(reportWithId);
          return reportId;
        } catch (e) {
          debugPrint('Error submitting bus report online: $e');
          // Queue for sync with pending status
          final tempId = _uuid.v4();
          final reportWithId = report.copyWithLocalUpdate().copyWith(
            id: tempId,
          );
          await _queueBusReportSubmission(reportWithId);
          await _localDb.cacheBusReport(reportWithId);
          return tempId;
        }
      } else {
        // Offline - queue for sync with pending status
        final tempId = _uuid.v4();
        final reportWithId = report.copyWithLocalUpdate().copyWith(id: tempId);
        await _queueBusReportSubmission(reportWithId);
        await _localDb.cacheBusReport(reportWithId);
        return tempId;
      }
    } catch (e) {
      debugPrint('Error in submitBusReport: $e');
      return null;
    }
  }

  /// Get fellowship reports with offline-aware caching
  Future<List<FellowshipReportModel>> getFellowshipReports({
    String? fellowshipId,
    String? pastorId,
    int limit = 50,
  }) async {
    try {
      // Try online first if available
      if (await isOnline) {
        try {
          List<FellowshipReportModel> reports;
          if (fellowshipId != null) {
            reports =
                await _firestoreService
                    .getFellowshipReports(
                      fellowshipId: fellowshipId,
                      limit: limit,
                    )
                    .first;
          } else {
            // For pastor-specific reports, use cached data for now
            return await _localDb.getCachedFellowshipReports(
              fellowshipId: fellowshipId,
              pastorId: pastorId,
              limit: limit,
            );
          }

          // Cache the fresh data
          for (final report in reports) {
            await _localDb.cacheFellowshipReport(report);
          }

          return reports;
        } catch (e) {
          debugPrint('Error fetching online reports: $e');
        }
      }

      // Return cached data
      return await _localDb.getCachedFellowshipReports(
        fellowshipId: fellowshipId,
        pastorId: pastorId,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error in getFellowshipReports: $e');
      return [];
    }
  }

  /// Get bus reports with offline-aware caching
  Future<List<SundayBusReportModel>> getBusReports({
    String? constituencyId,
    int limit = 50,
  }) async {
    try {
      // Try online first if available
      if (await isOnline && constituencyId != null) {
        try {
          final reports =
              await _firestoreService
                  .getBusReports(constituencyId: constituencyId, limit: limit)
                  .first;

          // Cache the fresh data
          for (final report in reports) {
            await _localDb.cacheBusReport(report);
          }

          return reports;
        } catch (e) {
          debugPrint('Error fetching online bus reports: $e');
        }
      }

      // Return cached data
      return await _localDb.getCachedBusReports(
        constituencyId: constituencyId,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error in getBusReports: $e');
      return [];
    }
  }

  // ================== PRIVATE HELPER METHODS ==================

  /// Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Detect conflicts between local and remote reports
  Future<ConflictData?> _detectReportConflict(
    FellowshipReportModel localReport,
    FellowshipReportModel remoteReport,
    String collection,
  ) async {
    try {
      // Use local update time vs remote submission time for conflict detection
      final localUpdateTime =
          localReport.localUpdatedAt ?? localReport.submittedAt;
      final remoteUpdateTime =
          remoteReport.lastUpdatedServer ?? remoteReport.submittedAt;

      return await _conflictService.detectConflict(
        documentId: remoteReport.id,
        collection: collection,
        localData: localReport.getConflictDetectionFields(),
        remoteData: remoteReport.getConflictDetectionFields(),
        localUpdatedAt: localUpdateTime,
        remoteUpdatedAt: remoteUpdateTime,
      );
    } catch (e) {
      debugPrint('Error detecting report conflict: $e');
      return null;
    }
  }

  /// Detect conflicts between local and remote bus reports
  Future<ConflictData?> _detectBusReportConflict(
    SundayBusReportModel localReport,
    SundayBusReportModel remoteReport,
    String collection,
  ) async {
    try {
      // Use local update time vs remote submission time for conflict detection
      final localUpdateTime =
          localReport.localUpdatedAt ?? localReport.submittedAt;
      final remoteUpdateTime =
          remoteReport.lastUpdatedServer ?? remoteReport.submittedAt;

      return await _conflictService.detectConflict(
        documentId: remoteReport.id,
        collection: collection,
        localData: localReport.getConflictDetectionFields(),
        remoteData: remoteReport.getConflictDetectionFields(),
        localUpdatedAt: localUpdateTime,
        remoteUpdatedAt: remoteUpdateTime,
      );
    } catch (e) {
      debugPrint('Error detecting bus report conflict: $e');
      return null;
    }
  }

  /// Get cached fellowship by ID (helper method)
  Future<FellowshipModel?> _getCachedFellowshipById(String fellowshipId) async {
    try {
      // Since LocalDatabaseService doesn't have getCachedFellowship by ID,
      // we'll need to implement this or search through all cached fellowships
      final allFellowships = await _localDb.getCachedFellowshipsByPastor(
        '',
      ); // Get all
      return allFellowships.firstWhere(
        (fellowship) => fellowship.id == fellowshipId,
        orElse: () => throw StateError('Not found'),
      );
    } catch (e) {
      return null;
    }
  }

  // ================== PRIVATE QUEUE METHODS ==================

  Future<void> _queueUserCreate(UserModel user) async {
    await _syncService.queueAction(
      PendingAction(
        id: _uuid.v4(),
        type: ActionType.createDocument,
        collection: 'users',
        documentId: user.id,
        data: user.toFirestore(),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _queueUserStatusUpdate(String userId, Status status) async {
    await _syncService.queueAction(
      PendingAction(
        id: _uuid.v4(),
        type: ActionType.updateDocument,
        collection: 'users',
        documentId: userId,
        data: {
          'status': status.value,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _queueFellowshipCreate(FellowshipModel fellowship) async {
    await _syncService.queueAction(
      PendingAction(
        id: _uuid.v4(),
        type: ActionType.createDocument,
        collection: 'fellowships',
        documentId: fellowship.id,
        data: fellowship.toFirestore(),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _queueFellowshipUpdate(
    String fellowshipId,
    Map<String, dynamic> updates,
  ) async {
    await _syncService.queueAction(
      PendingAction(
        id: _uuid.v4(),
        type: ActionType.updateDocument,
        collection: 'fellowships',
        documentId: fellowshipId,
        data: updates,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _queueReportSubmission(FellowshipReportModel report) async {
    await _syncService.queueAction(
      PendingAction(
        id: _uuid.v4(),
        type: ActionType.createDocument,
        collection: 'fellowship_reports',
        documentId: report.id,
        data: report.toFirestore(),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _queueBusReportSubmission(SundayBusReportModel report) async {
    await _syncService.queueAction(
      PendingAction(
        id: _uuid.v4(),
        type: ActionType.createDocument,
        collection: 'sunday_bus_reports',
        documentId: report.id,
        data: report.toFirestore(),
        createdAt: DateTime.now(),
      ),
    );
  }

  // ================== UTILITY METHODS ==================

  /// Initialize conflict resolution service
  Future<void> initializeConflictResolution() async {
    await _conflictService.loadStoredConflicts();
  }

  /// Get conflict statistics
  Map<String, dynamic> getConflictStatistics() {
    return _conflictService.getConflictStatistics();
  }

  /// Get all active conflicts
  List<ConflictData> getActiveConflicts() {
    return _conflictService.activeConflicts;
  }

  /// Get conflicts for specific collection
  List<ConflictData> getConflictsForCollection(String collection) {
    return _conflictService.getConflictsForCollection(collection);
  }

  /// Check if there are any unresolved conflicts
  bool get hasConflicts => _conflictService.hasConflicts;

  /// Get conflict count
  int get conflictCount => _conflictService.conflictCount;

  /// Resolve conflict manually (for user-driven resolution)
  Future<Map<String, dynamic>?> resolveConflict(
    String conflictId,
    ConflictResolutionStrategy strategy, {
    Map<String, dynamic>? userChoiceData,
    String? resolvedBy,
  }) async {
    try {
      final conflict =
          _conflictService.activeConflicts
              .where((c) => c.id == conflictId)
              .firstOrNull;

      if (conflict == null) {
        debugPrint('Conflict not found: $conflictId');
        return null;
      }

      return await _conflictService.resolveConflict(
        conflict,
        strategy,
        userChoiceData: userChoiceData,
        resolvedBy: resolvedBy,
      );
    } catch (e) {
      debugPrint('Error resolving conflict: $e');
      return null;
    }
  }

  /// Force sync all pending actions
  Future<void> forceSync() async {
    await _syncService.forcSync();
  }

  /// Get sync status information
  bool get isSyncing => _syncService.isSyncing;
  bool get hasPendingActions => _syncService.hasPendingActions;
  int get pendingActionsCount => _syncService.pendingActionsCount;

  /// Clear local cache (use with caution)
  Future<void> clearCache() async {
    await _localDb.cleanExpiredCache();
  }

  /// Clean up old resolved conflicts
  Future<void> cleanupResolvedConflicts({int olderThanDays = 7}) async {
    await _conflictService.cleanupResolvedConflicts(
      olderThanDays: olderThanDays,
    );
  }

  /// Refresh specific data type from server
  Future<void> refreshData(String dataType, {String? id}) async {
    if (!await isOnline) return;

    try {
      switch (dataType) {
        case 'users':
          // Refresh user data - would need specific implementation
          break;
        case 'fellowships':
          // Refresh fellowship data
          break;
        case 'reports':
          // Refresh reports data
          break;
      }
    } catch (e) {
      debugPrint('Error refreshing $dataType: $e');
    }
  }
}
