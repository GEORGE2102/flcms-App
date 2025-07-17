import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/fellowship_model.dart';
import '../models/fellowship_report_model.dart';
import '../models/sunday_bus_report_model.dart';
import '../utils/app_config.dart';
import '../utils/enums.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== USER OPERATIONS ====================

  /// Create or update user document
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.id)
          .set(user.toFirestore());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  /// Get user by ID
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc =
          await _firestore
              .collection(AppConfig.usersCollection)
              .doc(userId)
              .get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  /// Get users by role
  Stream<List<UserModel>> getUsersByRole(UserRole role) {
    return _firestore
        .collection(AppConfig.usersCollection)
        .where('role', isEqualTo: role.value)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Update user status
  Future<void> updateUserStatus(String userId, Status status) async {
    try {
      await _firestore.collection(AppConfig.usersCollection).doc(userId).update(
        {'status': status.value, 'updatedAt': FieldValue.serverTimestamp()},
      );
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  // ==================== FELLOWSHIP OPERATIONS ====================

  /// Create fellowship
  Future<String> createFellowship(FellowshipModel fellowship) async {
    try {
      final docRef = await _firestore
          .collection(AppConfig.fellowshipsCollection)
          .add(fellowship.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create fellowship: $e');
    }
  }

  /// Get fellowship by ID
  Future<FellowshipModel?> getFellowship(String fellowshipId) async {
    try {
      final doc =
          await _firestore
              .collection(AppConfig.fellowshipsCollection)
              .doc(fellowshipId)
              .get();
      if (doc.exists) {
        return FellowshipModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get fellowship: $e');
    }
  }

  /// Get fellowships by constituency
  Stream<List<FellowshipModel>> getFellowshipsByConstituency(
    String constituencyId,
  ) {
    return _firestore
        .collection(AppConfig.fellowshipsCollection)
        .where('constituencyId', isEqualTo: constituencyId)
        .where('status', isEqualTo: Status.active.value)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FellowshipModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get fellowships by pastor
  Stream<List<FellowshipModel>> getFellowshipsByPastor(String pastorId) {
    return _firestore
        .collection(AppConfig.fellowshipsCollection)
        .where('pastorId', isEqualTo: pastorId)
        .where('status', isEqualTo: Status.active.value)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FellowshipModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get fellowship by leader
  Future<FellowshipModel?> getFellowshipByLeader(String leaderId) async {
    try {
      final query =
          await _firestore
              .collection(AppConfig.fellowshipsCollection)
              .where('leaderId', isEqualTo: leaderId)
              .where('status', isEqualTo: Status.active.value)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        return FellowshipModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get fellowship by leader: $e');
    }
  }

  /// Update fellowship
  Future<void> updateFellowship(
    String fellowshipId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(AppConfig.fellowshipsCollection)
          .doc(fellowshipId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update fellowship: $e');
    }
  }

  // ==================== FELLOWSHIP REPORT OPERATIONS ====================

  /// Submit fellowship report
  Future<String> submitFellowshipReport(FellowshipReportModel report) async {
    try {
      final docRef = await _firestore
          .collection(AppConfig.fellowshipReportsCollection)
          .add(report.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to submit fellowship report: $e');
    }
  }

  /// Get fellowship reports by fellowship ID
  Stream<List<FellowshipReportModel>> getFellowshipReports({
    required String fellowshipId,
    int limit = 20,
  }) {
    return _firestore
        .collection(AppConfig.fellowshipReportsCollection)
        .where('fellowshipId', isEqualTo: fellowshipId)
        .orderBy('reportDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FellowshipReportModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get fellowship reports by constituency
  Stream<List<FellowshipReportModel>> getConstituencyReports({
    required String constituencyId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection(AppConfig.fellowshipReportsCollection)
        .where('constituencyId', isEqualTo: constituencyId);

    if (startDate != null) {
      query = query.where(
        'reportDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'reportDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    return query
        .orderBy('reportDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FellowshipReportModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get all fellowship reports (for bishops)
  Stream<List<FellowshipReportModel>> getAllFellowshipReports({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) {
    Query query = _firestore.collection(AppConfig.fellowshipReportsCollection);

    if (startDate != null) {
      query = query.where(
        'reportDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'reportDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    return query
        .orderBy('reportDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FellowshipReportModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Approve fellowship report
  Future<void> approveFellowshipReport(
    String reportId,
    String approvedBy,
  ) async {
    try {
      await _firestore
          .collection(AppConfig.fellowshipReportsCollection)
          .doc(reportId)
          .update({
            'isApproved': true,
            'approvedBy': approvedBy,
            'approvedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to approve report: $e');
    }
  }

  // ==================== BUS REPORT OPERATIONS ====================

  /// Submit Sunday bus report
  Future<String> submitBusReport(SundayBusReportModel report) async {
    try {
      final docRef = await _firestore
          .collection(AppConfig.busReportsCollection)
          .add(report.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to submit bus report: $e');
    }
  }

  /// Get bus reports by constituency
  Stream<List<SundayBusReportModel>> getBusReports({
    required String constituencyId,
    int limit = 20,
  }) {
    return _firestore
        .collection(AppConfig.busReportsCollection)
        .where('constituencyId', isEqualTo: constituencyId)
        .orderBy('reportDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => SundayBusReportModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get bus reports by date range
  Stream<List<SundayBusReportModel>> getBusReportsByDateRange({
    required String constituencyId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection(AppConfig.busReportsCollection)
        .where('constituencyId', isEqualTo: constituencyId);

    if (startDate != null) {
      query = query.where(
        'reportDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'reportDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    return query
        .orderBy('reportDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => SundayBusReportModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get all bus reports (for bishops)
  Stream<List<SundayBusReportModel>> getAllBusReports({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) {
    Query query = _firestore.collection(AppConfig.busReportsCollection);

    if (startDate != null) {
      query = query.where(
        'reportDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'reportDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    return query
        .orderBy('reportDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => SundayBusReportModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Approve bus report
  Future<void> approveBusReport(String reportId, String approvedBy) async {
    try {
      await _firestore
          .collection(AppConfig.busReportsCollection)
          .doc(reportId)
          .update({
            'isApproved': true,
            'approvedBy': approvedBy,
            'approvedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to approve bus report: $e');
    }
  }

  // ==================== ANALYTICS AND AGGREGATIONS ====================

  /// Get fellowship summary for dashboard
  Future<Map<String, dynamic>> getFellowshipSummary({
    String? constituencyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query baseQuery = _firestore.collection(
        AppConfig.fellowshipReportsCollection,
      );

      if (constituencyId != null) {
        baseQuery = baseQuery.where(
          'constituencyId',
          isEqualTo: constituencyId,
        );
      }

      if (startDate != null) {
        baseQuery = baseQuery.where(
          'reportDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        baseQuery = baseQuery.where(
          'reportDate',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await baseQuery.get();

      int totalReports = snapshot.docs.length;
      int totalAttendance = 0;
      double totalOffering = 0.0;
      int approvedReports = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalAttendance += (data['attendanceCount'] ?? 0) as int;
        totalOffering += (data['offeringAmount'] ?? 0.0).toDouble();
        if (data['isApproved'] == true) approvedReports++;
      }

      return {
        'totalReports': totalReports,
        'totalAttendance': totalAttendance,
        'totalOffering': totalOffering,
        'approvedReports': approvedReports,
        'averageAttendance':
            totalReports > 0 ? totalAttendance / totalReports : 0.0,
        'averageOffering':
            totalReports > 0 ? totalOffering / totalReports : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get fellowship summary: $e');
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// Batch update multiple documents
  Future<void> batchUpdate(List<Map<String, dynamic>> updates) async {
    try {
      final batch = _firestore.batch();

      for (final update in updates) {
        final docRef = _firestore
            .collection(update['collection'])
            .doc(update['docId']);
        batch.update(docRef, update['data']);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to perform batch update: $e');
    }
  }

  // ==================== SEARCH OPERATIONS ====================

  /// Search fellowships by name
  Future<List<FellowshipModel>> searchFellowships(String searchTerm) async {
    try {
      final snapshot =
          await _firestore
              .collection(AppConfig.fellowshipsCollection)
              .where('name', isGreaterThanOrEqualTo: searchTerm)
              .where('name', isLessThan: searchTerm + 'z')
              .where('status', isEqualTo: Status.active.value)
              .limit(20)
              .get();

      return snapshot.docs
          .map((doc) => FellowshipModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to search fellowships: $e');
    }
  }

  /// Search users by name
  Future<List<UserModel>> searchUsers(String searchTerm) async {
    try {
      final snapshot =
          await _firestore
              .collection(AppConfig.usersCollection)
              .where('firstName', isGreaterThanOrEqualTo: searchTerm)
              .where('firstName', isLessThan: searchTerm + 'z')
              .limit(20)
              .get();

      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }
}
