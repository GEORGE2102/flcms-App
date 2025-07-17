import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/report_service.dart';
import '../models/user_model.dart';

/// Advanced filter widget for report history screen
class ReportFilterWidget extends StatefulWidget {
  final ReportFilters initialFilters;
  final Function(ReportFilters) onFiltersChanged;
  final VoidCallback onClose;
  final UserModel currentUser;

  const ReportFilterWidget({
    super.key,
    required this.initialFilters,
    required this.onFiltersChanged,
    required this.onClose,
    required this.currentUser,
  });

  @override
  State<ReportFilterWidget> createState() => _ReportFilterWidgetState();
}

class _ReportFilterWidgetState extends State<ReportFilterWidget> {
  late ReportFilters _currentFilters;

  // Filter controllers
  RangeValues _amountRange = const RangeValues(0, 10000);

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.initialFilters;
    _initializeFilters();
  }

  void _initializeFilters() {
    double minAmount = _currentFilters.minAmount ?? 0;
    double maxAmount = _currentFilters.maxAmount ?? 10000;
    _amountRange = RangeValues(minAmount, maxAmount);
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
      case 'quarter':
        final currentQuarter = (now.month - 1) ~/ 3;
        startDate = DateTime(now.year, currentQuarter * 3 + 1, 1);
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

  void _resetFilters() {
    setState(() {
      _currentFilters = ReportFilters();
      _amountRange = const RangeValues(0, 10000);
    });
  }

  void _applyFilters() {
    final finalFilters = _currentFilters.copyWith(
      minAmount: _amountRange.start > 0 ? _amountRange.start : null,
      maxAmount: _amountRange.end < 10000 ? _amountRange.end : null,
    );

    widget.onFiltersChanged(finalFilters);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
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
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
            onPressed: widget.onClose,
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
            _buildQuickFilterChip('This Quarter', 'quarter'),
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
          values: _amountRange,
          min: 0,
          max: 10000,
          divisions: 100,
          labels: RangeLabels(
            'ZMW ${_amountRange.start.round()}',
            'ZMW ${_amountRange.end.round()}',
          ),
          onChanged: (values) {
            setState(() {
              _amountRange = values;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ZMW ${_amountRange.start.round()}',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'ZMW ${_amountRange.end.round()}',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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

  Widget _buildActionButtons() {
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
              onPressed: _resetFilters,
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
              onPressed: _applyFilters,
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
