import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/fellowship_report_model.dart';
import '../../models/sunday_bus_report_model.dart';
import '../../models/user_model.dart';
import '../../services/report_service.dart';
import '../../services/auth_service.dart';
import '../../services/permissions_service.dart';
import '../../utils/enums.dart';
import '../../widgets/cached_image_widget.dart';

/// Comprehensive mobile-first report history and analytics screen
///
/// This screen provides role-based access to view fellowship and Sunday bus reports
/// with advanced filtering, search, pagination, and analytics capabilities.
class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen>
    with TickerProviderStateMixin {
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService();
  final PermissionsService _permissionsService = PermissionsService();

  // UI Controllers
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // State variables
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  ReportFilters _currentFilters = ReportFilters();

  // Data storage
  List<FellowshipReportModel> _fellowshipReports = [];
  List<SundayBusReportModel> _busReports = [];
  DocumentSnapshot? _lastFellowshipDocument;
  DocumentSnapshot? _lastBusDocument;
  bool _hasMoreFellowshipReports = true;
  bool _hasMoreBusReports = true;

  // Analytics data
  FinancialSummary? _financialSummary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadUserAndReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Load current user data and initial reports
  Future<void> _loadUserAndReports() async {
    try {
      final user = await _authService.getCurrentUserData();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      setState(() {
        _currentUser = user;
      });

      await _loadInitialData();
    } catch (e) {
      _showErrorSnackBar('Failed to load user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Load initial data including reports and analytics
  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadFellowshipReports(refresh: true),
      _loadBusReports(refresh: true),
      _loadFinancialSummary(),
    ]);
  }

  /// Load fellowship reports with pagination
  Future<void> _loadFellowshipReports({bool refresh = false}) async {
    if (refresh) {
      _fellowshipReports.clear();
      _lastFellowshipDocument = null;
      _hasMoreFellowshipReports = true;
    }

    if (!_hasMoreFellowshipReports && !refresh) return;

    try {
      final result = await _reportService.getFellowshipReports(
        limit: 20,
        startAfter: _lastFellowshipDocument,
        filters: _currentFilters.copyWith(reportType: ReportType.fellowship),
      );

      setState(() {
        if (refresh) {
          _fellowshipReports = result.reports;
        } else {
          _fellowshipReports.addAll(result.reports);
        }
        _lastFellowshipDocument = result.lastDocument;
        _hasMoreFellowshipReports = result.hasMore;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load fellowship reports: $e');
    }
  }

  /// Load Sunday bus reports with pagination
  Future<void> _loadBusReports({bool refresh = false}) async {
    if (refresh) {
      _busReports.clear();
      _lastBusDocument = null;
      _hasMoreBusReports = true;
    }

    if (!_hasMoreBusReports && !refresh) return;

    try {
      final result = await _reportService.getSundayBusReports(
        limit: 20,
        startAfter: _lastBusDocument,
        filters: _currentFilters.copyWith(reportType: ReportType.sundayBus),
      );

      setState(() {
        if (refresh) {
          _busReports = result.reports;
        } else {
          _busReports.addAll(result.reports);
        }
        _lastBusDocument = result.lastDocument;
        _hasMoreBusReports = result.hasMore;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load bus reports: $e');
    }
  }

  /// Load financial summary for analytics
  Future<void> _loadFinancialSummary() async {
    try {
      final canView = await _permissionsService.canViewAllFinancialReports();
      if (!canView) return;

      final summary = await _reportService.getFinancialSummary(
        startDate: _currentFilters.startDate,
        endDate: _currentFilters.endDate,
        constituencyId: _currentFilters.constituencyId,
      );

      setState(() {
        _financialSummary = summary;
      });
    } catch (e) {
      // Silently handle - user might not have permissions
    }
  }

  /// Handle tab changes between Fellowship and Bus reports
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        // Update selected report type
      });
    }
  }

  /// Handle scroll events for infinite pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_tabController.index == 0 && _hasMoreFellowshipReports) {
        _loadMoreFellowshipReports();
      } else if (_tabController.index == 1 && _hasMoreBusReports) {
        _loadMoreBusReports();
      }
    }
  }

  /// Load more fellowship reports for pagination
  Future<void> _loadMoreFellowshipReports() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _loadFellowshipReports(refresh: false);

    setState(() {
      _isLoadingMore = false;
    });
  }

  /// Load more bus reports for pagination
  Future<void> _loadMoreBusReports() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _loadBusReports(refresh: false);

    setState(() {
      _isLoadingMore = false;
    });
  }

  /// Refresh all data
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    await _loadInitialData();

    setState(() {
      _isLoading = false;
    });
  }

  /// Show error message
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show filter bottom sheet
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildAdvancedFilterSheet(),
    );
  }

  /// Apply new filters and refresh data
  void _applyFilters(ReportFilters newFilters) {
    setState(() {
      _currentFilters = newFilters;
    });
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder:
            (context, innerBoxIsScrolled) => [
              _buildSliverAppBar(innerBoxIsScrolled),
              if (_financialSummary != null) _buildFinancialSummarySliver(),
              _buildTabBarSliver(),
            ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildFellowshipReportsView(), _buildBusReportsView()],
        ),
      ),
    );
  }

  /// Build collapsible app bar with search
  Widget _buildSliverAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      title: const Text(
        'Report History',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: _showFilterSheet,
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshData,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
              child: _buildSearchBar(),
            ),
          ),
        ),
      ),
    );
  }

  /// Build search bar
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search reports...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  /// Build financial summary sliver
  Widget _buildFinancialSummarySliver() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Summary',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Offerings',
                    _financialSummary!.formattedTotalOfferings,
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Bus Profit',
                    _financialSummary!.formattedBusProfit,
                    Icons.trending_up,
                    _financialSummary!.busProfit >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Reports',
                    '${_financialSummary!.reportCount}',
                    Icons.assignment,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Attendance',
                    '${_financialSummary!.totalAttendance}',
                    Icons.people,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build small summary card
  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build tab bar sliver
  Widget _buildTabBarSliver() {
    return SliverPersistentHeader(
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Fellowship Reports'),
            Tab(text: 'Bus Reports'),
          ],
        ),
      ),
      pinned: true,
    );
  }

  /// Build fellowship reports view
  Widget _buildFellowshipReportsView() {
    if (_fellowshipReports.isEmpty && !_isLoading) {
      return _buildEmptyState('No fellowship reports found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount:
          _fellowshipReports.length + (_hasMoreFellowshipReports ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _fellowshipReports.length) {
          return _buildLoadingIndicator();
        }

        return _buildFellowshipReportCard(_fellowshipReports[index]);
      },
    );
  }

  /// Build bus reports view
  Widget _buildBusReportsView() {
    if (_busReports.isEmpty && !_isLoading) {
      return _buildEmptyState('No bus reports found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _busReports.length + (_hasMoreBusReports ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _busReports.length) {
          return _buildLoadingIndicator();
        }

        return _buildBusReportCard(_busReports[index]);
      },
    );
  }

  /// Build fellowship report card
  Widget _buildFellowshipReportCard(FellowshipReportModel report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with fellowship name and date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          report.constituencyName,
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      _buildApprovalBadge(report.isApproved),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metrics row
              Row(
                children: [
                  _buildMetricChip(
                    'Attendance',
                    '${report.attendanceCount}',
                    Icons.people,
                    Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricChip(
                    'Offering',
                    report.formattedOffering,
                    Icons.attach_money,
                    Colors.green,
                  ),
                ],
              ),

              // Images preview if available
              if (report.hasImages) ...[
                const SizedBox(height: 12),
                _buildImagePreview(report),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build bus report card
  Widget _buildBusReportCard(SundayBusReportModel report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBusReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with constituency and date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${report.constituencyName} Bus',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Driver: ${report.driverName}',
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      _buildApprovalBadge(report.isApproved),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metrics row
              Row(
                children: [
                  _buildMetricChip(
                    'Passengers',
                    '${report.attendanceCount}',
                    Icons.people,
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    'Offering',
                    report.formattedOffering,
                    Icons.attach_money,
                    Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    'Cost',
                    report.formattedBusCost,
                    Icons.local_gas_station,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Profit/Loss indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      report.profit >= 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      report.profit >= 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 16,
                      color: report.profit >= 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      report.formattedProfit,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: report.profit >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build approval status badge
  Widget _buildApprovalBadge(bool isApproved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isApproved
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isApproved ? 'Approved' : 'Pending',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isApproved ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  /// Build metric chip
  Widget _buildMetricChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build image preview
  Widget _buildImagePreview(FellowshipReportModel report) {
    return Row(
      children: [
        if (report.fellowshipImageUrl != null)
          _buildImageThumbnail(
            report.fellowshipImageUrl!,
            'Fellowship Photo',
            Icons.group,
          ),
        if (report.fellowshipImageUrl != null && report.receiptImageUrl != null)
          const SizedBox(width: 8),
        if (report.receiptImageUrl != null)
          _buildImageThumbnail(
            report.receiptImageUrl!,
            'Receipt',
            Icons.receipt,
          ),
      ],
    );
  }

  /// Build image thumbnail
  Widget _buildImageThumbnail(String imageUrl, String label, IconData icon) {
    return GestureDetector(
      onTap: () => _showImageDialog(imageUrl, label),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedImageWidget(
            imageUrl: imageUrl,
            imageType: 'fellowship',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  /// Build empty state widget
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  /// Build loading indicator
  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  /// Show report details
  void _showReportDetails(FellowshipReportModel report) {
    // Navigate to detailed report view - will implement in next subtask
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report details for ${report.fellowshipName}')),
    );
  }

  /// Show bus report details
  void _showBusReportDetails(SundayBusReportModel report) {
    // Navigate to detailed bus report view - will implement in next subtask
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bus report details for ${report.constituencyName}'),
      ),
    );
  }

  /// Show image in full screen
  void _showImageDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  backgroundColor: Colors.black.withOpacity(0.7),
                  title: Text(
                    title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  elevation: 0,
                ),
                Expanded(
                  child: CachedImageWidget(
                    imageUrl: imageUrl,
                    imageType: 'fullscreen',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Build advanced filter sheet with comprehensive filtering options
  Widget _buildAdvancedFilterSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickFilters(),
                  const SizedBox(height: 24),
                  _buildDateRangeSection(),
                  const SizedBox(height: 24),
                  _buildAmountRangeSection(),
                  const SizedBox(height: 24),
                  _buildApprovalStatusSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _buildFilterActionButtons(),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Filter Reports',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Filters',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickFilterChip('Today', 'today'),
            _buildQuickFilterChip('This Week', 'week'),
            _buildQuickFilterChip('This Month', 'month'),
            _buildQuickFilterChip('This Year', 'year'),
            _buildQuickFilterChip('All Time', 'all'),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilterChip(String label, String filterType) {
    return FilterChip(
      label: Text(label),
      selected: _isQuickFilterSelected(filterType),
      onSelected: (selected) {
        if (selected) {
          _applyQuickFilter(filterType);
        }
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  bool _isQuickFilterSelected(String filterType) {
    final now = DateTime.now();
    if (_currentFilters.startDate == null && _currentFilters.endDate == null) {
      return filterType == 'all';
    }

    switch (filterType) {
      case 'today':
        return _currentFilters.startDate != null &&
            _currentFilters.startDate!.day == now.day &&
            _currentFilters.startDate!.month == now.month &&
            _currentFilters.startDate!.year == now.year;
      case 'week':
        return _currentFilters.startDate != null &&
            now.difference(_currentFilters.startDate!).inDays <= 7;
      case 'month':
        return _currentFilters.startDate != null &&
            _currentFilters.startDate!.month == now.month &&
            _currentFilters.startDate!.year == now.year;
      default:
        return false;
    }
  }

  void _applyQuickFilter(String filterType) {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate = now;

    switch (filterType) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'all':
        startDate = null;
        endDate = null;
        break;
    }

    setState(() {
      _currentFilters = _currentFilters.copyWith(
        startDate: startDate,
        endDate: endDate,
      );
    });
  }

  Widget _buildDateRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectDateRange,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getDateRangeText(),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _currentFilters.startDate != null && _currentFilters.endDate != null
              ? DateTimeRange(
                start: _currentFilters.startDate!,
                end: _currentFilters.endDate!,
              )
              : null,
    );

    if (picked != null) {
      setState(() {
        _currentFilters = _currentFilters.copyWith(
          startDate: picked.start,
          endDate: picked.end,
        );
      });
    }
  }

  String _getDateRangeText() {
    if (_currentFilters.startDate == null || _currentFilters.endDate == null) {
      return 'Select date range';
    }

    final start = _currentFilters.startDate!;
    final end = _currentFilters.endDate!;

    return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
  }

  Widget _buildAmountRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offering Amount Range',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        RangeSlider(
          values: RangeValues(
            _currentFilters.minAmount ?? 0,
            _currentFilters.maxAmount ?? 10000,
          ),
          min: 0,
          max: 10000,
          divisions: 100,
          labels: RangeLabels(
            'ZMW ${(_currentFilters.minAmount ?? 0).round()}',
            'ZMW ${(_currentFilters.maxAmount ?? 10000).round()}',
          ),
          onChanged: (values) {
            setState(() {
              _currentFilters = _currentFilters.copyWith(
                minAmount: values.start,
                maxAmount: values.end,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildApprovalStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Approval Status',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: _currentFilters.isApproved == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _currentFilters = _currentFilters.copyWith(
                      isApproved: null,
                    );
                  });
                }
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            ),
            FilterChip(
              label: const Text('Approved'),
              selected: _currentFilters.isApproved == true,
              onSelected: (selected) {
                setState(() {
                  _currentFilters = _currentFilters.copyWith(
                    isApproved: selected ? true : null,
                  );
                });
              },
              selectedColor: Colors.green.withOpacity(0.2),
            ),
            FilterChip(
              label: const Text('Pending'),
              selected: _currentFilters.isApproved == false,
              onSelected: (selected) {
                setState(() {
                  _currentFilters = _currentFilters.copyWith(
                    isApproved: selected ? false : null,
                  );
                });
              },
              selectedColor: Colors.orange.withOpacity(0.2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentFilters = ReportFilters();
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reset'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters(_currentFilters);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom sliver delegate for tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
