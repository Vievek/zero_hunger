import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/logistics_provider.dart';
import '../models/logistics_model.dart';
import '../widgets/dashboard_appbar.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  State<VolunteerDashboardScreen> createState() =>
      _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LogisticsProvider>(context, listen: false).fetchMyTasks();
      Provider.of<LogisticsProvider>(context, listen: false)
          .fetchAvailableTasks();
      Provider.of<LogisticsProvider>(context, listen: false)
          .fetchVolunteerStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final logisticsProvider = Provider.of<LogisticsProvider>(context);

    return Scaffold(
      appBar: const DashboardAppBar(
        title: 'Volunteer Dashboard',
      ),
      body: Column(
        children: [
          // Welcome Header
          _buildWelcomeHeader(),

          // Stats Overview
          _buildStatsCard(logisticsProvider),

          const SizedBox(height: 16),

          // Tabs for Available Tasks and My Tasks
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.list), text: 'Available Tasks'),
                      Tab(icon: Icon(Icons.assignment), text: 'My Tasks'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Available Tasks Tab
                        _buildAvailableTasksTab(logisticsProvider),

                        // My Tasks Tab
                        _buildMyTasksTab(logisticsProvider),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.withAlpha(25),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Volunteer Dashboard 🚗',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Find and accept delivery tasks near you',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(LogisticsProvider provider) {
    final stats = provider.taskStats;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                  'Available', provider.availableTasks.length, Colors.blue),
              _buildStatItem('Assigned', stats['assigned'] ?? 0, Colors.orange),
              _buildStatItem(
                  'In Progress', stats['in_progress'] ?? 0, Colors.purple),
              _buildStatItem(
                  'Completed', stats['completed'] ?? 0, Colors.green),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatIcon(label),
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
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

  Widget _buildAvailableTasksTab(LogisticsProvider provider) {
    return provider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildAvailableTasksList(provider.availableTasks, provider);
  }

  Widget _buildMyTasksTab(LogisticsProvider provider) {
    return provider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildTasksList(provider.tasks, provider);
  }

  Widget _buildAvailableTasksList(
      List<LogisticsTask> tasks, LogisticsProvider provider) {
    if (tasks.isEmpty) {
      return _buildEmptyAvailableTasksState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchAvailableTasks();
      },
      child: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildAvailableTaskCard(task, provider);
        },
      ),
    );
  }

  Widget _buildTasksList(
      List<LogisticsTask> tasks, LogisticsProvider provider) {
    if (tasks.isEmpty) {
      return _buildEmptyMyTasksState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchMyTasks();
      },
      child: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task, provider);
        },
      ),
    );
  }

  Widget _buildEmptyAvailableTasksState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Available Tasks',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for new delivery tasks\nwithin 5km of your location',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Provider.of<LogisticsProvider>(context, listen: false)
                  .fetchAvailableTasks();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMyTasksState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Tasks Assigned',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accept available tasks to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              DefaultTabController.of(context).animateTo(0);
            },
            icon: const Icon(Icons.list),
            label: const Text('View Available Tasks'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTaskCard(
      LogisticsTask task, LogisticsProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Colors.blue, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delivery Task',
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
                _formatDateTime(task.scheduledPickupTime!),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.isLoading
                    ? null
                    : () => _acceptTask(task.id!, provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: provider.isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Accept Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(LogisticsTask task, LogisticsProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _getTaskIcon(task.status),
        title: Text(
          'Delivery Task',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('From: ${task.pickupLocation['address'] ?? 'Unknown'}'),
            Text('To: ${task.dropoffLocation['address'] ?? 'Unknown'}'),
            const SizedBox(height: 4),
            _getStatusChip(task.status),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigate to task details
        },
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

  Widget _getTaskIcon(String status) {
    switch (status) {
      case 'assigned':
        return const Icon(Icons.assignment, color: Colors.blue, size: 30);
      case 'picked_up':
        return const Icon(Icons.inventory_2, color: Colors.orange, size: 30);
      case 'in_transit':
        return const Icon(Icons.delivery_dining,
            color: Colors.purple, size: 30);
      case 'delivered':
        return const Icon(Icons.check_circle, color: Colors.green, size: 30);
      default:
        return const Icon(Icons.pending, color: Colors.grey, size: 30);
    }
  }

  Widget _getStatusChip(String status) {
    Color chipColor;
    String statusText;

    switch (status) {
      case 'assigned':
        chipColor = Colors.blue;
        statusText = 'Assigned';
        break;
      case 'picked_up':
        chipColor = Colors.orange;
        statusText = 'Picked Up';
        break;
      case 'in_transit':
        chipColor = Colors.purple;
        statusText = 'In Transit';
        break;
      case 'delivered':
        chipColor = Colors.green;
        statusText = 'Delivered';
        break;
      default:
        chipColor = Colors.grey;
        statusText = 'Pending';
    }

    return Chip(
      label: Text(
        statusText,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
        ),
      ),
      backgroundColor: chipColor,
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _acceptTask(String taskId, LogisticsProvider provider) async {
    try {
      await provider.acceptTask(taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task accepted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getStatIcon(String label) {
    switch (label.toLowerCase()) {
      case 'available':
        return Icons.list;
      case 'assigned':
        return Icons.assignment;
      case 'in progress':
        return Icons.delivery_dining;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}
