import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conflict_model.dart';
import '../services/conflict_resolution_service.dart';
import 'conflict_resolution_dialog.dart';

/// Widget that displays conflict notifications and provides quick access to resolution
class ConflictNotificationWidget extends StatelessWidget {
  final bool showMinimized;
  final EdgeInsets? margin;

  const ConflictNotificationWidget({
    super.key,
    this.showMinimized = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConflictResolutionService>(
      builder: (context, conflictService, child) {
        if (!conflictService.hasConflicts) {
          return const SizedBox.shrink();
        }

        final criticalConflicts =
            conflictService.activeConflicts.where((c) => c.isCritical).length;
        final totalConflicts = conflictService.conflictCount;

        if (showMinimized) {
          return _buildMinimizedNotification(
            context,
            totalConflicts,
            criticalConflicts,
            conflictService,
          );
        }

        return _buildFullNotification(
          context,
          totalConflicts,
          criticalConflicts,
          conflictService,
        );
      },
    );
  }

  Widget _buildMinimizedNotification(
    BuildContext context,
    int totalConflicts,
    int criticalConflicts,
    ConflictResolutionService conflictService,
  ) {
    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      child: Material(
        color: criticalConflicts > 0 ? Colors.red[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showConflictsList(context, conflictService),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  criticalConflicts > 0 ? Icons.error : Icons.warning,
                  color: criticalConflicts > 0 ? Colors.red : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$totalConflicts conflict${totalConflicts != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        criticalConflicts > 0
                            ? Colors.red[700]
                            : Colors.orange[700],
                  ),
                ),
                if (criticalConflicts > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$criticalConflicts critical',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullNotification(
    BuildContext context,
    int totalConflicts,
    int criticalConflicts,
    ConflictResolutionService conflictService,
  ) {
    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      child: Card(
        color: criticalConflicts > 0 ? Colors.red[50] : Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    criticalConflicts > 0 ? Icons.error : Icons.warning,
                    color: criticalConflicts > 0 ? Colors.red : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          criticalConflicts > 0
                              ? 'Critical Data Conflicts Detected'
                              : 'Data Conflicts Detected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color:
                                criticalConflicts > 0
                                    ? Colors.red[700]
                                    : Colors.orange[700],
                          ),
                        ),
                        Text(
                          _buildConflictSummary(
                            totalConflicts,
                            criticalConflicts,
                          ),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        () => _showConflictsList(context, conflictService),
                    icon: const Icon(Icons.list),
                    tooltip: 'View all conflicts',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (criticalConflicts > 0) ...[
                Text(
                  'Critical conflicts require immediate attention to ensure data integrity.',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed:
                        () => _showConflictsList(context, conflictService),
                    icon: const Icon(Icons.list),
                    label: const Text('View All Conflicts'),
                  ),
                  if (criticalConflicts > 0)
                    ElevatedButton.icon(
                      onPressed:
                          () => _resolveNextCriticalConflict(
                            context,
                            conflictService,
                          ),
                      icon: const Icon(Icons.priority_high),
                      label: const Text('Resolve Critical'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed:
                          () => _resolveNextConflict(context, conflictService),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Resolve Next'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildConflictSummary(int totalConflicts, int criticalConflicts) {
    if (criticalConflicts > 0) {
      return '$totalConflicts total conflicts ($criticalConflicts critical, ${totalConflicts - criticalConflicts} minor)';
    }
    return '$totalConflicts conflict${totalConflicts != 1 ? 's' : ''} need${totalConflicts == 1 ? 's' : ''} resolution';
  }

  void _showConflictsList(
    BuildContext context,
    ConflictResolutionService conflictService,
  ) {
    showDialog(
      context: context,
      builder:
          (context) =>
              ConflictsListDialog(conflicts: conflictService.activeConflicts),
    );
  }

  void _resolveNextCriticalConflict(
    BuildContext context,
    ConflictResolutionService conflictService,
  ) {
    final criticalConflict =
        conflictService.activeConflicts.where((c) => c.isCritical).first;

    _showConflictResolutionDialog(context, criticalConflict);
  }

  void _resolveNextConflict(
    BuildContext context,
    ConflictResolutionService conflictService,
  ) {
    final nextConflict = conflictService.activeConflicts.first;
    _showConflictResolutionDialog(context, nextConflict);
  }

  void _showConflictResolutionDialog(
    BuildContext context,
    ConflictData conflict,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => ConflictResolutionDialog(
            conflict: conflict,
            onResolved: (resolvedData) {
              // Conflict resolution handled by the dialog
            },
          ),
    );
  }
}

/// Dialog that shows a list of all active conflicts
class ConflictsListDialog extends StatelessWidget {
  final List<ConflictData> conflicts;

  const ConflictsListDialog({super.key, required this.conflicts});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Conflicts',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${conflicts.length} conflict${conflicts.length != 1 ? 's' : ''} require attention',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: conflicts.length,
                itemBuilder: (context, index) {
                  final conflict = conflicts[index];
                  return _buildConflictListItem(context, conflict);
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictListItem(BuildContext context, ConflictData conflict) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          conflict.isCritical ? Icons.error : Icons.warning,
          color: conflict.isCritical ? Colors.red : Colors.orange,
        ),
        title: Text(
          '${conflict.collection} - ${conflict.documentId}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${conflict.conflictType}'),
            Text(
              'Detected: ${_formatDateTime(conflict.conflictDetectedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (conflict.isCritical)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'CRITICAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close list dialog
                _showConflictResolutionDialog(context, conflict);
              },
              child: const Text('Resolve'),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showConflictResolutionDialog(
    BuildContext context,
    ConflictData conflict,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => ConflictResolutionDialog(
            conflict: conflict,
            onResolved: (resolvedData) {
              // Conflict resolution handled by the dialog
            },
          ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
