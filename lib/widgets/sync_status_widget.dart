import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';
import '../services/conflict_resolution_service.dart';
import 'conflict_notification_widget.dart';

/// Mobile-first sync status widget with touch-friendly controls
class MobileSyncStatusWidget extends StatefulWidget {
  final bool showCompact;
  final VoidCallback? onSyncRequested;
  final VoidCallback? onViewDetails;

  const MobileSyncStatusWidget({
    super.key,
    this.showCompact = false,
    this.onSyncRequested,
    this.onViewDetails,
  });

  @override
  State<MobileSyncStatusWidget> createState() => _MobileSyncStatusWidgetState();
}

class _MobileSyncStatusWidgetState extends State<MobileSyncStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _startPulseAnimation() {
    _pulseController.repeat(reverse: true);
  }

  void _stopPulseAnimation() {
    _pulseController.stop();
    _pulseController.reset();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SyncService, ConflictResolutionService>(
      builder: (context, syncService, conflictService, child) {
        // Start/stop pulse animation based on sync status
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (syncService.isSyncing) {
            _startPulseAnimation();
          } else {
            _stopPulseAnimation();
          }
        });

        if (widget.showCompact) {
          return _buildCompactView(syncService, conflictService);
        }

        return _buildFullView(syncService, conflictService);
      },
    );
  }

  Widget _buildCompactView(
    SyncService syncService,
    ConflictResolutionService conflictService,
  ) {
    if (syncService.isOnline &&
        !syncService.hasPendingActions &&
        !conflictService.hasConflicts) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return GestureDetector(
      onTap: _toggleExpanded,
      onLongPress: () => _showSyncActionSheet(context, syncService),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: syncService.isSyncing ? _pulseAnimation.value : 1.0,
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 12,
                vertical: isSmallScreen ? 4 : 6,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 12,
                vertical: isSmallScreen ? 6 : 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getStatusColors(syncService, conflictService),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusIcon(syncService, conflictService, isSmallScreen),
                  if (syncService.hasPendingActions ||
                      conflictService.hasConflicts) ...[
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    _buildStatusBadge(
                      syncService,
                      conflictService,
                      isSmallScreen,
                    ),
                  ],
                  if (!syncService.isOnline &&
                      !syncService.hasPendingActions) ...[
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 11,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullView(
    SyncService syncService,
    ConflictResolutionService conflictService,
  ) {
    if (syncService.isOnline &&
        !syncService.hasPendingActions &&
        !conflictService.hasConflicts) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Column(
      children: [
        // Main status indicator
        GestureDetector(
          onTap: _toggleExpanded,
          onLongPress: () => _showSyncActionSheet(context, syncService),
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12,
              vertical: isSmallScreen ? 4 : 6,
            ),
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getStatusColors(syncService, conflictService),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale:
                          syncService.isSyncing ? _pulseAnimation.value : 1.0,
                      child: _buildStatusIcon(
                        syncService,
                        conflictService,
                        isSmallScreen,
                      ),
                    );
                  },
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(syncService, conflictService),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _getTextColor(syncService, conflictService),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getStatusSubtitle(syncService, conflictService),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getTextColor(
                            syncService,
                            conflictService,
                          ).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (syncService.hasPendingActions)
                      _buildStatusBadge(
                        syncService,
                        conflictService,
                        isSmallScreen,
                      ),
                    if (conflictService.hasConflicts) ...[
                      if (syncService.hasPendingActions)
                        const SizedBox(width: 6),
                      _buildConflictBadge(conflictService, isSmallScreen),
                    ],
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Icon(
                      _isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: _getTextColor(syncService, conflictService),
                      size: isSmallScreen ? 16 : 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Expanded details
        SlideTransition(
          position: _slideAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isExpanded ? null : 0,
            child:
                _isExpanded
                    ? _buildExpandedDetails(syncService, conflictService)
                    : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(
    SyncService syncService,
    ConflictResolutionService conflictService,
    bool isSmallScreen,
  ) {
    IconData iconData;
    Color iconColor;

    if (conflictService.hasConflicts) {
      iconData = Icons.warning_rounded;
      iconColor = Colors.orange.shade700;
    } else if (syncService.isSyncing) {
      iconData = Icons.sync_rounded;
      iconColor = Colors.blue.shade700;
    } else if (!syncService.isOnline) {
      iconData = Icons.cloud_off_rounded;
      iconColor = Colors.red.shade700;
    } else if (syncService.hasPendingActions) {
      iconData = Icons.upload_rounded;
      iconColor = Colors.orange.shade700;
    } else {
      iconData = Icons.check_circle_rounded;
      iconColor = Colors.green.shade700;
    }

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child:
          syncService.isSyncing
              ? SizedBox(
                width: isSmallScreen ? 16 : 18,
                height: isSmallScreen ? 16 : 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
              : Icon(iconData, size: isSmallScreen ? 16 : 18, color: iconColor),
    );
  }

  Widget _buildStatusBadge(
    SyncService syncService,
    ConflictResolutionService conflictService,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 4 : 6,
        vertical: isSmallScreen ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _getBadgeColor(syncService, conflictService),
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
      ),
      child: Text(
        '${syncService.pendingActionsCount}',
        style: TextStyle(
          fontSize: isSmallScreen ? 9 : 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildConflictBadge(
    ConflictResolutionService conflictService,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 4 : 6,
        vertical: isSmallScreen ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_rounded,
            size: isSmallScreen ? 8 : 9,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            '${conflictService.conflictCount}',
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(
    SyncService syncService,
    ConflictResolutionService conflictService,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12),
      child: Column(
        children: [
          // Conflict notification
          if (conflictService.hasConflicts)
            ConflictNotificationWidget(
              showMinimized: true,
              margin: const EdgeInsets.only(bottom: 8),
            ),
          // Action buttons
          if (!syncService.isSyncing)
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  if (syncService.isOnline && syncService.hasPendingActions)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            widget.onSyncRequested ??
                            () => _performManualSync(syncService),
                        icon: const Icon(Icons.sync_rounded, size: 16),
                        label: const Text('Sync Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 8 : 10,
                          ),
                        ),
                      ),
                    ),
                  if (syncService.isOnline && syncService.hasPendingActions)
                    const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          widget.onViewDetails ??
                          () => _showSyncDetails(
                            context,
                            syncService,
                            conflictService,
                          ),
                      icon: const Icon(Icons.info_outline_rounded, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 8 : 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Color> _getStatusColors(
    SyncService syncService,
    ConflictResolutionService conflictService,
  ) {
    if (conflictService.hasConflicts) {
      return [Colors.red.shade50, Colors.red.shade100];
    } else if (syncService.isSyncing) {
      return [Colors.blue.shade50, Colors.blue.shade100];
    } else if (!syncService.isOnline) {
      return [Colors.grey.shade50, Colors.grey.shade100];
    } else if (syncService.hasPendingActions) {
      return [Colors.orange.shade50, Colors.orange.shade100];
    } else {
      return [Colors.green.shade50, Colors.green.shade100];
    }
  }

  Color _getTextColor(
    SyncService syncService,
    ConflictResolutionService conflictService,
  ) {
    if (conflictService.hasConflicts) {
      return Colors.red.shade800;
    } else if (syncService.isSyncing) {
      return Colors.blue.shade800;
    } else if (!syncService.isOnline) {
      return Colors.grey.shade700;
    } else if (syncService.hasPendingActions) {
      return Colors.orange.shade800;
    } else {
      return Colors.green.shade800;
    }
  }

  Color _getBadgeColor(
    SyncService syncService,
    ConflictResolutionService conflictService,
  ) {
    if (conflictService.hasConflicts) {
      return Colors.red.shade600;
    } else if (syncService.isSyncing) {
      return Colors.blue.shade600;
    } else if (!syncService.isOnline) {
      return Colors.grey.shade600;
    } else {
      return Colors.orange.shade600;
    }
  }

  String _getStatusTitle(
    SyncService syncService,
    ConflictResolutionService conflictService,
  ) {
    if (conflictService.hasConflicts) {
      return 'Conflicts Detected';
    } else if (syncService.isSyncing) {
      return 'Syncing Data';
    } else if (!syncService.isOnline) {
      return 'Working Offline';
    } else if (syncService.hasPendingActions) {
      return 'Ready to Sync';
    } else {
      return 'All Synced';
    }
  }

  String _getStatusSubtitle(
    SyncService syncService,
    ConflictResolutionService conflictService,
  ) {
    if (conflictService.hasConflicts) {
      return '${conflictService.conflictCount} conflict${conflictService.conflictCount > 1 ? 's' : ''} need${conflictService.conflictCount == 1 ? 's' : ''} resolution';
    } else if (syncService.isSyncing) {
      return 'Uploading ${syncService.pendingActionsCount} action${syncService.pendingActionsCount > 1 ? 's' : ''}';
    } else if (!syncService.isOnline) {
      if (syncService.hasPendingActions) {
        return 'Using cached data • ${syncService.pendingActionsCount} action${syncService.pendingActionsCount > 1 ? 's' : ''} pending';
      } else {
        return 'Using cached data';
      }
    } else if (syncService.hasPendingActions) {
      return '${syncService.pendingActionsCount} action${syncService.pendingActionsCount > 1 ? 's' : ''} ready to upload';
    } else {
      return 'All data synchronized';
    }
  }

  void _showSyncActionSheet(BuildContext context, SyncService syncService) {
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
                  'Sync Actions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (syncService.isOnline && syncService.hasPendingActions)
                  ListTile(
                    leading: const Icon(Icons.sync_rounded),
                    title: const Text('Sync Now'),
                    subtitle: Text(
                      'Upload ${syncService.pendingActionsCount} pending actions',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _performManualSync(syncService);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('View Details'),
                  subtitle: const Text('See sync status and pending actions'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSyncDetails(
                      context,
                      syncService,
                      Provider.of<ConflictResolutionService>(
                        context,
                        listen: false,
                      ),
                    );
                  },
                ),
                if (syncService.hasPendingActions)
                  ListTile(
                    leading: const Icon(Icons.clear_all_rounded),
                    title: const Text('Clear Pending'),
                    subtitle: const Text('Remove all pending sync actions'),
                    onTap: () {
                      Navigator.pop(context);
                      _showClearPendingDialog(context, syncService);
                    },
                  ),
              ],
            ),
          ),
    );
  }

  void _performManualSync(SyncService syncService) {
    if (widget.onSyncRequested != null) {
      widget.onSyncRequested!();
    } else {
      syncService.forcSync();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Manual sync started'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSyncDetails(
    BuildContext context,
    SyncService syncService,
    ConflictResolutionService conflictService,
  ) {
    if (widget.onViewDetails != null) {
      widget.onViewDetails!();
    } else {
      showDialog<void>(
        context: context,
        builder:
            (context) => SyncDetailsDialog(
              syncService: syncService,
              conflictService: conflictService,
            ),
      );
    }
  }

  void _showClearPendingDialog(BuildContext context, SyncService syncService) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Pending Actions'),
            content: Text(
              'Are you sure you want to clear ${syncService.pendingActionsCount} pending sync actions? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  syncService.clearPendingActions();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pending actions cleared'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }
}

/// Dialog showing detailed sync information
class SyncDetailsDialog extends StatelessWidget {
  final SyncService syncService;
  final ConflictResolutionService conflictService;

  const SyncDetailsDialog({
    super.key,
    required this.syncService,
    required this.conflictService,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_rounded, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Sync Status Details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailItem(
              'Connection Status',
              syncService.isOnline ? 'Online' : 'Offline',
              syncService.isOnline
                  ? Icons.cloud_rounded
                  : Icons.cloud_off_rounded,
              syncService.isOnline ? Colors.green : Colors.red,
            ),
            _buildDetailItem(
              'Sync Status',
              syncService.isSyncing ? 'Syncing' : 'Idle',
              syncService.isSyncing
                  ? Icons.sync_rounded
                  : Icons.check_circle_rounded,
              syncService.isSyncing ? Colors.blue : Colors.green,
            ),
            _buildDetailItem(
              'Pending Actions',
              '${syncService.pendingActionsCount}',
              Icons.upload_rounded,
              syncService.hasPendingActions ? Colors.orange : Colors.green,
            ),
            _buildDetailItem(
              'Active Conflicts',
              '${conflictService.conflictCount}',
              Icons.warning_rounded,
              conflictService.hasConflicts ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
