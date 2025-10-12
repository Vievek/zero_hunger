import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("in welcome screen");
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              // Logo from assets
              Image.asset(
                'assets/images/Logo.png', // Make sure to add your logo to pubspec.yaml
                width: 220,
                height: 220,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to Zerobye',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9FB301), // #9fb301 color
                  fontFamily:
                      'JockeyOne', // Make sure to add this font to pubspec.yaml
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Join us in the fight against hunger. Together we can make a difference.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily:
                      'GeistMono', // Make sure to add this font to pubspec.yaml
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RoleSelectionScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'GeistMono', // Apply GeistMono to buttons too
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Already have an account',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'GeistMono', // Apply GeistMono to buttons too
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
