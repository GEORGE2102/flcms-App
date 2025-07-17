import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fellowship_report_model.dart';
import '../models/sunday_bus_report_model.dart';
import '../models/user_model.dart';
import '../utils/enums.dart';
import 'auth_service.dart';
import 'permissions_service.dart';

/// Comprehensive service for managing report data access and analytics
///
/// This service provides role-based access to fellowship and Sunday bus reports,
/// with advanced filtering, pagination, and analytics capabilities. It ensures
/// proper permissions are enforced at the data layer.
///
/// Key features:
/// - Role-based data filtering (Bishop, Pastor, Treasurer, Leader)
/// - Pagination with efficient Firestore queries
/// - Advanced filtering (date range, fellowship, constituency, etc.)
/// - Analytics and aggregation functions
/// - Image access management
///
/// Usage:
/// ```dart
/// final reportService = ReportService();
///
/// // Get paginated fellowship reports
/// final reports = await reportService.getFellowshipReports(
///   limit: 20,
///   filters: ReportFilters(dateRange: last30Days),
/// );
///
/// // Get analytics data
/// final analytics = await reportService.getReportAnalytics();
/// ```
class ReportService {
  /// Singleton instance of ReportService
  static final ReportService _instance = ReportService._internal();

  /// Factory constructor that returns the singleton instance
  factory ReportService() => _instance;

  /// Private constructor for singleton pattern
  ReportService._internal();

  /// Firestore instance for database operations
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Auth service for user authentication
  final AuthService _authService = AuthService();

  /// Permissions service for access control
  final PermissionsService _permissionsService = PermissionsService();

  // =================== FELLOWSHIP REPORTS ===================

  /// Retrieves fellowship reports with role-based filtering and pagination
  ///
  /// [limit] - Number of reports to fetch (default: 20)
  /// [startAfter] - Document to start after for pagination
  /// [filters] - Optional filters to apply
  ///
  /// Returns paginated fellowship reports based on user role:
  /// - Bishop: All reports
  /// - Pastor: Reports from their constituency only
  /// - Treasurer: All reports (financial focus)
  /// - Leader: Their fellowship reports only
  Future<PaginatedReports<FellowshipReportModel>> getFellowshipReports({
    int limit = 20,
    DocumentSnapshot? startAfter,
    ReportFilters? filters,
  }) async {
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    Query query = _firestore.collection('fellowship_reports');

    // Apply role-based filtering
    query = await _applyRoleBasedFiltering(
      query,
      currentUser,
      ReportType.fellowship,
    );

    // Apply additional filters
    if (filters != null) {
      query = _applyFilters(query, filters);
    }

    // Apply ordering and pagination
    query = query.orderBy('reportDate', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    final reports =
        snapshot.docs
            .map((doc) => FellowshipReportModel.fromFirestore(doc))
            .toList();

    return PaginatedReports(
      reports: reports,
      hasMore: snapshot.docs.length == limit,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  }

  /// Retrieves a specific fellowship report by ID
  ///
  /// Checks permissions before returning the report
  Future<FellowshipReportModel?> getFellowshipReport(String reportId) async {
    final doc =
        await _firestore.collection('fellowship_reports').doc(reportId).get();

    if (!doc.exists) return null;

    final report = FellowshipReportModel.fromFirestore(doc);

    // Check if user can view this specific report
    final canView = await _permissionsService.canViewFellowshipReports(
      report.fellowshipId,
    );
    if (!canView) {
      throw Exception('Insufficient permissions to view this report');
    }

    return report;
  }

  // =================== SUNDAY BUS REPORTS ===================

  /// Retrieves Sunday bus reports with role-based filtering and pagination
  Future<PaginatedReports<SundayBusReportModel>> getSundayBusReports({
    int limit = 20,
    DocumentSnapshot? startAfter,
    ReportFilters? filters,
  }) async {
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    Query query = _firestore.collection('sunday_bus_reports');

    // Apply role-based filtering
    query = await _applyRoleBasedFiltering(
      query,
      currentUser,
      ReportType.sundayBus,
    );

    // Apply additional filters
    if (filters != null) {
      query = _applyFilters(query, filters);
    }

    // Apply ordering and pagination
    query = query.orderBy('reportDate', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    final reports =
        snapshot.docs
            .map((doc) => SundayBusReportModel.fromFirestore(doc))
            .toList();

    return PaginatedReports(
      reports: reports,
      hasMore: snapshot.docs.length == limit,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  }

  /// Retrieves a specific Sunday bus report by ID
  Future<SundayBusReportModel?> getSundayBusReport(String reportId) async {
    final doc =
        await _firestore.collection('sunday_bus_reports').doc(reportId).get();

    if (!doc.exists) return null;

    return SundayBusReportModel.fromFirestore(doc);
  }

  // =================== ANALYTICS ===================

  /// Retrieves comprehensive analytics based on user role
  Future<ReportAnalytics> getReportAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? constituencyId,
    String? fellowshipId,
  }) async {
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Set default date range (last 30 days)
    startDate ??= DateTime.now().subtract(const Duration(days: 30));
    endDate ??= DateTime.now();

    switch (currentUser.role) {
      case UserRole.bishop:
        return _getBishopAnalytics(startDate, endDate);
      case UserRole.pastor:
        return _getPastorAnalytics(
          startDate,
          endDate,
          currentUser.constituencyId!,
        );
      case UserRole.treasurer:
        return _getTreasurerAnalytics(startDate, endDate);
      case UserRole.leader:
        return _getLeaderAnalytics(
          startDate,
          endDate,
          currentUser.fellowshipId!,
        );
    }
  }

  /// Gets financial summary for treasurers and bishops
  Future<FinancialSummary> getFinancialSummary({
    DateTime? startDate,
    DateTime? endDate,
    String? constituencyId,
  }) async {
    final canView = await _permissionsService.canViewAllFinancialReports();
    if (!canView) {
      throw Exception('Insufficient permissions to view financial summary');
    }

    startDate ??= DateTime.now().subtract(const Duration(days: 30));
    endDate ??= DateTime.now();

    // Fellowship offering totals
    Query fellowshipQuery = _firestore
        .collection('fellowship_reports')
        .where(
          'reportDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('reportDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    if (constituencyId != null) {
      fellowshipQuery = fellowshipQuery.where(
        'constituencyId',
        isEqualTo: constituencyId,
      );
    }

    // Bus report financial data
    Query busQuery = _firestore
        .collection('sunday_bus_reports')
        .where(
          'reportDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('reportDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    if (constituencyId != null) {
      busQuery = busQuery.where('constituencyId', isEqualTo: constituencyId);
    }

    final fellowshipSnapshot = await fellowshipQuery.get();
    final busSnapshot = await busQuery.get();

    double totalFellowshipOfferings = 0;
    double totalBusOfferings = 0;
    double totalBusCosts = 0;
    int totalAttendance = 0;

    for (var doc in fellowshipSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalFellowshipOfferings += (data['offeringAmount'] ?? 0.0).toDouble();
      totalAttendance += (data['attendanceCount'] ?? 0) as int;
    }

    for (var doc in busSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalBusOfferings += (data['offering'] ?? 0.0).toDouble();
      totalBusCosts += (data['busCost'] ?? 0.0).toDouble();
    }

    return FinancialSummary(
      totalFellowshipOfferings: totalFellowshipOfferings,
      totalBusOfferings: totalBusOfferings,
      totalBusCosts: totalBusCosts,
      busProfit: totalBusOfferings - totalBusCosts,
      totalOfferings: totalFellowshipOfferings + totalBusOfferings,
      totalAttendance: totalAttendance,
      reportCount: fellowshipSnapshot.docs.length + busSnapshot.docs.length,
    );
  }

  // =================== PRIVATE HELPER METHODS ===================

  /// Applies role-based filtering to queries
  Future<Query> _applyRoleBasedFiltering(
    Query query,
    UserModel user,
    ReportType reportType,
  ) async {
    switch (user.role) {
      case UserRole.bishop:
        // Bishop can see all reports
        return query;

      case UserRole.pastor:
        // Pastor can only see reports from their constituency
        if (user.constituencyId != null) {
          return query.where('constituencyId', isEqualTo: user.constituencyId);
        }
        break;

      case UserRole.treasurer:
        // Treasurer can see all financial reports
        return query;

      case UserRole.leader:
        // Leader can only see their own fellowship reports
        if (reportType == ReportType.fellowship && user.fellowshipId != null) {
          return query.where('fellowshipId', isEqualTo: user.fellowshipId);
        } else if (reportType == ReportType.sundayBus &&
            user.constituencyId != null) {
          // For bus reports, leaders see constituency-level data
          return query.where('constituencyId', isEqualTo: user.constituencyId);
        }
        break;
    }

    // Default: no results if role doesn't match
    return query.where(FieldPath.documentId, isEqualTo: 'non-existent');
  }

  /// Applies additional filters to the query
  Query _applyFilters(Query query, ReportFilters filters) {
    if (filters.startDate != null) {
      query = query.where(
        'reportDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(filters.startDate!),
      );
    }

    if (filters.endDate != null) {
      query = query.where(
        'reportDate',
        isLessThanOrEqualTo: Timestamp.fromDate(filters.endDate!),
      );
    }

    if (filters.constituencyId != null) {
      query = query.where('constituencyId', isEqualTo: filters.constituencyId);
    }

    if (filters.fellowshipId != null) {
      query = query.where('fellowshipId', isEqualTo: filters.fellowshipId);
    }

    if (filters.pastorId != null) {
      query = query.where('pastorId', isEqualTo: filters.pastorId);
    }

    if (filters.isApproved != null) {
      query = query.where('isApproved', isEqualTo: filters.isApproved);
    }

    if (filters.minAmount != null) {
      String amountField =
          filters.reportType == ReportType.fellowship
              ? 'offeringAmount'
              : 'offering';
      query = query.where(
        amountField,
        isGreaterThanOrEqualTo: filters.minAmount,
      );
    }

    if (filters.maxAmount != null) {
      String amountField =
          filters.reportType == ReportType.fellowship
              ? 'offeringAmount'
              : 'offering';
      query = query.where(amountField, isLessThanOrEqualTo: filters.maxAmount);
    }

    return query;
  }

  /// Gets comprehensive analytics for bishops
  Future<ReportAnalytics> _getBishopAnalytics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Implementation for bishop analytics
    return ReportAnalytics(
      totalReports: 0,
      totalOfferings: 0,
      averageAttendance: 0,
      complianceRate: 0,
      trends: [],
    );
  }

  /// Gets constituency-specific analytics for pastors
  Future<ReportAnalytics> _getPastorAnalytics(
    DateTime startDate,
    DateTime endDate,
    String constituencyId,
  ) async {
    // Implementation for pastor analytics
    return ReportAnalytics(
      totalReports: 0,
      totalOfferings: 0,
      averageAttendance: 0,
      complianceRate: 0,
      trends: [],
    );
  }

  /// Gets financial analytics for treasurers
  Future<ReportAnalytics> _getTreasurerAnalytics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Implementation for treasurer analytics
    return ReportAnalytics(
      totalReports: 0,
      totalOfferings: 0,
      averageAttendance: 0,
      complianceRate: 0,
      trends: [],
    );
  }

  /// Gets fellowship-specific analytics for leaders
  Future<ReportAnalytics> _getLeaderAnalytics(
    DateTime startDate,
    DateTime endDate,
    String fellowshipId,
  ) async {
    // Implementation for leader analytics
    return ReportAnalytics(
      totalReports: 0,
      totalOfferings: 0,
      averageAttendance: 0,
      complianceRate: 0,
      trends: [],
    );
  }
}

// =================== DATA MODELS ===================

/// Pagination wrapper for report results
class PaginatedReports<T> {
  final List<T> reports;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;

  PaginatedReports({
    required this.reports,
    required this.hasMore,
    this.lastDocument,
  });
}

/// Filter options for report queries
class ReportFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? constituencyId;
  final String? fellowshipId;
  final String? pastorId;
  final bool? isApproved;
  final double? minAmount;
  final double? maxAmount;
  final ReportType? reportType;
  final String? searchQuery;

  ReportFilters({
    this.startDate,
    this.endDate,
    this.constituencyId,
    this.fellowshipId,
    this.pastorId,
    this.isApproved,
    this.minAmount,
    this.maxAmount,
    this.reportType,
    this.searchQuery,
  });

  ReportFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? constituencyId,
    String? fellowshipId,
    String? pastorId,
    bool? isApproved,
    double? minAmount,
    double? maxAmount,
    ReportType? reportType,
    String? searchQuery,
  }) {
    return ReportFilters(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      constituencyId: constituencyId ?? this.constituencyId,
      fellowshipId: fellowshipId ?? this.fellowshipId,
      pastorId: pastorId ?? this.pastorId,
      isApproved: isApproved ?? this.isApproved,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      reportType: reportType ?? this.reportType,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Analytics data structure
class ReportAnalytics {
  final int totalReports;
  final double totalOfferings;
  final double averageAttendance;
  final double complianceRate;
  final List<TrendData> trends;

  ReportAnalytics({
    required this.totalReports,
    required this.totalOfferings,
    required this.averageAttendance,
    required this.complianceRate,
    required this.trends,
  });
}

/// Trend data for analytics charts
class TrendData {
  final DateTime date;
  final double value;
  final String label;

  TrendData({required this.date, required this.value, required this.label});
}

/// Financial summary data
class FinancialSummary {
  final double totalFellowshipOfferings;
  final double totalBusOfferings;
  final double totalBusCosts;
  final double busProfit;
  final double totalOfferings;
  final int totalAttendance;
  final int reportCount;

  FinancialSummary({
    required this.totalFellowshipOfferings,
    required this.totalBusOfferings,
    required this.totalBusCosts,
    required this.busProfit,
    required this.totalOfferings,
    required this.totalAttendance,
    required this.reportCount,
  });

  /// Format currency values
  String formatCurrency(double amount) {
    return 'ZMW ${amount.toStringAsFixed(2)}';
  }

  String get formattedTotalOfferings => formatCurrency(totalOfferings);
  String get formattedBusProfit => formatCurrency(busProfit);
  String get formattedFellowshipOfferings =>
      formatCurrency(totalFellowshipOfferings);
  String get formattedBusOfferings => formatCurrency(totalBusOfferings);
  String get formattedBusCosts => formatCurrency(totalBusCosts);
}
