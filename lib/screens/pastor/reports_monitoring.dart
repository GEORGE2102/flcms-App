import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../models/fellowship_report_model.dart';
import '../../models/sunday_bus_report_model.dart';
import '../../services/firestore_service.dart';

/// Sorting options for reports
enum SortOption {
  dateDescending('Date (Newest First)', 'date_desc'),
  dateAscending('Date (Oldest First)', 'date_asc'),
  attendanceHighToLow('Attendance (High to Low)', 'attendance_desc'),
  attendanceLowToHigh('Attendance (Low to High)', 'attendance_asc'),
  offeringHighToLow('Offering (High to Low)', 'offering_desc'),
  offeringLowToHigh('Offering (Low to High)', 'offering_asc'),
  fellowshipAZ('Fellowship (A-Z)', 'fellowship_asc'),
  fellowshipZA('Fellowship (Z-A)', 'fellowship_desc');

  const SortOption(this.displayName, this.value);
  final String displayName;
  final String value;
}

/// Attendance range filters
enum AttendanceRange {
  small('0-10 people', 0, 10),
  medium('11-25 people', 11, 25),
  large('26-50 people', 26, 50),
  extraLarge('50+ people', 51, 999);

  const AttendanceRange(this.displayName, this.min, this.max);
  final String displayName;
  final int min;
  final int max;
}

/// Offering range filters
enum OfferingRange {
  low('Under ZMW 100', 0, 100),
  medium('ZMW 100-500', 100, 500),
  high('ZMW 500-1000', 500, 1000),
  veryHigh('Over ZMW 1000', 1000, 999999);

  const OfferingRange(this.displayName, this.min, this.max);
  final String displayName;
  final double min;
  final double max;
}

/// Reports Monitoring Screen for Pastors
/// Allows pastors to view and analyze fellowship reports from their constituency
class ReportsMonitoringScreen extends StatefulWidget {
  final UserModel user;

  const ReportsMonitoringScreen({super.key, required this.user});

  @override
  State<ReportsMonitoringScreen> createState() =>
      _ReportsMonitoringScreenState();
}

class _ReportsMonitoringScreenState extends State<ReportsMonitoringScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  // Filter state
  DateTimeRange? _selectedDateRange;
  String? _selectedFellowshipFilter;
  bool? _approvalFilter; // null = all, true = approved, false = pending

  // New sorting state
  SortOption _sortOption = SortOption.dateDescending;
  AttendanceRange? _attendanceRangeFilter;
  OfferingRange? _offeringRangeFilter;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  // UI state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Set default date range to last 30 days
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Monitoring'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.orange[100],
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Fellowship Reports'),
            Tab(icon: Icon(Icons.directions_bus), text: 'Bus Reports'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showFilterBottomSheet();
            },
            tooltip: 'Filter Reports',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          _buildAnalyticsCards(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFellowshipReportsTab(), _buildBusReportsTab()],
            ),
          ),
        ],
      ),
    );
  }

  /// Build search and filter bar
  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search reports...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchTerm.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _searchController.clear();
                            _searchTerm = '';
                          });
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchTerm = value.trim();
              });
            },
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateRangeChip(),
                const SizedBox(width: 8),
                _buildSortChip(),
                const SizedBox(width: 8),
                if (_approvalFilter != null) _buildApprovalFilterChip(),
                const SizedBox(width: 8),
                if (_attendanceRangeFilter != null) _buildAttendanceRangeChip(),
                const SizedBox(width: 8),
                if (_offeringRangeFilter != null) _buildOfferingRangeChip(),
                const SizedBox(width: 8),
                if (_selectedFellowshipFilter != null)
                  _buildFellowshipFilterChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build date range filter chip
  Widget _buildDateRangeChip() {
    return FilterChip(
      avatar: const Icon(Icons.date_range, size: 18),
      label: Text(
        _selectedDateRange != null
            ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
            : 'Date Range',
        style: const TextStyle(fontSize: 12),
      ),
      selected: _selectedDateRange != null,
      onSelected: (selected) {
        HapticFeedback.lightImpact();
        _showDateRangePicker();
      },
      selectedColor: Colors.orange.withOpacity(0.2),
    );
  }

  /// Build sort chip
  Widget _buildSortChip() {
    return FilterChip(
      avatar: const Icon(Icons.sort, size: 18),
      label: Text(
        _sortOption.displayName,
        style: const TextStyle(fontSize: 12),
      ),
      selected: true,
      onSelected: (selected) {
        HapticFeedback.lightImpact();
        _showSortBottomSheet();
      },
      selectedColor: Colors.orange.withOpacity(0.2),
    );
  }

  /// Build approval filter chip
  Widget _buildApprovalFilterChip() {
    return FilterChip(
      avatar: Icon(
        _approvalFilter == true ? Icons.check_circle : Icons.pending,
        size: 18,
        color: _approvalFilter == true ? Colors.green : Colors.orange,
      ),
      label: Text(
        _approvalFilter == true ? 'Approved' : 'Pending',
        style: const TextStyle(fontSize: 12),
      ),
      selected: true,
      onSelected: (selected) {
        HapticFeedback.lightImpact();
        setState(() {
          _approvalFilter = null;
        });
      },
      selectedColor: (_approvalFilter == true ? Colors.green : Colors.orange)
          .withOpacity(0.2),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: () {
        HapticFeedback.lightImpact();
        setState(() {
          _approvalFilter = null;
        });
      },
    );
  }

  /// Build attendance range filter chip
  Widget _buildAttendanceRangeChip() {
    return FilterChip(
      avatar: const Icon(Icons.people, size: 18),
      label: Text(
        _attendanceRangeFilter?.displayName ?? 'Attendance Range',
        style: const TextStyle(fontSize: 12),
      ),
      selected: _attendanceRangeFilter != null,
      onSelected: (selected) {
        HapticFeedback.lightImpact();
        _showAttendanceRangePicker();
      },
      selectedColor: Colors.blue.withOpacity(0.2),
    );
  }

  /// Build offering range filter chip
  Widget _buildOfferingRangeChip() {
    return FilterChip(
      avatar: const Icon(Icons.account_balance_wallet, size: 18),
      label: Text(
        _offeringRangeFilter?.displayName ?? 'Offering Range',
        style: const TextStyle(fontSize: 12),
      ),
      selected: _offeringRangeFilter != null,
      onSelected: (selected) {
        HapticFeedback.lightImpact();
        _showOfferingRangePicker();
      },
      selectedColor: Colors.green.withOpacity(0.2),
    );
  }

  /// Build fellowship filter chip
  Widget _buildFellowshipFilterChip() {
    return FilterChip(
      avatar: const Icon(Icons.group, size: 18),
      label: Text(
        _selectedFellowshipFilter ?? 'Fellowship',
        style: const TextStyle(fontSize: 12),
      ),
      selected: true,
      onSelected: (selected) {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedFellowshipFilter = null;
        });
      },
      selectedColor: Colors.blue.withOpacity(0.2),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedFellowshipFilter = null;
        });
      },
    );
  }

  /// Build analytics cards
  Widget _buildAnalyticsCards() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _getAnalyticsSummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final data = snapshot.data!;
          return Column(
            children: [
              // First row of analytics cards
              SizedBox(
                height: 80,
                child: Row(
                  children: [
                    _buildAnalyticsCard(
                      'Total Reports',
                      '${data['totalReports'] ?? 0}',
                      Icons.description,
                      Colors.blue,
                      onTap: () => _showReportsBreakdown(data),
                    ),
                    const SizedBox(width: 12),
                    _buildAnalyticsCard(
                      'Approved',
                      '${data['approvedReports'] ?? 0}',
                      Icons.check_circle,
                      Colors.green,
                      onTap: () => _filterByApprovalStatus(true),
                    ),
                    const SizedBox(width: 12),
                    _buildAnalyticsCard(
                      'Avg Attendance',
                      '${(data['averageAttendance'] ?? 0.0).toStringAsFixed(0)}',
                      Icons.people,
                      Colors.orange,
                      onTap: () => _showAttendanceTrends(data),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Second row of analytics cards
              SizedBox(
                height: 80,
                child: Row(
                  children: [
                    _buildAnalyticsCard(
                      'Total Offering',
                      _formatCurrency(data['totalOffering'] ?? 0.0),
                      Icons.account_balance_wallet,
                      Colors.green,
                      onTap: () => _showOfferingTrends(data),
                    ),
                    const SizedBox(width: 12),
                    _buildAnalyticsCard(
                      'Peak Attendance',
                      '${data['peakAttendance'] ?? 0}',
                      Icons.trending_up,
                      Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildAnalyticsCard(
                      'Export Data',
                      'CSV',
                      Icons.download,
                      Colors.purple,
                      onTap: () => _exportReportsToCSV(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build individual analytics card
  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap:
            onTap != null
                ? () {
                  HapticFeedback.lightImpact();
                  onTap();
                }
                : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build fellowship reports tab
  Widget _buildFellowshipReportsTab() {
    return StreamBuilder<List<FellowshipReportModel>>(
      stream: _getFellowshipReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            'Error loading fellowship reports: ${snapshot.error}',
          );
        }

        final reports = snapshot.data ?? [];
        final filteredReports = _filterFellowshipReports(reports);

        if (filteredReports.isEmpty) {
          return _buildEmptyState(
            'No fellowship reports found',
            'No reports match your current filters.',
            Icons.description_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: Colors.orange,
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: filteredReports.length,
            itemBuilder: (context, index) {
              final report = filteredReports[index];
              return _buildFellowshipReportCard(report);
            },
          ),
        );
      },
    );
  }

  /// Build bus reports tab
  Widget _buildBusReportsTab() {
    return StreamBuilder<List<SundayBusReportModel>>(
      stream: _getBusReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            'Error loading bus reports: ${snapshot.error}',
          );
        }

        final reports = snapshot.data ?? [];
        final filteredReports = _filterBusReports(reports);

        if (filteredReports.isEmpty) {
          return _buildEmptyState(
            'No bus reports found',
            'No reports match your current filters.',
            Icons.directions_bus_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: Colors.orange,
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: filteredReports.length,
            itemBuilder: (context, index) {
              final report = filteredReports[index];
              return _buildBusReportCard(report);
            },
          ),
        );
      },
    );
  }

  /// Build fellowship report card
  Widget _buildFellowshipReportCard(FellowshipReportModel report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          _showReportDetails(report);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.formattedReportDate,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildApprovalChip(report.isApproved),
                ],
              ),
              const SizedBox(height: 12),

              // Metrics row
              Row(
                children: [
                  _buildMetricItem(
                    'Attendance',
                    '${report.attendanceCount}',
                    Icons.people,
                    Colors.blue,
                  ),
                  const SizedBox(width: 24),
                  _buildMetricItem(
                    'Offering',
                    report.formattedOffering,
                    Icons.account_balance_wallet,
                    Colors.green,
                  ),
                ],
              ),

              if (report.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  report.notes!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Action row
              const SizedBox(height: 12),
              Row(
                children: [
                  if (report.hasImages)
                    Icon(Icons.photo, size: 16, color: Colors.grey[500]),
                  const Spacer(),
                  Text(
                    'By ${report.submitterName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build bus report card
  Widget _buildBusReportCard(SundayBusReportModel report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          _showBusReportDetails(report);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sunday Bus - ${report.constituencyName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.formattedReportDate,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildApprovalChip(report.isApproved),
                ],
              ),
              const SizedBox(height: 12),

              // Metrics row
              Row(
                children: [
                  _buildMetricItem(
                    'Attendance',
                    '${report.attendanceCount}',
                    Icons.people,
                    Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildMetricItem(
                    'Profit/Loss',
                    report.formattedProfit,
                    report.profit >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    report.profit >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Driver info
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Driver: ${report.driverName}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  if (report.hasBusPhoto)
                    Icon(Icons.photo, size: 16, color: Colors.grey[500]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build approval chip
  Widget _buildApprovalChip(bool isApproved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isApproved
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isApproved ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApproved ? Icons.check_circle : Icons.pending,
            size: 14,
            color: isApproved ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isApproved ? 'Approved' : 'Pending',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isApproved ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  /// Build metric item
  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  /// Build error state
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                  _selectedFellowshipFilter = null;
                  _approvalFilter = null;
                  _searchController.clear();
                  _searchTerm = '';
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show filter bottom sheet
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Filter Reports',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.date_range),
                        title: Text(
                          _selectedDateRange != null
                              ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
                              : 'Select Date Range',
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await _showDateRangePicker();
                        },
                      ),
                      const Divider(),
                      const Text(
                        'Approval Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      RadioListTile<bool?>(
                        title: const Text('All Reports'),
                        value: null,
                        groupValue: _approvalFilter,
                        onChanged: (value) {
                          setState(() => _approvalFilter = value);
                          Navigator.pop(context);
                        },
                      ),
                      RadioListTile<bool?>(
                        title: const Text('Approved Only'),
                        value: true,
                        groupValue: _approvalFilter,
                        onChanged: (value) {
                          setState(() => _approvalFilter = value);
                          Navigator.pop(context);
                        },
                      ),
                      RadioListTile<bool?>(
                        title: const Text('Pending Only'),
                        value: false,
                        groupValue: _approvalFilter,
                        onChanged: (value) {
                          setState(() => _approvalFilter = value);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Show date range picker
  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) setState(() => _selectedDateRange = picked);
  }

  /// Format date for display
  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  /// Get fellowship reports stream
  Stream<List<FellowshipReportModel>> _getFellowshipReportsStream() {
    if (!widget.user.isPastor) return Stream.value([]);
    return _firestoreService.getConstituencyReports(
      constituencyId: widget.user.constituencyId!,
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
      limit: 100,
    );
  }

  /// Get bus reports stream
  Stream<List<SundayBusReportModel>> _getBusReportsStream() {
    if (!widget.user.isPastor) return Stream.value([]);
    return _firestoreService.getBusReportsByDateRange(
      constituencyId: widget.user.constituencyId!,
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
      limit: 100,
    );
  }

  /// Filter fellowship reports based on search and filters
  List<FellowshipReportModel> _filterFellowshipReports(
    List<FellowshipReportModel> reports,
  ) {
    var filteredReports =
        reports.where((report) {
          // Search filter
          if (_searchTerm.isNotEmpty) {
            final searchLower = _searchTerm.toLowerCase();
            if (!report.fellowshipName.toLowerCase().contains(searchLower) &&
                !report.submitterName.toLowerCase().contains(searchLower))
              return false;
          }
          // Approval filter
          if (_approvalFilter != null && report.isApproved != _approvalFilter)
            return false;
          // Fellowship filter
          if (_selectedFellowshipFilter != null &&
              report.fellowshipName != _selectedFellowshipFilter)
            return false;
          // Attendance range filter
          if (_attendanceRangeFilter != null) {
            if (report.attendanceCount < _attendanceRangeFilter!.min ||
                report.attendanceCount > _attendanceRangeFilter!.max)
              return false;
          }
          // Offering range filter
          if (_offeringRangeFilter != null) {
            if (report.offeringAmount < _offeringRangeFilter!.min ||
                report.offeringAmount > _offeringRangeFilter!.max)
              return false;
          }
          return true;
        }).toList();

    // Apply sorting
    return _sortFellowshipReports(filteredReports);
  }

  /// Filter bus reports based on search and filters
  List<SundayBusReportModel> _filterBusReports(
    List<SundayBusReportModel> reports,
  ) {
    var filteredReports =
        reports.where((report) {
          // Search filter
          if (_searchTerm.isNotEmpty) {
            final searchLower = _searchTerm.toLowerCase();
            if (!report.constituencyName.toLowerCase().contains(searchLower) &&
                !report.driverName.toLowerCase().contains(searchLower))
              return false;
          }
          // Approval filter
          if (_approvalFilter != null && report.isApproved != _approvalFilter)
            return false;
          // Attendance range filter
          if (_attendanceRangeFilter != null) {
            if (report.attendanceCount < _attendanceRangeFilter!.min ||
                report.attendanceCount > _attendanceRangeFilter!.max)
              return false;
          }
          // Offering range filter
          if (_offeringRangeFilter != null) {
            if (report.offering < _offeringRangeFilter!.min ||
                report.offering > _offeringRangeFilter!.max)
              return false;
          }
          return true;
        }).toList();

    // Apply sorting
    return _sortBusReports(filteredReports);
  }

  /// Sort fellowship reports based on selected sort option
  List<FellowshipReportModel> _sortFellowshipReports(
    List<FellowshipReportModel> reports,
  ) {
    switch (_sortOption) {
      case SortOption.dateDescending:
        reports.sort((a, b) => b.reportDate.compareTo(a.reportDate));
        break;
      case SortOption.dateAscending:
        reports.sort((a, b) => a.reportDate.compareTo(b.reportDate));
        break;
      case SortOption.attendanceHighToLow:
        reports.sort((a, b) => b.attendanceCount.compareTo(a.attendanceCount));
        break;
      case SortOption.attendanceLowToHigh:
        reports.sort((a, b) => a.attendanceCount.compareTo(b.attendanceCount));
        break;
      case SortOption.offeringHighToLow:
        reports.sort((a, b) => b.offeringAmount.compareTo(a.offeringAmount));
        break;
      case SortOption.offeringLowToHigh:
        reports.sort((a, b) => a.offeringAmount.compareTo(b.offeringAmount));
        break;
      case SortOption.fellowshipAZ:
        reports.sort((a, b) => a.fellowshipName.compareTo(b.fellowshipName));
        break;
      case SortOption.fellowshipZA:
        reports.sort((a, b) => b.fellowshipName.compareTo(a.fellowshipName));
        break;
    }
    return reports;
  }

  /// Sort bus reports based on selected sort option
  List<SundayBusReportModel> _sortBusReports(
    List<SundayBusReportModel> reports,
  ) {
    switch (_sortOption) {
      case SortOption.dateDescending:
        reports.sort((a, b) => b.reportDate.compareTo(a.reportDate));
        break;
      case SortOption.dateAscending:
        reports.sort((a, b) => a.reportDate.compareTo(b.reportDate));
        break;
      case SortOption.attendanceHighToLow:
        reports.sort((a, b) => b.attendanceCount.compareTo(a.attendanceCount));
        break;
      case SortOption.attendanceLowToHigh:
        reports.sort((a, b) => a.attendanceCount.compareTo(b.attendanceCount));
        break;
      case SortOption.offeringHighToLow:
        reports.sort((a, b) => b.offering.compareTo(a.offering));
        break;
      case SortOption.offeringLowToHigh:
        reports.sort((a, b) => a.offering.compareTo(b.offering));
        break;
      case SortOption.fellowshipAZ:
        reports.sort(
          (a, b) => a.constituencyName.compareTo(b.constituencyName),
        );
        break;
      case SortOption.fellowshipZA:
        reports.sort(
          (a, b) => b.constituencyName.compareTo(a.constituencyName),
        );
        break;
    }
    return reports;
  }

  /// Show sort bottom sheet
  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Sort Reports',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...SortOption.values.map(
                  (option) => RadioListTile<SortOption>(
                    title: Text(option.displayName),
                    value: option,
                    groupValue: _sortOption,
                    onChanged: (value) {
                      setState(() => _sortOption = value!);
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Show attendance range picker
  void _showAttendanceRangePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Attendance Range',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RadioListTile<AttendanceRange?>(
                  title: const Text('All Attendance'),
                  value: null,
                  groupValue: _attendanceRangeFilter,
                  onChanged: (value) {
                    setState(() => _attendanceRangeFilter = value);
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                  },
                ),
                ...AttendanceRange.values.map(
                  (range) => RadioListTile<AttendanceRange?>(
                    title: Text(range.displayName),
                    value: range,
                    groupValue: _attendanceRangeFilter,
                    onChanged: (value) {
                      setState(() => _attendanceRangeFilter = value);
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Show offering range picker
  void _showOfferingRangePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Offering Range',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RadioListTile<OfferingRange?>(
                  title: const Text('All Offerings'),
                  value: null,
                  groupValue: _offeringRangeFilter,
                  onChanged: (value) {
                    setState(() => _offeringRangeFilter = value);
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                  },
                ),
                ...OfferingRange.values.map(
                  (range) => RadioListTile<OfferingRange?>(
                    title: Text(range.displayName),
                    value: range,
                    groupValue: _offeringRangeFilter,
                    onChanged: (value) {
                      setState(() => _offeringRangeFilter = value);
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Get analytics summary
  Future<Map<String, dynamic>> _getAnalyticsSummary() async {
    if (!widget.user.isPastor) return {};
    try {
      return await _firestoreService.getFellowshipSummary(
        constituencyId: widget.user.constituencyId!,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );
    } catch (e) {
      return {};
    }
  }

  /// Show fellowship report details
  void _showReportDetails(FellowshipReportModel report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(report.fellowshipName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${report.formattedReportDate}'),
                Text('Attendance: ${report.attendanceCount}'),
                Text('Offering: ${report.formattedOffering}'),
                Text('Submitted by: ${report.submitterName}'),
                if (report.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text('Notes: ${report.notes}'),
                ],
              ],
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

  /// Show bus report details
  void _showBusReportDetails(SundayBusReportModel report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Sunday Bus - ${report.constituencyName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${report.formattedReportDate}'),
                Text('Attendance: ${report.attendanceCount}'),
                Text('Driver: ${report.driverName}'),
                Text('Offering: ${report.formattedOffering}'),
                Text('Bus Cost: ${report.formattedBusCost}'),
                Text('Profit/Loss: ${report.formattedProfit}'),
              ],
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

  /// Show reports breakdown dialog
  void _showReportsBreakdown(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reports Breakdown'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Reports: ${data['totalReports'] ?? 0}'),
                Text('Approved: ${data['approvedReports'] ?? 0}'),
                Text(
                  'Pending: ${(data['totalReports'] ?? 0) - (data['approvedReports'] ?? 0)}',
                ),
                Text(
                  'Approval Rate: ${((data['approvedReports'] ?? 0) / (data['totalReports'] ?? 1) * 100).toStringAsFixed(1)}%',
                ),
              ],
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

  /// Filter reports by approval status
  void _filterByApprovalStatus(bool approved) {
    setState(() {
      _approvalFilter = approved;
    });
  }

  /// Show attendance trends dialog
  void _showAttendanceTrends(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Attendance Trends'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Average Attendance: ${(data['averageAttendance'] ?? 0.0).toStringAsFixed(1)}',
                ),
                Text('Peak Attendance: ${data['peakAttendance'] ?? 0}'),
                Text('Total Attendees: ${data['totalAttendance'] ?? 0}'),
                const SizedBox(height: 8),
                const Text(
                  'Tip: Use filters to analyze specific time periods or fellowship groups.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
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

  /// Format currency for display
  String _formatCurrency(double amount) {
    return 'ZMW ${amount.toStringAsFixed(2)}';
  }

  /// Show offering trends dialog
  void _showOfferingTrends(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Offering Trends'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Offering: ${_formatCurrency(data['totalOffering'] ?? 0.0)}',
                ),
                Text(
                  'Average per Report: ${_formatCurrency((data['totalOffering'] ?? 0.0) / (data['totalReports'] ?? 1))}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track offering patterns to identify growth opportunities.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
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

  /// Export reports to CSV
  void _exportReportsToCSV() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Export to CSV'),
            content: const Text(
              'CSV export functionality will be implemented in a future update. This feature will allow you to export filtered reports for analysis in spreadsheet applications.',
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
}
