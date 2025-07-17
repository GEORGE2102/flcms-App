import '../utils/enums.dart';
import 'auth_service.dart';

/// Service to handle role-based permissions and access control
class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;
  PermissionsService._internal();

  final AuthService _authService = AuthService();

  /// Check if current user can create fellowships
  Future<bool> canCreateFellowship() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Only pastors and bishops can create fellowships
    return user.isPastor || user.isBishop;
  }

  /// Check if current user can manage fellowship with given ID
  Future<bool> canManageFellowship(String fellowshipId) async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    switch (user.role) {
      case UserRole.bishop:
        return true; // Bishop can manage all fellowships
      case UserRole.pastor:
        // Pastor can manage fellowships in their constituency
        // This would require checking fellowship's constituency
        return true; // Simplified for now
      case UserRole.treasurer:
        return false; // Treasurers cannot manage fellowships
      case UserRole.leader:
        // Leader can only manage their own fellowship
        return user.fellowshipId == fellowshipId;
    }
  }

  /// Check if current user can view reports from a specific fellowship
  Future<bool> canViewFellowshipReports(String fellowshipId) async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    switch (user.role) {
      case UserRole.bishop:
        return true; // Bishop can view all reports
      case UserRole.pastor:
        // Pastor can view reports from fellowships in their constituency
        return true; // Simplified for now
      case UserRole.treasurer:
        return true; // Treasurer can view all financial reports
      case UserRole.leader:
        // Leader can only view their own fellowship reports
        return user.fellowshipId == fellowshipId;
    }
  }

  /// Check if current user can submit fellowship reports
  Future<bool> canSubmitFellowshipReport() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Only leaders can submit fellowship reports
    return user.isLeader && user.fellowshipId != null;
  }

  /// Check if current user can submit Sunday bus reports
  Future<bool> canSubmitBusReport() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Only leaders can submit bus reports
    return user.isLeader;
  }

  /// Check if current user can manage pastors
  Future<bool> canManagePastors() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Only bishops can manage pastors
    return user.isBishop;
  }

  /// Check if current user can manage leaders
  Future<bool> canManageLeaders() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Pastors and bishops can manage leaders
    return user.isPastor || user.isBishop;
  }

  /// Check if current user can view church-wide analytics
  Future<bool> canViewChurchAnalytics() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Only bishops can view church-wide analytics
    return user.isBishop;
  }

  /// Check if current user can view constituency analytics
  Future<bool> canViewConstituencyAnalytics() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Pastors and bishops can view constituency analytics
    return user.isPastor || user.isBishop;
  }

  /// Check if current user can approve/reject user registrations
  Future<bool> canApproveUsers() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Pastors and bishops can approve users
    return user.isPastor || user.isBishop;
  }

  /// Check if current user can export data
  Future<bool> canExportData() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Bishops and treasurers can export financial data
    return user.isBishop || user.isTreasurer;
  }

  /// Check if current user can view all financial reports
  Future<bool> canViewAllFinancialReports() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Bishops, pastors, and treasurers can view financial reports
    return user.isBishop || user.isPastor || user.isTreasurer;
  }

  /// Check if current user can download financial reports
  Future<bool> canDownloadFinancialReports() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Bishops and treasurers can download financial reports
    return user.isBishop || user.isTreasurer;
  }

  /// Check if current user can view receipt images
  Future<bool> canViewReceiptImages() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Bishops, pastors, and treasurers can view receipt images
    return user.isBishop || user.isPastor || user.isTreasurer;
  }

  /// Check if current user can view financial analytics
  Future<bool> canViewFinancialAnalytics() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return false;

    // Bishops and treasurers can view financial analytics
    return user.isBishop || user.isTreasurer;
  }

  /// Get navigation permissions for current user
  Future<NavigationPermissions> getNavigationPermissions() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) {
      return NavigationPermissions.none();
    }

    switch (user.role) {
      case UserRole.bishop:
        return NavigationPermissions.bishop();
      case UserRole.pastor:
        return NavigationPermissions.pastor();
      case UserRole.treasurer:
        return NavigationPermissions.treasurer();
      case UserRole.leader:
        return NavigationPermissions.leader();
    }
  }

  /// Get feature permissions for current user
  Future<FeaturePermissions> getFeaturePermissions() async {
    final user = await _authService.getCurrentUserData();
    if (user == null) {
      return FeaturePermissions.none();
    }

    return FeaturePermissions(
      canCreateFellowship: await canCreateFellowship(),
      canSubmitReports: await canSubmitFellowshipReport(),
      canSubmitBusReports: await canSubmitBusReport(),
      canManagePastors: await canManagePastors(),
      canManageLeaders: await canManageLeaders(),
      canViewAnalytics: await canViewChurchAnalytics(),
      canApproveUsers: await canApproveUsers(),
      canExportData: await canExportData(),
      canViewAllFinancialReports: await canViewAllFinancialReports(),
      canDownloadFinancialReports: await canDownloadFinancialReports(),
      canViewReceiptImages: await canViewReceiptImages(),
      canViewFinancialAnalytics: await canViewFinancialAnalytics(),
    );
  }
}

/// Navigation permissions for different user roles
class NavigationPermissions {
  final bool showDashboard;
  final bool showFellowships;
  final bool showReports;
  final bool showMembers;
  final bool showAnalytics;
  final bool showUserManagement;
  final bool showSettings;

  NavigationPermissions({
    required this.showDashboard,
    required this.showFellowships,
    required this.showReports,
    required this.showMembers,
    required this.showAnalytics,
    required this.showUserManagement,
    required this.showSettings,
  });

  factory NavigationPermissions.bishop() {
    return NavigationPermissions(
      showDashboard: true,
      showFellowships: true,
      showReports: true,
      showMembers: true,
      showAnalytics: true,
      showUserManagement: true,
      showSettings: true,
    );
  }

  factory NavigationPermissions.pastor() {
    return NavigationPermissions(
      showDashboard: true,
      showFellowships: true,
      showReports: true,
      showMembers: true,
      showAnalytics: true,
      showUserManagement: true,
      showSettings: false,
    );
  }

  factory NavigationPermissions.treasurer() {
    return NavigationPermissions(
      showDashboard: true,
      showFellowships: false,
      showReports: true,
      showMembers: false,
      showAnalytics: true,
      showUserManagement: false,
      showSettings: false,
    );
  }

  factory NavigationPermissions.leader() {
    return NavigationPermissions(
      showDashboard: true,
      showFellowships: true,
      showReports: true,
      showMembers: true,
      showAnalytics: false,
      showUserManagement: false,
      showSettings: false,
    );
  }

  factory NavigationPermissions.none() {
    return NavigationPermissions(
      showDashboard: false,
      showFellowships: false,
      showReports: false,
      showMembers: false,
      showAnalytics: false,
      showUserManagement: false,
      showSettings: false,
    );
  }
}

/// Feature permissions for different user roles
class FeaturePermissions {
  final bool canCreateFellowship;
  final bool canSubmitReports;
  final bool canSubmitBusReports;
  final bool canManagePastors;
  final bool canManageLeaders;
  final bool canViewAnalytics;
  final bool canApproveUsers;
  final bool canExportData;
  final bool canViewAllFinancialReports;
  final bool canDownloadFinancialReports;
  final bool canViewReceiptImages;
  final bool canViewFinancialAnalytics;

  FeaturePermissions({
    required this.canCreateFellowship,
    required this.canSubmitReports,
    required this.canSubmitBusReports,
    required this.canManagePastors,
    required this.canManageLeaders,
    required this.canViewAnalytics,
    required this.canApproveUsers,
    required this.canExportData,
    required this.canViewAllFinancialReports,
    required this.canDownloadFinancialReports,
    required this.canViewReceiptImages,
    required this.canViewFinancialAnalytics,
  });

  factory FeaturePermissions.none() {
    return FeaturePermissions(
      canCreateFellowship: false,
      canSubmitReports: false,
      canSubmitBusReports: false,
      canManagePastors: false,
      canManageLeaders: false,
      canViewAnalytics: false,
      canApproveUsers: false,
      canExportData: false,
      canViewAllFinancialReports: false,
      canDownloadFinancialReports: false,
      canViewReceiptImages: false,
      canViewFinancialAnalytics: false,
    );
  }
}
