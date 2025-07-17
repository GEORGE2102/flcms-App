import 'package:cloud_firestore/cloud_firestore.dart';
import 'conflict_model.dart';
import '../utils/enums.dart';

class SundayBusReportModel with ConflictDetectionMixin {
  final String id;
  final String constituencyId;
  final String constituencyName;
  final String pastorId;
  final String pastorName;
  final String submittedBy;
  final String submitterName;
  final DateTime reportDate;
  final DateTime submittedAt;
  final List<String> attendanceList;
  final int attendanceCount;
  final String? busPhotoUrl;
  final double offering;
  final String driverName;
  final String driverPhone;
  final double busCost;
  final String? notes;
  final bool isApproved;
  final String? approvedBy;
  final DateTime? approvedAt;

  // Conflict detection fields
  @override
  final DateTime? lastUpdatedServer;
  @override
  final int version;
  @override
  final DateTime? localUpdatedAt;
  @override
  final SyncStatus syncStatus;
  @override
  final ConflictData? conflictData;

  SundayBusReportModel({
    required this.id,
    required this.constituencyId,
    required this.constituencyName,
    required this.pastorId,
    required this.pastorName,
    required this.submittedBy,
    required this.submitterName,
    required this.reportDate,
    required this.submittedAt,
    required this.attendanceList,
    required this.driverName,
    required this.driverPhone,
    required this.busCost,
    this.busPhotoUrl,
    this.offering = 0.0,
    this.notes,
    this.isApproved = false,
    this.approvedBy,
    this.approvedAt,
    // Conflict detection parameters
    this.lastUpdatedServer,
    this.version = 1,
    this.localUpdatedAt,
    this.syncStatus = SyncStatus.synced,
    this.conflictData,
  }) : attendanceCount = attendanceList.length;

  @override
  Map<String, dynamic> getConflictDetectionFields() {
    return {
      'attendanceList': attendanceList,
      'attendanceCount': attendanceCount,
      'busPhotoUrl': busPhotoUrl,
      'offering': offering,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'busCost': busCost,
      'notes': notes,
      'isApproved': isApproved,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
    };
  }

  @override
  List<String> getCriticalFields() {
    return [
      'attendanceList',
      'attendanceCount',
      'offering',
      'busCost',
      'driverName',
      'driverPhone',
      'isApproved',
      'approvedBy',
      'approvedAt',
    ];
  }

  /// Get offering amount formatted as currency
  String get formattedOffering => 'ZMW ${offering.toStringAsFixed(2)}';

  /// Get bus cost formatted as currency
  String get formattedBusCost => 'ZMW ${busCost.toStringAsFixed(2)}';

  /// Get report date formatted
  String get formattedReportDate =>
      '${reportDate.day}/${reportDate.month}/${reportDate.year}';

  /// Check if bus photo is attached
  bool get hasBusPhoto => busPhotoUrl != null && busPhotoUrl!.isNotEmpty;

  /// Get profit/loss from bus operation
  double get profit => offering - busCost;

  /// Get profit/loss formatted
  String get formattedProfit {
    final profitAmount = profit;
    if (profitAmount >= 0) {
      return 'Profit: ZMW ${profitAmount.toStringAsFixed(2)}';
    } else {
      return 'Loss: ZMW ${(-profitAmount).toStringAsFixed(2)}';
    }
  }

  /// Get sync status display text
  String get syncStatusDisplay => syncStatus.displayName;

  /// Check if report can be edited (not approved and not in conflict)
  bool get canEdit => !isApproved && !hasConflict;

  /// Convert to Firebase document
  Map<String, dynamic> toFirestore() {
    return {
      'constituencyId': constituencyId,
      'constituencyName': constituencyName,
      'pastorId': pastorId,
      'pastorName': pastorName,
      'submittedBy': submittedBy,
      'submitterName': submitterName,
      'reportDate': Timestamp.fromDate(reportDate),
      'submittedAt': Timestamp.fromDate(submittedAt),
      'attendanceList': attendanceList,
      'attendanceCount': attendanceCount,
      'busPhotoUrl': busPhotoUrl,
      'offering': offering,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'busCost': busCost,
      'notes': notes,
      'isApproved': isApproved,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      // Conflict detection fields
      'lastUpdatedServer': FieldValue.serverTimestamp(),
      'version': version,
      'localUpdatedAt': localUpdatedAt?.toIso8601String(),
      'syncStatus': syncStatus.value,
    };
  }

  /// Create from Firebase document
  factory SundayBusReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return SundayBusReportModel(
      id: doc.id,
      constituencyId: data['constituencyId'] ?? '',
      constituencyName: data['constituencyName'] ?? '',
      pastorId: data['pastorId'] ?? '',
      pastorName: data['pastorName'] ?? '',
      submittedBy: data['submittedBy'] ?? '',
      submitterName: data['submitterName'] ?? '',
      reportDate:
          (data['reportDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attendanceList: List<String>.from(data['attendanceList'] ?? []),
      busPhotoUrl: data['busPhotoUrl'],
      offering: (data['offering'] ?? 0.0).toDouble(),
      driverName: data['driverName'] ?? '',
      driverPhone: data['driverPhone'] ?? '',
      busCost: (data['busCost'] ?? 0.0).toDouble(),
      notes: data['notes'],
      isApproved: data['isApproved'] ?? false,
      approvedBy: data['approvedBy'],
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      // Conflict detection fields
      lastUpdatedServer: (data['lastUpdatedServer'] as Timestamp?)?.toDate(),
      version: data['version'] ?? 1,
      localUpdatedAt:
          data['localUpdatedAt'] != null
              ? DateTime.parse(data['localUpdatedAt'])
              : null,
      syncStatus: SyncStatus.fromString(data['syncStatus'] ?? 'synced'),
    );
  }

  /// Create from local storage (includes conflict data)
  factory SundayBusReportModel.fromLocalStorage(Map<String, dynamic> data) {
    return SundayBusReportModel(
      id: data['id'] ?? '',
      constituencyId: data['constituencyId'] ?? '',
      constituencyName: data['constituencyName'] ?? '',
      pastorId: data['pastorId'] ?? '',
      pastorName: data['pastorName'] ?? '',
      submittedBy: data['submittedBy'] ?? '',
      submitterName: data['submitterName'] ?? '',
      reportDate: DateTime.parse(data['reportDate']),
      submittedAt: DateTime.parse(data['submittedAt']),
      attendanceList: List<String>.from(data['attendanceList'] ?? []),
      busPhotoUrl: data['busPhotoUrl'],
      offering: (data['offering'] ?? 0.0).toDouble(),
      driverName: data['driverName'] ?? '',
      driverPhone: data['driverPhone'] ?? '',
      busCost: (data['busCost'] ?? 0.0).toDouble(),
      notes: data['notes'],
      isApproved: data['isApproved'] ?? false,
      approvedBy: data['approvedBy'],
      approvedAt:
          data['approvedAt'] != null
              ? DateTime.parse(data['approvedAt'])
              : null,
      // Conflict detection fields
      lastUpdatedServer:
          data['lastUpdatedServer'] != null
              ? DateTime.parse(data['lastUpdatedServer'])
              : null,
      version: data['version'] ?? 1,
      localUpdatedAt:
          data['localUpdatedAt'] != null
              ? DateTime.parse(data['localUpdatedAt'])
              : null,
      syncStatus: SyncStatus.fromString(data['syncStatus'] ?? 'synced'),
      conflictData:
          data['conflictData'] != null
              ? ConflictData.fromMap(data['conflictData'])
              : null,
    );
  }

  /// Create a copy with updated fields
  SundayBusReportModel copyWith({
    String? id,
    String? constituencyId,
    String? constituencyName,
    String? pastorId,
    String? pastorName,
    String? submittedBy,
    String? submitterName,
    DateTime? reportDate,
    DateTime? submittedAt,
    List<String>? attendanceList,
    String? busPhotoUrl,
    double? offering,
    String? driverName,
    String? driverPhone,
    double? busCost,
    String? notes,
    bool? isApproved,
    String? approvedBy,
    DateTime? approvedAt,
    // Conflict detection fields
    DateTime? lastUpdatedServer,
    int? version,
    DateTime? localUpdatedAt,
    SyncStatus? syncStatus,
    ConflictData? conflictData,
  }) {
    return SundayBusReportModel(
      id: id ?? this.id,
      constituencyId: constituencyId ?? this.constituencyId,
      constituencyName: constituencyName ?? this.constituencyName,
      pastorId: pastorId ?? this.pastorId,
      pastorName: pastorName ?? this.pastorName,
      submittedBy: submittedBy ?? this.submittedBy,
      submitterName: submitterName ?? this.submitterName,
      reportDate: reportDate ?? this.reportDate,
      submittedAt: submittedAt ?? this.submittedAt,
      attendanceList: attendanceList ?? this.attendanceList,
      busPhotoUrl: busPhotoUrl ?? this.busPhotoUrl,
      offering: offering ?? this.offering,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      busCost: busCost ?? this.busCost,
      notes: notes ?? this.notes,
      isApproved: isApproved ?? this.isApproved,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      // Conflict detection fields
      lastUpdatedServer: lastUpdatedServer ?? this.lastUpdatedServer,
      version: version ?? this.version,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      conflictData: conflictData ?? this.conflictData,
    );
  }

  /// Create a copy with incremented version and updated local timestamp
  SundayBusReportModel copyWithLocalUpdate() {
    return copyWith(
      version: version + 1,
      localUpdatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  /// Create a copy marked as conflicted
  SundayBusReportModel copyWithConflict(ConflictData conflict) {
    return copyWith(syncStatus: SyncStatus.conflicted, conflictData: conflict);
  }

  /// Create a copy with resolved conflict
  SundayBusReportModel copyWithResolvedConflict({
    required Map<String, dynamic> resolvedData,
    required DateTime serverTimestamp,
  }) {
    return SundayBusReportModel(
      id: id,
      constituencyId: resolvedData['constituencyId'] ?? constituencyId,
      constituencyName: resolvedData['constituencyName'] ?? constituencyName,
      pastorId: resolvedData['pastorId'] ?? pastorId,
      pastorName: resolvedData['pastorName'] ?? pastorName,
      submittedBy: resolvedData['submittedBy'] ?? submittedBy,
      submitterName: resolvedData['submitterName'] ?? submitterName,
      reportDate:
          resolvedData['reportDate'] != null
              ? DateTime.parse(resolvedData['reportDate'])
              : reportDate,
      submittedAt:
          resolvedData['submittedAt'] != null
              ? DateTime.parse(resolvedData['submittedAt'])
              : submittedAt,
      attendanceList:
          resolvedData['attendanceList'] != null
              ? List<String>.from(resolvedData['attendanceList'])
              : attendanceList,
      busPhotoUrl: resolvedData['busPhotoUrl'] ?? busPhotoUrl,
      offering: (resolvedData['offering'] ?? offering).toDouble(),
      driverName: resolvedData['driverName'] ?? driverName,
      driverPhone: resolvedData['driverPhone'] ?? driverPhone,
      busCost: (resolvedData['busCost'] ?? busCost).toDouble(),
      notes: resolvedData['notes'] ?? notes,
      isApproved: resolvedData['isApproved'] ?? isApproved,
      approvedBy: resolvedData['approvedBy'] ?? approvedBy,
      approvedAt:
          resolvedData['approvedAt'] != null
              ? DateTime.parse(resolvedData['approvedAt'])
              : approvedAt,
      // Reset conflict state
      lastUpdatedServer: serverTimestamp,
      version: version + 1,
      localUpdatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      conflictData: null,
    );
  }

  @override
  String toString() {
    return 'SundayBusReportModel(id: $id, constituency: $constituencyName, date: $formattedReportDate, attendance: $attendanceCount, syncStatus: ${syncStatus.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SundayBusReportModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
