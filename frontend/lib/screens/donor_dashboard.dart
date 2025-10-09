import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';
import 'create_donation_screen.dart';
import '../providers/auth_provider.dart';
import 'welcome_screen.dart';

class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  State<DonorDashboardScreen> createState() => _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends State<DonorDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DonationProvider>(context, listen: false).fetchMyDonations();
    });
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
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => WelcomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final donationProvider = Provider.of<DonationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateDonationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: donationProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Overview
                _buildStatsCard(donationProvider),
                const SizedBox(height: 16),
                // Donations List
                Expanded(
                  child: _buildDonationsList(donationProvider.donations),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCard(DonationProvider provider) {
    final stats = {
      'Total': provider.donations.length,
      'Active': provider.donations
          .where((d) => ['active', 'matched'].contains(d.status))
          .length,
      'Completed':
          provider.donations.where((d) => d.status == 'delivered').length,
      'Pending': provider.donations
          .where((d) => ['pending', 'ai_processing'].contains(d.status))
          .length,
    };

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: stats.entries
              .map((entry) => _buildStatItem(entry.key, entry.value))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDonationsList(List<Donation> donations) {
    if (donations.isEmpty) {
      return const Center(
        child: Text('No donations yet. Create your first donation!'),
      );
    }

    return ListView.builder(
      itemCount: donations.length,
      itemBuilder: (context, index) {
        final donation = donations[index];
        return _buildDonationCard(donation);
      },
    );
  }

  Widget _buildDonationCard(Donation donation) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: donation.images.isNotEmpty
            ? Image.network(
                donation.images.first,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              )
            : const Icon(Icons.fastfood, size: 40),
        title: Text(donation.aiDescription ?? 'Food Donation'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${donation.type}'),
            Text('Status: ${donation.status}'),
            if (donation.categories.isNotEmpty)
              Text('Categories: ${donation.categories.join(', ')}'),
          ],
        ),
        trailing: _getStatusIcon(donation.status),
        onTap: () {
          // Navigate to donation details
        },
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return const Icon(Icons.access_time, color: Colors.orange);
      case 'matched':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'delivered':
        return const Icon(Icons.done_all, color: Colors.blue);
      default:
        return const Icon(Icons.pending, color: Colors.grey);
    }
  }
}
