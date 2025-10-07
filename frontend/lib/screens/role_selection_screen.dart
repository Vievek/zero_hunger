import 'package:flutter/material.dart';
import 'signup_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join as...'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How would you like to help?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Select your role to continue',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView(
                children: [
                  _buildRoleCard(
                    context,
                    icon: Icons.volunteer_activism,
                    title: 'Donor',
                    description:
                        'I want to donate food or resources to help those in need',
                    color: Colors.green,
                    role: 'donor',
                  ),
                  const SizedBox(height: 20),
                  _buildRoleCard(
                    context,
                    icon: Icons.receipt_long,
                    title: 'Recipient',
                    description: 'I need assistance with food resources',
                    color: Colors.orange,
                    role: 'recipient',
                  ),
                  const SizedBox(height: 20),
                  _buildRoleCard(
                    context,
                    icon: Icons.people,
                    title: 'Volunteer',
                    description: 'I want to volunteer my time and effort',
                    color: Colors.purple,
                    role: 'volunteer',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required String role,
  }) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(51), // 20% opacity equivalent
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SignupScreen(),
            ),
          );
        },
      ),
    );
  }
}
