/// App-wide configuration and constants for First Love Church Management System
class AppConfig {
  // App Information
  static const String appName = 'First Love Church CMS';
  static const String appVersion = '1.0.0';
  static const String churchName = 'First Love Church';
  static const String churchLocation = 'Foxdale, Lusaka, Zambia';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String constituenciesCollection = 'constituencies';
  static const String fellowshipsCollection = 'fellowships';
  static const String membersCollection = 'members';
  static const String fellowshipReportsCollection = 'fellowship_reports';
  static const String busReportsCollection = 'bus_reports';
  static const String uploadsCollection = 'uploads';
  static const String settingsCollection = 'settings';

  // File Upload Limits
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];
  static const int maxImagesPerReport = 3;

  // Validation Rules
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  static const int maxPhoneLength = 15;
  static const int maxDescriptionLength = 500;

  // Default Values
  static const int defaultReportsPageSize = 20;
  static const int maxRecentReports = 10;
  static const Duration cacheExpiry = Duration(minutes: 15);

  // Feature Flags (can be controlled remotely)
  static const bool enableOfflineMode = true;
  static const bool enablePushNotifications = true;
  static const bool enableDataExport = true;
  static const bool enableBulkOperations = true;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 8.0;
  static const double elevationCard = 2.0;
  static const double elevationModal = 8.0;

  // Animation Durations
  static const Duration quickAnimation = Duration(milliseconds: 200);
  static const Duration standardAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // Error Messages
  static const String genericErrorMessage =
      'An error occurred. Please try again.';
  static const String networkErrorMessage =
      'Please check your internet connection.';
  static const String permissionErrorMessage =
      'You don\'t have permission to perform this action.';
  static const String dataNotFoundMessage = 'No data found.';
}

/// App route names for navigation
class AppRoutes {
  // Authentication routes
  static const String login = '/login';

  static const String forgotPassword = '/forgot-password';

  // Main app routes
  static const String home = '/';
  static const String dashboard = '/dashboard';

  // Leader routes
  static const String leaderDashboard = '/leader';
  static const String fellowshipManagement = '/leader/fellowship';
  static const String memberManagement = '/leader/members';
  static const String submitFellowshipReport = '/leader/fellowship-report';
  static const String submitBusReport = '/leader/bus-report';
  static const String reportHistory = '/leader/reports';

  // Pastor routes
  static const String pastorDashboard = '/pastor';
  static const String constituencyOverview = '/pastor/constituency';
  static const String leaderManagement = '/pastor/leaders';
  static const String reportMonitoring = '/pastor/reports';
  static const String analytics = '/pastor/analytics';

  // Bishop routes
  static const String bishopDashboard = '/bishop';
  static const String churchOverview = '/bishop/overview';
  static const String pastorManagement = '/bishop/pastors';
  static const String churchAnalytics = '/bishop/analytics';
  static const String userManagement = '/bishop/users';
  static const String systemSettings = '/bishop/settings';

  // Common routes
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String help = '/help';
  static const String about = '/about';
}

/// Theme configuration
class AppTheme {
  // Colors for church theme
  static const primaryBlue = 0xFF2196F3;
  static const darkBlue = 0xFF1976D2;
  static const lightBlue = 0xFFE3F2FD;
  static const accentGold = 0xFFFFB300;
  static const successGreen = 0xFF4CAF50;
  static const warningOrange = 0xFFFF9800;
  static const errorRed = 0xFFF44336;
  static const backgroundGrey = 0xFFF5F5F5;
  static const textDark = 0xFF212121;
  static const textLight = 0xFF757575;
}

/// String constants and labels
class AppStrings {
  // General
  static const String loading = 'Loading...';
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String add = 'Add';
  static const String submit = 'Submit';
  static const String confirm = 'Confirm';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String ok = 'OK';
  static const String retry = 'Retry';

  // Authentication
  static const String login = 'Login';
  static const String register = 'Register';
  static const String logout = 'Logout';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String firstName = 'First Name';
  static const String lastName = 'Last Name';
  static const String phoneNumber = 'Phone Number';

  // Roles
  static const String bishop = 'Bishop';
  static const String pastor = 'Pastor';
  static const String leader = 'Fellowship Leader';

  // Dashboard
  static const String dashboard = 'Dashboard';
  static const String overview = 'Overview';
  static const String analytics = 'Analytics';
  static const String reports = 'Reports';
  static const String members = 'Members';
  static const String fellowships = 'Fellowships';

  // Reports
  static const String fellowshipReport = 'Fellowship Report';
  static const String busReport = 'Bus Report';
  static const String attendance = 'Attendance';
  static const String offering = 'Offering';
  static const String submitReport = 'Submit Report';
  static const String reportSubmitted = 'Report submitted successfully';

  // Fellowship
  static const String fellowship = 'Fellowship';
  static const String addMember = 'Add Member';
  static const String fellowshipMembers = 'Fellowship Members';
  static const String memberName = 'Member Name';
  static const String memberPhone = 'Member Phone';

  // Bus Report
  static const String busAttendance = 'Bus Attendance';
  static const String driverName = 'Driver Name';
  static const String driverPhone = 'Driver Phone';
  static const String busCost = 'Bus Cost';
  static const String busPhoto = 'Bus Photo';

  // Messages
  static const String welcomeMessage = 'Welcome to First Love Church CMS';
  static const String accountPendingMessage =
      'Your account is pending approval';
  static const String accountSuspendedMessage =
      'Your account has been suspended';
  static const String reportSavedMessage = 'Report saved successfully';
  static const String profileUpdatedMessage = 'Profile updated successfully';
}

/// Validation helpers
class AppValidators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < AppConfig.minPasswordLength) {
      return 'Password must be at least ${AppConfig.minPasswordLength} characters';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length > AppConfig.maxNameLength) {
      return 'Name must be less than ${AppConfig.maxNameLength} characters';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional
    }
    if (value.length > AppConfig.maxPhoneLength) {
      return 'Phone number is too long';
    }
    if (!RegExp(r'^[\+]?[0-9]{10,15}$').hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (double.tryParse(value) == null) {
      return '$fieldName must be a valid number';
    }
    return null;
  }
}
