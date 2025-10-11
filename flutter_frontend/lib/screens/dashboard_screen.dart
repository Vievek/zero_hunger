import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/role_bottom_navbar.dart';
import '../widgets/dashboard_appbar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // If user profile is not completed, show default dashboard
    if (user == null || !user.profileCompleted) {
      return _buildDefaultDashboard(context);
    }

    // Use role-based bottom navigation for completed profiles
    return const RoleBottomNavBar();
  }

  Widget _buildDefaultDashboard(BuildContext context) {
    return Scaffold(
      appBar: const DashboardAppBar(
        title: 'Dashboard',
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Profile Incomplete',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Please complete your profile to access all features',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
