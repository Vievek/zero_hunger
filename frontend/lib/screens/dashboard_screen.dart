import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    String getDashboardTitle() {
      switch (user?.role) {
        case 'donor':
          return 'Donor Dashboard';
        case 'recipient':
          return 'Recipient Dashboard';
        case 'volunteer':
          return 'Volunteer Dashboard';
        default:
          return 'Dashboard';
      }
    }

    Widget getRoleSpecificContent() {
      switch (user?.role) {
        case 'donor':
          return _buildDonorDashboard();
        case 'recipient':
          return _buildRecipientDashboard();
        case 'volunteer':
          return _buildVolunteerDashboard();
        default:
          return _buildDefaultDashboard();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(getDashboardTitle()),
        backgroundColor: _getRoleColor(user?.role),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _getRoleColor(
                        user?.role,
                      ).withAlpha(51), // 20% opacity equivalent
                      child: Icon(
                        _getRoleIcon(user?.role),
                        size: 30,
                        color: _getRoleColor(user?.role),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user?.name}!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Role: ${_capitalize(user?.role ?? 'User')}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(child: getRoleSpecificContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donation Opportunities',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              _buildDashboardCard(
                title: 'Food Donation',
                subtitle: 'Donate non-perishable food items',
                icon: Icons.fastfood,
                color: Colors.green,
              ),
              _buildDashboardCard(
                title: 'Monetary Donation',
                subtitle: 'Make a financial contribution',
                icon: Icons.attach_money,
                color: Colors.blue,
              ),
              _buildDashboardCard(
                title: 'Delivery Help',
                subtitle: 'Assist with food delivery',
                icon: Icons.delivery_dining,
                color: Colors.orange,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Resources',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              _buildDashboardCard(
                title: 'Food Banks',
                subtitle: 'Find nearby food distribution centers',
                icon: Icons.store,
                color: Colors.orange,
              ),
              _buildDashboardCard(
                title: 'Meal Programs',
                subtitle: 'Community meal services',
                icon: Icons.restaurant,
                color: Colors.red,
              ),
              _buildDashboardCard(
                title: 'Emergency Assistance',
                subtitle: 'Immediate food support',
                icon: Icons.emergency,
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVolunteerDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Volunteer Opportunities',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              _buildDashboardCard(
                title: 'Food Sorting',
                subtitle: 'Help sort and package food donations',
                icon: Icons.sort,
                color: Colors.blue,
              ),
              _buildDashboardCard(
                title: 'Delivery',
                subtitle: 'Deliver food to those in need',
                icon: Icons.delivery_dining,
                color: Colors.green,
              ),
              _buildDashboardCard(
                title: 'Event Support',
                subtitle: 'Assist with community events',
                icon: Icons.event,
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultDashboard() {
    return const Center(
      child: Text(
        'Welcome to Zero Hunger!',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(51), // 20% opacity equivalent
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Handle card tap
        },
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'donor':
        return Colors.green;
      case 'recipient':
        return Colors.orange;
      case 'volunteer':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role) {
      case 'donor':
        return Icons.volunteer_activism;
      case 'recipient':
        return Icons.receipt_long;
      case 'volunteer':
        return Icons.people;
      default:
        return Icons.person;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
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
