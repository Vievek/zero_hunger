import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/logistics_provider.dart';
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
          // Tasks List
          Expanded(
            child: logisticsProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTasksList(logisticsProvider.tasks),
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
            'Help deliver food to those in need',
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
              _buildStatItem('Total', stats['total'] ?? 0, Colors.blue),
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

  IconData _getStatIcon(String label) {
    switch (label.toLowerCase()) {
      case 'total':
        return Icons.list_alt;
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

  Widget _buildTasksList(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tasks assigned',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tasks will appear here when assigned',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(dynamic task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _getTaskIcon(task.status),
        title: Text(
          'Delivery Task #${task.id?.substring(0, 8) ?? 'Unknown'}',
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
}
