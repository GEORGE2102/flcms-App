/// User roles in the First Love Church Management System
enum UserRole {
  bishop('bishop', 'Bishop', 4),
  pastor('pastor', 'Pastor', 3),
  treasurer('treasurer', 'Treasurer', 2),
  leader('leader', 'Fellowship Leader', 1);

  const UserRole(this.value, this.displayName, this.level);

  final String value;
  final String displayName;
  final int level;

  /// Returns true if this role has higher or equal authority than [other]
  bool hasAuthorityOver(UserRole other) => level >= other.level;

  /// Returns true if this role can manage users with [other] role
  bool canManage(UserRole other) => level > other.level;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.leader,
    );
  }

  /// Check if role is treasurer
  bool get isTreasurer => this == UserRole.treasurer;
}

/// Status of various entities in the system
enum Status {
  active('active', 'Active'),
  inactive('inactive', 'Inactive'),
  pending('pending', 'Pending'),
  suspended('suspended', 'Suspended');

  const Status(this.value, this.displayName);

  final String value;
  final String displayName;

  static Status fromString(String value) {
    return Status.values.firstWhere(
      (status) => status.value == value,
      orElse: () => Status.active,
    );
  }
}

/// Report types in the system
enum ReportType {
  fellowship('fellowship', 'Fellowship Report'),
  sundayBus('sunday_bus', 'Sunday Bus Report'),
  offering('offering', 'Offering Report'),
  attendance('attendance', 'Attendance Report');

  const ReportType(this.value, this.displayName);

  final String value;
  final String displayName;

  static ReportType fromString(String value) {
    return ReportType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ReportType.fellowship,
    );
  }
}

/// Synchronization status for offline-aware data models
enum SyncStatus {
  synced('synced', 'Synced'),
  pending('pending', 'Pending Sync'),
  syncing('syncing', 'Syncing'),
  conflicted('conflicted', 'Conflicted'),
  error('error', 'Sync Error');

  const SyncStatus(this.value, this.displayName);

  final String value;
  final String displayName;

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SyncStatus.synced,
    );
  }

  /// Check if data needs syncing
  bool get needsSync => this == SyncStatus.pending || this == SyncStatus.error;

  /// Check if there's a conflict
  bool get hasConflict => this == SyncStatus.conflicted;
}

/// Conflict resolution strategies for data synchronization
enum ConflictResolutionStrategy {
  lastWriteWins('last_write_wins', 'Last Write Wins'),
  mergeFields('merge_fields', 'Merge Fields'),
  userChoice('user_choice', 'User Choice Required'),
  keepLocal('keep_local', 'Keep Local Version'),
  keepRemote('keep_remote', 'Keep Remote Version');

  const ConflictResolutionStrategy(this.value, this.displayName);

  final String value;
  final String displayName;

  static ConflictResolutionStrategy fromString(String value) {
    return ConflictResolutionStrategy.values.firstWhere(
      (strategy) => strategy.value == value,
      orElse: () => ConflictResolutionStrategy.lastWriteWins,
    );
  }

  /// Check if strategy requires user intervention
  bool get requiresUserInput => this == ConflictResolutionStrategy.userChoice;
}
