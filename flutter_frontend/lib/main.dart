import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/donation_provider.dart';
import 'providers/logistics_provider.dart';
import 'screens/launch_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DonationProvider()),
        ChangeNotifierProvider(create: (_) => LogisticsProvider()),
      ],
      child: MaterialApp(
        title: 'FoodLink - AI Food Redistribution',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        home: const AuthWrapper(), // Use AuthWrapper instead of LaunchScreen
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// AuthWrapper decides which screen to show based on authentication state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Trigger auto-login check when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });
  }

  Future<void> _checkAuthStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.autoLogin();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Show loading screen while checking auth status
    if (authProvider.isLoading) {
      return const LaunchScreen();
    }

    // If authenticated, show dashboard
    if (authProvider.isAuthenticated) {
      return const DashboardScreen();
    }

    // If not authenticated, show welcome screen
    return const WelcomeScreen();
  }
}
