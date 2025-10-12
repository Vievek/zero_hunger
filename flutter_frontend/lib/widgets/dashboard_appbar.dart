import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/welcome_screen.dart';

/// Simple, reusable dashboard app bar with logout functionality
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const DashboardAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      bottom: bottom,
      actions: [
        // Custom actions passed from screen
        ...?actions,

        // Logout button
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutDialog(context),
          tooltip: 'Logout',
        ),
      ],
    );
  }

  /// Show logout confirmation dialog
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
            onPressed: () => _performLogout(context),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Perform logout and navigate to welcome screen
  Future<void> _performLogout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Close dialog immediately
    navigator.pop();

    try {
      // Show loading indicator
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator.adaptive(strokeWidth: 2),
              SizedBox(width: 12),
              Text('Logging out...'),
            ],
          ),
          duration: Duration(seconds: 5),
        ),
      );

      // Perform logout
      await Provider.of<AuthProvider>(context, listen: false).logout();

      // Clear any existing snacks
      scaffoldMessenger.hideCurrentSnackBar();

      // Use pushAndRemoveUntil with a more specific condition
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false, // Remove all routes
      );
    } catch (error) {
      // Clear loading snack
      scaffoldMessenger.hideCurrentSnackBar();

      // Show error
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Logout failed: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      // Even on error, try to navigate to welcome screen
      if (context.mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Size get preferredSize {
    if (bottom != null) {
      return Size.fromHeight(kToolbarHeight + bottom!.preferredSize.height);
    }
    return const Size.fromHeight(kToolbarHeight);
  }
}
