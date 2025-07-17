import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/enums.dart';

class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final Status status;
  final String? phoneNumber;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Role-specific fields
  final String? constituencyId; // For pastors - which constituency they manage
  final String? fellowshipId; // For leaders - which fellowship they lead
  final String? assignedPastorId; // For leaders - who their pastor is

  // Enhanced invitation fields
  final String? invitationToken;
  final DateTime? invitationExpiresAt;
  final String? invitedBy;
  final DateTime? invitationSentAt;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.status = Status.pending,
    this.phoneNumber,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.constituencyId,
    this.fellowshipId,
    this.assignedPastorId,
    this.invitationToken,
    this.invitationExpiresAt,
    this.invitedBy,
    this.invitationSentAt,
  });

  /// Get full name
  String get fullName => '$firstName $lastName';

  /// Get display name with role
  String get displayNameWithRole => '$fullName (${role.displayName})';

  /// Check if user is bishop
  bool get isBishop => role == UserRole.bishop;

  /// Check if user is pastor
  bool get isPastor => role == UserRole.pastor;

  /// Check if user is treasurer
  bool get isTreasurer => role == UserRole.treasurer;

  /// Check if user is leader
  bool get isLeader => role == UserRole.leader;

  /// Check if user can manage another user
  bool canManage(UserModel other) {
    if (role.canManage(other.role)) {
      // Additional business logic for church hierarchy
      switch (role) {
        case UserRole.bishop:
          return true; // Bishop can manage everyone
        case UserRole.pastor:
          // Pastor can manage leaders in their constituency
          if (other.isLeader) {
            return other.assignedPastorId == id;
          }
          return false;
        case UserRole.treasurer:
          return false; // Treasurers can't manage other users
        case UserRole.leader:
          return false; // Leaders can't manage other users
      }
    }
    return false;
  }

  /// Convert to Firebase document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.value,
      'status': status.value,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'constituencyId': constituencyId,
      'fellowshipId': fellowshipId,
      'assignedPastorId': assignedPastorId,
      'invitationToken': invitationToken,
      'invitationExpiresAt': invitationExpiresAt,
      'invitedBy': invitedBy,
      'invitationSentAt': invitationSentAt,
    };
  }

  /// Create from Firebase document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      role: UserRole.fromString(data['role'] ?? 'leader'),
      status: Status.fromString(data['status'] ?? 'pending'),
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      constituencyId: data['constituencyId'],
      fellowshipId: data['fellowshipId'],
      assignedPastorId: data['assignedPastorId'],
      invitationToken: data['invitationToken'],
      invitationExpiresAt: data['invitationExpiresAt']?.toDate(),
      invitedBy: data['invitedBy'],
      invitationSentAt: data['invitationSentAt']?.toDate(),
    );
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    UserRole? role,
    Status? status,
    String? phoneNumber,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? constituencyId,
    String? fellowshipId,
    String? assignedPastorId,
    String? invitationToken,
    DateTime? invitationExpiresAt,
    String? invitedBy,
    DateTime? invitationSentAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      constituencyId: constituencyId ?? this.constituencyId,
      fellowshipId: fellowshipId ?? this.fellowshipId,
      assignedPastorId: assignedPastorId ?? this.assignedPastorId,
      invitationToken: invitationToken ?? this.invitationToken,
      invitationExpiresAt: invitationExpiresAt ?? this.invitationExpiresAt,
      invitedBy: invitedBy ?? this.invitedBy,
      invitationSentAt: invitationSentAt ?? this.invitationSentAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, fullName: $fullName, role: ${role.displayName}, status: ${status.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
