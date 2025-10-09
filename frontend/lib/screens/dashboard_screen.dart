import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'donor_dashboard.dart';
import 'recipient_dashboard_screen.dart';
import 'volunteer_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Navigate to role-specific dashboard
    Widget getRoleSpecificDashboard() {
      switch (user?.role) {
        case 'donor':
          return const DonorDashboardScreen();
        case 'recipient':
          return const RecipientDashboardScreen();
        case 'volunteer':
          return const VolunteerDashboardScreen();
        case 'admin':
          return const AdminDashboardScreen();
        default:
          return _buildDefaultDashboard(context);
      }
    }

    return getRoleSpecificDashboard();
  }

  Widget _buildDefaultDashboard(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Welcome to Zero Hunger!',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
