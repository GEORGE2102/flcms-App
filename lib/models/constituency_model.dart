import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/enums.dart';

class ConstituencyModel {
  final String id;
  final String name;
  final String? description;
  final String pastorId;
  final String pastorName;
  final Status status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int fellowshipCount;
  final int totalMembers;

  ConstituencyModel({
    required this.id,
    required this.name,
    this.description,
    required this.pastorId,
    required this.pastorName,
    this.status = Status.active,
    required this.createdAt,
    required this.updatedAt,
    this.fellowshipCount = 0,
    this.totalMembers = 0,
  });

  /// Convert to Firebase document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'pastorId': pastorId,
      'pastorName': pastorName,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'fellowshipCount': fellowshipCount,
      'totalMembers': totalMembers,
    };
  }

  /// Create from Firebase document
  factory ConstituencyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ConstituencyModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      pastorId: data['pastorId'] ?? '',
      pastorName: data['pastorName'] ?? '',
      status: Status.fromString(data['status'] ?? 'active'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fellowshipCount: data['fellowshipCount'] ?? 0,
      totalMembers: data['totalMembers'] ?? 0,
    );
  }

  /// Create a copy with updated fields
  ConstituencyModel copyWith({
    String? id,
    String? name,
    String? description,
    String? pastorId,
    String? pastorName,
    Status? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? fellowshipCount,
    int? totalMembers,
  }) {
    return ConstituencyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      pastorId: pastorId ?? this.pastorId,
      pastorName: pastorName ?? this.pastorName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fellowshipCount: fellowshipCount ?? this.fellowshipCount,
      totalMembers: totalMembers ?? this.totalMembers,
    );
  }

  @override
  String toString() {
    return 'ConstituencyModel(id: $id, name: $name, pastor: $pastorName, fellowships: $fellowshipCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConstituencyModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
