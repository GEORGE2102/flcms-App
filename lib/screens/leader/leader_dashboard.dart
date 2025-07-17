import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../models/user_model.dart';
import '../../models/member_model.dart';
import '../../models/fellowship_report_model.dart';
import '../../models/sunday_bus_report_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/offline_aware_service.dart';
import '../../services/permissions_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_config.dart';
import '../../widgets/conflict_notification_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Main dashboard screen for Fellowship Leaders
/// Provides navigation between Fellowship management, Reports, History, and Profile
class LeaderDashboard extends StatefulWidget {
  final UserModel user;

  const LeaderDashboard({super.key, required this.user});

  @override
  State<LeaderDashboard> createState() => _LeaderDashboardState();
}

class _LeaderDashboardState extends State<LeaderDashboard> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final OfflineAwareService _offlineAwareService = OfflineAwareService();
  final PermissionsService _permissionsService = PermissionsService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  int _currentIndex = 0;
  bool _isLoading = false;
  String _searchTerm = '';

  // Fellowship Report Form variables
  final GlobalKey<FormState> _fellowshipFormKey = GlobalKey<FormState>();
  final TextEditingController _attendanceController = TextEditingController();
  final TextEditingController _offeringController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;
  File? _fellowshipImage;
  File? _receiptImage;
  bool _isUploadingFellowshipImage = false;
  bool _isUploadingReceiptImage = false;

  // Bus Report Form variables
  final GlobalKey<FormState> _busFormKey = GlobalKey<FormState>();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverPhoneController = TextEditingController();
  final TextEditingController _busCostController = TextEditingController();
  final TextEditingController _busOfferingController = TextEditingController();
  final TextEditingController _busNotesController = TextEditingController();
  DateTime? _selectedBusDate;
  File? _busImage;
  bool _isUploadingBusImage = false;
  bool _isSubmittingFellowshipReport = false;
  bool _isSubmittingBusReport = false;

  // Dynamic attendance list variables
  List<TextEditingController> _attendanceControllers = [];
  List<String> _attendanceNames = [];

  // Persistent image files for cleanup
  final List<String> _tempImagePaths = [];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    // Fellowship form controllers
    _attendanceController.dispose();
    _offeringController.dispose();
    _notesController.dispose();

    // Bus form controllers
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _busCostController.dispose();
    _busOfferingController.dispose();
    _busNotesController.dispose();

    // Clean up temporary image files
    _cleanupTempImages();

    super.dispose();
  }

  /// Copy picked image to persistent app directory to avoid cache cleanup issues
  Future<File> _copyImageToPersistentStorage(
    File sourceFile,
    String type,
  ) async {
    try {
      // Get app documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory imagesDir = Directory('${appDir.path}/temp_images');

      // Create directory if it doesn't exist
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Generate unique filename
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = path.extension(sourceFile.path);
      final String fileName = '${type}_${timestamp}$extension';
      final String targetPath = '${imagesDir.path}/$fileName';

      // Copy file to persistent location
      final File copiedFile = await sourceFile.copy(targetPath);

      // Track for cleanup
      _tempImagePaths.add(targetPath);

      return copiedFile;
    } catch (e) {
      throw Exception('Failed to copy image to persistent storage: $e');
    }
  }

  /// Clean up temporary image files
  void _cleanupTempImages() {
    for (final imagePath in _tempImagePaths) {
      try {
        final file = File(imagePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        // Ignore cleanup errors
        print('Failed to delete temp image: $e');
      }
    }
    _tempImagePaths.clear();
  }

  /// Remove specific image from tracking list
  void _removeImageFromTracking(String imagePath) {
    _tempImagePaths.remove(imagePath);
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      // Ignore cleanup errors
      print('Failed to delete temp image: $e');
    }
  }

  Future<void> _initializeDashboard() async {
    setState(() => _isLoading = true);

    try {
      // Initialize any required data
      // This will be expanded in subsequent subtasks
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      await _authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('First Love CMS'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.user.fullName.isNotEmpty
                    ? widget.user.fullName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  _handleLogout();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.user.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Fellowship Leader',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardOverview(),
          _buildFellowshipSection(),
          _buildReportsSection(),
          _buildHistorySection(),
          _buildProfileSection(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Fellowship',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Reports',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  /// Dashboard Overview Tab with welcome message, stats, and quick actions
  Widget _buildDashboardOverview() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 12),
            // Conflict notification widget - shows when conflicts exist
            const ConflictNotificationWidget(),
            const SizedBox(height: 20),
            _buildQuickStatsSection(),
            const SizedBox(height: 20),
            _buildQuickActionsSection(),
            const SizedBox(height: 20),
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isLoading = true);
    try {
      // Refresh dashboard data
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildWelcomeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange,
              radius: 30,
              child: Text(
                widget.user.fullName.isNotEmpty
                    ? widget.user.fullName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${widget.user.firstName}!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fellowship Leader',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.fellowshipId ?? 'No fellowship assigned',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fellowship Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Members count - using real-time data
        StreamBuilder<List<MemberModel>>(
          stream: _getMembersStream(),
          builder: (context, membersSnapshot) {
            final members = membersSnapshot.data ?? [];

            return StreamBuilder<List<FellowshipReportModel>>(
              stream:
                  widget.user.fellowshipId != null
                      ? _firestoreService.getFellowshipReports(
                        fellowshipId: widget.user.fellowshipId!,
                        limit: 100,
                      )
                      : Stream.value([]),
              builder: (context, reportsSnapshot) {
                final allReports = reportsSnapshot.data ?? [];

                // Filter reports for this month
                final now = DateTime.now();
                final thisMonth = DateTime(now.year, now.month);
                final monthlyReports =
                    allReports.where((report) {
                      return report.reportDate.isAfter(thisMonth);
                    }).toList();

                // Filter reports for this week
                final weekStart = now.subtract(Duration(days: now.weekday - 1));
                final weeklyReports =
                    allReports.where((report) {
                      return report.reportDate.isAfter(weekStart);
                    }).toList();

                // Calculate weekly offerings
                double weeklyOfferings = 0.0;
                for (final report in weeklyReports) {
                  weeklyOfferings += report.offeringAmount;
                }

                // Calculate next Sunday
                final today = DateTime.now();
                final daysUntilSunday = (7 - today.weekday) % 7;
                final nextSunday = today.add(
                  Duration(days: daysUntilSunday == 0 ? 7 : daysUntilSunday),
                );
                final monthNames = [
                  'Jan',
                  'Feb',
                  'Mar',
                  'Apr',
                  'May',
                  'Jun',
                  'Jul',
                  'Aug',
                  'Sep',
                  'Oct',
                  'Nov',
                  'Dec',
                ];

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.people,
                            title: 'Members',
                            value: '${members.length}',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.assignment_turned_in,
                            title: 'Reports',
                            value: '${monthlyReports.length}',
                            color: Colors.green,
                            subtitle: 'This month',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.calendar_today,
                            title: 'Next Meeting',
                            value: 'Sunday',
                            color: Colors.purple,
                            subtitle:
                                '${monthNames[nextSunday.month - 1]} ${nextSunday.day}, ${nextSunday.year}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.monetization_on,
                            title: 'This Week',
                            value:
                                weeklyOfferings > 0
                                    ? 'K${(weeklyOfferings / 1000).toStringAsFixed(0)}'
                                    : 'K0',
                            color: Colors.orange,
                            subtitle: 'Offerings',
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.person_add,
                title: 'Add Member',
                subtitle: 'Register new fellowship member',
                color: Colors.blue,
                onTap: () {
                  setState(() => _currentIndex = 1); // Switch to Fellowship tab
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _showAddMemberDialog(); // Show add member dialog
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.assignment,
                title: 'Submit Report',
                subtitle: 'Weekly fellowship report',
                color: Colors.green,
                onTap:
                    () => setState(
                      () => _currentIndex = 2,
                    ), // Switch to Reports tab
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.directions_bus,
                title: 'Bus Report',
                subtitle: 'Sunday bus transport report',
                color: Colors.orange,
                onTap: () {
                  setState(() => _currentIndex = 2); // Switch to Reports tab
                  // The Reports tab already has bus report form in second tab
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.people_outline,
                title: 'View Members',
                subtitle: 'Manage fellowship members',
                color: Colors.purple,
                onTap:
                    () => setState(
                      () => _currentIndex = 1,
                    ), // Switch to Fellowship tab
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _currentIndex = 3),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Recent Fellowship Reports
        StreamBuilder<List<FellowshipReportModel>>(
          stream: _getRecentFellowshipReports(),
          builder: (context, fellowshipSnapshot) {
            // Recent Bus Reports
            return StreamBuilder<List<SundayBusReportModel>>(
              stream: _getRecentBusReports(),
              builder: (context, busSnapshot) {
                if (fellowshipSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    busSnapshot.connectionState == ConnectionState.waiting) {
                  return Card(
                    elevation: 2,
                    child: Container(
                      height: 120,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    ),
                  );
                }

                final fellowshipReports = fellowshipSnapshot.data ?? [];
                final busReports = busSnapshot.data ?? [];

                if (fellowshipReports.isEmpty && busReports.isEmpty) {
                  return Card(
                    elevation: 2,
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              color: Colors.grey,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No recent activity',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Submit reports to see activity here',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Combine and sort all activities by date
                final allActivities = <Map<String, dynamic>>[];

                for (final report in fellowshipReports.take(3)) {
                  allActivities.add({
                    'type': 'fellowship',
                    'icon': Icons.assignment_turned_in,
                    'title': 'Fellowship Report Submitted',
                    'subtitle':
                        '${report.attendanceCount} attendees • ${report.formattedOffering}',
                    'time': report.submittedAt,
                    'color': Colors.green,
                  });
                }

                for (final report in busReports.take(3)) {
                  allActivities.add({
                    'type': 'bus',
                    'icon': Icons.directions_bus,
                    'title': 'Bus Report Submitted',
                    'subtitle':
                        '${report.attendanceCount} transported • ${report.formattedBusCost}',
                    'time': report.submittedAt,
                    'color': Colors.orange,
                  });
                }

                // Sort by most recent first
                allActivities.sort(
                  (a, b) =>
                      (b['time'] as DateTime).compareTo(a['time'] as DateTime),
                );

                return Card(
                  elevation: 2,
                  child: Column(
                    children: [
                      ...allActivities
                          .take(3)
                          .map(
                            (activity) => _buildRecentActivityItem(
                              icon: activity['icon'] as IconData,
                              title: activity['title'] as String,
                              subtitle: activity['subtitle'] as String,
                              time: _getRelativeTime(
                                activity['time'] as DateTime,
                              ),
                              color: activity['color'] as Color,
                            ),
                          ),
                      if (allActivities.isNotEmpty) const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.history, color: Colors.grey[600]),
                        title: Text(
                          'View All Activity',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => setState(() => _currentIndex = 3),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  // Helper method to get recent fellowship reports for this leader's fellowship
  Stream<List<FellowshipReportModel>> _getRecentFellowshipReports() {
    if (widget.user.fellowshipId == null) {
      return Stream.value([]);
    }

    return _firestoreService.getFellowshipReports(
      fellowshipId: widget.user.fellowshipId!,
      limit: 5,
    );
  }

  // Helper method to get recent bus reports for this leader's constituency
  Stream<List<SundayBusReportModel>> _getRecentBusReports() {
    if (widget.user.constituencyId == null) {
      return Stream.value([]);
    }

    return _firestoreService.getBusReports(
      constituencyId: widget.user.constituencyId!,
      limit: 5,
    );
  }

  // Helper method to format relative time
  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('$feature Coming Soon'),
            content: Text(
              'The $feature feature will be implemented in upcoming tasks. '
              'For now, you can explore other sections of the dashboard.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  /// Fellowship Management Tab - member management interface
  Widget _buildFellowshipSection() {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterMembers,
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          // Members list
          Expanded(child: _buildMembersList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemberDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  /// Filter members based on search term
  void _filterMembers(String searchTerm) {
    setState(() {
      _searchTerm = searchTerm.toLowerCase();
    });
  }

  /// Build the members list view
  Widget _buildMembersList() {
    return StreamBuilder<List<MemberModel>>(
      stream: _getMembersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading members',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}), // Trigger rebuild
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final members = snapshot.data ?? [];
        final filteredMembers = _filterMembersList(members);

        if (filteredMembers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _searchTerm.isEmpty ? 'No members yet' : 'No members found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchTerm.isEmpty
                      ? 'Add your first fellowship member'
                      : 'Try a different search term',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshMembers,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: filteredMembers.length,
            itemBuilder: (context, index) {
              final member = filteredMembers[index];
              return _buildMemberCard(member);
            },
          ),
        );
      },
    );
  }

  /// Build individual member card
  Widget _buildMemberCard(MemberModel member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 2,
      child: Dismissible(
        key: Key(member.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) => _confirmDeleteMember(member),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white, size: 24),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16.0),
          leading: CircleAvatar(
            backgroundColor: Colors.orange,
            radius: 24,
            child: Text(
              member.firstName.isNotEmpty
                  ? member.firstName[0].toUpperCase()
                  : 'M',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          title: Text(
            member.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(member.formattedPhone),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Joined ${_formatDate(member.dateJoined)}'),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) => _handleMemberAction(value, member),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 20),
                        SizedBox(width: 8),
                        Text('View Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
          ),
          onTap: () => _showMemberDetails(member),
        ),
      ),
    );
  }

  /// Reports Submission Tab - tabbed interface for fellowship and bus reports
  Widget _buildReportsSection() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.orange,
              tabs: [
                Tab(icon: Icon(Icons.groups), text: 'Fellowship'),
                Tab(icon: Icon(Icons.directions_bus), text: 'Bus Report'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [_buildFellowshipReportForm(), _buildBusReportForm()],
        ),
      ),
    );
  }

  /// Fellowship Report Form
  Widget _buildFellowshipReportForm() {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _fellowshipFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Fellowship Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Submit your weekly fellowship meeting report',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Report Date
              _buildDateField(),
              const SizedBox(height: 16),

              // Attendance Count
              _buildAttendanceField(),
              const SizedBox(height: 16),

              // Offering Amount
              _buildOfferingField(),
              const SizedBox(height: 16),

              // Notes/Activities
              _buildNotesField(),
              const SizedBox(height: 24),

              // Fellowship Photo
              _buildFellowshipPhotoSection(),
              const SizedBox(height: 16),

              // Receipt Photo
              _buildReceiptPhotoSection(),
              const SizedBox(height: 32),

              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Bus Report Form
  Widget _buildBusReportForm() {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _busFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sunday Bus Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Submit your Sunday bus transport report',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Report Date
              _buildBusDateField(),
              const SizedBox(height: 16),

              // Attendance Count
              _buildBusAttendanceField(),
              const SizedBox(height: 16),

              // Driver Information
              _buildDriverInfoSection(),
              const SizedBox(height: 24),

              // Financial Information
              _buildBusFinancialSection(),
              const SizedBox(height: 24),

              // Bus Photo
              _buildBusPhotoSection(),
              const SizedBox(height: 16),

              // Notes
              _buildBusNotesField(),
              const SizedBox(height: 32),

              // Submit Button
              _buildBusSubmitButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Report History Tab - shows past fellowship and bus reports
  Widget _buildHistorySection() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.orange,
              tabs: [
                Tab(icon: Icon(Icons.groups), text: 'Fellowship Reports'),
                Tab(icon: Icon(Icons.directions_bus), text: 'Bus Reports'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildFellowshipReportsHistory(),
            _buildBusReportsHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildFellowshipReportsHistory() {
    return StreamBuilder<List<FellowshipReportModel>>(
      stream: _getFellowshipReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('Error loading reports'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text('No fellowship reports yet'),
                const SizedBox(height: 8),
                const Text('Submit your first report from the Reports tab'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: const Text('Submit Report'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportHistoryCard(
                icon: Icons.groups,
                title: 'Fellowship Report',
                date: report.reportDate,
                status: report.isApproved ? 'Approved' : 'Pending',
                statusColor: report.isApproved ? Colors.green : Colors.orange,
                details: [
                  'Attendance: ${report.attendanceCount}',
                  'Offering: ZMW ${report.offeringAmount.toStringAsFixed(2)}',
                  if (report.notes?.isNotEmpty == true)
                    'Notes: ${report.notes}',
                ],
                onTap: () => _showReportDetails(report),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBusReportsHistory() {
    return StreamBuilder<List<SundayBusReportModel>>(
      stream: _getBusReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('Error loading bus reports'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_bus_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text('No bus reports yet'),
                const SizedBox(height: 8),
                const Text('Submit your first bus report from the Reports tab'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: const Text('Submit Bus Report'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportHistoryCard(
                icon: Icons.directions_bus,
                title: 'Bus Report',
                date: report.reportDate,
                status: 'Submitted',
                statusColor: Colors.blue,
                details: [
                  'Driver: ${report.driverName}',
                  'Cost: ZMW ${report.busCost.toStringAsFixed(2)}',
                  'Offering: ZMW ${report.offering.toStringAsFixed(2)}',
                  if (report.notes?.isNotEmpty == true)
                    'Notes: ${report.notes}',
                ],
                onTap: () => _showBusReportDetails(report),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReportHistoryCard({
    required IconData icon,
    required String title,
    required DateTime date,
    required String status,
    required Color statusColor,
    required List<String> details,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...details.map(
                (detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    detail,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to view details',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Profile Tab - user profile and settings
  Widget _buildProfileSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          _buildProfileHeader(),
          const SizedBox(height: 24),

          // Profile Information
          _buildProfileInfoSection(),
          const SizedBox(height: 24),

          // Settings Section
          _buildSettingsSection(),
          const SizedBox(height: 24),

          // Action Buttons
          _buildActionButtonsSection(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.orange,
              child: Text(
                widget.user.fullName.isNotEmpty
                    ? widget.user.fullName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fellowship Leader',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.email,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showEditProfileDialog(),
              icon: const Icon(Icons.edit, color: Colors.orange),
              tooltip: 'Edit Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('First Name', widget.user.firstName),
            _buildInfoRow('Last Name', widget.user.lastName),
            _buildInfoRow('Email', widget.user.email),
            _buildInfoRow(
              'Phone Number',
              widget.user.phoneNumber?.isNotEmpty == true
                  ? widget.user.phoneNumber!
                  : 'Not provided',
            ),
            _buildInfoRow(
              'Fellowship ID',
              widget.user.fellowshipId ?? 'Not assigned',
            ),
            _buildInfoRow('Status', widget.user.status.value.toUpperCase()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications, color: Colors.orange),
              title: const Text('Notifications'),
              subtitle: const Text('Manage notification preferences'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showNotificationSettings(),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.security, color: Colors.orange),
              title: const Text('Change Password'),
              subtitle: const Text('Update your account password'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showChangePasswordDialog(),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help, color: Colors.orange),
              title: const Text('Help & Support'),
              subtitle: const Text('Get help and support'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showHelpDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsSection() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _handleLogout(),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              'Logout',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Version 1.0.0',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ==================== MISSING STREAM AND DIALOG METHODS ====================

  /// Get fellowship reports stream for current user
  Stream<List<FellowshipReportModel>> _getFellowshipReportsStream() {
    return _firestoreService.getAllFellowshipReports();
  }

  /// Get bus reports stream for current user
  Stream<List<SundayBusReportModel>> _getBusReportsStream() {
    return _firestoreService.getAllBusReports();
  }

  /// Show fellowship report details dialog
  void _showReportDetails(FellowshipReportModel report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Fellowship Report Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Date', _formatDate(report.reportDate)),
                  _buildDetailRow('Attendance', '${report.attendanceCount}'),
                  _buildDetailRow(
                    'Offering',
                    'ZMW ${report.offeringAmount.toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Status',
                    report.isApproved ? 'Approved' : 'Pending',
                  ),
                  if (report.notes?.isNotEmpty == true)
                    _buildDetailRow('Notes', report.notes!),
                  if (report.fellowshipImageUrl?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Fellowship Photo:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        report.fellowshipImageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                      ),
                    ),
                  ],
                  if (report.receiptImageUrl?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Receipt Photo:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        report.receiptImageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  /// Show bus report details dialog
  void _showBusReportDetails(SundayBusReportModel report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Bus Report Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Date', _formatDate(report.reportDate)),
                  _buildDetailRow('Driver Name', report.driverName),
                  _buildDetailRow('Driver Phone', report.driverPhone),
                  _buildDetailRow(
                    'Bus Cost',
                    'ZMW ${report.busCost.toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Offering',
                    'ZMW ${report.offering.toStringAsFixed(2)}',
                  ),
                  if (report.attendanceList?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Attendance:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...report.attendanceList!.map(
                      (name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $name'),
                      ),
                    ),
                  ],
                  if (report.notes?.isNotEmpty == true)
                    _buildDetailRow('Notes', report.notes!),
                  if (report.busPhotoUrl?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Bus Photo:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        report.busPhotoUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  /// Show edit profile dialog
  void _showEditProfileDialog() {
    final firstNameController = TextEditingController(
      text: widget.user.firstName,
    );
    final lastNameController = TextEditingController(
      text: widget.user.lastName,
    );
    final phoneController = TextEditingController(
      text: widget.user.phoneNumber ?? '',
    );

    bool isUpdating = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Edit Profile'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isUpdating,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isUpdating,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          enabled: !isUpdating,
                        ),
                        if (isUpdating) ...[
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text('Updating profile...'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isUpdating ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isUpdating
                              ? null
                              : () async {
                                setState(() => isUpdating = true);

                                try {
                                  final authService = AuthService();

                                  // Validate input
                                  if (firstNameController.text.trim().isEmpty ||
                                      lastNameController.text.trim().isEmpty) {
                                    throw Exception(
                                      'First name and last name are required',
                                    );
                                  }

                                  // Update profile
                                  await authService.updateUserProfile(
                                    firstName: firstNameController.text.trim(),
                                    lastName: lastNameController.text.trim(),
                                    phoneNumber:
                                        phoneController.text.trim().isEmpty
                                            ? null
                                            : phoneController.text.trim(),
                                  );

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Profile updated successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

                                    // Refresh the page to show updated data
                                    setState(() {});
                                  }
                                } catch (e) {
                                  setState(() => isUpdating = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to update profile: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  /// Show notification settings dialog
  void _showNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();

    bool reportReminders =
        prefs.getBool('notification_report_reminders') ?? true;
    bool approvalNotifications =
        prefs.getBool('notification_approval_notifications') ?? true;
    bool fellowshipUpdates =
        prefs.getBool('notification_fellowship_updates') ?? true;
    bool systemMessages = prefs.getBool('notification_system_messages') ?? true;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Notification Settings'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Report Reminders'),
                        subtitle: const Text(
                          'Get reminded to submit weekly reports',
                        ),
                        value: reportReminders,
                        onChanged: (value) async {
                          setState(() => reportReminders = value);
                          await prefs.setBool(
                            'notification_report_reminders',
                            value,
                          );
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Approval Notifications'),
                        subtitle: const Text(
                          'Get notified when reports are approved',
                        ),
                        value: approvalNotifications,
                        onChanged: (value) async {
                          setState(() => approvalNotifications = value);
                          await prefs.setBool(
                            'notification_approval_notifications',
                            value,
                          );
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Fellowship Updates'),
                        subtitle: const Text(
                          'Get updates about fellowship activities',
                        ),
                        value: fellowshipUpdates,
                        onChanged: (value) async {
                          setState(() => fellowshipUpdates = value);
                          await prefs.setBool(
                            'notification_fellowship_updates',
                            value,
                          );
                        },
                      ),
                      SwitchListTile(
                        title: const Text('System Messages'),
                        subtitle: const Text('Important system announcements'),
                        value: systemMessages,
                        onChanged: (value) async {
                          setState(() => systemMessages = value);
                          await prefs.setBool(
                            'notification_system_messages',
                            value,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Settings are saved locally on this device.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          ),
    );
  }

  /// Show change password dialog
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool isChangingPassword = false;
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Change Password'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: currentPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        showCurrentPassword =
                                            !showCurrentPassword,
                                  ),
                            ),
                          ),
                          obscureText: !showCurrentPassword,
                          enabled: !isChangingPassword,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: newPasswordController,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed:
                                  () => setState(
                                    () => showNewPassword = !showNewPassword,
                                  ),
                            ),
                            helperText: 'Minimum 6 characters',
                          ),
                          obscureText: !showNewPassword,
                          enabled: !isChangingPassword,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        showConfirmPassword =
                                            !showConfirmPassword,
                                  ),
                            ),
                          ),
                          obscureText: !showConfirmPassword,
                          enabled: !isChangingPassword,
                        ),
                        if (isChangingPassword) ...[
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text('Changing password...'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isChangingPassword
                              ? null
                              : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isChangingPassword
                              ? null
                              : () async {
                                setState(() => isChangingPassword = true);

                                try {
                                  // Validate input
                                  if (currentPasswordController.text.isEmpty) {
                                    throw Exception(
                                      'Current password is required',
                                    );
                                  }

                                  if (newPasswordController.text.length < 6) {
                                    throw Exception(
                                      'New password must be at least 6 characters',
                                    );
                                  }

                                  if (newPasswordController.text !=
                                      confirmPasswordController.text) {
                                    throw Exception(
                                      'New passwords do not match',
                                    );
                                  }

                                  if (currentPasswordController.text ==
                                      newPasswordController.text) {
                                    throw Exception(
                                      'New password must be different from current password',
                                    );
                                  }

                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) {
                                    throw Exception('No user signed in');
                                  }

                                  // Reauthenticate user with current password
                                  final credential =
                                      EmailAuthProvider.credential(
                                        email: user.email!,
                                        password:
                                            currentPasswordController.text,
                                      );

                                  await user.reauthenticateWithCredential(
                                    credential,
                                  );

                                  // Update password
                                  await user.updatePassword(
                                    newPasswordController.text,
                                  );

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Password changed successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setState(() => isChangingPassword = false);
                                  if (mounted) {
                                    String errorMessage =
                                        'Failed to change password';
                                    if (e.toString().contains(
                                      'wrong-password',
                                    )) {
                                      errorMessage =
                                          'Current password is incorrect';
                                    } else if (e.toString().contains(
                                      'weak-password',
                                    )) {
                                      errorMessage = 'New password is too weak';
                                    } else if (e.toString().contains(
                                      'requires-recent-login',
                                    )) {
                                      errorMessage =
                                          'Please sign out and sign in again before changing password';
                                    } else if (e is Exception) {
                                      errorMessage = e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      );
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(errorMessage),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                      child: const Text('Change Password'),
                    ),
                  ],
                ),
          ),
    );
  }

  /// Show help dialog
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Help & Support'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fellowship Leader Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Text('This dashboard allows you to:'),
                  SizedBox(height: 8),
                  Text('• View and manage fellowship members'),
                  Text('• Submit fellowship and bus reports'),
                  Text('• Track report history and status'),
                  Text('• Manage your profile and settings'),
                  SizedBox(height: 16),
                  Text(
                    'Need Help?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Contact your pastor or church administrator for assistance.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Report Issues',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'If you encounter any problems, please report them to your church IT team.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  /// Helper method to build detail rows in dialogs
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ==================== FELLOWSHIP REPORT FORM METHODS ====================

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Date *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.orange),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Select report date',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        _selectedDate != null ? Colors.black : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance Count *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _attendanceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter number of attendees',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
            prefixIcon: const Icon(Icons.people, color: Colors.orange),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Attendance count is required';
            }
            final count = int.tryParse(value!);
            if (count == null || count < 0) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildOfferingField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Offering Amount *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _offeringController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter offering amount (ZMW)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
            prefixIcon: const Icon(Icons.monetization_on, color: Colors.orange),
            prefixText: 'ZMW ',
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Offering amount is required';
            }
            final amount = double.tryParse(value!);
            if (amount == null || amount < 0) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activities & Notes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'Describe fellowship activities, key points, prayer requests, etc.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFellowshipPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fellowship Photo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Take a photo of your fellowship meeting',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildImagePicker(
          'Fellowship Photo',
          _fellowshipImage,
          () => _pickImage('fellowship'),
          Icons.groups,
          _isUploadingFellowshipImage,
        ),
      ],
    );
  }

  Widget _buildReceiptPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Offering Receipt Photo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Take a photo of the offering receipt or count slip',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildImagePicker(
          'Receipt Photo',
          _receiptImage,
          () => _pickImage('receipt'),
          Icons.receipt,
          _isUploadingReceiptImage,
        ),
      ],
    );
  }

  Widget _buildImagePicker(
    String label,
    File? imageFile,
    VoidCallback onTap,
    IconData icon,
    bool isUploading,
  ) {
    return InkWell(
      onTap: isUploading ? null : onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child:
            isUploading
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.orange),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading $label...',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const LinearProgressIndicator(
                        color: Colors.orange,
                        backgroundColor: Colors.orange,
                      ),
                    ],
                  ),
                )
                : imageFile != null
                ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _clearImage(label),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add $label',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed:
            _isSubmittingFellowshipReport
                ? null
                : () => _submitFellowshipReport(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child:
            _isSubmittingFellowshipReport
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUploadingFellowshipImage || _isUploadingReceiptImage
                          ? 'Uploading images...'
                          : 'Submitting report...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
                : const Text(
                  'Submit Fellowship Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearImage(String label) {
    setState(() {
      switch (label) {
        case 'Fellowship Photo':
          if (_fellowshipImage != null) {
            _removeImageFromTracking(_fellowshipImage!.path);
          }
          _fellowshipImage = null;
          break;
        case 'Receipt Photo':
          if (_receiptImage != null) {
            _removeImageFromTracking(_receiptImage!.path);
          }
          _receiptImage = null;
          break;
        case 'Bus Photo':
          if (_busImage != null) {
            _removeImageFromTracking(_busImage!.path);
          }
          _busImage = null;
          break;
      }
    });
  }

  Future<void> _pickImage(String type) async {
    try {
      // Show image source options
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      // Pick image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70, // Compress to reduce file size
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) return;

      final File tempImageFile = File(pickedFile.path);

      // Validate file
      if (!_storageService.isValidImageFile(tempImageFile)) {
        throw Exception('Please select a valid image file (JPG, JPEG, PNG)');
      }

      final fileSizeMB = await _storageService.getFileSizeMB(tempImageFile);
      if (fileSizeMB > AppConfig.maxImageSizeBytes / (1024 * 1024)) {
        throw Exception(
          'Image size must be less than ${AppConfig.maxImageSizeBytes ~/ 1024 ~/ 1024}MB',
        );
      }

      // Copy to persistent storage to avoid cache cleanup issues
      final File persistentImageFile = await _copyImageToPersistentStorage(
        tempImageFile,
        type,
      );

      // Set the image file based on type
      setState(() {
        switch (type) {
          case 'fellowship':
            _fellowshipImage = persistentImageFile;
            break;
          case 'receipt':
            _receiptImage = persistentImageFile;
            break;
          case 'bus':
            _busImage = persistentImageFile;
            break;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image selected successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.orange),
                  title: const Text('Camera'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Colors.orange,
                  ),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _submitFellowshipReport() async {
    if (!_fellowshipFormKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a report date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final shouldSubmit = await _showSubmissionConfirmationDialog(
      'Fellowship Report',
      'Submit fellowship report for ${_formatDate(_selectedDate!)}?',
    );
    if (!shouldSubmit) return;

    setState(() {
      _isSubmittingFellowshipReport = true;
    });

    try {
      String? fellowshipImageUrl;
      String? receiptImageUrl;

      // Upload fellowship image if selected
      if (_fellowshipImage != null) {
        setState(() {
          _isUploadingFellowshipImage = true;
        });
        fellowshipImageUrl = await _storageService.uploadFellowshipImage(
          imageFile: _fellowshipImage!,
          fellowshipId: widget.user.fellowshipId ?? 'unknown',
          userId: widget.user.id,
        );
        setState(() {
          _isUploadingFellowshipImage = false;
        });
      }

      // Upload receipt image if selected
      if (_receiptImage != null) {
        setState(() {
          _isUploadingReceiptImage = true;
        });
        receiptImageUrl = await _storageService.uploadReceiptImage(
          imageFile: _receiptImage!,
          reportId: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          userId: widget.user.id,
        );
        setState(() {
          _isUploadingReceiptImage = false;
        });
      }

      // Create fellowship report model
      final report = FellowshipReportModel(
        id: '', // Will be set by Firestore
        fellowshipId: widget.user.fellowshipId ?? 'unknown',
        fellowshipName: 'Fellowship ${widget.user.fellowshipId}',
        constituencyId: widget.user.constituencyId ?? 'unknown',
        constituencyName: 'Constituency ${widget.user.constituencyId}',
        pastorId: widget.user.assignedPastorId ?? 'unknown',
        pastorName:
            widget.user.assignedPastorId != null
                ? 'Pastor Name'
                : 'Unknown Pastor',
        submittedBy: widget.user.id,
        submitterName: widget.user.fullName,
        reportDate: _selectedDate!,
        submittedAt: DateTime.now(),
        attendanceCount: int.parse(_attendanceController.text),
        offeringAmount: double.parse(_offeringController.text),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        fellowshipImageUrl: fellowshipImageUrl,
        receiptImageUrl: receiptImageUrl,
      );

      // Submit to Firestore using offline-aware service
      await _offlineAwareService.submitFellowshipReport(report);

      // Clear form
      _clearFellowshipForm();

      // Show enhanced success message
      _showSuccessMessage(
        'Fellowship Report',
        'Report for ${_formatDate(_selectedDate!)} submitted to ${widget.user.constituencyId}',
      );
    } catch (e) {
      // Show enhanced error message
      _showErrorMessage('submit fellowship report', e.toString());
    } finally {
      setState(() {
        _isSubmittingFellowshipReport = false;
        _isUploadingFellowshipImage = false;
        _isUploadingReceiptImage = false;
      });
    }
  }

  void _clearFellowshipForm() {
    _fellowshipFormKey.currentState?.reset();
    _attendanceController.clear();
    _offeringController.clear();
    _notesController.clear();

    // Clean up temporary image files for fellowship form
    if (_fellowshipImage != null) {
      _removeImageFromTracking(_fellowshipImage!.path);
    }
    if (_receiptImage != null) {
      _removeImageFromTracking(_receiptImage!.path);
    }

    setState(() {
      _selectedDate = null;
      _fellowshipImage = null;
      _receiptImage = null;
    });
  }

  // ==================== BUS REPORT FORM METHODS ====================

  Widget _buildBusDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Date *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectBusDate(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.orange),
                const SizedBox(width: 12),
                Text(
                  _selectedBusDate != null
                      ? '${_selectedBusDate!.day}/${_selectedBusDate!.month}/${_selectedBusDate!.year}'
                      : 'Select bus report date',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        _selectedBusDate != null
                            ? Colors.black
                            : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBusAttendanceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bus Attendance List *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton.icon(
              onPressed:
                  _attendanceControllers.length >= 100
                      ? null
                      : _addAttendanceEntry,
              icon: const Icon(Icons.person_add, size: 18),
              label: Text(
                _attendanceControllers.length >= 100 ? 'Full' : 'Add',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Add names of bus passengers',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (_attendanceControllers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No passengers added yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Add" to start adding passenger names',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          ...List.generate(_attendanceControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _attendanceControllers[index],
                      decoration: InputDecoration(
                        hintText: 'Passenger ${index + 1} name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.orange,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Name is required';
                        }
                        final trimmedValue = value!.trim();
                        if (trimmedValue.length < 2) {
                          return 'Name too short (min 2 characters)';
                        }
                        if (trimmedValue.length > 50) {
                          return 'Name too long (max 50 characters)';
                        }
                        if (!RegExp(
                          r"^[a-zA-Z\s\-']+$",
                        ).hasMatch(trimmedValue)) {
                          return 'Invalid characters (letters, spaces, hyphens, apostrophes only)';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (index < _attendanceNames.length) {
                          _attendanceNames[index] = value.trim();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeAttendanceEntry(index),
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    tooltip: 'Remove passenger',
                  ),
                ],
              ),
            );
          }),
        if (_attendanceControllers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Total passengers: ${_attendanceControllers.length}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.orange,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDriverInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Driver Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Driver Name
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Driver Name *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _driverNameController,
              decoration: InputDecoration(
                hintText: 'Enter driver\'s full name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
                prefixIcon: const Icon(Icons.person, color: Colors.orange),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Driver name is required';
                }
                return null;
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Driver Phone
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Driver Phone *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _driverPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Enter driver\'s phone number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
                prefixIcon: const Icon(Icons.phone, color: Colors.orange),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Driver phone number is required';
                }
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusFinancialSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Bus Cost
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bus Cost (Fuel & Expenses) *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _busCostController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: 'Enter total bus expenses',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
                prefixIcon: const Icon(
                  Icons.local_gas_station,
                  color: Colors.orange,
                ),
                prefixText: 'ZMW ',
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Bus cost is required';
                }
                final amount = double.tryParse(value!);
                if (amount == null || amount < 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Bus Offering
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bus Offering Collected',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _busOfferingController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: 'Enter offering collected (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
                prefixIcon: const Icon(
                  Icons.monetization_on,
                  color: Colors.orange,
                ),
                prefixText: 'ZMW ',
              ),
              validator: (value) {
                if (value?.isNotEmpty ?? false) {
                  final amount = double.tryParse(value!);
                  if (amount == null || amount < 0) {
                    return 'Please enter a valid amount';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bus Photo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Take a photo of the bus or passengers',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildImagePicker(
          'Bus Photo',
          _busImage,
          () => _pickImage('bus'),
          Icons.directions_bus,
          _isUploadingBusImage,
        ),
      ],
    );
  }

  Widget _buildBusNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Notes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _busNotesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any additional notes about the bus trip (optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBusSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmittingBusReport ? null : () => _submitBusReport(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child:
            _isSubmittingBusReport
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUploadingBusImage
                          ? 'Uploading image...'
                          : 'Submitting report...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
                : const Text(
                  'Submit Bus Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
      ),
    );
  }

  Future<void> _selectBusDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBusDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedBusDate = picked;
      });
    }
  }

  Future<void> _submitBusReport() async {
    if (!_busFormKey.currentState!.validate()) {
      return;
    }

    if (_selectedBusDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a report date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate attendance list
    final attendanceValidation = _validateAttendanceList();
    if (attendanceValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(attendanceValidation),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final shouldSubmit = await _showSubmissionConfirmationDialog(
      'Bus Report',
      'Submit bus report for ${_formatDate(_selectedBusDate!)}?',
    );
    if (!shouldSubmit) return;

    setState(() {
      _isSubmittingBusReport = true;
    });

    try {
      String? busImageUrl;

      // Upload bus image if selected
      if (_busImage != null) {
        setState(() {
          _isUploadingBusImage = true;
        });
        busImageUrl = await _storageService.uploadBusImage(
          imageFile: _busImage!,
          busReportId: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          userId: widget.user.id,
        );
        setState(() {
          _isUploadingBusImage = false;
        });
      }

      // Create bus report model with dynamic attendance list
      final report = SundayBusReportModel(
        id: '', // Will be set by Firestore
        constituencyId: widget.user.constituencyId ?? 'unknown',
        constituencyName: 'Constituency ${widget.user.constituencyId}',
        pastorId: widget.user.assignedPastorId ?? 'unknown',
        pastorName:
            widget.user.assignedPastorId != null
                ? 'Pastor Name'
                : 'Unknown Pastor',
        submittedBy: widget.user.id,
        submitterName: widget.user.fullName,
        reportDate: _selectedBusDate!,
        submittedAt: DateTime.now(),
        attendanceList: _getCleanAttendanceList(),
        driverName: _driverNameController.text,
        driverPhone: _driverPhoneController.text,
        busCost: double.parse(_busCostController.text),
        offering:
            _busOfferingController.text.isEmpty
                ? 0.0
                : double.parse(_busOfferingController.text),
        busPhotoUrl: busImageUrl,
        notes:
            _busNotesController.text.isEmpty ? null : _busNotesController.text,
      );

      // Submit to Firestore using offline-aware service
      await _offlineAwareService.submitBusReport(report);

      // Clear form
      _clearBusForm();

      // Show enhanced success message
      _showSuccessMessage(
        'Bus Report',
        'Report for ${_formatDate(_selectedBusDate!)} submitted with driver ${_driverNameController.text}',
      );
    } catch (e) {
      // Show enhanced error message
      _showErrorMessage('submit bus report', e.toString());
    } finally {
      setState(() {
        _isSubmittingBusReport = false;
        _isUploadingBusImage = false;
      });
    }
  }

  void _clearBusForm() {
    _busFormKey.currentState?.reset();
    _driverNameController.clear();
    _driverPhoneController.clear();
    _busCostController.clear();
    _busOfferingController.clear();
    _busNotesController.clear();
    _clearAttendanceList();

    // Clean up temporary image files for bus form
    if (_busImage != null) {
      _removeImageFromTracking(_busImage!.path);
    }

    setState(() {
      _selectedBusDate = null;
      _busImage = null;
    });
  }

  /// Add new attendance entry
  void _addAttendanceEntry() {
    if (_attendanceControllers.length >= 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum of 100 passengers allowed per bus'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _attendanceControllers.add(TextEditingController());
      _attendanceNames.add('');
    });
  }

  /// Remove attendance entry at index
  void _removeAttendanceEntry(int index) {
    setState(() {
      _attendanceControllers[index].dispose();
      _attendanceControllers.removeAt(index);
      _attendanceNames.removeAt(index);
    });
  }

  /// Clear all attendance entries
  void _clearAttendanceList() {
    for (final controller in _attendanceControllers) {
      controller.dispose();
    }
    setState(() {
      _attendanceControllers.clear();
      _attendanceNames.clear();
    });
  }

  /// Get clean attendance list with non-empty names
  List<String> _getCleanAttendanceList() {
    return _attendanceControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Validate attendance list for submission
  String? _validateAttendanceList() {
    final cleanList = _getCleanAttendanceList();

    // Check minimum attendance
    if (cleanList.isEmpty) {
      return 'Please add at least one passenger to the attendance list';
    }

    // Check for duplicate names
    final uniqueNames = <String>{};
    for (final name in cleanList) {
      final normalizedName = name.toLowerCase().trim();
      if (uniqueNames.contains(normalizedName)) {
        return 'Duplicate passenger name found: "$name". Please ensure all names are unique.';
      }
      uniqueNames.add(normalizedName);
    }

    // Check name format (basic validation)
    for (final name in cleanList) {
      if (name.length < 2) {
        return 'Passenger name "$name" is too short. Please enter at least 2 characters.';
      }
      if (name.length > 50) {
        return 'Passenger name "$name" is too long. Please keep names under 50 characters.';
      }
      // Check for invalid characters (only letters, spaces, hyphens, apostrophes)
      if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(name)) {
        return 'Passenger name "$name" contains invalid characters. Please use only letters, spaces, hyphens, and apostrophes.';
      }
    }

    // Check maximum list size
    if (cleanList.length > 100) {
      return 'Too many passengers (${cleanList.length}). Maximum allowed is 100 passengers per bus.';
    }

    return null; // All validations passed
  }

  /// Show confirmation dialog before report submission
  Future<bool> _showSubmissionConfirmationDialog(
    String reportType,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm $reportType Submission'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                const Text(
                  'Please ensure all information is accurate before submitting.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text(
                  'Submit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  /// Enhanced success message with details
  void _showSuccessMessage(String reportType, String details) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$reportType submitted successfully!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(details, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View History',
          textColor: Colors.white,
          onPressed: () => setState(() => _currentIndex = 3),
        ),
      ),
    );
  }

  /// Enhanced error message with recovery suggestions
  void _showErrorMessage(String operation, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Failed to $operation',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(error, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            const Text(
              'Please check your internet connection and try again.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => {}, // Will be set to retry function
        ),
      ),
    );
  }

  // ==================== MEMBER MANAGEMENT HELPER METHODS ====================

  /// Get stream of members for current user's fellowship
  Stream<List<MemberModel>> _getMembersStream() {
    // For now, return an empty stream until we implement full Firestore integration
    // In a real implementation, this would query Firestore for members where fellowshipId == user's fellowship
    return Stream.value([
      // Mock data for demonstration
      MemberModel(
        id: '1',
        firstName: 'John',
        lastName: 'Mwanza',
        phoneNumber: '+260977123456',
        email: 'john.mwanza@example.com',
        fellowshipId: widget.user.fellowshipId ?? 'mock-fellowship',
        fellowshipName: 'Mock Fellowship',
        constituencyId: 'mock-constituency',
        dateJoined: DateTime.now().subtract(const Duration(days: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MemberModel(
        id: '2',
        firstName: 'Mary',
        lastName: 'Banda',
        phoneNumber: '+260966789123',
        fellowshipId: widget.user.fellowshipId ?? 'mock-fellowship',
        fellowshipName: 'Mock Fellowship',
        constituencyId: 'mock-constituency',
        dateJoined: DateTime.now().subtract(const Duration(days: 15)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);
  }

  /// Filter members list based on search term
  List<MemberModel> _filterMembersList(List<MemberModel> members) {
    if (_searchTerm.isEmpty) return members;

    return members
        .where(
          (member) =>
              member.fullName.toLowerCase().contains(_searchTerm) ||
              (member.phoneNumber?.toLowerCase().contains(_searchTerm) ??
                  false) ||
              (member.email?.toLowerCase().contains(_searchTerm) ?? false),
        )
        .toList();
  }

  /// Refresh members data
  Future<void> _refreshMembers() async {
    setState(() => _isLoading = true);
    try {
      // In real implementation, this would refresh data from Firestore
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Members refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing members: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Handle member action menu selections
  void _handleMemberAction(String action, MemberModel member) {
    switch (action) {
      case 'view':
        _showMemberDetails(member);
        break;
      case 'edit':
        _showEditMemberDialog(member);
        break;
      case 'delete':
        _confirmDeleteMember(member);
        break;
    }
  }

  /// Show member details dialog
  void _showMemberDetails(MemberModel member) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${member.fullName} Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Name', member.fullName),
                  _buildDetailRow('Phone', member.formattedPhone),
                  if (member.email != null)
                    _buildDetailRow('Email', member.email!),
                  _buildDetailRow('Fellowship', member.fellowshipName),
                  _buildDetailRow(
                    'Date Joined',
                    _formatDate(member.dateJoined),
                  ),
                  if (member.address != null)
                    _buildDetailRow('Address', member.address!),
                  if (member.occupation != null)
                    _buildDetailRow('Occupation', member.occupation!),
                  if (member.age != null)
                    _buildDetailRow('Age', '${member.age} years'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showEditMemberDialog(member);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  /// Show add member dialog
  void _showAddMemberDialog() {
    _showMemberFormDialog(null);
  }

  /// Show edit member dialog
  void _showEditMemberDialog(MemberModel member) {
    _showMemberFormDialog(member);
  }

  /// Show member form dialog (for both add and edit)
  void _showMemberFormDialog(MemberModel? member) {
    final isEdit = member != null;
    final firstNameController = TextEditingController(
      text: member?.firstName ?? '',
    );
    final lastNameController = TextEditingController(
      text: member?.lastName ?? '',
    );
    final phoneController = TextEditingController(
      text: member?.phoneNumber ?? '',
    );
    final emailController = TextEditingController(text: member?.email ?? '');
    final addressController = TextEditingController(
      text: member?.address ?? '',
    );
    final occupationController = TextEditingController(
      text: member?.occupation ?? '',
    );
    DateTime selectedDate = member?.dateJoined ?? DateTime.now();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isEdit ? 'Edit Member' : 'Add New Member'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: occupationController,
                    decoration: const InputDecoration(
                      labelText: 'Occupation',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Date Joined'),
                    subtitle: Text(_formatDate(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        selectedDate = picked;
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    () => _saveMember(
                      isEdit,
                      member?.id,
                      firstNameController.text,
                      lastNameController.text,
                      phoneController.text.isEmpty
                          ? null
                          : phoneController.text,
                      emailController.text.isEmpty
                          ? null
                          : emailController.text,
                      addressController.text.isEmpty
                          ? null
                          : addressController.text,
                      occupationController.text.isEmpty
                          ? null
                          : occupationController.text,
                      selectedDate,
                    ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text(
                  isEdit ? 'Update' : 'Add',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  /// Save member (add or update)
  void _saveMember(
    bool isEdit,
    String? memberId,
    String firstName,
    String lastName,
    String? phone,
    String? email,
    String? address,
    String? occupation,
    DateTime dateJoined,
  ) {
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First name and last name are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // In real implementation, this would save to Firestore
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEdit ? 'Member updated successfully' : 'Member added successfully',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Confirm delete member
  Future<bool?> _confirmDeleteMember(MemberModel member) async {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Member'),
            content: Text(
              'Are you sure you want to remove ${member.fullName} from the fellowship? '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  _deleteMember(member);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  /// Delete member
  void _deleteMember(MemberModel member) {
    // In real implementation, this would delete from Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${member.fullName} removed from fellowship'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            // In real implementation, this would restore the member
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Member restored'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }
}
