import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';

/// Mobile-first widget that shows offline status and pending sync actions
class OfflineIndicator extends StatefulWidget {
  final bool isOnline;
  final int pendingActions;
  final bool isSyncing;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const OfflineIndicator({
    super.key,
    required this.isOnline,
    required this.pendingActions,
    required this.isSyncing,
    this.onTap,
    this.onDismiss,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    if (widget.onDismiss != null) {
      setState(() {
        _isDismissed = true;
      });
      _animationController.reverse().then((_) {
        widget.onDismiss!();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed || (widget.isOnline && widget.pendingActions == 0)) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Dismissible(
              key: const Key('offline_indicator'),
              direction: DismissDirection.up,
              onDismissed: (_) => _handleDismiss(),
              child: Material(
                elevation: 2,
                child: InkWell(
                  onTap: widget.onTap,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            widget.isOnline
                                ? [
                                  Colors.orange.shade50,
                                  Colors.orange.shade100,
                                ]
                                : [Colors.red.shade50, Colors.red.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color:
                              widget.isOnline
                                  ? Colors.orange.shade300
                                  : Colors.red.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
      decoration: BoxDecoration(
        color: widget.isOnline ? Colors.orange.shade200 : Colors.red.shade200,
        shape: BoxShape.circle,
      ),
      child:
          widget.isSyncing
              ? SizedBox(
                width: isSmallScreen ? 16 : 18,
                height: isSmallScreen ? 16 : 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isOnline
                        ? Colors.orange.shade700
                        : Colors.red.shade700,
                  ),
                ),
              )
              : Icon(
                widget.isOnline ? Icons.sync_rounded : Icons.cloud_off_rounded,
                size: isSmallScreen ? 16 : 18,
                color:
                    widget.isOnline
                        ? Colors.orange.shade700
                        : Colors.red.shade700,
              ),
    );
  }

  Widget _buildActionButton(bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.pendingActions > 0)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 6 : 8,
                vertical: isSmallScreen ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color:
                    widget.isOnline
                        ? Colors.orange.shade600
                        : Colors.red.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.pendingActions}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 10 : 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (widget.onTap != null) ...[
            SizedBox(width: isSmallScreen ? 6 : 8),
            Icon(
              Icons.chevron_right_rounded,
              size: isSmallScreen ? 16 : 18,
              color:
                  widget.isOnline
                      ? Colors.orange.shade600
                      : Colors.red.shade600,
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusTitle() {
    if (!widget.isOnline) {
      return 'Working Offline';
    } else if (widget.isSyncing) {
      return 'Syncing Data';
    } else if (widget.pendingActions > 0) {
      return 'Ready to Sync';
    } else {
      return 'All Synced';
    }
  }

  String _getStatusSubtitle() {
    if (!widget.isOnline) {
      if (widget.pendingActions > 0) {
        return '${widget.pendingActions} action${widget.pendingActions > 1 ? 's' : ''} pending';
      } else {
        return 'Using cached data';
      }
    } else if (widget.isSyncing) {
      return 'Uploading ${widget.pendingActions} action${widget.pendingActions > 1 ? 's' : ''}';
    } else if (widget.pendingActions > 0) {
      return 'Tap to sync now';
    }
    return '';
  }
}

/// Mobile-optimized compact version for use in app bars
class CompactOfflineIndicator extends StatelessWidget {
  final VoidCallback? onTap;

  const CompactOfflineIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, syncService, child) {
        if (syncService.isOnline && !syncService.hasPendingActions) {
          return const SizedBox.shrink();
        }

        final isSmallScreen = MediaQuery.of(context).size.width < 400;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: EdgeInsets.only(right: isSmallScreen ? 6 : 8),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 6 : 8,
              vertical: isSmallScreen ? 3 : 4,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    syncService.isOnline
                        ? [
                          Colors.orange.withOpacity(0.15),
                          Colors.orange.withOpacity(0.25),
                        ]
                        : [
                          Colors.red.withOpacity(0.15),
                          Colors.red.withOpacity(0.25),
                        ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              border: Border.all(
                color:
                    syncService.isOnline
                        ? Colors.orange.shade400
                        : Colors.red.shade400,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (syncService.isSyncing)
                  SizedBox(
                    width: isSmallScreen ? 12 : 14,
                    height: isSmallScreen ? 12 : 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        syncService.isOnline
                            ? Colors.orange.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  )
                else
                  Icon(
                    syncService.isOnline
                        ? Icons.sync_rounded
                        : Icons.cloud_off_rounded,
                    size: isSmallScreen ? 12 : 14,
                    color:
                        syncService.isOnline
                            ? Colors.orange.shade700
                            : Colors.red.shade700,
                  ),
                if (syncService.hasPendingActions) ...[
                  SizedBox(width: isSmallScreen ? 3 : 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 4 : 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color:
                          syncService.isOnline
                              ? Colors.orange.shade600
                              : Colors.red.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${syncService.pendingActionsCount}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 9 : 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else if (!syncService.isOnline) ...[
                  SizedBox(width: isSmallScreen ? 3 : 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 9 : 10,
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
    );
  }
}

/// Mobile-optimized full-width sync status banner
class SyncStatusBanner extends StatelessWidget {
  final VoidCallback? onManualSync;
  final VoidCallback? onViewDetails;

  const SyncStatusBanner({super.key, this.onManualSync, this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, syncService, child) {
        if (syncService.isOnline && !syncService.hasPendingActions) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final isSmallScreen = MediaQuery.of(context).size.width < 400;

        return Container(
          width: double.infinity,
          margin: EdgeInsets.all(isSmallScreen ? 8 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  syncService.isOnline
                      ? [Colors.orange.shade50, Colors.orange.shade100]
                      : [Colors.red.shade50, Colors.red.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
            border: Border.all(
              color:
                  syncService.isOnline
                      ? Colors.orange.shade300
                      : Colors.red.shade300,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                      decoration: BoxDecoration(
                        color:
                            syncService.isOnline
                                ? Colors.orange.shade200
                                : Colors.red.shade200,
                        shape: BoxShape.circle,
                      ),
                      child:
                          syncService.isSyncing
                              ? SizedBox(
                                width: isSmallScreen ? 16 : 18,
                                height: isSmallScreen ? 16 : 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    syncService.isOnline
                                        ? Colors.orange.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              )
                              : Icon(
                                syncService.isOnline
                                    ? Icons.sync_rounded
                                    : Icons.cloud_off_rounded,
                                size: isSmallScreen ? 16 : 18,
                                color:
                                    syncService.isOnline
                                        ? Colors.orange.shade700
                                        : Colors.red.shade700,
                              ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            syncService.isOnline
                                ? (syncService.isSyncing
                                    ? 'Syncing Data'
                                    : 'Ready to Sync')
                                : 'Working Offline',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color:
                                  syncService.isOnline
                                      ? Colors.orange.shade800
                                      : Colors.red.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            syncService.isOnline
                                ? (syncService.isSyncing
                                    ? 'Uploading ${syncService.pendingActionsCount} pending actions'
                                    : '${syncService.pendingActionsCount} actions ready to upload')
                                : 'Using cached data • ${syncService.pendingActionsCount} actions pending',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  syncService.isOnline
                                      ? Colors.orange.shade700
                                      : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!syncService.isSyncing &&
                    (onManualSync != null || onViewDetails != null)) ...[
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  Row(
                    children: [
                      if (onManualSync != null &&
                          syncService.isOnline &&
                          syncService.hasPendingActions)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onManualSync,
                            icon: const Icon(Icons.sync_rounded, size: 16),
                            label: const Text('Sync Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 8 : 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      if (onViewDetails != null) ...[
                        if (onManualSync != null) const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onViewDetails,
                            icon: const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                            ),
                            label: const Text('Details'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  syncService.isOnline
                                      ? Colors.orange.shade700
                                      : Colors.red.shade700,
                              side: BorderSide(
                                color:
                                    syncService.isOnline
                                        ? Colors.orange.shade400
                                        : Colors.red.shade400,
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 8 : 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
