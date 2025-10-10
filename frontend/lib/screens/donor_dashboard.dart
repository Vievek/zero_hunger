import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';
import '../providers/auth_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final donationProvider = Provider.of<DonationProvider>(context);

    return Scaffold(
      body: donationProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Welcome Header
                _buildWelcomeHeader(),
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

  Widget _buildWelcomeHeader() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(25),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, ${user?.name ?? 'Donor'}! 👋',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to make a difference today?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(DonationProvider provider) {
    final stats = provider.donationStats;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', stats['total'] ?? 0, Colors.blue),
              _buildStatItem('Active', stats['active'] ?? 0, Colors.green),
              _buildStatItem(
                  'Completed', stats['completed'] ?? 0, Colors.purple),
              _buildStatItem('Pending', stats['pending'] ?? 0, Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
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
          value.toString(),
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

  IconData _getStatIcon(String label) {
    switch (label.toLowerCase()) {
      case 'total':
        return Icons.list_alt;
      case 'active':
        return Icons.refresh;
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help;
    }
  }

  Widget _buildDonationsList(List<Donation> donations) {
    if (donations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No donations yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first donation to get started!',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: donation.images.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  donation.images.first,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    );
                  },
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fastfood, color: Colors.grey),
              ),
        title: Text(
          donation.displayDescription,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Quantity: ${donation.quantityText}'),
            Text('Type: ${donation.type}'),
            const SizedBox(height: 4),
            Row(
              children: [
                _getStatusChip(donation.status),
                if (donation.categories.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Chip(
                    label: Text(
                      donation.categories.first,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.blue.withAlpha(25),
                    visualDensity: VisualDensity.compact,
                  ),
                ]
              ],
            ),
          ],
        ),
        trailing: _getStatusIcon(donation.status),
      ),
    );
  }

  Widget _getStatusChip(String status) {
    Color chipColor;
    String statusText;

    switch (status) {
      case 'active':
        chipColor = Colors.green;
        statusText = 'Active';
        break;
      case 'matched':
        chipColor = Colors.blue;
        statusText = 'Matched';
        break;
      case 'delivered':
        chipColor = Colors.purple;
        statusText = 'Delivered';
        break;
      case 'ai_processing':
        chipColor = Colors.orange;
        statusText = 'AI Processing';
        break;
      default:
        chipColor = Colors.grey;
        statusText = 'Pending';
    }

    return Chip(
      label: Text(
        statusText,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
        ),
      ),
      backgroundColor: chipColor,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return const Icon(Icons.access_time, color: Colors.green);
      case 'matched':
        return const Icon(Icons.check_circle, color: Colors.blue);
      case 'delivered':
        return const Icon(Icons.done_all, color: Colors.purple);
      case 'ai_processing':
        return const Icon(Icons.sync, color: Colors.orange);
      default:
        return const Icon(Icons.pending, color: Colors.grey);
    }
  }
}
