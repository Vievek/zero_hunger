import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/logistics_provider.dart';
import '../models/logistics_model.dart';
import '../widgets/dashboard_appbar.dart';
import '../services/location_service.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  State<VolunteerDashboardScreen> createState() =>
      _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  bool _isInitializing = true;
  bool _locationLoaded = false;
  bool _tasksLoaded = false;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    final provider = Provider.of<LogisticsProvider>(context, listen: false);

    // Start all API calls simultaneously
    final locationFuture = _initializeLocation(provider);
    final tasksFuture = _initializeTasks(provider);
    final statsFuture = _initializeStats(provider);

    // Wait a bit for initial data, then show UI
    await Future.any([
      Future.delayed(const Duration(seconds: 2)),
      Future.wait([locationFuture, tasksFuture, statsFuture])
    ]);

    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _initializeLocation(LogisticsProvider provider) async {
    try {
      final position = await LocationService.getCurrentLocation();
      await provider.updateVolunteerLocation(
        position.latitude,
        position.longitude,
        address: 'Current Location',
      );
      setState(() {
        _locationLoaded = true;
      });
    } catch (e) {
      debugPrint('Auto-location failed: $e');
      setState(() {
        _locationLoaded = true; // Mark as loaded even if failed
      });
    }
  }

  Future<void> _initializeTasks(LogisticsProvider provider) async {
    try {
      await provider.fetchAvailableTasks();
      setState(() {
        _tasksLoaded = true;
      });
    } catch (e) {
      debugPrint('Tasks loading failed: $e');
      setState(() {
        _tasksLoaded = true; // Mark as loaded even if failed
      });
    }
  }

  Future<void> _initializeStats(LogisticsProvider provider) async {
    try {
      await provider.fetchVolunteerStats();
      setState(() {
        _statsLoaded = true;
      });
    } catch (e) {
      debugPrint('Stats loading failed: $e');
      setState(() {
        _statsLoaded = true; // Mark as loaded even if failed
      });
    }
  }

  Future<void> _updateVolunteerLocation(LogisticsProvider provider) async {
    try {
      final position = await LocationService.getCurrentLocation();

      await provider.updateVolunteerLocation(
        position.latitude,
        position.longitude,
        address: 'Current Location',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToMyTasks() {
    Navigator.pushNamed(context, '/volunteer-tasks');
  }

  @override
  Widget build(BuildContext context) {
    final logisticsProvider = Provider.of<LogisticsProvider>(context);

    return Scaffold(
      appBar: const DashboardAppBar(
        title: 'Volunteer Dashboard',
      ),
      body: _isInitializing
          ? _buildLoadingScreen()
          : Column(
              children: [
                // Welcome Header
                _buildWelcomeHeader(logisticsProvider),

                // Stats Overview
                _buildStatsCard(logisticsProvider),

                const SizedBox(height: 16),

                // Quick Actions
                _buildQuickActions(),

                const SizedBox(height: 16),

                // Available Tasks Section
                Expanded(
                  child: _buildAvailableTasksSection(logisticsProvider),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Column(
      children: [
        // Loading header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.purple.withAlpha(25),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Volunteer Dashboard 🚗',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Loading your dashboard...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_locationLoaded && _tasksLoaded && _statsLoaded)
                    ? 1.0
                    : null,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 8),
              Text(
                _getLoadingStatus(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Loading content
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  _getLoadingMessage(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getLoadingStatus() {
    int loadedCount =
        [_locationLoaded, _tasksLoaded, _statsLoaded].where((e) => e).length;
    return 'Loading... $loadedCount/3 complete';
  }

  String _getLoadingMessage() {
    if (!_locationLoaded) return 'Getting your location...';
    if (!_tasksLoaded) return 'Loading available tasks...';
    if (!_statsLoaded) return 'Loading your statistics...';
    return 'Almost ready...';
  }

  Widget _buildWelcomeHeader(LogisticsProvider provider) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Volunteer Dashboard 🚗',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find and accept delivery tasks near you',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _updateVolunteerLocation(provider),
            icon: const Icon(Icons.location_on),
            label: const Text('Update My Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(LogisticsProvider provider) {
    final stats = provider.volunteerStats;

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
              _buildStatItem('My Tasks', provider.tasks.length, Colors.orange),
              _buildStatItem(
                  'Completed', stats['completedTasks'] ?? 0, Colors.green),
              _buildStatItem('Rating',
                  (stats['averageRating'] ?? 0.0).toDouble(), Colors.purple),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value, Color color) {
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

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _navigateToMyTasks,
              icon: const Icon(Icons.assignment),
              label: const Text('My Tasks'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Provider.of<LogisticsProvider>(context, listen: false)
                    .fetchAvailableTasks();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTasksSection(LogisticsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Available Tasks Nearby',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('${provider.availableTasks.length} tasks'),
                backgroundColor: Colors.blue.withAlpha(30),
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.isLoading && !_tasksLoaded
              ? const Center(child: CircularProgressIndicator())
              : _buildAvailableTasksList(provider.availableTasks, provider),
        ),
      ],
    );
  }

  Widget _buildAvailableTasksList(
      List<LogisticsTask> tasks, LogisticsProvider provider) {
    if (tasks.isEmpty) {
      return _buildEmptyAvailableTasksState(provider);
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

  Widget _buildEmptyAvailableTasksState(LogisticsProvider provider) {
    final hasLocation = provider.currentLocation != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasLocation ? Icons.search_off : Icons.location_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            hasLocation ? 'No Available Tasks' : 'Location Required',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            hasLocation
                ? 'Check back later for new delivery tasks\nwithin 5km of your location'
                : 'Please update your location to see nearby tasks',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (!hasLocation)
            ElevatedButton.icon(
              onPressed: () => _updateVolunteerLocation(provider),
              icon: const Icon(Icons.location_on),
              label: const Text('Set Location'),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                provider.fetchAvailableTasks();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailableTaskCard(
      LogisticsTask task, LogisticsProvider provider) {
    final distance = provider.currentLocation != null
        ? task.calculateDistanceFrom(
            provider.currentLocation!.lat, provider.currentLocation!.lng)
        : null;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Task',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (distance != null)
                        Text(
                          '${distance.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                _getUrgencyChip(task.urgency),
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
            if (task.specialInstructions != null &&
                task.specialInstructions!.isNotEmpty)
              _buildTaskInfo(
                '📝 Instructions',
                task.specialInstructions!,
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
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 18),
                          SizedBox(width: 8),
                          Text('Accept Task'),
                        ],
                      ),
              ),
            ),
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

  Widget _getUrgencyChip(String? urgency) {
    Color chipColor;
    String urgencyText;

    switch (urgency) {
      case 'critical':
        chipColor = Colors.red;
        urgencyText = 'Critical';
        break;
      case 'high':
        chipColor = Colors.orange;
        urgencyText = 'High';
        break;
      default:
        chipColor = Colors.blue;
        urgencyText = 'Normal';
    }

    return Chip(
      label: Text(
        urgencyText,
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

        // Show directions dialog after accepting
        _showDirectionsDialog(taskId, provider);
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

  void _showDirectionsDialog(String taskId, LogisticsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Accepted! 🎉'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your task has been accepted successfully.'),
            SizedBox(height: 12),
            Text('Would you like to view directions to the pickup location?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('LATER'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openMapsDirections(taskId, provider);
            },
            child: const Text('GET DIRECTIONS'),
          ),
        ],
      ),
    );
  }

  void _openMapsDirections(String taskId, LogisticsProvider provider) {
    final task = provider.availableTasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => provider.tasks.firstWhere(
        (t) => t.id == taskId,
      ),
    );

    final pickupLat = task.pickupLocation['lat'];
    final pickupLng = task.pickupLocation['lng'];
    final pickupAddress = task.pickupLocation['address'];

    if (pickupLat != null && pickupLng != null) {
      // Open in Google Maps
      final url =
          'https://www.google.com/maps/dir/?api=1&destination=$pickupLat,$pickupLng&destination_place_id=${Uri.encodeComponent(pickupAddress ?? '')}';

      // You can use url_launcher package to open the URL
      // For now, show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Opening directions to: ${pickupAddress ?? 'pickup location'}'),
          duration: const Duration(seconds: 3),
        ),
      );

      // Log the URL for debugging
      debugPrint('Maps URL: $url');

      // In a real app, you would use:
      // launchUrl(Uri.parse(url));
    }
  }

  IconData _getStatIcon(String label) {
    switch (label.toLowerCase()) {
      case 'available':
        return Icons.list;
      case 'my tasks':
        return Icons.assignment;
      case 'completed':
        return Icons.check_circle;
      case 'rating':
        return Icons.star;
      default:
        return Icons.help;
    }
  }
}
