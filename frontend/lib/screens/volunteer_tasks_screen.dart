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
    });
  }

  @override
  Widget build(BuildContext context) {
    final logisticsProvider = Provider.of<LogisticsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Delivery Tasks')),
      body: logisticsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTasksList(logisticsProvider.tasks),
    );
  }

  Widget _buildTasksList(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks assigned yet.'));
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getStatusIcon(task['status']),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Task #${task['_id']?.substring(0, 8) ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    task['status']
                        .toString()
                        .replaceAll('_', ' ')
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _getStatusColor(task['status']),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTaskInfo('Pickup', task['pickupLocation']['address']),
            _buildTaskInfo('Dropoff', task['dropoffLocation']['address']),
            if (task['scheduledPickupTime'] != null)
              _buildTaskInfo(
                'Scheduled',
                _formatDateTime(task['scheduledPickupTime']),
              ),
            const SizedBox(height: 12),
            _buildActionButtons(task),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> task) {
    return Row(
      children: [
        if (task['status'] == 'assigned') ...[
          ElevatedButton(
            onPressed: () => _updateTaskStatus(task['_id'], 'picked_up'),
            child: const Text('Mark as Picked Up'),
          ),
          const SizedBox(width: 8),
        ],
        if (task['status'] == 'picked_up') ...[
          ElevatedButton(
            onPressed: () => _updateTaskStatus(task['_id'], 'in_transit'),
            child: const Text('Start Delivery'),
          ),
          const SizedBox(width: 8),
        ],
        if (task['status'] == 'in_transit') ...[
          ElevatedButton(
            onPressed: () => _updateTaskStatus(task['_id'], 'delivered'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark as Delivered'),
          ),
        ],
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.directions),
          onPressed: () => _showDirections(task),
        ),
      ],
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'assigned':
        return const Icon(Icons.assignment, color: Colors.blue);
      case 'picked_up':
        return const Icon(Icons.inventory_2, color: Colors.orange);
      case 'in_transit':
        return const Icon(Icons.delivery_dining, color: Colors.purple);
      case 'delivered':
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const Icon(Icons.pending, color: Colors.grey);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue[100]!;
      case 'picked_up':
        return Colors.orange[100]!;
      case 'in_transit':
        return Colors.purple[100]!;
      case 'delivered':
        return Colors.green[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _updateTaskStatus(String taskId, String status) async {
    try {
      await Provider.of<LogisticsProvider>(
        context,
        listen: false,
      ).updateTaskStatus(taskId, status);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  void _showDirections(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optimized Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${task['pickupLocation']['address']}'),
            Text('To: ${task['dropoffLocation']['address']}'),
            if (task['optimizedRoute'] != null) ...[
              const SizedBox(height: 16),
              const Text('Optimized route available'),
              Text('Distance: ${task['optimizedRoute']['totalDistance']}m'),
              Text('Duration: ${task['optimizedRoute']['estimatedDuration']}s'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OPEN IN MAPS'),
          ),
        ],
      ),
    );
  }
}
