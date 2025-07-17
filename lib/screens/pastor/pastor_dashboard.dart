import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/constituency_model.dart';
import '../../models/fellowship_model.dart';
import '../../models/fellowship_report_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/pastor_service.dart';
import '../../services/permissions_service.dart';
import '../../services/image_cache_service.dart';
import '../../widgets/cached_image_widget.dart';
import '../../widgets/conflict_notification_widget.dart';
import '../../utils/enums.dart';
import 'leader_management.dart';

/// Main dashboard screen for Pastors
/// Provides overview of constituency fellowships, reports, and analytics
class PastorDashboard extends StatefulWidget {
  final UserModel user;

  const PastorDashboard({super.key, required this.user});

  @override
  State<PastorDashboard> createState() => _PastorDashboardState();
}

class _PastorDashboardState extends State<PastorDashboard> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final PermissionsService _permissionsService = PermissionsService();

  int _currentIndex = 0;
  bool _isLoading = false;
  ConstituencyModel? _constituency;
  List<FellowshipModel> _fellowships = [];
  final List<FellowshipReportModel> _recentReports = [];

  // Dashboard metrics (now calculated in real-time from streams)
  int _totalFellowships = 0;
  int _activeLeaders = 0;

  // Add new state variables for analytics
  String _selectedDateRange = 'monthly'; // 'weekly' or 'monthly'

  // Filter state variables for Reports and Fellowships sections
  String? _selectedFellowshipFilter;
  String _selectedReportDateRange = 'last_30_days';
  String _selectedFellowshipStatusFilter = 'all';
  String _selectedLeaderAssignmentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    setState(() => _isLoading = true);

    try {
      // Initialize image caching service
      await ImageCacheService().initialize();

      // Check if user has pastor permissions
      final hasPermission =
          await _permissionsService.canViewConstituencyAnalytics();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You do not have permission to access this dashboard',
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Load pastor's constituency data
      await _loadConstituencyData();
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

  Future<void> _loadConstituencyData() async {
    if (widget.user.constituencyId == null) {
      return;
    }

    try {
      // For now, we'll use the existing methods to load fellowships
      // TODO: Add constituency loading methods to FirestoreService

      // Load fellowships in this constituency using stream (for now get the first result)
      final fellowshipsStream = _firestoreService.getFellowshipsByConstituency(
        widget.user.constituencyId!,
      );

      // Get the first result from the stream
      final fellowships = await fellowshipsStream.first;
      _fellowships = fellowships;

      // Calculate metrics
      _calculateDashboardMetrics();

      setState(() {});
    } catch (e) {
      debugPrint('Error loading constituency data: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load constituency data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateDashboardMetrics() {
    _totalFellowships = _fellowships.length;
    _activeLeaders = _fellowships.where((f) => f.leaderId != null).length;

    // Metrics are now calculated in real-time using StreamBuilder
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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text('Loading Pastor Dashboard...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pastor Dashboard'),
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
                    : 'P',
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
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Pastor',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_constituency != null)
                          Text(
                            _constituency!.name,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
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
          _buildFellowshipsSection(),
          _buildReportsSection(),
          _buildAnalyticsSection(),
          _buildLeadersSection(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Fellowships',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Leaders'),
        ],
      ),
    );
  }

  /// Dashboard Overview Tab with constituency metrics and quick stats
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
            _buildMetricsSection(),
            const SizedBox(height: 20),
            _buildRecentActivitySection(),
            const SizedBox(height: 20),
            _buildFellowshipPhotoGallery(),
          ],
        ),
      ),
    );
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
                    : 'P',
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
                    'Welcome, Pastor ${widget.user.firstName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  if (_constituency != null) ...[
                    Text(
                      _constituency!.name,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalFellowships Fellowships | $_activeLeaders Leaders',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ] else
                    Text(
                      'No constituency assigned',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    if (widget.user.constituencyId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No constituency assigned',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Constituency Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<FellowshipModel>>(
          stream: _firestoreService.getFellowshipsByConstituency(
            widget.user.constituencyId!,
          ),
          builder: (context, fellowshipSnapshot) {
            if (fellowshipSnapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading fellowships',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            }

            final fellowships = fellowshipSnapshot.data ?? [];
            final totalFellowships = fellowships.length;
            final activeLeaders =
                fellowships.where((f) => f.leaderId != null).length;

            return StreamBuilder<List<FellowshipReportModel>>(
              stream: _firestoreService.getConstituencyReports(
                constituencyId: widget.user.constituencyId!,
                startDate: DateTime.now().subtract(
                  const Duration(days: 7),
                ), // This week
                limit: 100,
              ),
              builder: (context, weeklyReportsSnapshot) {
                if (weeklyReportsSnapshot.hasError) {
                  debugPrint(
                    'Error loading weekly reports: ${weeklyReportsSnapshot.error}',
                  );
                }

                final weeklyReports = weeklyReportsSnapshot.data ?? [];
                final weeklyReportsCount = weeklyReports.length;

                return StreamBuilder<List<FellowshipReportModel>>(
                  stream: _firestoreService.getConstituencyReports(
                    constituencyId: widget.user.constituencyId!,
                    startDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ), // This month
                    limit: 200,
                  ),
                  builder: (context, monthlyReportsSnapshot) {
                    if (monthlyReportsSnapshot.hasError) {
                      debugPrint(
                        'Error loading monthly reports: ${monthlyReportsSnapshot.error}',
                      );
                    }

                    final monthlyReports = monthlyReportsSnapshot.data ?? [];

                    // Calculate total offerings for this month
                    double totalOfferings = 0.0;
                    for (final report in monthlyReports) {
                      totalOfferings += report.offeringAmount;
                    }

                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildMetricCard(
                          icon: Icons.groups,
                          title: 'Fellowships',
                          value: totalFellowships.toString(),
                          color: Colors.blue,
                          subtitle: 'Active groups',
                          isLoading:
                              fellowshipSnapshot.connectionState ==
                              ConnectionState.waiting,
                        ),
                        _buildMetricCard(
                          icon: Icons.person,
                          title: 'Leaders',
                          value: activeLeaders.toString(),
                          color: Colors.green,
                          subtitle: 'Assigned',
                          isLoading:
                              fellowshipSnapshot.connectionState ==
                              ConnectionState.waiting,
                        ),
                        _buildMetricCard(
                          icon: Icons.assignment_turned_in,
                          title: 'Reports',
                          value: weeklyReportsCount.toString(),
                          color: Colors.purple,
                          subtitle: 'This week',
                          isLoading:
                              weeklyReportsSnapshot.connectionState ==
                              ConnectionState.waiting,
                        ),
                        _buildMetricCard(
                          icon: Icons.monetization_on,
                          title: 'Offerings',
                          value: 'K${totalOfferings.toStringAsFixed(0)}',
                          color: Colors.orange,
                          subtitle: 'This month',
                          isLoading:
                              monthlyReportsSnapshot.connectionState ==
                              ConnectionState.waiting,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
    bool isLoading = false,
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
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isLoading ? '...' : value,
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

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Fellowship Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () {
                // Navigate to reports section
                setState(() => _currentIndex = 2);
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<FellowshipReportModel>>(
          stream: _getRecentActivityReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                elevation: 2,
                child: Container(
                  height: 120,
                  padding: const EdgeInsets.all(20.0),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  ),
                ),
              );
            }

            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
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
                          'No recent fellowship activity',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        Text(
                          'Reports will appear here when submitted',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Card(
              elevation: 2,
              child: Column(
                children:
                    reports
                        .take(5)
                        .map((report) => _buildRecentActivityItem(report))
                        .toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivityItem(FellowshipReportModel report) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          // Fellowship photo thumbnail
          CachedImageThumbnail(
            imageUrl: report.fellowshipImageUrl,
            imageType: 'fellowship',
            size: 50,
            onTap:
                report.fellowshipImageUrl != null
                    ? () => _showFullscreenImage(
                      report.fellowshipImageUrl!,
                      '${report.fellowshipName} - ${report.formattedReportDate}',
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          // Report details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.fellowshipName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.attendanceCount} attendees • ${report.formattedOffering}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  _getRelativeTime(report.submittedAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          // Status and actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      report.isApproved
                          ? Colors.green[100]
                          : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  report.isApproved ? 'Approved' : 'Pending',
                  style: TextStyle(
                    color:
                        report.isApproved
                            ? Colors.green[700]
                            : Colors.orange[700],
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (report.hasImages)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (report.fellowshipImageUrl != null)
                      Icon(
                        Icons.photo_camera,
                        color: Colors.blue[400],
                        size: 14,
                      ),
                    if (report.fellowshipImageUrl != null &&
                        report.receiptImageUrl != null)
                      const SizedBox(width: 4),
                    if (report.receiptImageUrl != null)
                      Icon(Icons.receipt, color: Colors.green[400], size: 14),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Fellowship photo gallery section
  Widget _buildFellowshipPhotoGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Fellowship Photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () {
                // Navigate to analytics section to see more photos
                setState(() => _currentIndex = 3);
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<FellowshipReportModel>>(
          stream: _getPhotoGalleryReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                elevation: 2,
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(20.0),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  ),
                ),
              );
            }

            final reports = snapshot.data ?? [];
            final reportsWithPhotos =
                reports
                    .where((report) => report.fellowshipImageUrl != null)
                    .toList();

            if (reportsWithPhotos.isEmpty) {
              return Card(
                elevation: 2,
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(20.0),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          color: Colors.grey,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No fellowship photos yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        Text(
                          'Photos will appear here when reports are submitted',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Card(
              elevation: 2,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.photo_camera, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${reportsWithPhotos.length} Recent Photos',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: reportsWithPhotos.length,
                        itemBuilder: (context, index) {
                          final report = reportsWithPhotos[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              right:
                                  index < reportsWithPhotos.length - 1 ? 12 : 0,
                            ),
                            child: _buildPhotoGalleryItem(report),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhotoGalleryItem(FellowshipReportModel report) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        children: [
          // Photo with enhanced caching
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: GestureDetector(
                onTap:
                    () => _showFullscreenImage(
                      report.fellowshipImageUrl!,
                      '${report.fellowshipName} - ${report.formattedReportDate}',
                    ),
                child: CachedImageWidget.fellowship(
                  imageUrl: report.fellowshipImageUrl,
                  width: 120,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Fellowship info overlay
          Container(
            width: 120,
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(11),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.fellowshipName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getRelativeTime(report.reportDate),
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fellowships management section
  Widget _buildFellowshipsSection() {
    if (widget.user.constituencyId == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No constituency assigned\nFellowship management requires constituency data',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFellowshipsHeader(),
              const SizedBox(height: 16),
              _buildFellowshipsFilters(),
              const SizedBox(height: 16),
              _buildFellowshipsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFellowshipsHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.groups, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fellowship Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage and monitor fellowships in your constituency',
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

  Widget _buildFellowshipsFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Fellowships',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Leader Assignment',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: _selectedLeaderAssignmentFilter,
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Fellowships'),
                      ),
                      DropdownMenuItem(
                        value: 'assigned',
                        child: Text('With Leaders'),
                      ),
                      DropdownMenuItem(
                        value: 'unassigned',
                        child: Text('Without Leaders'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedLeaderAssignmentFilter = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: _selectedFellowshipStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'suspended',
                        child: Text('Suspended'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedFellowshipStatusFilter = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFellowshipsList() {
    return StreamBuilder<List<FellowshipModel>>(
      stream: _getFilteredFellowships(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading fellowships: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final fellowships = snapshot.data ?? [];

        if (fellowships.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.groups, color: Colors.grey, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No Fellowships Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No fellowships match the selected filters',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                '${fellowships.length} Fellowship${fellowships.length != 1 ? 's' : ''} Found',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fellowships.length,
              itemBuilder: (context, index) {
                final fellowship = fellowships[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildFellowshipCard(fellowship),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFellowshipCard(FellowshipModel fellowship) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToFellowshipDetail(fellowship),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fellowship.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (fellowship.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            fellowship.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            fellowship.status,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(
                              fellowship.status,
                            ).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          fellowship.status.value.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(fellowship.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildFellowshipMetric(
                    icon: Icons.person,
                    label: 'Leader',
                    value: fellowship.leaderId != null ? 'Assigned' : 'None',
                    color:
                        fellowship.leaderId != null
                            ? Colors.green
                            : Colors.orange,
                  ),
                  const SizedBox(width: 16),
                  _buildFellowshipMetric(
                    icon: Icons.people,
                    label: 'Members',
                    value: fellowship.memberCount.toString(),
                    color: Colors.blue,
                  ),
                  if (fellowship.meetingDay?.isNotEmpty == true) ...[
                    const SizedBox(width: 16),
                    _buildFellowshipMetric(
                      icon: Icons.calendar_today,
                      label: 'Meeting',
                      value: fellowship.meetingDay!,
                      color: Colors.purple,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFellowshipMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(Status status) {
    switch (status) {
      case Status.active:
        return Colors.green;
      case Status.pending:
        return Colors.orange;
      case Status.suspended:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Reports monitoring section
  Widget _buildReportsSection() {
    if (widget.user.constituencyId == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No constituency assigned\nReport monitoring requires constituency data',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportsHeader(),
              const SizedBox(height: 16),
              _buildReportsFilters(),
              const SizedBox(height: 16),
              _buildReportsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.assignment, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fellowship Reports',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitor and review reports from your constituency fellowships',
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

  Widget _buildReportsFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Reports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Fellowship filter dropdown
            StreamBuilder<List<FellowshipModel>>(
              stream: _firestoreService.getFellowshipsByConstituency(
                widget.user.constituencyId!,
              ),
              builder: (context, snapshot) {
                final fellowships = snapshot.data ?? [];

                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Fellowship',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        value: _selectedFellowshipFilter,
                        hint: const Text('All Fellowships'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Fellowships'),
                          ),
                          ...fellowships.map(
                            (fellowship) => DropdownMenuItem<String>(
                              value: fellowship.id,
                              child: Text(fellowship.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFellowshipFilter = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Date Range',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        value: _selectedReportDateRange,
                        items: const [
                          DropdownMenuItem(
                            value: 'last_7_days',
                            child: Text('Last 7 Days'),
                          ),
                          DropdownMenuItem(
                            value: 'last_30_days',
                            child: Text('Last 30 Days'),
                          ),
                          DropdownMenuItem(
                            value: 'last_90_days',
                            child: Text('Last 90 Days'),
                          ),
                          DropdownMenuItem(
                            value: 'all_time',
                            child: Text('All Time'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedReportDateRange = value!;
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    return StreamBuilder<List<FellowshipReportModel>>(
      stream: _getFilteredReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading reports: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.assignment, color: Colors.grey, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No Reports Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No fellowship reports match the selected filters',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                '${reports.length} Report${reports.length != 1 ? 's' : ''} Found',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildReportCard(report),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportCard(FellowshipReportModel report) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToReportDetail(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.fellowshipName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submitted by ${report.submitterName}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        report.formattedReportDate,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRelativeTime(report.submittedAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildReportMetric(
                    icon: Icons.people,
                    label: 'Attendance',
                    value: report.attendanceCount.toString(),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildReportMetric(
                    icon: Icons.monetization_on,
                    label: 'Offering',
                    value: report.formattedOffering,
                    color: Colors.orange,
                  ),
                  if (report.hasImages) ...[
                    const SizedBox(width: 16),
                    _buildReportMetric(
                      icon: Icons.photo_camera,
                      label: 'Photos',
                      value: '✓',
                      color: Colors.green,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Analytics section with charts for attendance and offering trends
  Widget _buildAnalyticsSection() {
    if (widget.user.constituencyId == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No constituency assigned\nAnalytics require constituency data',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnalyticsHeader(),
              const SizedBox(height: 20),
              _buildDateRangeSelector(),
              const SizedBox(height: 20),
              _buildAttendanceChart(),
              const SizedBox(height: 20),
              _buildOfferingChart(),
              const SizedBox(height: 20),
              _buildAnalyticsSummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.analytics, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Constituency Analytics',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attendance and offering trends for your fellowships',
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

  Widget _buildDateRangeSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Text(
              'View:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SegmentedButton<String>(
                selected: {_selectedDateRange},
                onSelectionChanged: (Set<String> selected) {
                  setState(() {
                    _selectedDateRange = selected.first;
                  });
                },
                segments: const [
                  ButtonSegment<String>(
                    value: 'weekly',
                    label: Text('Last 7 Weeks'),
                    icon: Icon(Icons.calendar_view_week),
                  ),
                  ButtonSegment<String>(
                    value: 'monthly',
                    label: Text('Last 6 Months'),
                    icon: Icon(Icons.calendar_view_month),
                  ),
                ],
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.orange,
                  selectedForegroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Attendance Trends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<FellowshipReportModel>>(
              stream: _getAnalyticsReports(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  );
                }

                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No attendance data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return SizedBox(
                  height: 200,
                  child: LineChart(_buildAttendanceLineChart(reports)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferingChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Offering Trends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<FellowshipReportModel>>(
              stream: _getAnalyticsReports(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  );
                }

                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No offering data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return SizedBox(
                  height: 200,
                  child: BarChart(_buildOfferingBarChart(reports)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSummary() {
    return StreamBuilder<List<FellowshipReportModel>>(
      stream: _getAnalyticsReports(),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return const SizedBox.shrink();
        }

        // Calculate summary statistics
        final totalAttendance = reports.fold(
          0,
          (sum, report) => sum + report.attendanceCount,
        );
        final totalOfferings = reports.fold(
          0.0,
          (sum, report) => sum + report.offeringAmount,
        );
        final averageAttendance =
            reports.isNotEmpty ? totalAttendance / reports.length : 0.0;
        final averageOffering =
            reports.isNotEmpty ? totalOfferings / reports.length : 0.0;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Period Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Reports',
                        reports.length.toString(),
                        Icons.assignment,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Avg Attendance',
                        averageAttendance.toStringAsFixed(1),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Offerings',
                        'K${totalOfferings.toStringAsFixed(0)}',
                        Icons.monetization_on,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Avg Offering',
                        'K${averageOffering.toStringAsFixed(0)}',
                        Icons.account_balance_wallet,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to get analytics reports based on selected date range
  Stream<List<FellowshipReportModel>> _getAnalyticsReports() {
    final now = DateTime.now();
    final startDate =
        _selectedDateRange == 'weekly'
            ? now.subtract(const Duration(days: 49)) // 7 weeks
            : now.subtract(const Duration(days: 180)); // 6 months

    return _firestoreService.getConstituencyReports(
      constituencyId: widget.user.constituencyId!,
      startDate: startDate,
      limit: 100,
    );
  }

  // Helper method to get recent activity reports (last 7 days)
  Stream<List<FellowshipReportModel>> _getRecentActivityReports() {
    if (widget.user.constituencyId == null) {
      return Stream.value([]);
    }

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return _firestoreService.getConstituencyReports(
      constituencyId: widget.user.constituencyId!,
      startDate: sevenDaysAgo,
      limit: 10,
    );
  }

  // Helper method to get reports with photos for photo gallery (last 30 days)
  Stream<List<FellowshipReportModel>> _getPhotoGalleryReports() {
    if (widget.user.constituencyId == null) {
      return Stream.value([]);
    }

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _firestoreService.getConstituencyReports(
      constituencyId: widget.user.constituencyId!,
      startDate: thirtyDaysAgo,
      limit: 20,
    );
  }

  // Helper method to show fullscreen image viewer
  void _showFullscreenImage(String imageUrl, String title) {
    try {
      if (imageUrl.isNotEmpty && mounted) {
        CachedImageViewer.show(
          context,
          imageUrl: imageUrl,
          imageType: 'fellowship',
          title: title,
        );
      }
    } catch (e) {
      debugPrint('Error showing fullscreen image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to display image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  // Build line chart data for attendance trends
  LineChartData _buildAttendanceLineChart(List<FellowshipReportModel> reports) {
    final chartData = _processAttendanceData(reports);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 5,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 1);
        },
        getDrawingVerticalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 1);
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (double value, TitleMeta meta) {
              if (value.toInt() < chartData.length) {
                final dateStr = chartData[value.toInt()]['label'] as String;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              }
              return Container();
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d)),
      ),
      minX: 0,
      maxX: (chartData.length - 1).toDouble(),
      minY: 0,
      maxY: _getMaxAttendance(chartData) * 1.2,
      lineBarsData: [
        LineChartBarData(
          spots:
              chartData.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value['attendance'] as double,
                );
              }).toList(),
          isCurved: true,
          gradient: LinearGradient(
            colors: [Colors.blue.withOpacity(0.8), Colors.blue],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Colors.blue,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.3),
                Colors.blue.withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  // Build bar chart data for offering trends
  BarChartData _buildOfferingBarChart(List<FellowshipReportModel> reports) {
    final chartData = _processOfferingData(reports);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: _getMaxOffering(chartData) * 1.2,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            return BarTooltipItem(
              'K${rod.toY.toStringAsFixed(0)}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (double value, TitleMeta meta) {
              if (value.toInt() < chartData.length) {
                final dateStr = chartData[value.toInt()]['label'] as String;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              }
              return Container();
            },
            reservedSize: 38,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            interval: _getOfferingInterval(chartData),
            getTitlesWidget: (double value, TitleMeta meta) {
              return Text(
                'K${value.toInt()}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups:
          chartData.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value['offering'] as double,
                  gradient: LinearGradient(
                    colors: [Colors.orange.withOpacity(0.8), Colors.orange],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        horizontalInterval: _getOfferingInterval(chartData),
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 1);
        },
      ),
    );
  }

  // Helper methods for data processing
  List<Map<String, dynamic>> _processAttendanceData(
    List<FellowshipReportModel> reports,
  ) {
    final Map<String, List<int>> groupedData = {};

    for (final report in reports) {
      final period =
          _selectedDateRange == 'weekly'
              ? _getWeekLabel(report.reportDate)
              : _getMonthLabel(report.reportDate);

      if (!groupedData.containsKey(period)) {
        groupedData[period] = [];
      }
      groupedData[period]!.add(report.attendanceCount);
    }

    final sortedPeriods = groupedData.keys.toList()..sort();
    final maxPeriods = _selectedDateRange == 'weekly' ? 7 : 6;
    final periods = sortedPeriods.take(maxPeriods).toList();

    return periods.map((period) {
      final attendances = groupedData[period] ?? [];
      final avgAttendance =
          attendances.isNotEmpty
              ? attendances.fold(0, (a, b) => a + b) / attendances.length
              : 0.0;
      return {'label': period, 'attendance': avgAttendance};
    }).toList();
  }

  List<Map<String, dynamic>> _processOfferingData(
    List<FellowshipReportModel> reports,
  ) {
    final Map<String, List<double>> groupedData = {};

    for (final report in reports) {
      final period =
          _selectedDateRange == 'weekly'
              ? _getWeekLabel(report.reportDate)
              : _getMonthLabel(report.reportDate);

      if (!groupedData.containsKey(period)) {
        groupedData[period] = [];
      }
      groupedData[period]!.add(report.offeringAmount);
    }

    final sortedPeriods = groupedData.keys.toList()..sort();
    final maxPeriods = _selectedDateRange == 'weekly' ? 7 : 6;
    final periods = sortedPeriods.take(maxPeriods).toList();

    return periods.map((period) {
      final offerings = groupedData[period] ?? [];
      final totalOffering = offerings.fold(0.0, (a, b) => a + b);
      return {'label': period, 'offering': totalOffering};
    }).toList();
  }

  String _getWeekLabel(DateTime date) {
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    return '${weekStart.day}/${weekStart.month}';
  }

  String _getMonthLabel(DateTime date) {
    const months = [
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
    return months[date.month - 1];
  }

  double _getMaxAttendance(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 50;
    try {
      return data
          .map((item) => (item['attendance'] as num?)?.toDouble() ?? 0.0)
          .reduce((a, b) => a > b ? a : b);
    } catch (e) {
      debugPrint('Error calculating max attendance: $e');
      return 50;
    }
  }

  double _getMaxOffering(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 1000;
    try {
      return data
          .map((item) => (item['offering'] as num?)?.toDouble() ?? 0.0)
          .reduce((a, b) => a > b ? a : b);
    } catch (e) {
      debugPrint('Error calculating max offering: $e');
      return 1000;
    }
  }

  double _getOfferingInterval(List<Map<String, dynamic>> data) {
    final maxOffering = _getMaxOffering(data);
    if (maxOffering <= 500) return 100;
    if (maxOffering <= 2000) return 500;
    if (maxOffering <= 10000) return 1000;
    return 2000;
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isLoading = true);
    try {
      await _loadConstituencyData();
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

  /// Leaders management section
  Widget _buildLeadersSection() {
    return LeaderManagementScreen(user: widget.user);
  }

  /// Get filtered reports based on current filter selections
  Stream<List<FellowshipReportModel>> _getFilteredReports() {
    if (widget.user.constituencyId == null) {
      return Stream.value([]);
    }

    // Calculate start date based on selected date range
    DateTime? startDate;
    switch (_selectedReportDateRange) {
      case 'last_7_days':
        startDate = DateTime.now().subtract(const Duration(days: 7));
        break;
      case 'last_30_days':
        startDate = DateTime.now().subtract(const Duration(days: 30));
        break;
      case 'last_90_days':
        startDate = DateTime.now().subtract(const Duration(days: 90));
        break;
      case 'all_time':
        startDate = null;
        break;
    }

    // Get reports from Firestore
    final reportsStream = _firestoreService.getConstituencyReports(
      constituencyId: widget.user.constituencyId!,
      startDate: startDate,
      limit: 200,
    );

    // Apply fellowship filter if selected
    if (_selectedFellowshipFilter != null) {
      return reportsStream.map(
        (reports) =>
            reports
                .where(
                  (report) => report.fellowshipId == _selectedFellowshipFilter,
                )
                .toList(),
      );
    }

    return reportsStream;
  }

  /// Navigate to detailed report view
  void _navigateToReportDetail(FellowshipReportModel report) {
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        builder: (context) => _ReportDetailDialog(report: report),
      );
    } catch (e) {
      debugPrint('Error showing report detail: $e');
    }
  }

  /// Get filtered fellowships based on current filter selections
  Stream<List<FellowshipModel>> _getFilteredFellowships() {
    if (widget.user.constituencyId == null) {
      return Stream.value([]);
    }

    // Get fellowships from Firestore
    final fellowshipsStream = _firestoreService.getFellowshipsByConstituency(
      widget.user.constituencyId!,
    );

    return fellowshipsStream.map((fellowships) {
      // Apply leader assignment filter
      var filtered = fellowships;

      switch (_selectedLeaderAssignmentFilter) {
        case 'assigned':
          filtered = filtered.where((f) => f.leaderId != null).toList();
          break;
        case 'unassigned':
          filtered = filtered.where((f) => f.leaderId == null).toList();
          break;
        case 'all':
        default:
          // No filter needed
          break;
      }

      // Apply status filter
      switch (_selectedFellowshipStatusFilter) {
        case 'active':
          filtered = filtered.where((f) => f.status == Status.active).toList();
          break;
        case 'pending':
          filtered = filtered.where((f) => f.status == Status.pending).toList();
          break;
        case 'suspended':
          filtered =
              filtered.where((f) => f.status == Status.suspended).toList();
          break;
        case 'all':
        default:
          // No filter needed
          break;
      }

      return filtered;
    });
  }

  /// Navigate to detailed fellowship view
  void _navigateToFellowshipDetail(FellowshipModel fellowship) {
    if (!mounted) return;

    try {
      // For now, show a detailed dialog since we don't have a separate detail screen yet
      showDialog(
        context: context,
        builder: (context) => _FellowshipDetailDialog(fellowship: fellowship),
      );
    } catch (e) {
      debugPrint('Error showing fellowship detail: $e');
    }
  }

  /// Build floating action button based on current tab
  Widget? _buildFloatingActionButton() {
    switch (_currentIndex) {
      case 1: // Fellowships tab
        return FloatingActionButton.extended(
          onPressed: _showCreateFellowshipDialog,
          icon: const Icon(Icons.add),
          label: const Text('Create Fellowship'),
          backgroundColor: Colors.orange,
        );
      case 4: // Leaders tab
        return FloatingActionButton.extended(
          onPressed: () {
            // Navigate to leader creation
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LeaderManagementScreen(user: widget.user),
              ),
            );
          },
          icon: const Icon(Icons.person_add),
          label: const Text('Add Leader'),
          backgroundColor: Colors.green,
        );
      default:
        return null; // No FAB for other tabs
    }
  }

  /// Show dialog to create a new fellowship
  Future<void> _showCreateFellowshipDialog() async {
    if (widget.user.constituencyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No constituency assigned to create fellowships'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => _CreateFellowshipDialog(
            constituencyId: widget.user.constituencyId!,
            pastorId: widget.user.id,
            onFellowshipCreated: () {
              // Refresh the UI when fellowship is created
              setState(() {});
            },
          ),
    );
  }
}

/// Dialog widget to display detailed report information
class _ReportDetailDialog extends StatelessWidget {
  final FellowshipReportModel report;

  const _ReportDetailDialog({required this.report});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fellowship Report',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Fellowship', report.fellowshipName),
                    _buildDetailRow('Constituency', report.constituencyName),
                    _buildDetailRow('Pastor', report.pastorName),
                    const Divider(),
                    _buildDetailRow('Report Date', report.formattedReportDate),
                    _buildDetailRow('Submitted By', report.submitterName),
                    _buildDetailRow(
                      'Submitted At',
                      _formatDateTime(report.submittedAt),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Attendance',
                      report.attendanceCount.toString(),
                    ),
                    _buildDetailRow(
                      'Offering Amount',
                      report.formattedOffering,
                    ),
                    if (report.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Notes:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(report.notes!),
                    ],
                    if (report.hasImages) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Fellowship Photo:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedImageWidget.fellowship(
                          imageUrl: report.fellowshipImageUrl,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Dialog widget to create a new fellowship
class _CreateFellowshipDialog extends StatefulWidget {
  final String constituencyId;
  final String pastorId;
  final VoidCallback onFellowshipCreated;

  const _CreateFellowshipDialog({
    required this.constituencyId,
    required this.pastorId,
    required this.onFellowshipCreated,
  });

  @override
  State<_CreateFellowshipDialog> createState() =>
      _CreateFellowshipDialogState();
}

class _CreateFellowshipDialogState extends State<_CreateFellowshipDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _meetingDayController = TextEditingController();
  final _meetingTimeController = TextEditingController();
  final _meetingLocationController = TextEditingController();

  final _firestoreService = FirestoreService();

  bool _isLoading = false;
  List<UserModel> _availableLeaders = [];
  String? _selectedLeaderId;

  @override
  void initState() {
    super.initState();
    _loadAvailableLeaders();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _meetingDayController.dispose();
    _meetingTimeController.dispose();
    _meetingLocationController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableLeaders() async {
    try {
      // Get all leaders in this constituency using FirestoreService
      final allLeaders =
          await _firestoreService
              .getUsersByRole(UserRole.leader)
              .map(
                (users) =>
                    users
                        .where(
                          (user) =>
                              user.constituencyId == widget.constituencyId,
                        )
                        .toList(),
              )
              .first;

      final fellowships =
          await _firestoreService
              .getFellowshipsByConstituency(widget.constituencyId)
              .first;

      final assignedLeaderIds =
          fellowships
              .where((f) => f.leaderId != null)
              .map((f) => f.leaderId!)
              .toSet();

      final availableLeaders =
          allLeaders
              .where((leader) => !assignedLeaderIds.contains(leader.id))
              .toList();

      if (mounted) {
        setState(() {
          _availableLeaders = availableLeaders;
        });
      }
    } catch (e) {
      debugPrint('Error loading available leaders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Create New Fellowship',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fellowship name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Fellowship Name *',
                          hintText: 'Enter fellowship name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Fellowship name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Brief description of the fellowship',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Leader assignment
                      const Text(
                        'Assign Leader (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedLeaderId,
                        decoration: const InputDecoration(
                          hintText: 'Select a leader',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No leader assigned'),
                          ),
                          ..._availableLeaders.map((leader) {
                            return DropdownMenuItem<String>(
                              value: leader.id,
                              child: Text(
                                '${leader.firstName} ${leader.lastName}',
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedLeaderId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Meeting details section
                      const Text(
                        'Meeting Details (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Meeting day
                      TextFormField(
                        controller: _meetingDayController,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Day',
                          hintText: 'e.g., Every Sunday',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Meeting time
                      TextFormField(
                        controller: _meetingTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Time',
                          hintText: 'e.g., 2:00 PM - 4:00 PM',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Meeting location
                      TextFormField(
                        controller: _meetingLocationController,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Location',
                          hintText: 'e.g., Community Hall',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createFellowship,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Create Fellowship'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFellowship() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create fellowship model
      final fellowship = FellowshipModel(
        id: '', // Will be set by Firestore
        name: _nameController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        constituencyId: widget.constituencyId,
        pastorId: widget.pastorId,
        leaderId: _selectedLeaderId,
        memberCount: 0,
        status: Status.active,
        meetingDay:
            _meetingDayController.text.trim().isEmpty
                ? null
                : _meetingDayController.text.trim(),
        meetingTime:
            _meetingTimeController.text.trim().isEmpty
                ? null
                : _meetingTimeController.text.trim(),
        meetingLocation:
            _meetingLocationController.text.trim().isEmpty
                ? null
                : _meetingLocationController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create fellowship in Firestore
      await _firestoreService.createFellowship(fellowship);

      // If leader was assigned, update their fellowship assignment
      if (_selectedLeaderId != null) {
        // Use direct Firestore call to update leader with fellowship assignment
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_selectedLeaderId!)
            .update({
              'fellowshipId': fellowship.id,
              'updatedAt': Timestamp.now(),
            });
      }

      if (mounted) {
        // Notify parent widget
        widget.onFellowshipCreated();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fellowship "${fellowship.name}" created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Close dialog
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating fellowship: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error creating fellowship: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Dialog widget to display detailed fellowship information
class _FellowshipDetailDialog extends StatelessWidget {
  final FellowshipModel fellowship;

  const _FellowshipDetailDialog({required this.fellowship});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.groups, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fellowship Details',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Fellowship Name', fellowship.name),
                    if (fellowship.description?.isNotEmpty == true)
                      _buildDetailRow('Description', fellowship.description!),
                    const Divider(),
                    _buildDetailRow(
                      'Status',
                      fellowship.status.value.toUpperCase(),
                    ),
                    _buildDetailRow(
                      'Member Count',
                      fellowship.memberCount.toString(),
                    ),
                    if (fellowship.leaderId != null)
                      _buildDetailRow('Leader Assigned', 'Yes')
                    else
                      _buildDetailRow('Leader Assigned', 'No'),
                    const Divider(),
                    if (fellowship.meetingDay?.isNotEmpty == true)
                      _buildDetailRow('Meeting Day', fellowship.meetingDay!),
                    if (fellowship.meetingTime?.isNotEmpty == true)
                      _buildDetailRow('Meeting Time', fellowship.meetingTime!),
                    if (fellowship.meetingLocation?.isNotEmpty == true)
                      _buildDetailRow(
                        'Meeting Location',
                        fellowship.meetingLocation!,
                      ),
                    const Divider(),
                    _buildDetailRow(
                      'Created',
                      _formatDateTime(fellowship.createdAt),
                    ),
                    _buildDetailRow(
                      'Last Updated',
                      _formatDateTime(fellowship.updatedAt),
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
