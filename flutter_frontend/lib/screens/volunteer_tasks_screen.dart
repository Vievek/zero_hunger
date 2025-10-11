import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/logistics_provider.dart';

class VolunteerTasksScreen extends StatefulWidget {
  const VolunteerTasksScreen({super.key});

  @override
  State<VolunteerTasksScreen> createState() => _VolunteerTasksScreenState();
}

class _VolunteerTasksScreenState extends State<VolunteerTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LogisticsProvider>(context, listen: false).fetchMyTasks();
      Provider.of<LogisticsProvider>(context, listen: false)
          .fetchVolunteerStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final logisticsProvider = Provider.of<LogisticsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Delivery Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              logisticsProvider.fetchMyTasks();
              logisticsProvider.fetchVolunteerStats();
            },
          ),
        ],
      ),
      body: logisticsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTasksContent(logisticsProvider),
    );
  }

  Widget _buildTasksContent(LogisticsProvider provider) {
    if (provider.tasks.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchMyTasks();
        await provider.fetchVolunteerStats();
      },
      child: Column(
        children: [
          // Stats Overview
          _buildStatsCard(provider),

          // Tasks List
          Expanded(
            child: ListView.builder(
              itemCount: provider.tasks.length,
              itemBuilder: (context, index) {
                final task = provider.tasks[index];
                return _buildTaskCard(task, provider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'No Tasks Assigned',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tasks will appear here when you\'re assigned deliveries',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Provider.of<LogisticsProvider>(context, listen: false)
                  .fetchMyTasks();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(LogisticsProvider provider) {
    final stats = provider.volunteerStats;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total', stats['totalTasks'] ?? 0, Icons.assignment,
                Colors.blue),
            _buildStatItem('Completed', stats['completedTasks'] ?? 0,
                Icons.check_circle, Colors.green),
            _buildStatItem('Rating', (stats['averageRating'] ?? 0.0).toDouble(),
                Icons.star, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, dynamic value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value is double ? value.toStringAsFixed(1) : value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTaskCard(dynamic task, LogisticsProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getStatusIcon(task.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Task #${task.id?.substring(0, 8) ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _getStatusChip(task.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildTaskInfo(
                '📍 Pickup', task.pickupLocation['address'] ?? 'Unknown'),
            _buildTaskInfo(
                '🎯 Dropoff', task.dropoffLocation['address'] ?? 'Unknown'),
            if (task.scheduledPickupTime != null)
              _buildTaskInfo(
                '⏰ Scheduled',
                _formatDateTime(task.scheduledPickupTime),
              ),
            if (task.urgency != null && task.urgency != 'normal')
              _buildTaskInfo(
                '🚨 Priority',
                '${task.urgency.toUpperCase()} PRIORITY',
                isUrgent: true,
              ),
            const SizedBox(height: 12),
            _buildActionButtons(task, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInfo(String label, String value, {bool isUrgent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: isUrgent ? Colors.red : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isUrgent ? Colors.red : null,
                fontWeight: isUrgent ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(dynamic task, LogisticsProvider provider) {
    return Row(
      children: [
        // Status progression buttons
        if (task.status == 'assigned') ...[
          ElevatedButton(
            onPressed: provider.isUpdating(task.id)
                ? null
                : () => _updateTaskStatus(task.id, 'picked_up', provider),
            child: const Text('Mark as Picked Up'),
          ),
          const SizedBox(width: 8),
        ],
        if (task.status == 'picked_up') ...[
          ElevatedButton(
            onPressed: provider.isUpdating(task.id)
                ? null
                : () => _updateTaskStatus(task.id, 'in_transit', provider),
            child: const Text('Start Delivery'),
          ),
          const SizedBox(width: 8),
        ],
        if (task.status == 'in_transit') ...[
          ElevatedButton(
            onPressed: provider.isUpdating(task.id)
                ? null
                : () => _updateTaskStatus(task.id, 'delivered', provider),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark as Delivered'),
          ),
          const SizedBox(width: 8),
        ],

        const Spacer(),

        // Additional actions
        IconButton(
          icon: const Icon(Icons.directions),
          onPressed: () => _showDirections(task, provider),
          tooltip: 'View Route',
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showTaskDetails(task, provider),
          tooltip: 'Task Details',
        ),
      ],
    );
  }

  Widget _getStatusIcon(String status) {
    final iconData = {
          'assigned': Icons.assignment,
          'picked_up': Icons.inventory_2,
          'in_transit': Icons.delivery_dining,
          'delivered': Icons.check_circle,
        }[status] ??
        Icons.pending;

    final color = {
          'assigned': Colors.blue,
          'picked_up': Colors.orange,
          'in_transit': Colors.purple,
          'delivered': Colors.green,
        }[status] ??
        Colors.grey;

    return Icon(iconData, color: color, size: 30);
  }

  Widget _getStatusChip(String status) {
    final color = {
          'assigned': Colors.blue,
          'picked_up': Colors.orange,
          'in_transit': Colors.purple,
          'delivered': Colors.green,
        }[status] ??
        Colors.grey;

    final text = {
          'assigned': 'Assigned',
          'picked_up': 'Picked Up',
          'in_transit': 'In Transit',
          'delivered': 'Delivered',
        }[status] ??
        'Pending';

    return Chip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _updateTaskStatus(
      String taskId, String status, LogisticsProvider provider) async {
    try {
      Map<String, dynamic>? additionalData;

      // Include location for certain status updates
      if (status == 'picked_up' || status == 'in_transit') {
        // In a real app, you would get the current location here
        additionalData = {
          'currentLocation': {
            'lat': 0.0, // Replace with actual location
            'lng': 0.0, // Replace with actual location
          },
        };
      }

      await provider.updateTaskStatus(taskId, status,
          additionalData: additionalData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  void _showDirections(dynamic task, LogisticsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery Route'),
        content: FutureBuilder(
          future: provider.getOptimizedRoute(task.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error loading route: ${snapshot.error}');
            }

            final routeData = snapshot.data ?? {};

            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From: ${task.pickupLocation['address']}'),
                  Text('To: ${task.dropoffLocation['address']}'),
                  const SizedBox(height: 16),
                  if (routeData['optimizedRoute'] != null) ...[
                    const Text('Optimized Route Available',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'Distance: ${(routeData['optimizedRoute']['totalDistance'] / 1000).toStringAsFixed(1)} km'),
                    Text(
                        'Estimated Time: ${_formatDuration(routeData['optimizedRoute']['estimatedDuration'] ?? 0)}'),
                    if (routeData['trafficConditions'] != null)
                      Text('Traffic: ${routeData['trafficConditions']}'),
                  ] else ...[
                    const Text('Basic route information'),
                  ],
                ]);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openInMaps(task);
            },
            child: const Text('OPEN IN MAPS'),
          ),
        ],
      ),
    );
  }

  void _showTaskDetails(dynamic task, LogisticsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Details'),
        content: FutureBuilder(
          future: provider.getTaskDetails(task.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error loading details: ${snapshot.error}');
            }

            final taskDetails = snapshot.data ?? {};

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailItem(
                      'Status', taskDetails['status'] ?? 'Unknown'),
                  _buildDetailItem(
                      'Priority', taskDetails['urgency'] ?? 'Normal'),
                  _buildDetailItem(
                      'Progress', '${taskDetails['progress'] ?? 0}%'),
                  const SizedBox(height: 16),
                  const Text('Safety Checklist',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._buildSafetyChecklist(
                      taskDetails['safetyChecklist'] ?? []),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(value),
        ],
      ),
    );
  }

  List<Widget> _buildSafetyChecklist(List<dynamic> checklist) {
    if (checklist.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('No safety checklist available'),
        ),
      ];
    }

    return checklist.map<Widget>((item) {
      return CheckboxListTile(
        title: Text(item['item'] ?? 'Unknown'),
        value: item['completed'] ?? false,
        onChanged: null, // Read-only in this view
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
    }).toList();
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  void _openInMaps(dynamic task) {
    // This would open the route in the device's maps app
    // Implementation depends on the maps integration you're using
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening in maps...')),
    );
  }
}
