import '../utils/enums.dart';

/// Represents conflict information when data synchronization conflicts occur
class ConflictData {
  final String id;
  final String documentId;
  final String collection;
  final ConflictType conflictType;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;
  final ConflictResolutionStrategy suggestedStrategy;
  final DateTime conflictDetectedAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final ConflictResolutionStrategy? resolvedStrategy;
  final Map<String, dynamic>? resolvedData;

  ConflictData({
    required this.id,
    required this.documentId,
    required this.collection,
    required this.conflictType,
    required this.localData,
    required this.remoteData,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.suggestedStrategy,
    required this.conflictDetectedAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolvedStrategy,
    this.resolvedData,
  });

  /// Check if conflict is resolved
  bool get isResolved => resolvedAt != null;

  /// Get conflict age in minutes
  int get ageInMinutes =>
      DateTime.now().difference(conflictDetectedAt).inMinutes;

  /// Determine if conflict is critical (affects sensitive data)
  bool get isCritical => _criticalCollections.contains(collection);

  static const List<String> _criticalCollections = [
    'users',
    'fellowship_reports',
    'sunday_bus_reports',
  ];

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'collection': collection,
      'conflictType': conflictType.name,
      'localData': localData,
      'remoteData': remoteData,
      'localUpdatedAt': localUpdatedAt.toIso8601String(),
      'remoteUpdatedAt': remoteUpdatedAt.toIso8601String(),
      'suggestedStrategy': suggestedStrategy.value,
      'conflictDetectedAt': conflictDetectedAt.toIso8601String(),
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolvedStrategy': resolvedStrategy?.value,
      'resolvedData': resolvedData,
    };
  }

  /// Create from map
  factory ConflictData.fromMap(Map<String, dynamic> map) {
    return ConflictData(
      id: map['id'] ?? '',
      documentId: map['documentId'] ?? '',
      collection: map['collection'] ?? '',
      conflictType: ConflictType.values.firstWhere(
        (e) => e.name == (map['conflictType'] ?? 'none'),
        orElse: () => ConflictType.none,
      ),
      localData: Map<String, dynamic>.from(map['localData'] ?? {}),
      remoteData: Map<String, dynamic>.from(map['remoteData'] ?? {}),
      localUpdatedAt: DateTime.parse(map['localUpdatedAt']),
      remoteUpdatedAt: DateTime.parse(map['remoteUpdatedAt']),
      suggestedStrategy: ConflictResolutionStrategy.fromString(
        map['suggestedStrategy'] ?? 'last_write_wins',
      ),
      conflictDetectedAt: DateTime.parse(map['conflictDetectedAt']),
      resolvedBy: map['resolvedBy'],
      resolvedAt:
          map['resolvedAt'] != null ? DateTime.parse(map['resolvedAt']) : null,
      resolvedStrategy:
          map['resolvedStrategy'] != null
              ? ConflictResolutionStrategy.fromString(map['resolvedStrategy'])
              : null,
      resolvedData:
          map['resolvedData'] != null
              ? Map<String, dynamic>.from(map['resolvedData'])
              : null,
    );
  }

  /// Create a copy with resolved information
  ConflictData copyWithResolution({
    required String resolvedBy,
    required ConflictResolutionStrategy resolvedStrategy,
    required Map<String, dynamic> resolvedData,
  }) {
    return ConflictData(
      id: id,
      documentId: documentId,
      collection: collection,
      conflictType: conflictType,
      localData: localData,
      remoteData: remoteData,
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
      suggestedStrategy: suggestedStrategy,
      conflictDetectedAt: conflictDetectedAt,
      resolvedBy: resolvedBy,
      resolvedAt: DateTime.now(),
      resolvedStrategy: resolvedStrategy,
      resolvedData: resolvedData,
    );
  }

  @override
  String toString() {
    return 'ConflictData(id: $id, collection: $collection, documentId: $documentId, type: ${conflictType.name}, resolved: $isResolved)';
  }
}

/// Mixin to add conflict detection capabilities to data models
mixin ConflictDetectionMixin {
  /// Last time the document was updated on the server
  DateTime? get lastUpdatedServer;

  /// Version number for optimistic locking
  int get version;

  /// Local update timestamp for client-side tracking
  DateTime? get localUpdatedAt;

  /// Current sync status
  SyncStatus get syncStatus;

  /// Conflict data if document is in conflicted state
  ConflictData? get conflictData;

  /// Check if document has conflict
  bool get hasConflict => syncStatus.hasConflict;

  /// Check if document needs sync
  bool get needsSync => syncStatus.needsSync;

  /// Get fields that should be included in conflict detection
  Map<String, dynamic> getConflictDetectionFields();

  /// Compare with another version for conflict detection
  bool hasConflictWith(
    Map<String, dynamic> otherData,
    DateTime otherLastUpdated,
  ) {
    // If we have no server timestamp, always consider it a potential conflict
    if (lastUpdatedServer == null) return true;

    // If the other version is newer, there's a potential conflict
    return otherLastUpdated.isAfter(lastUpdatedServer!);
  }

  /// Get conflict-sensitive fields (fields that should trigger user intervention if different)
  List<String> getCriticalFields();

  /// Detect specific conflict types
  ConflictType detectConflictType(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
  ) {
    final criticalFields = getCriticalFields();
    bool hasCriticalConflict = false;
    bool hasMinorConflict = false;

    for (final field in localData.keys) {
      if (localData[field] != remoteData[field]) {
        if (criticalFields.contains(field)) {
          hasCriticalConflict = true;
        } else {
          hasMinorConflict = true;
        }
      }
    }

    if (hasCriticalConflict) {
      return ConflictType.critical;
    } else if (hasMinorConflict) {
      return ConflictType.minor;
    } else {
      return ConflictType.none;
    }
  }
}

/// Types of conflicts that can occur
enum ConflictType {
  none,
  minor, // Non-critical fields changed
  critical, // Critical fields changed, requires user intervention
  structural, // Schema or structure changes
}
