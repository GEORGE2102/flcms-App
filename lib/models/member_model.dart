import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/enums.dart';

class MemberModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? email;
  final String fellowshipId;
  final String fellowshipName;
  final String constituencyId;
  final DateTime dateJoined;
  final Status status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profileImageUrl;
  final String? address;
  final DateTime? dateOfBirth;
  final String? occupation;

  MemberModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.email,
    required this.fellowshipId,
    required this.fellowshipName,
    required this.constituencyId,
    required this.dateJoined,
    this.status = Status.active,
    required this.createdAt,
    required this.updatedAt,
    this.profileImageUrl,
    this.address,
    this.dateOfBirth,
    this.occupation,
  });

  /// Get full name
  String get fullName => '$firstName $lastName';

  /// Get formatted phone number
  String get formattedPhone => phoneNumber ?? 'No phone';

  /// Calculate age if date of birth is available
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  /// Convert to Firebase document
  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'email': email,
      'fellowshipId': fellowshipId,
      'fellowshipName': fellowshipName,
      'constituencyId': constituencyId,
      'dateJoined': Timestamp.fromDate(dateJoined),
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'profileImageUrl': profileImageUrl,
      'address': address,
      'dateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'occupation': occupation,
    };
  }

  /// Create from Firebase document
  factory MemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MemberModel(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      phoneNumber: data['phoneNumber'],
      email: data['email'],
      fellowshipId: data['fellowshipId'] ?? '',
      fellowshipName: data['fellowshipName'] ?? '',
      constituencyId: data['constituencyId'] ?? '',
      dateJoined:
          (data['dateJoined'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: Status.fromString(data['status'] ?? 'active'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImageUrl: data['profileImageUrl'],
      address: data['address'],
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate(),
      occupation: data['occupation'],
    );
  }

  /// Create a copy with updated fields
  MemberModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? email,
    String? fellowshipId,
    String? fellowshipName,
    String? constituencyId,
    DateTime? dateJoined,
    Status? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profileImageUrl,
    String? address,
    DateTime? dateOfBirth,
    String? occupation,
  }) {
    return MemberModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      fellowshipId: fellowshipId ?? this.fellowshipId,
      fellowshipName: fellowshipName ?? this.fellowshipName,
      constituencyId: constituencyId ?? this.constituencyId,
      dateJoined: dateJoined ?? this.dateJoined,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      address: address ?? this.address,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      occupation: occupation ?? this.occupation,
    );
  }

  @override
  String toString() {
    return 'MemberModel(id: $id, name: $fullName, fellowship: $fellowshipName, phone: $formattedPhone)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemberModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
