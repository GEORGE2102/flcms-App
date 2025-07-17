import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/constituency_model.dart';
import '../../models/fellowship_model.dart';
import '../../models/fellowship_report_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/pastor_service.dart';
import '../../services/sync_service.dart';
import '../../services/offline_aware_service.dart';
import '../../utils/enums.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/sync_status_widget.dart';
import 'pastor_management.dart';
import '../common/report_history_screen.dart';

/// Main dashboard screen for Bishops
/// Provides church-wide oversight, pastor management, and analytics
class BishopDashboard extends StatefulWidget {
  final UserModel user;

  const BishopDashboard({super.key, required this.user});

  @override
  State<BishopDashboard> createState() => _BishopDashboardState();
}

class _BishopDashboardState extends State<BishopDashboard>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final PastorService _pastorService = PastorService();
  final OfflineAwareService _offlineAwareService = OfflineAwareService();

  late TabController _tabController;
  bool _isLoading = false;

  // Church-wide metrics - now will be calculated from real-time data
  // Remove hardcoded values

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      // Update the floating action button when tab changes
      setState(() {});
    });
    _initializeDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    setState(() => _isLoading = true);

    try {
      // No longer need to load hardcoded metrics
      // All data will be loaded via StreamBuilder widgets
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

  Future<void> _loadChurchMetrics() async {
    // This method is no longer needed as we'll use StreamBuilder
    // Remove hardcoded data loading
  }

  /// Demonstrate offline-aware data operations
  Future<void> _refreshDataOfflineAware() async {
    try {
      setState(() => _isLoading = true);

      // Test offline-aware data loading
      final pastorsStream = _offlineAwareService.getUsersByRole(
        UserRole.pastor,
      );
      final pastors = await pastorsStream.first;

      // Update metrics
      // _totalPastors = pastors.length;

      // Force a sync if online
      await _offlineAwareService.forceSync();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data refreshed! Found ${pastors.length} pastors'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View Sync Status',
              textColor: Colors.white,
              onPressed: () => _showSyncStatusDialog(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
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

  /// Show detailed sync status dialog
  void _showSyncStatusDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sync Status'),
            content: const MobileSyncStatusWidget(showCompact: false),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
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
              CircularProgressIndicator(color: Colors.purple),
              SizedBox(height: 16),
              Text('Loading Bishop Dashboard...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bishop Dashboard - ${widget.user.firstName}'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.purple.shade100,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Pastors'),
            Tab(icon: Icon(Icons.location_city), text: 'Constituencies'),
            Tab(icon: Icon(Icons.assignment), text: 'Reports'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await _handleLogout();
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 8),
                        Text(widget.user.fullName),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer<SyncService>(
            builder: (context, syncService, child) {
              return OfflineIndicator(
                isOnline: syncService.isOnline,
                pendingActions: syncService.pendingActionsCount,
                isSyncing: syncService.isSyncing,
              );
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPastorsTab(),
                _buildConstituenciesTab(),
                _buildReportsTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// Build floating action button based on current tab
  Widget? _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 0: // Overview tab
        return FloatingActionButton.extended(
          heroTag: "refresh_data_fab",
          onPressed: _refreshDataOfflineAware,
          backgroundColor: Colors.blue,
          icon: const Icon(Icons.refresh),
          label: const Text('Test Sync'),
        );

      case 1: // Pastors tab
        return null; // Pastor Management tab has its own add button

      case 2: // Constituencies tab
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.small(
              heroTag: "sync_fab",
              onPressed: _syncPastorConstituencyData,
              backgroundColor: Colors.orange,
              child: const Icon(Icons.sync, color: Colors.white),
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              heroTag: "add_constituency_fab",
              onPressed: _showAddConstituencyDialog,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add),
            ),
          ],
        );

      case 3: // Reports tab
        return null; // No floating action button for reports

      case 4: // Analytics tab
        return null; // No floating action button for analytics

      default:
        return null;
    }
  }

  /// Overview tab with church-wide metrics and summary
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildChurchMetricsGrid(),
          const SizedBox(height: 16),
          _buildRecentActivityCard(),
          const SizedBox(height: 16),
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.purple.shade100,
                  child: Text(
                    '${widget.user.firstName[0]}${widget.user.lastName[0]}',
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, Bishop ${widget.user.firstName}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'First Love Church Leadership',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'BISHOP',
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Oversee church operations, manage pastors, and monitor spiritual growth',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
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

  Widget _buildChurchMetricsGrid() {
    return StreamBuilder<List<ConstituencyModel>>(
      stream: _pastorService.getAllConstituencies(),
      builder: (context, constituencySnapshot) {
        final constituencies = constituencySnapshot.data ?? [];

        return StreamBuilder<List<UserModel>>(
          stream: _offlineAwareService.getUsersByRole(UserRole.pastor),
          builder: (context, pastorSnapshot) {
            final pastors = pastorSnapshot.data ?? [];

            return StreamBuilder<List<FellowshipReportModel>>(
              stream: _firestoreService.getAllFellowshipReports(
                startDate: DateTime.now().subtract(const Duration(days: 30)),
              ),
              builder: (context, reportsSnapshot) {
                final reports = reportsSnapshot.data ?? [];
                double totalOfferings = 0.0;
                Set<String> uniqueFellowships = {};

                for (final report in reports) {
                  totalOfferings += report.offeringAmount;
                  uniqueFellowships.add(report.fellowshipId);
                }

                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _buildMetricCard(
                      icon: Icons.location_city,
                      title: 'Constituencies',
                      value: '${constituencies.length}',
                      subtitle: 'Active areas',
                      color: Colors.blue,
                      trend: 'Real-time',
                    ),
                    _buildMetricCard(
                      icon: Icons.people,
                      title: 'Pastors',
                      value: '${pastors.length}',
                      subtitle: 'Serving',
                      color: Colors.orange,
                      trend: 'Real-time',
                    ),
                    _buildMetricCard(
                      icon: Icons.groups,
                      title: 'Fellowships',
                      value: '${uniqueFellowships.length}',
                      subtitle: 'Reporting',
                      color: Colors.green,
                      trend: 'Real-time',
                    ),
                    _buildMetricCard(
                      icon: Icons.monetization_on,
                      title: 'Offerings',
                      value:
                          totalOfferings > 0
                              ? 'K${(totalOfferings / 1000).toStringAsFixed(0)}'
                              : 'K0',
                      subtitle: 'This month',
                      color: Colors.purple,
                      trend: 'Real-time',
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required String trend,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Church Activity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _tabController.animateTo(3),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View All'),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<FellowshipReportModel>>(
              stream: _getRecentChurchActivity(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 120,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  );
                }

                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return Container(
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
                            'No recent church activity',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          Text(
                            'Reports will appear here when submitted',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children:
                      reports
                          .take(3)
                          .map((report) => _buildRecentActivityItem(report))
                          .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityItem(FellowshipReportModel report) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.withOpacity(0.1),
            child: const Icon(
              Icons.assignment_turned_in,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.fellowshipName} Report',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.constituencyName} • ${report.attendanceCount} attendees • ${report.formattedOffering}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      report.isApproved
                          ? Colors.green[100]
                          : Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
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
              const SizedBox(height: 2),
              Text(
                _getRelativeTime(report.submittedAt),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to get recent church-wide activity for bishops
  Stream<List<FellowshipReportModel>> _getRecentChurchActivity() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return _firestoreService.getAllFellowshipReports(
      startDate: sevenDaysAgo,
      limit: 10,
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

  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.person_add,
                    label: 'Add Pastor',
                    color: Colors.orange,
                    onTap: () => _tabController.animateTo(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.location_city,
                    label: 'Manage Areas',
                    color: Colors.blue,
                    onTap: () => _tabController.animateTo(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.cloud_sync,
                    label: 'Sync Status',
                    color: Colors.teal,
                    onTap: _showSyncStatusDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.analytics,
                    label: 'Analytics',
                    color: Colors.purple,
                    onTap: () => _tabController.animateTo(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Pastors management tab
  Widget _buildPastorsTab() {
    return const PastorManagement();
  }

  /// Constituencies management tab
  Widget _buildConstituenciesTab() {
    return StreamBuilder<List<ConstituencyModel>>(
      stream: _pastorService.getAllConstituencies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final constituencies = snapshot.data ?? [];

        return Scaffold(
          body:
              constituencies.isEmpty
                  ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No constituencies found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the + button to add a new constituency',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: constituencies.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final constituency = constituencies[index];
                      return _buildConstituencyCard(constituency);
                    },
                  ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddConstituencyDialog,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildConstituencyCard(ConstituencyModel constituency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.business, color: Colors.blue.shade700),
        ),
        title: Text(
          constituency.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (constituency.description != null)
              Text(
                constituency.description!,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  constituency.pastorName.isNotEmpty
                      ? Icons.person
                      : Icons.person_off,
                  size: 16,
                  color:
                      constituency.pastorName.isNotEmpty
                          ? Colors.green
                          : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  constituency.pastorName.isNotEmpty
                      ? 'Pastor: ${constituency.pastorName}'
                      : 'No pastor assigned',
                  style: TextStyle(
                    color:
                        constituency.pastorName.isNotEmpty
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editConstituency(constituency);
                break;
              case 'assign':
                _assignPastorToConstituency(constituency);
                break;
              case 'delete':
                _deleteConstituency(constituency);
                break;
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'assign',
                  child: Row(
                    children: [
                      Icon(Icons.assignment_ind),
                      SizedBox(width: 8),
                      Text('Assign Pastor'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConstituencyDetails(constituency),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => _editConstituency(constituency),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed:
                          () => _assignPastorToConstituency(constituency),
                      icon: const Icon(Icons.assignment_ind),
                      label: const Text('Assign Pastor'),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteConstituency(constituency),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstituencyDetails(ConstituencyModel constituency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Constituency Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildDetailRow(Icons.business, 'Name', constituency.name),
        if (constituency.description != null)
          _buildDetailRow(
            Icons.description,
            'Description',
            constituency.description!,
          ),
        _buildDetailRow(
          Icons.person,
          'Pastor',
          constituency.pastorName.isNotEmpty
              ? constituency.pastorName
              : 'No pastor assigned',
        ),
        _buildDetailRow(
          Icons.groups,
          'Fellowships',
          '${constituency.fellowshipCount}',
        ),
        _buildDetailRow(
          Icons.calendar_today,
          'Created',
          '${constituency.createdAt.day}/${constituency.createdAt.month}/${constituency.createdAt.year}',
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showAddConstituencyDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Constituency'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Constituency Name',
                        hintText: 'e.g., Garden, Foxdale, Libala',
                      ),
                      validator:
                          (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Brief description of the area',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await _pastorService.createConstituency(
                        name: nameController.text.trim(),
                        description:
                            descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Constituency created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  void _editConstituency(ConstituencyModel constituency) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: constituency.name);
    final descriptionController = TextEditingController(
      text: constituency.description ?? '',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Constituency'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Constituency Name',
                      ),
                      validator:
                          (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await _pastorService.updateConstituency(
                        constituencyId: constituency.id,
                        name: nameController.text.trim(),
                        description:
                            descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Constituency updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  void _assignPastorToConstituency(ConstituencyModel constituency) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Assign Pastor to ${constituency.name}'),
            content: StreamBuilder<List<UserModel>>(
              stream: _pastorService.getAllPastors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final pastors = snapshot.data ?? [];
                final availablePastors =
                    pastors
                        .where(
                          (p) =>
                              p.constituencyId == null ||
                              p.constituencyId == constituency.pastorId,
                        )
                        .toList();

                if (availablePastors.isEmpty) {
                  return const Text('No available pastors to assign.');
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        availablePastors.map((pastor) {
                          final isCurrentlyAssigned =
                              constituency.pastorId == pastor.id;

                          return ListTile(
                            title: Text(pastor.fullName),
                            subtitle: Text(pastor.email),
                            leading: CircleAvatar(
                              child: Text(
                                pastor.firstName[0] + pastor.lastName[0],
                              ),
                            ),
                            trailing:
                                isCurrentlyAssigned
                                    ? TextButton(
                                      onPressed: () async {
                                        try {
                                          await _pastorService
                                              .updateConstituency(
                                                constituencyId: constituency.id,
                                                pastorId: '',
                                              );
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Pastor unassigned successfully',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Remove'),
                                    )
                                    : TextButton(
                                      onPressed: () async {
                                        try {
                                          await _pastorService
                                              .updateConstituency(
                                                constituencyId: constituency.id,
                                                pastorId: pastor.id,
                                              );
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Pastor assigned successfully',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Assign'),
                                    ),
                          );
                        }).toList(),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _deleteConstituency(ConstituencyModel constituency) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Constituency'),
            content: Text(
              'Are you sure you want to delete "${constituency.name}"?\n\nThis action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _pastorService.deleteConstituency(constituency.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Constituency deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Reports overview tab
  Widget _buildReportsTab() {
    return const ReportHistoryScreen();
  }

  /// Analytics and insights tab
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Church Analytics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildOfferingTrendsChart(),
          const SizedBox(height: 16),
          _buildGrowthMetricsChart(),
          const SizedBox(height: 16),
          _buildConstituencyComparisonChart(),
        ],
      ),
    );
  }

  Widget _buildOfferingTrendsChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Offering Trends',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                          ];
                          if (value.toInt() >= 0 &&
                              value.toInt() < months.length) {
                            return Text(
                              months[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value / 1000).toStringAsFixed(0)}K',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 380000),
                        FlSpot(1, 420000),
                        FlSpot(2, 395000),
                        FlSpot(3, 445000),
                        FlSpot(4, 430000),
                        FlSpot(5, 450000),
                      ],
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthMetricsChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Church Growth Metrics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 300,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const titles = ['Fellowships', 'Members', 'Reports'];
                          if (value.toInt() >= 0 &&
                              value.toInt() < titles.length) {
                            return Text(
                              titles[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [BarChartRodData(toY: 65, color: Colors.blue)],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [BarChartRodData(toY: 280, color: Colors.green)],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(toY: 180, color: Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstituencyComparisonChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Constituency Performance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.blue,
                      value: 25,
                      title: 'Garden\n25%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.green,
                      value: 20,
                      title: 'Foxdale\n20%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.orange,
                      value: 18,
                      title: 'Kabulonga\n18%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.purple,
                      value: 15,
                      title: 'Chelston\n15%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.red,
                      value: 22,
                      title: 'Others\n22%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncPastorConstituencyData() async {
    // Show confirmation dialog first
    final shouldSync = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.sync, color: Colors.orange),
                SizedBox(width: 8),
                Text('Sync Data'),
              ],
            ),
            content: const Text(
              'This will check and fix any mismatched pastor-constituency assignments.\n\nProceed?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Sync Now'),
              ),
            ],
          ),
    );

    if (shouldSync != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Syncing...'),
              ],
            ),
            content: const Text('Checking and fixing assignments...'),
          ),
    );

    try {
      // Add a small delay to ensure dialog shows
      await Future.delayed(const Duration(milliseconds: 300));

      // Perform the sync
      await _pastorService.fixPastorConstituencySync();

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Sync completed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('❌ Sync failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
