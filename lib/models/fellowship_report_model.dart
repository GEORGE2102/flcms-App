import 'package:cloud_firestore/cloud_firestore.dart';
import 'conflict_model.dart';
import '../utils/enums.dart';

class FellowshipReportModel with ConflictDetectionMixin {
  final String id;
  final String fellowshipId;
  final String fellowshipName;
  final String constituencyId;
  final String constituencyName;
  final String pastorId;
  final String pastorName;
  final String submittedBy;
  final String submitterName;
  final DateTime reportDate;
  final DateTime submittedAt;
  final int attendanceCount;
  final double offeringAmount;
  final String? notes;
  final String? fellowshipImageUrl;
  final String? receiptImageUrl;
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

  FellowshipReportModel({
    required this.id,
    required this.fellowshipId,
    required this.fellowshipName,
    required this.constituencyId,
    required this.constituencyName,
    required this.pastorId,
    required this.pastorName,
    required this.submittedBy,
    required this.submitterName,
    required this.reportDate,
    required this.submittedAt,
    required this.attendanceCount,
    required this.offeringAmount,
    this.notes,
    this.fellowshipImageUrl,
    this.receiptImageUrl,
    this.isApproved = false,
    this.approvedBy,
    this.approvedAt,
    // Conflict detection parameters
    this.lastUpdatedServer,
    this.version = 1,
    this.localUpdatedAt,
    this.syncStatus = SyncStatus.synced,
    this.conflictData,
  });

  @override
  Map<String, dynamic> getConflictDetectionFields() {
    return {
      'attendanceCount': attendanceCount,
      'offeringAmount': offeringAmount,
      'notes': notes,
      'fellowshipImageUrl': fellowshipImageUrl,
      'receiptImageUrl': receiptImageUrl,
      'isApproved': isApproved,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
    };
  }

  @override
  List<String> getCriticalFields() {
    return [
      'attendanceCount',
      'offeringAmount',
      'isApproved',
      'approvedBy',
      'approvedAt',
    ];
  }

  /// Convert to Firebase document
  Map<String, dynamic> toFirestore() {
    return {
      'fellowshipId': fellowshipId,
      'fellowshipName': fellowshipName,
      'constituencyId': constituencyId,
      'constituencyName': constituencyName,
      'pastorId': pastorId,
      'pastorName': pastorName,
      'submittedBy': submittedBy,
      'submitterName': submitterName,
      'reportDate': Timestamp.fromDate(reportDate),
      'submittedAt': Timestamp.fromDate(submittedAt),
      'attendanceCount': attendanceCount,
      'offeringAmount': offeringAmount,
      'notes': notes,
      'fellowshipImageUrl': fellowshipImageUrl,
      'receiptImageUrl': receiptImageUrl,
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
  factory FellowshipReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FellowshipReportModel(
      id: doc.id,
      fellowshipId: data['fellowshipId'] ?? '',
      fellowshipName: data['fellowshipName'] ?? '',
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
      attendanceCount: data['attendanceCount'] ?? 0,
      offeringAmount: (data['offeringAmount'] ?? 0.0).toDouble(),
      notes: data['notes'],
      fellowshipImageUrl: data['fellowshipImageUrl'],
      receiptImageUrl: data['receiptImageUrl'],
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
  factory FellowshipReportModel.fromLocalStorage(Map<String, dynamic> data) {
    return FellowshipReportModel(
      id: data['id'] ?? '',
      fellowshipId: data['fellowshipId'] ?? '',
      fellowshipName: data['fellowshipName'] ?? '',
      constituencyId: data['constituencyId'] ?? '',
      constituencyName: data['constituencyName'] ?? '',
      pastorId: data['pastorId'] ?? '',
      pastorName: data['pastorName'] ?? '',
      submittedBy: data['submittedBy'] ?? '',
      submitterName: data['submitterName'] ?? '',
      reportDate: DateTime.parse(data['reportDate']),
      submittedAt: DateTime.parse(data['submittedAt']),
      attendanceCount: data['attendanceCount'] ?? 0,
      offeringAmount: (data['offeringAmount'] ?? 0.0).toDouble(),
      notes: data['notes'],
      fellowshipImageUrl: data['fellowshipImageUrl'],
      receiptImageUrl: data['receiptImageUrl'],
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
  FellowshipReportModel copyWith({
    String? id,
    String? fellowshipId,
    String? fellowshipName,
    String? constituencyId,
    String? constituencyName,
    String? pastorId,
    String? pastorName,
    String? submittedBy,
    String? submitterName,
    DateTime? reportDate,
    DateTime? submittedAt,
    int? attendanceCount,
    double? offeringAmount,
    String? notes,
    String? fellowshipImageUrl,
    String? receiptImageUrl,
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
    return FellowshipReportModel(
      id: id ?? this.id,
      fellowshipId: fellowshipId ?? this.fellowshipId,
      fellowshipName: fellowshipName ?? this.fellowshipName,
      constituencyId: constituencyId ?? this.constituencyId,
      constituencyName: constituencyName ?? this.constituencyName,
      pastorId: pastorId ?? this.pastorId,
      pastorName: pastorName ?? this.pastorName,
      submittedBy: submittedBy ?? this.submittedBy,
      submitterName: submitterName ?? this.submitterName,
      reportDate: reportDate ?? this.reportDate,
      submittedAt: submittedAt ?? this.submittedAt,
      attendanceCount: attendanceCount ?? this.attendanceCount,
      offeringAmount: offeringAmount ?? this.offeringAmount,
      notes: notes ?? this.notes,
      fellowshipImageUrl: fellowshipImageUrl ?? this.fellowshipImageUrl,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
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
  FellowshipReportModel copyWithLocalUpdate() {
    return copyWith(
      version: version + 1,
      localUpdatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  /// Create a copy marked as conflicted
  FellowshipReportModel copyWithConflict(ConflictData conflict) {
    return copyWith(syncStatus: SyncStatus.conflicted, conflictData: conflict);
  }

  /// Create a copy with resolved conflict
  FellowshipReportModel copyWithResolvedConflict({
    required Map<String, dynamic> resolvedData,
    required DateTime serverTimestamp,
  }) {
    return FellowshipReportModel(
      id: id,
      fellowshipId: resolvedData['fellowshipId'] ?? fellowshipId,
      fellowshipName: resolvedData['fellowshipName'] ?? fellowshipName,
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
      attendanceCount: resolvedData['attendanceCount'] ?? attendanceCount,
      offeringAmount:
          (resolvedData['offeringAmount'] ?? offeringAmount).toDouble(),
      notes: resolvedData['notes'] ?? notes,
      fellowshipImageUrl:
          resolvedData['fellowshipImageUrl'] ?? fellowshipImageUrl,
      receiptImageUrl: resolvedData['receiptImageUrl'] ?? receiptImageUrl,
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

  /// Get offering amount formatted as currency
  String get formattedOffering => 'ZMW ${offeringAmount.toStringAsFixed(2)}';

  /// Get report date formatted
  String get formattedReportDate =>
      '${reportDate.day}/${reportDate.month}/${reportDate.year}';

  /// Get submitted date formatted
  String get formattedSubmittedDate =>
      '${submittedAt.day}/${submittedAt.month}/${submittedAt.year}';

  /// Check if report has any attachments
  bool get hasAttachments =>
      fellowshipImageUrl != null || receiptImageUrl != null;

  /// Check if fellowship image is attached
  bool get hasFellowshipImage =>
      fellowshipImageUrl != null && fellowshipImageUrl!.isNotEmpty;

  /// Check if receipt image is attached
  bool get hasReceiptImage =>
      receiptImageUrl != null && receiptImageUrl!.isNotEmpty;

  /// Check if images are attached
  bool get hasImages => fellowshipImageUrl != null || receiptImageUrl != null;

  /// Get sync status display text
  String get syncStatusDisplay => syncStatus.displayName;

  /// Check if report can be edited (not approved and not in conflict)
  bool get canEdit => !isApproved && !hasConflict;

  @override
  String toString() {
    return 'FellowshipReportModel(id: $id, fellowship: $fellowshipName, date: $formattedReportDate, attendance: $attendanceCount, syncStatus: ${syncStatus.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FellowshipReportModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
