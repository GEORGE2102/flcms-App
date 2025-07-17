import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conflict_model.dart';
import '../services/conflict_resolution_service.dart';
import '../utils/enums.dart';

/// Mobile-first dialog widget for manual conflict resolution
///
/// Provides mobile-optimized UI with swipe gestures, responsive design,
/// and intuitive touch interactions for conflict resolution.
class ConflictResolutionDialog extends StatefulWidget {
  final ConflictData conflict;
  final Function(Map<String, dynamic> resolvedData) onResolved;
  final String? resolvedBy;

  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    required this.onResolved,
    this.resolvedBy,
  });

  @override
  State<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();

  /// Show mobile-optimized conflict resolution dialog
  static Future<void> showMobileDialog({
    required BuildContext context,
    required ConflictData conflict,
    required Function(Map<String, dynamic> resolvedData) onResolved,
    String? resolvedBy,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    if (isSmallScreen) {
      // Use bottom sheet for small screens
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder:
            (context) => DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder:
                  (context, scrollController) => ConflictResolutionDialog(
                    conflict: conflict,
                    onResolved: onResolved,
                    resolvedBy: resolvedBy,
                  ),
            ),
      );
    } else {
      // Use dialog for larger screens
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => ConflictResolutionDialog(
              conflict: conflict,
              onResolved: onResolved,
              resolvedBy: resolvedBy,
            ),
      );
    }
  }
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog>
    with TickerProviderStateMixin {
  ConflictResolutionStrategy _selectedStrategy =
      ConflictResolutionStrategy.userChoice;
  Map<String, dynamic> _resolvedData = {};
  Map<String, String> _fieldChoices = {}; // 'local', 'remote', or 'custom'
  bool _isResolving = false;
  late TabController _tabController;
  PageController _pageController = PageController();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _selectedStrategy = widget.conflict.suggestedStrategy;
    _resolvedData = Map.from(widget.conflict.remoteData);
    _tabController = TabController(length: 3, vsync: this);
    _initializeFieldChoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _initializeFieldChoices() {
    for (final field in widget.conflict.localData.keys) {
      _fieldChoices[field] = 'remote'; // Default to remote data
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600 || screenSize.height < 700;
    final safeAreaPadding = MediaQuery.of(context).padding;

    if (isSmallScreen) {
      return _buildMobileLayout(safeAreaPadding);
    } else {
      return _buildTabletLayout();
    }
  }

  Widget _buildMobileLayout(EdgeInsets safeAreaPadding) {
    return Material(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildMobileHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentStep = page;
                  });
                },
                children: [
                  _buildConflictOverviewPage(),
                  _buildStrategySelectionPage(),
                  _buildDataResolutionPage(),
                ],
              ),
            ),
            _buildMobileNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            _buildTabletHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConflictOverviewPage(),
                  _buildStrategySelectionPage(),
                  _buildDataResolutionPage(),
                ],
              ),
            ),
            _buildTabletNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            widget.conflict.isCritical
                ? Colors.red.shade50
                : Colors.orange.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          bottom: BorderSide(
            color:
                widget.conflict.isCritical
                    ? Colors.red.shade200
                    : Colors.orange.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      widget.conflict.isCritical
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.conflict.isCritical
                      ? Icons.error_rounded
                      : Icons.warning_rounded,
                  color:
                      widget.conflict.isCritical
                          ? Colors.red.shade700
                          : Colors.orange.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Conflict',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.conflict.isCritical
                          ? 'Critical - Requires attention'
                          : 'Minor - Can be auto-resolved',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            widget.conflict.isCritical
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      isCompleted || isActive
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:
            widget.conflict.isCritical
                ? Colors.red.shade50
                : Colors.orange.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                widget.conflict.isCritical
                    ? Icons.error_rounded
                    : Icons.warning_rounded,
                color:
                    widget.conflict.isCritical
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Conflict Detected',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${widget.conflict.collection} - ${widget.conflict.documentId}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Strategy'),
              Tab(text: 'Resolution'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConflictOverviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conflict Information',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.info_rounded,
            title: 'Conflict Type',
            subtitle: widget.conflict.conflictType.name,
            color: Colors.blue,
          ),
          _buildInfoCard(
            icon: Icons.schedule_rounded,
            title: 'Detected',
            subtitle: _formatDateTime(widget.conflict.conflictDetectedAt),
            color: Colors.green,
          ),
          _buildInfoCard(
            icon: Icons.smartphone_rounded,
            title: 'Local Updated',
            subtitle: _formatDateTime(widget.conflict.localUpdatedAt),
            color: Colors.orange,
          ),
          _buildInfoCard(
            icon: Icons.cloud_rounded,
            title: 'Remote Updated',
            subtitle: _formatDateTime(widget.conflict.remoteUpdatedAt),
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildDataPreview(),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildDataPreview() {
    final conflictedFields =
        widget.conflict.localData.keys
            .where(
              (key) =>
                  widget.conflict.localData[key] !=
                  widget.conflict.remoteData[key],
            )
            .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.compare_arrows_rounded,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Conflicted Fields',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (conflictedFields.isEmpty)
              const Text('No conflicted fields detected')
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    conflictedFields
                        .map(
                          (field) => Chip(
                            label: Text(field),
                            backgroundColor: Colors.red.shade50,
                            side: BorderSide(color: Colors.red.shade200),
                          ),
                        )
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategySelectionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Resolution Strategy',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select how you want to resolve this conflict:',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          _buildStrategyCard(
            strategy: ConflictResolutionStrategy.keepLocal,
            title: 'Keep Local Version',
            description: 'Use your offline changes and discard server data',
            icon: Icons.smartphone_rounded,
            color: Colors.blue,
          ),
          _buildStrategyCard(
            strategy: ConflictResolutionStrategy.keepRemote,
            title: 'Keep Server Version',
            description: 'Use server data and discard your local changes',
            icon: Icons.cloud_rounded,
            color: Colors.green,
          ),
          _buildStrategyCard(
            strategy: ConflictResolutionStrategy.userChoice,
            title: 'Field-by-Field Selection',
            description: 'Choose the best data for each individual field',
            icon: Icons.tune_rounded,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyCard({
    required ConflictResolutionStrategy strategy,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedStrategy == strategy;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStrategy = strategy;
            _updateResolvedData();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border:
                isSelected
                    ? Border.all(color: color, width: 2)
                    : Border.all(color: Colors.grey.shade200),
            color: isSelected ? color.withOpacity(0.05) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataResolutionPage() {
    if (_selectedStrategy != ConflictResolutionStrategy.userChoice) {
      return _buildSimpleResolutionPreview();
    }
    return _buildFieldByFieldResolution();
  }

  Widget _buildSimpleResolutionPreview() {
    final isKeepingLocal =
        _selectedStrategy == ConflictResolutionStrategy.keepLocal;
    final dataToShow =
        isKeepingLocal ? widget.conflict.localData : widget.conflict.remoteData;
    final title =
        isKeepingLocal ? 'Local Data (Selected)' : 'Server Data (Selected)';
    final color = isKeepingLocal ? Colors.blue : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resolution Preview',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isKeepingLocal
                              ? Icons.smartphone_rounded
                              : Icons.cloud_rounded,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...dataToShow.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _formatFieldValue(entry.value),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldByFieldResolution() {
    final allFields =
        {
            ...widget.conflict.localData.keys,
            ...widget.conflict.remoteData.keys,
          }.toList()
          ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Field Selection',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Swipe left for local, right for server, or tap to choose',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allFields.length,
            itemBuilder: (context, index) {
              final field = allFields[index];
              return _buildSwipeableFieldCard(field);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeableFieldCard(String field) {
    final localValue = widget.conflict.localData[field];
    final remoteValue = widget.conflict.remoteData[field];
    final isConflicted = localValue != remoteValue;
    final selectedChoice = _fieldChoices[field] ?? 'remote';

    return Dismissible(
      key: Key('field_$field'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        final newChoice =
            direction == DismissDirection.startToEnd ? 'local' : 'remote';
        setState(() {
          _fieldChoices[field] = newChoice;
          _updateResolvedData();
        });
        return false; // Don't actually dismiss
      },
      background: Container(
        color: Colors.blue.shade100,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smartphone_rounded, color: Colors.blue.shade700),
            Text('Local', style: TextStyle(color: Colors.blue.shade700)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.green.shade100,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_rounded, color: Colors.green.shade700),
            Text('Server', style: TextStyle(color: Colors.green.shade700)),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: isConflicted ? 2 : 1,
        child: InkWell(
          onTap: () => _showFieldSelectionDialog(field),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border:
                  isConflicted
                      ? Border.all(color: Colors.orange.shade300, width: 1)
                      : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        field,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isConflicted
                                  ? Colors.orange.shade800
                                  : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (isConflicted)
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.orange.shade600,
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selectedChoice == 'local'
                                ? Colors.blue.shade100
                                : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selectedChoice == 'local'
                                ? Icons.smartphone_rounded
                                : Icons.cloud_rounded,
                            size: 12,
                            color:
                                selectedChoice == 'local'
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            selectedChoice == 'local' ? 'Local' : 'Server',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  selectedChoice == 'local'
                                      ? Colors.blue.shade700
                                      : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Local',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatFieldValue(localValue),
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    selectedChoice == 'local'
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Server',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatFieldValue(remoteValue),
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    selectedChoice == 'remote'
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFieldSelectionDialog(String field) {
    final localValue = widget.conflict.localData[field];
    final remoteValue = widget.conflict.remoteData[field];
    final currentChoice = _fieldChoices[field] ?? 'remote';

    showModalBottomSheet<void>(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select value for "$field"',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildValueOption(
                  'Local Version',
                  localValue,
                  'local',
                  currentChoice,
                  Icons.smartphone_rounded,
                  Colors.blue,
                  (value) {
                    setState(() {
                      _fieldChoices[field] = value;
                      _updateResolvedData();
                    });
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                _buildValueOption(
                  'Server Version',
                  remoteValue,
                  'remote',
                  currentChoice,
                  Icons.cloud_rounded,
                  Colors.green,
                  (value) {
                    setState(() {
                      _fieldChoices[field] = value;
                      _updateResolvedData();
                    });
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildValueOption(
    String title,
    dynamic value,
    String optionValue,
    String currentChoice,
    IconData icon,
    Color color,
    Function(String) onSelected,
  ) {
    final isSelected = currentChoice == optionValue;
    return InkWell(
      onTap: () => onSelected(optionValue),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? color.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFieldValue(value),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep > 0 ? 2 : 1,
              child:
                  _currentStep < 2
                      ? ElevatedButton.icon(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('Next'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                      : ElevatedButton.icon(
                        onPressed: _isResolving ? null : _resolveConflict,
                        icon:
                            _isResolving
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.check_rounded),
                        label: const Text('Resolve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletNavigation() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Row(
            children: [
              if (_selectedStrategy == ConflictResolutionStrategy.userChoice)
                TextButton(
                  onPressed: _resetToDefaults,
                  child: const Text('Reset'),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isResolving ? null : _resolveConflict,
                child:
                    _isResolving
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Resolve Conflict'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateResolvedData() {
    switch (_selectedStrategy) {
      case ConflictResolutionStrategy.keepLocal:
        _resolvedData = Map.from(widget.conflict.localData);
        break;
      case ConflictResolutionStrategy.keepRemote:
        _resolvedData = Map.from(widget.conflict.remoteData);
        break;
      case ConflictResolutionStrategy.userChoice:
        _resolvedData = {};
        for (final field in _fieldChoices.keys) {
          final choice = _fieldChoices[field];
          if (choice == 'local') {
            _resolvedData[field] = widget.conflict.localData[field];
          } else {
            _resolvedData[field] = widget.conflict.remoteData[field];
          }
        }
        break;
      default:
        _resolvedData = Map.from(widget.conflict.remoteData);
    }
  }

  void _resetToDefaults() {
    setState(() {
      _initializeFieldChoices();
      _updateResolvedData();
    });
  }

  Future<void> _resolveConflict() async {
    setState(() {
      _isResolving = true;
    });

    try {
      final conflictService = Provider.of<ConflictResolutionService>(
        context,
        listen: false,
      );

      await conflictService.resolveConflict(
        widget.conflict,
        _selectedStrategy,
        userChoiceData: _resolvedData,
        resolvedBy: widget.resolvedBy ?? 'user',
      );

      widget.onResolved(_resolvedData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conflict resolved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resolving conflict: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  String _formatFieldValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is bool) return value.toString();
    if (value is List) return '[${value.length} items]';
    if (value is Map) return '{${value.length} fields}';
    return value.toString();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
