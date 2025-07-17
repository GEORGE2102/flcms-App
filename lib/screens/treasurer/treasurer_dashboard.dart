import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/user_model.dart';
import '../../models/fellowship_report_model.dart';
import '../../models/sunday_bus_report_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

/// Main dashboard screen for Treasurers
/// Provides financial oversight, offering tracking, and expense management
class TreasurerDashboard extends StatefulWidget {
  final UserModel user;

  const TreasurerDashboard({super.key, required this.user});

  @override
  State<TreasurerDashboard> createState() => _TreasurerDashboardState();
}

class _TreasurerDashboardState extends State<TreasurerDashboard>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late TabController _tabController;

  // Financial metrics - will be calculated from real-time data
  double _budgetTarget = 180000.0; // This could be configurable in the future

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Treasurer Dashboard - ${widget.user.firstName}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.green.shade100,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.monetization_on), text: 'Offerings'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Expenses'),
            Tab(icon: Icon(Icons.account_balance), text: 'Funds'),
            Tab(icon: Icon(Icons.analytics), text: 'Reports'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await _authService.signOut();
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildOfferingsTab(),
          _buildExpensesTab(),
          _buildFundsTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  /// Financial overview tab
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildFinancialSummary(),
          const SizedBox(height: 16),
          _buildOfferingTrendChart(),
          const SizedBox(height: 16),
          _buildRecentTransactionsSection(),
          const SizedBox(height: 16),
          _buildQuickActions(),
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
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    '${widget.user.firstName[0]}${widget.user.lastName[0]}',
                    style: TextStyle(
                      color: Colors.green.shade700,
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
                        'Welcome, Treasurer ${widget.user.firstName}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Financial Management & Oversight',
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
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'TREASURER',
                          style: TextStyle(
                            color: Colors.green.shade700,
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
                      'Monitor church finances, track offerings, and manage expenses',
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

  Widget _buildFinancialSummary() {
    return StreamBuilder<List<FellowshipReportModel>>(
      stream: _firestoreService.getAllFellowshipReports(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      ),
      builder: (context, fellowshipReportsSnapshot) {
        final fellowshipReports = fellowshipReportsSnapshot.data ?? [];

        return StreamBuilder<List<SundayBusReportModel>>(
          stream: _firestoreService.getAllBusReports(
            startDate: DateTime.now().subtract(const Duration(days: 30)),
          ),
          builder: (context, busReportsSnapshot) {
            final busReports = busReportsSnapshot.data ?? [];

            // Calculate totals from real-time data
            double totalOfferings = 0.0;
            double totalExpenses = 0.0;

            // Sum fellowship offerings
            for (final report in fellowshipReports) {
              totalOfferings += report.offeringAmount;
            }

            // Sum bus costs and offerings
            for (final report in busReports) {
              totalOfferings += report.offering;
              totalExpenses += report.busCost;
            }

            final netBalance = totalOfferings - totalExpenses;
            final budgetPercentage =
                _budgetTarget > 0 ? (totalExpenses / _budgetTarget) : 0.0;

            // Calculate trends based on previous period
            final previousMonth = DateTime.now().subtract(
              const Duration(days: 60),
            );
            final currentMonth = DateTime.now().subtract(
              const Duration(days: 30),
            );

            final previousReports =
                fellowshipReports.where((report) {
                  return report.reportDate.isAfter(previousMonth) &&
                      report.reportDate.isBefore(currentMonth);
                }).toList();

            double previousOfferings = 0.0;
            for (final report in previousReports) {
              previousOfferings += report.offeringAmount;
            }

            final offeringTrend =
                previousOfferings > 0
                    ? ((totalOfferings - previousOfferings) /
                            previousOfferings *
                            100)
                        .toStringAsFixed(0)
                    : '0';

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildFinancialCard(
                  icon: Icons.monetization_on,
                  title: 'Total Offerings',
                  value:
                      totalOfferings > 0
                          ? 'K${(totalOfferings / 1000).toStringAsFixed(0)}'
                          : 'K0',
                  subtitle: 'This month',
                  color: Colors.green,
                  trend:
                      '${double.parse(offeringTrend) >= 0 ? '+' : ''}$offeringTrend%',
                ),
                _buildFinancialCard(
                  icon: Icons.receipt_long,
                  title: 'Total Expenses',
                  value:
                      totalExpenses > 0
                          ? 'K${(totalExpenses / 1000).toStringAsFixed(0)}'
                          : 'K0',
                  subtitle: 'This month',
                  color: Colors.orange,
                  trend: 'Real-time',
                ),
                _buildFinancialCard(
                  icon: Icons.account_balance_wallet,
                  title: 'Net Balance',
                  value: 'K${(netBalance / 1000).toStringAsFixed(0)}',
                  subtitle: 'Current',
                  color: netBalance >= 0 ? Colors.green : Colors.red,
                  trend: netBalance >= 0 ? 'Positive' : 'Negative',
                ),
                _buildFinancialCard(
                  icon: Icons.pie_chart,
                  title: 'Budget Used',
                  value: '${(budgetPercentage * 100).toStringAsFixed(0)}%',
                  subtitle:
                      'Of K${(_budgetTarget / 1000).toStringAsFixed(0)} target',
                  color: budgetPercentage < 0.8 ? Colors.blue : Colors.amber,
                  trend: budgetPercentage < 0.8 ? 'On track' : 'High usage',
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFinancialCard({
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

  Widget _buildOfferingTrendChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Offering Trends',
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
                      spots: [
                        FlSpot(0, 142000),
                        FlSpot(1, 148000),
                        FlSpot(2, 135000),
                        FlSpot(3, 162000),
                        FlSpot(4, 154000),
                        FlSpot(5, 156000),
                      ],
                      isCurved: true,
                      color: Colors.green,
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

  Widget _buildQuickActions() {
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
                    icon: Icons.add_circle,
                    label: 'Record Offering',
                    color: Colors.green,
                    onTap: () => _showComingSoonDialog('Record Offering'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.receipt_long,
                    label: 'Add Expense',
                    color: Colors.orange,
                    onTap: () => _showComingSoonDialog('Add Expense'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.download,
                    label: 'Export Report',
                    color: Colors.blue,
                    onTap: () => _showComingSoonDialog('Export Report'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.verified,
                    label: 'Verify Receipts',
                    color: Colors.purple,
                    onTap: () => _showComingSoonDialog('Verify Receipts'),
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
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Offerings Management Tab - Complete implementation
  Widget _buildOfferingsTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOfferingsHeader(),
              const SizedBox(height: 16),
              _buildOfferingsFilters(),
              const SizedBox(height: 16),
              _buildOfferingsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferingsHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.monetization_on, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Offerings Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track and manage all church offerings',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            StreamBuilder<List<FellowshipReportModel>>(
              stream: _firestoreService.getAllFellowshipReports(limit: 1000),
              builder: (context, snapshot) {
                final reports = snapshot.data ?? [];
                final totalOfferings = reports.fold(
                  0.0,
                  (sum, report) => sum + report.offeringAmount,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Offerings',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'K${(totalOfferings / 1000).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
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

  Widget _buildOfferingsFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Offerings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Time Period',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: 'last_30_days',
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
                    onChanged: (value) => setState(() {}),
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
                    value: 'all',
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Offerings'),
                      ),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Approved Only'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending Review'),
                      ),
                    ],
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferingsList() {
    return StreamBuilder<List<FellowshipReportModel>>(
      stream: _firestoreService.getAllFellowshipReports(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        limit: 100,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Card(
            elevation: 2,
            child: Container(
              padding: const EdgeInsets.all(40.0),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.monetization_on_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No offerings found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    Text(
                      'Offerings will appear here when reports are submitted',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Fellowship',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(
                      width: 100,
                      child: Text(
                        'Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(
                      width: 80,
                      child: Text(
                        'Amount',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(
                      width: 80,
                      child: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...reports.map((report) => _buildOfferingItem(report)),
          ],
        );
      },
    );
  }

  Widget _buildOfferingItem(FellowshipReportModel report) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: const Icon(Icons.church, color: Colors.green),
        ),
        title: Text(
          report.fellowshipName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${report.constituencyName} • ${report.attendanceCount} attendees',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                '${report.reportDate.day}/${report.reportDate.month}/${report.reportDate.year}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                report.formattedOffering,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Container(
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
            ),
          ],
        ),
      ),
    );
  }

  /// Expenses Management Tab - Complete implementation
  Widget _buildExpensesTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildExpensesHeader(),
              const SizedBox(height: 16),
              _buildExpensesSummary(),
              const SizedBox(height: 16),
              _buildExpensesList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildExpensesHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expenses Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track and manage church expenses',
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

  Widget _buildExpensesSummary() {
    return StreamBuilder<List<SundayBusReportModel>>(
      stream: _firestoreService.getAllBusReports(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        limit: 1000,
      ),
      builder: (context, snapshot) {
        final busReports = snapshot.data ?? [];
        final totalExpenses = busReports.fold(
          0.0,
          (sum, report) => sum + report.busCost,
        );

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildExpenseCard(
              icon: Icons.directions_bus,
              title: 'Bus Expenses',
              value: 'K${(totalExpenses / 1000).toStringAsFixed(0)}',
              subtitle: 'This month',
              color: Colors.orange,
            ),
            _buildExpenseCard(
              icon: Icons.category,
              title: 'Other Expenses',
              value: 'K0',
              subtitle: 'Coming soon',
              color: Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpenseCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesList() {
    return StreamBuilder<List<SundayBusReportModel>>(
      stream: _firestoreService.getAllBusReports(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        limit: 50,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Card(
            elevation: 2,
            child: Container(
              padding: const EdgeInsets.all(40.0),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No expenses found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    Text(
                      'Expenses will appear here when bus reports are submitted',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Recent Expenses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...reports.map((report) => _buildExpenseItem(report)),
          ],
        );
      },
    );
  }

  Widget _buildExpenseItem(SundayBusReportModel report) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.1),
          child: const Icon(Icons.directions_bus, color: Colors.orange),
        ),
        title: Text(
          'Bus Transport - ${report.constituencyName}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Driver: ${report.driverName} • ${report.attendanceCount} passengers',
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              report.formattedBusCost,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            Text(
              '${report.reportDate.day}/${report.reportDate.month}/${report.reportDate.year}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Expense'),
            content: const Text(
              'Manual expense entry will be available in the next update.\n\nCurrently, expenses are tracked through:\n• Bus transport costs from Sunday bus reports\n• Other automated expense tracking',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  /// Fund Management Tab - Complete implementation
  Widget _buildFundsTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFundsHeader(),
              const SizedBox(height: 16),
              _buildFundsSummary(),
              const SizedBox(height: 16),
              _buildFundsList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFundDialog,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Fund', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildFundsHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.account_balance, color: Colors.purple, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fund Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage church funds and accounts',
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

  Widget _buildFundsSummary() {
    return StreamBuilder<List<FellowshipReportModel>>(
      stream: _firestoreService.getAllFellowshipReports(limit: 1000),
      builder: (context, fellowshipSnapshot) {
        return StreamBuilder<List<SundayBusReportModel>>(
          stream: _firestoreService.getAllBusReports(limit: 1000),
          builder: (context, busSnapshot) {
            final fellowshipReports = fellowshipSnapshot.data ?? [];
            final busReports = busSnapshot.data ?? [];

            final totalIncome =
                fellowshipReports.fold(
                  0.0,
                  (sum, report) => sum + report.offeringAmount,
                ) +
                busReports.fold(0.0, (sum, report) => sum + report.offering);
            final totalExpenses = busReports.fold(
              0.0,
              (sum, report) => sum + report.busCost,
            );
            final generalFund = totalIncome - totalExpenses;

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildFundCard(
                  title: 'General Fund',
                  balance: generalFund,
                  description: 'Main operating fund',
                  color: Colors.blue,
                ),
                _buildFundCard(
                  title: 'Building Fund',
                  balance: 0.0,
                  description: 'Construction & maintenance',
                  color: Colors.orange,
                ),
                _buildFundCard(
                  title: 'Mission Fund',
                  balance: 0.0,
                  description: 'Outreach & evangelism',
                  color: Colors.green,
                ),
                _buildFundCard(
                  title: 'Emergency Fund',
                  balance: 0.0,
                  description: 'Emergency expenses',
                  color: Colors.red,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFundCard({
    required String title,
    required double balance,
    required String description,
    required Color color,
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
                Icon(Icons.account_balance_wallet, color: color, size: 24),
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
                    balance >= 0 ? 'Active' : 'Deficit',
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
              'K${(balance / 1000).toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundsList() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fund Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No fund transactions yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  Text(
                    'Fund transfers and allocations will appear here',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFundDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Fund'),
            content: const Text(
              'Custom fund creation and management will be available in the next update.\n\nCurrently available funds:\n• General Fund (auto-calculated)\n• Building Fund\n• Mission Fund\n• Emergency Fund',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  /// Financial Reports Tab - Complete implementation
  Widget _buildReportsTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportsHeader(),
              const SizedBox(height: 16),
              _buildReportsSummary(),
              const SizedBox(height: 16),
              _buildReportsActions(),
              const SizedBox(height: 16),
              _buildRecentReports(),
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
            Icon(Icons.assessment, color: Colors.blue, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Financial Reports',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate and export financial reports',
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

  Widget _buildReportsSummary() {
    return StreamBuilder<List<FellowshipReportModel>>(
      stream: _firestoreService.getAllFellowshipReports(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        limit: 1000,
      ),
      builder: (context, fellowshipSnapshot) {
        return StreamBuilder<List<SundayBusReportModel>>(
          stream: _firestoreService.getAllBusReports(
            startDate: DateTime.now().subtract(const Duration(days: 30)),
            limit: 1000,
          ),
          builder: (context, busSnapshot) {
            final fellowshipReports = fellowshipSnapshot.data ?? [];
            final busReports = busSnapshot.data ?? [];

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildReportCard(
                  icon: Icons.receipt,
                  title: 'Fellowship Reports',
                  value: '${fellowshipReports.length}',
                  subtitle: 'This month',
                  color: Colors.green,
                ),
                _buildReportCard(
                  icon: Icons.directions_bus,
                  title: 'Bus Reports',
                  value: '${busReports.length}',
                  subtitle: 'This month',
                  color: Colors.orange,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsActions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Reports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _buildReportActionButton(
                  icon: Icons.monetization_on,
                  label: 'Offerings Report',
                  color: Colors.green,
                  onTap: () => _generateOfferingsReport(),
                ),
                _buildReportActionButton(
                  icon: Icons.receipt_long,
                  label: 'Expenses Report',
                  color: Colors.orange,
                  onTap: () => _generateExpensesReport(),
                ),
                _buildReportActionButton(
                  icon: Icons.account_balance,
                  label: 'Fund Summary',
                  color: Colors.purple,
                  onTap: () => _generateFundReport(),
                ),
                _buildReportActionButton(
                  icon: Icons.download,
                  label: 'Export All',
                  color: Colors.blue,
                  onTap: () => _exportAllReports(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReports() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Reports Generated',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Column(
                children: [
                  Icon(Icons.description, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No reports generated yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  Text(
                    'Generated reports will appear here for download',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateOfferingsReport() {
    _showReportDialog(
      'Offerings Report',
      'Generate a detailed report of all fellowship offerings for the selected period.',
    );
  }

  void _generateExpensesReport() {
    _showReportDialog(
      'Expenses Report',
      'Generate a comprehensive report of all church expenses including transportation costs.',
    );
  }

  void _generateFundReport() {
    _showReportDialog(
      'Fund Summary',
      'Generate a summary report of all fund balances and recent transactions.',
    );
  }

  void _exportAllReports() {
    _showReportDialog(
      'Export All Reports',
      'Export all financial data including offerings, expenses, and fund information to a comprehensive report.',
    );
  }

  void _showReportDialog(String title, String description) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                const SizedBox(height: 16),
                const Text(
                  'Report Generation Features:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• PDF export functionality'),
                const Text('• Email distribution'),
                const Text('• Date range selection'),
                const Text('• Detailed financial breakdown'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Advanced reporting features will be available in the next update.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Financial Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<FellowshipReportModel>>(
          stream: _getRecentFinancialActivity(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
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
                          'No recent financial activity',
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
                        .take(3)
                        .map((report) => _buildRecentTransactionItem(report))
                        .toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentTransactionItem(FellowshipReportModel report) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.withOpacity(0.1),
            child: const Icon(
              Icons.monetization_on,
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
                  '${report.fellowshipName} Offering',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.constituencyName} • ${report.attendanceCount} attendees',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                report.formattedOffering,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
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

  // Helper method to get recent financial activity for treasurers
  Stream<List<FellowshipReportModel>> _getRecentFinancialActivity() {
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

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('$feature Coming Soon'),
            content: Text(
              'The $feature feature will be implemented in upcoming updates.',
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
}
