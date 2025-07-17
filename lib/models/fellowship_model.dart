import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/enums.dart';

class FellowshipModel {
  final String id;
  final String name;
  final String? description;
  final String constituencyId;
  final String pastorId;
  final String? leaderId;
  final Status status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? meetingDay;
  final String? meetingTime;
  final String? meetingLocation;
  final int memberCount;

  FellowshipModel({
    required this.id,
    required this.name,
    this.description,
    required this.constituencyId,
    required this.pastorId,
    this.leaderId,
    this.status = Status.active,
    required this.createdAt,
    required this.updatedAt,
    this.meetingDay,
    this.meetingTime,
    this.meetingLocation,
    this.memberCount = 0,
  });

  /// Convert to Firebase document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'constituencyId': constituencyId,
      'pastorId': pastorId,
      'leaderId': leaderId,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'meetingDay': meetingDay,
      'meetingTime': meetingTime,
      'meetingLocation': meetingLocation,
      'memberCount': memberCount,
    };
  }

  /// Create from Firebase document
  factory FellowshipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FellowshipModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      constituencyId: data['constituencyId'] ?? '',
      pastorId: data['pastorId'] ?? '',
      leaderId: data['leaderId'],
      status: Status.fromString(data['status'] ?? 'active'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      meetingDay: data['meetingDay'],
      meetingTime: data['meetingTime'],
      meetingLocation: data['meetingLocation'],
      memberCount: data['memberCount'] ?? 0,
    );
  }

  /// Create a copy with updated fields
  FellowshipModel copyWith({
    String? id,
    String? name,
    String? description,
    String? constituencyId,
    String? pastorId,
    String? leaderId,
    Status? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? meetingDay,
    String? meetingTime,
    String? meetingLocation,
    int? memberCount,
  }) {
    return FellowshipModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      constituencyId: constituencyId ?? this.constituencyId,
      pastorId: pastorId ?? this.pastorId,
      leaderId: leaderId ?? this.leaderId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      meetingDay: meetingDay ?? this.meetingDay,
      meetingTime: meetingTime ?? this.meetingTime,
      meetingLocation: meetingLocation ?? this.meetingLocation,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  @override
  String toString() {
    return 'FellowshipModel(id: $id, name: $name, status: ${status.displayName}, members: $memberCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FellowshipModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
