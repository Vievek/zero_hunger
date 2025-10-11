import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/donor_dashboard.dart';
import '../screens/recipient_dashboard_screen.dart';
import '../screens/volunteer_dashboard_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/foodsafe_chat_screen.dart';
import '../screens/volunteer_tasks_screen.dart';
import '../screens/create_donation_screen.dart';

class RoleBottomNavBar extends StatefulWidget {
  const RoleBottomNavBar({super.key});

  @override
  State<RoleBottomNavBar> createState() => _RoleBottomNavBarState();
}

class _RoleBottomNavBarState extends State<RoleBottomNavBar> {
  int _selectedIndex = 0;

  // Role-based navigation items
  List<BottomNavigationItem> _getNavigationItems(String role) {
    switch (role) {
      case 'donor':
        return [
          BottomNavigationItem(
            label: 'Dashboard',
            icon: Icons.dashboard,
            screen: const DonorDashboardScreen(),
          ),
          BottomNavigationItem(
            label: 'Donate',
            icon: Icons.add_circle_outline,
            screen: const CreateDonationScreen(),
          ),
          BottomNavigationItem(
            label: 'FoodSafe AI',
            icon: Icons.chat,
            screen: const FoodSafeChatScreen(),
          ),
        ];
      case 'recipient':
        return [
          BottomNavigationItem(
            label: 'Dashboard',
            icon: Icons.dashboard,
            screen: const RecipientDashboardScreen(), // This contains all tabs
          ),
          BottomNavigationItem(
            label: 'FoodSafe AI',
            icon: Icons.chat,
            screen: const FoodSafeChatScreen(),
          ),
        ];
      case 'volunteer':
        return [
          BottomNavigationItem(
            label: 'Dashboard',
            icon: Icons.dashboard,
            screen: const VolunteerDashboardScreen(),
          ),
          BottomNavigationItem(
            label: 'Tasks',
            icon: Icons.assignment,
            screen: const VolunteerTasksScreen(),
          ),
          BottomNavigationItem(
            label: 'FoodSafe AI',
            icon: Icons.chat,
            screen: const FoodSafeChatScreen(),
          ),
        ];
      case 'admin':
        return [
          BottomNavigationItem(
            label: 'Dashboard',
            icon: Icons.dashboard,
            screen: const AdminDashboardScreen(),
          ),
          BottomNavigationItem(
            label: 'Analytics',
            icon: Icons.analytics,
            screen: const Scaffold(
                body: Center(child: Text('Analytics Dashboard'))),
          ),
          BottomNavigationItem(
            label: 'Manage',
            icon: Icons.manage_accounts,
            screen:
                const Scaffold(body: Center(child: Text('User Management'))),
          ),
        ];
      default:
        return [
          BottomNavigationItem(
            label: 'Home',
            icon: Icons.home,
            screen: const Scaffold(body: Center(child: Text('Home'))),
          ),
        ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final navItems = _getNavigationItems(user.role);

    // Ensure selected index is within bounds
    if (_selectedIndex >= navItems.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: navItems[_selectedIndex].screen,
      bottomNavigationBar: BottomNavigationBar(
        items: navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                ))
            .toList(),
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class BottomNavigationItem {
  final String label;
  final IconData icon;
  final Widget screen;

  BottomNavigationItem({
    required this.label,
    required this.icon,
    required this.screen,
  });
}
