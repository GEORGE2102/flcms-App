import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/fellowship_model.dart';
import '../utils/enums.dart';
import '../utils/app_config.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

/// Service for managing fellowship leaders
/// Provides role-based CRUD operations for pastors to manage their leaders
class LeaderService {
  static final LeaderService _instance = LeaderService._internal();
  factory LeaderService() => _instance;
  LeaderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // ==================== LEADER QUERY OPERATIONS ====================

  /// Get leaders managed by current pastor
  Stream<List<UserModel>> getLeadersByPastor(String pastorId) {
    return _firestore
        .collection(AppConfig.usersCollection)
        .where('role', isEqualTo: UserRole.leader.value)
        .where('assignedPastorId', isEqualTo: pastorId)
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Get leaders by constituency
  Stream<List<UserModel>> getLeadersByConstituency(String constituencyId) {
    return _firestore
        .collection(AppConfig.usersCollection)
        .where('role', isEqualTo: UserRole.leader.value)
        .where('constituencyId', isEqualTo: constituencyId)
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Get available leaders (not assigned to any fellowship)
  Stream<List<UserModel>> getAvailableLeaders({
    String? pastorId,
    String? constituencyId,
  }) {
    Query query = _firestore
        .collection(AppConfig.usersCollection)
        .where('role', isEqualTo: UserRole.leader.value)
        .where('fellowshipId', isNull: true)
        .where('status', isEqualTo: Status.active.value);

    if (pastorId != null) {
      query = query.where('assignedPastorId', isEqualTo: pastorId);
    } else if (constituencyId != null) {
      query = query.where('constituencyId', isEqualTo: constituencyId);
    }

    return query
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Search leaders by name within pastor's scope
  Future<List<UserModel>> searchLeaders({
    required String searchTerm,
    String? pastorId,
    String? constituencyId,
    Status? status,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConfig.usersCollection)
          .where('role', isEqualTo: UserRole.leader.value)
          .where('firstName', isGreaterThanOrEqualTo: searchTerm)
          .where('firstName', isLessThan: searchTerm + 'z');

      if (pastorId != null) {
        query = query.where('assignedPastorId', isEqualTo: pastorId);
      } else if (constituencyId != null) {
        query = query.where('constituencyId', isEqualTo: constituencyId);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }

      final snapshot = await query.limit(20).get();

      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to search leaders: $e');
    }
  }

  // ==================== LEADER CRUD OPERATIONS ====================

  /// Create new leader with invitation system (pastor only)
  Future<Map<String, dynamic>> createLeader({
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
    required String pastorId,
    required String constituencyId,
    String? fellowshipId,
  }) async {
    try {
      // Verify current user can create leaders
      final currentUser = await _authService.getCurrentUserData();
      if (currentUser == null || !currentUser.isPastor) {
        throw Exception('Only pastors can create leader accounts');
      }

      if (currentUser.id != pastorId) {
        throw Exception('You can only create leaders for yourself');
      }

      // Check if email already exists in Firestore
      final existingQuery =
          await _firestore
              .collection(AppConfig.usersCollection)
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('A user with this email already exists');
      }

      // Generate a unique ID for the leader
      final leaderDocRef =
          _firestore.collection(AppConfig.usersCollection).doc();
      final leaderId = leaderDocRef.id;

      // Create leader document in Firestore (no Firebase Auth account yet)
      final now = DateTime.now();
      final leader = UserModel(
        id: leaderId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.leader,
        phoneNumber: phoneNumber,
        constituencyId: constituencyId,
        fellowshipId: fellowshipId,
        assignedPastorId: pastorId,
        status: Status.pending, // Leader will activate when they register
        createdAt: now,
        updatedAt: now,
      );

      // Save leader document to Firestore
      await leaderDocRef.set(leader.toFirestore());

      // If fellowship is assigned, update fellowship with leader details
      if (fellowshipId != null) {
        await _firestore
            .collection(AppConfig.fellowshipsCollection)
            .doc(fellowshipId)
            .update({
              'leaderId': leaderId,
              'leaderName': '${firstName} ${lastName}',
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      return {
        'leaderId': leaderId,
        'leader': leader,
        'success': true,
        'message':
            'Leader account created successfully! Share the login details with ${firstName}.',
      };
    } catch (e) {
      throw Exception('Failed to create leader: $e');
    }
  }

  /// Update leader information
  Future<void> updateLeader(
    String leaderId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Verify permissions
      final canManage = await _authService.canManageUser(leaderId);
      if (!canManage) {
        throw Exception('Insufficient permissions to update this leader');
      }

      // Add timestamp
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(AppConfig.usersCollection)
          .doc(leaderId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update leader: $e');
    }
  }

  /// Update leader status (active/inactive/suspended)
  Future<void> updateLeaderStatus(String leaderId, Status newStatus) async {
    try {
      final canManage = await _authService.canManageUser(leaderId);
      if (!canManage) {
        throw Exception('Insufficient permissions to update leader status');
      }

      await _firestoreService.updateUserStatus(leaderId, newStatus);
    } catch (e) {
      throw Exception('Failed to update leader status: $e');
    }
  }

  /// Remove leader (soft delete by changing status)
  Future<void> removeLeader(String leaderId) async {
    try {
      final canManage = await _authService.canManageUser(leaderId);
      if (!canManage) {
        throw Exception('Insufficient permissions to remove this leader');
      }

      // Unassign from fellowship first if assigned
      await unassignLeaderFromFellowship(leaderId);

      // Set status to suspended (soft delete)
      await updateLeaderStatus(leaderId, Status.suspended);
    } catch (e) {
      throw Exception('Failed to remove leader: $e');
    }
  }

  // ==================== FELLOWSHIP ASSIGNMENT OPERATIONS ====================

  /// Assign leader to fellowship
  Future<void> assignLeaderToFellowship(
    String leaderId,
    String fellowshipId,
  ) async {
    try {
      // Verify permissions
      final canManage = await _authService.canManageUser(leaderId);
      if (!canManage) {
        throw Exception('Insufficient permissions to assign this leader');
      }

      // Verify fellowship exists and is accessible
      final fellowship = await _firestoreService.getFellowship(fellowshipId);
      if (fellowship == null) {
        throw Exception('Fellowship not found');
      }

      // Check if fellowship already has a leader
      if (fellowship.leaderId != null && fellowship.leaderId != leaderId) {
        throw Exception('Fellowship already has an assigned leader');
      }

      // Use batch update for consistency
      final batch = _firestore.batch();

      // Update leader document
      final leaderRef = _firestore
          .collection(AppConfig.usersCollection)
          .doc(leaderId);
      batch.update(leaderRef, {
        'fellowshipId': fellowshipId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update fellowship document
      final fellowshipRef = _firestore
          .collection(AppConfig.fellowshipsCollection)
          .doc(fellowshipId);
      batch.update(fellowshipRef, {
        'leaderId': leaderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to assign leader to fellowship: $e');
    }
  }

  /// Unassign leader from fellowship
  Future<void> unassignLeaderFromFellowship(String leaderId) async {
    try {
      // Get current leader data
      final leader = await _firestoreService.getUser(leaderId);
      if (leader == null) {
        throw Exception('Leader not found');
      }

      // Verify permissions
      final canManage = await _authService.canManageUser(leaderId);
      if (!canManage) {
        throw Exception('Insufficient permissions to unassign this leader');
      }

      // Use batch update for consistency
      final batch = _firestore.batch();

      // Update leader document
      final leaderRef = _firestore
          .collection(AppConfig.usersCollection)
          .doc(leaderId);
      batch.update(leaderRef, {
        'fellowshipId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update fellowship document if leader was assigned
      if (leader.fellowshipId != null) {
        final fellowshipRef = _firestore
            .collection(AppConfig.fellowshipsCollection)
            .doc(leader.fellowshipId!);
        batch.update(fellowshipRef, {
          'leaderId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to unassign leader from fellowship: $e');
    }
  }

  /// Reassign leader to different fellowship
  Future<void> reassignLeaderToFellowship(
    String leaderId,
    String newFellowshipId,
  ) async {
    try {
      // First unassign from current fellowship
      await unassignLeaderFromFellowship(leaderId);

      // Then assign to new fellowship
      await assignLeaderToFellowship(leaderId, newFellowshipId);
    } catch (e) {
      throw Exception('Failed to reassign leader: $e');
    }
  }

  // ==================== ANALYTICS AND REPORTING ====================

  /// Get leader statistics for pastor dashboard
  Future<Map<String, dynamic>> getLeaderStatistics({
    String? pastorId,
    String? constituencyId,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConfig.usersCollection)
          .where('role', isEqualTo: UserRole.leader.value);

      if (pastorId != null) {
        query = query.where('assignedPastorId', isEqualTo: pastorId);
      } else if (constituencyId != null) {
        query = query.where('constituencyId', isEqualTo: constituencyId);
      }

      final snapshot = await query.get();

      int totalLeaders = snapshot.docs.length;
      int activeLeaders = 0;
      int assignedLeaders = 0;
      int pendingLeaders = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = Status.values.firstWhere(
          (s) => s.value == data['status'],
          orElse: () => Status.pending,
        );

        if (status == Status.active) activeLeaders++;
        if (status == Status.pending) pendingLeaders++;
        if (data['fellowshipId'] != null) assignedLeaders++;
      }

      return {
        'totalLeaders': totalLeaders,
        'activeLeaders': activeLeaders,
        'assignedLeaders': assignedLeaders,
        'availableLeaders': activeLeaders - assignedLeaders,
        'pendingLeaders': pendingLeaders,
        'assignmentRate':
            totalLeaders > 0 ? (assignedLeaders / totalLeaders) : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get leader statistics: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Check if current user can manage leaders
  Future<bool> canManageLeaders() async {
    final currentUser = await _authService.getCurrentUserData();
    return currentUser?.isPastor == true || currentUser?.isBishop == true;
  }

  /// Validate leader assignment permissions
  Future<bool> canAssignLeader(String leaderId, String fellowshipId) async {
    try {
      final canManage = await _authService.canManageUser(leaderId);
      if (!canManage) return false;

      final fellowship = await _firestoreService.getFellowship(fellowshipId);
      if (fellowship == null) return false;

      // Additional constituency checks could be added here
      return true;
    } catch (e) {
      return false;
    }
  }
}
