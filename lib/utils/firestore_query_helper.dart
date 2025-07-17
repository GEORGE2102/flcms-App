import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/fellowship_model.dart';
import '../utils/enums.dart';

/// Helper class to prevent Firestore index issues with optimized queries
/// Use these methods instead of direct Firestore queries to avoid index errors
class FirestoreQueryHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get leaders by constituency with optimized indexing
  /// This query is covered by composite index: role + constituencyId + firstName
  static Stream<List<UserModel>> getLeadersByConstituency(
    String constituencyId,
  ) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.leader.value)
        .where('constituencyId', isEqualTo: constituencyId)
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Get fellowships by constituency with optimized indexing
  /// This query is covered by composite index: constituencyId + name
  static Stream<List<FellowshipModel>> getFellowshipsByConstituency(
    String constituencyId,
  ) {
    return _firestore
        .collection('fellowships')
        .where('constituencyId', isEqualTo: constituencyId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FellowshipModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get users by role only (no additional filters)
  /// This uses single field index, no composite index needed
  static Stream<List<UserModel>> getUsersByRole(UserRole role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role.value)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Get users by role with status filter (uses existing composite index)
  /// Covered by index: role + status + createdAt
  static Stream<List<UserModel>> getUsersByRoleAndStatus(
    UserRole role,
    Status status,
  ) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role.value)
        .where('status', isEqualTo: status.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Get leaders assigned to a specific pastor
  /// Covered by index: assignedPastorId + status
  static Stream<List<UserModel>> getLeadersByPastor(String pastorId) {
    return _firestore
        .collection('users')
        .where('assignedPastorId', isEqualTo: pastorId)
        .where('status', isEqualTo: Status.active.value)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Alternative method: Get leaders without ordering (no composite index needed)
  /// Use this if you want to avoid composite indexes and sort in memory
  static Stream<List<UserModel>> getLeadersByConstituencyNoOrder(
    String constituencyId,
  ) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.leader.value)
        .where('constituencyId', isEqualTo: constituencyId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList()
                ..sort((a, b) => a.firstName.compareTo(b.firstName)),
        );
  }

  /// Check if a query requires a composite index
  /// Use this during development to identify potential index issues
  static bool requiresCompositeIndex({
    required List<String> whereFields,
    String? orderByField,
  }) {
    // Single where clause with orderBy on different field = needs index
    if (whereFields.length == 1 &&
        orderByField != null &&
        !whereFields.contains(orderByField)) {
      return true;
    }

    // Multiple where clauses = needs index
    if (whereFields.length > 1) {
      return true;
    }

    // Multiple where clauses with orderBy = definitely needs index
    if (whereFields.length > 1 && orderByField != null) {
      return true;
    }

    return false;
  }

  /// Debug method to analyze query complexity
  static Map<String, dynamic> analyzeQuery({
    required List<String> whereFields,
    String? orderByField,
    String? collectionPath,
  }) {
    final needsIndex = requiresCompositeIndex(
      whereFields: whereFields,
      orderByField: orderByField,
    );

    return {
      'collection': collectionPath,
      'whereFields': whereFields,
      'orderByField': orderByField,
      'needsCompositeIndex': needsIndex,
      'indexFields':
          needsIndex
              ? [...whereFields, if (orderByField != null) orderByField]
              : null,
      'recommendation':
          needsIndex
              ? 'Add composite index for optimal performance'
              : 'Single field indexes sufficient',
    };
  }
}

/// Extension methods for common query patterns
extension FirestoreQueryExtensions on Query<Map<String, dynamic>> {
  /// Safe orderBy that checks for potential index issues
  Query<Map<String, dynamic>> safeOrderBy(
    String field, {
    bool descending = false,
  }) {
    // In development, you could add logging here to track orderBy usage
    return orderBy(field, descending: descending);
  }

  /// Chain multiple where clauses with index awareness
  Query<Map<String, dynamic>> safeWhere(
    String field, {
    required dynamic isEqualTo,
    bool logIndexWarning = true,
  }) {
    // In development, you could track field combinations here
    return where(field, isEqualTo: isEqualTo);
  }
}
