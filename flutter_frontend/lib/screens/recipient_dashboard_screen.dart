import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';
import 'recipient_matched_donations_screen.dart';
import 'recipient_all_donations_screen.dart';

class RecipientDashboardScreen extends StatefulWidget {
  const RecipientDashboardScreen({super.key});

  @override
  State<RecipientDashboardScreen> createState() =>
      _RecipientDashboardScreenState();
}

class _RecipientDashboardScreenState extends State<RecipientDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    debugPrint("🔄 Loading recipient dashboard data...");
    final donationProvider =
        Provider.of<DonationProvider>(context, listen: false);

    if (!mounted) return;

    try {
      await donationProvider.fetchRecipientDashboard();
      await donationProvider.fetchDonationStats();
    } catch (e) {
      debugPrint("❌ Error loading dashboard data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final donationProvider = Provider.of<DonationProvider>(context);

    return DefaultTabController(
      length: 3, // Three tabs
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recipient Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.list_alt), text: 'All Donations'),
              Tab(icon: Icon(Icons.handshake), text: 'Matched'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Overview
            _buildOverviewTab(donationProvider),

            // Tab 2: All Donations
            const RecipientAllDonationsScreen(),

            // Tab 3: Matched Donations
            const RecipientMatchedDonationsScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(DonationProvider provider) {
    return provider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Welcome Header
                  _buildWelcomeHeader(),

                  // Stats Overview
                  _buildStatsCard(provider),

                  const SizedBox(height: 16),

                  // Quick Actions
                  _buildQuickActions(),

                  const SizedBox(height: 16),

                  // Recent Available Donations
                  _buildRecentDonations(provider),

                  const SizedBox(height: 16),

                  // Accepted Donations
                  _buildAcceptedDonations(provider),
                ],
              ),
            ),
          );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(25),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back! 🍽️',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manage your food donations and help those in need',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(DonationProvider provider) {
    final stats = provider.recipientStatsSummary;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                      'Available', stats['available'] ?? 0, Colors.blue),
                  _buildStatItem(
                      'Matched', stats['matched'] ?? 0, Colors.orange),
                  _buildStatItem(
                      'Accepted', stats['accepted'] ?? 0, Colors.green),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildImpactItem('Total Impact',
                      '${stats['totalMeals'] ?? 0} meals', Icons.people),
                  _buildImpactItem('Success Rate',
                      '${stats['acceptanceRate'] ?? 0}%', Icons.trending_up),
                ],
              ),
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

  Widget _buildImpactItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Card(
              child: InkWell(
                onTap: () {
                  // Navigate to all donations
                  DefaultTabController.of(context).animateTo(1);
                },
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.search, color: Colors.blue),
                      SizedBox(height: 8),
                      Text(
                        'Browse All',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Card(
              child: InkWell(
                onTap: () {
                  // Navigate to matched donations
                  DefaultTabController.of(context).animateTo(2);
                },
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.handshake, color: Colors.orange),
                      SizedBox(height: 8),
                      Text(
                        'My Matches',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Card(
              child: InkWell(
                onTap: () {
                  // Refresh data
                  _loadDashboardData();
                },
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.refresh, color: Colors.green),
                      SizedBox(height: 8),
                      Text(
                        'Refresh',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDonations(DonationProvider provider) {
    final donations = provider.availableDonations.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.new_releases, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Recent Available Donations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (donations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No available donations at the moment',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...donations.map(
                    (donation) => _buildDonationListItem(donation, provider)),
              const SizedBox(height: 8),
              if (donations.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      DefaultTabController.of(context).animateTo(1);
                    },
                    child: const Text('View All →'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedDonations(DonationProvider provider) {
    final donations = provider.donations
        .where((d) => d.status == 'matched' || d.status == 'scheduled')
        .take(3)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Recently Accepted',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (donations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No accepted donations yet',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...donations
                    .map((donation) => _buildAcceptedDonationItem(donation)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonationListItem(Donation donation, DonationProvider provider) {
    return ListTile(
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quantity: ${donation.quantityText}'),
          if (donation.categories.isNotEmpty)
            Text('Categories: ${donation.categories.join(', ')}'),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showDonationDetails(donation, provider),
    );
  }

  Widget _buildAcceptedDonationItem(Donation donation) {
    return ListTile(
      leading: const Icon(Icons.inventory_2, color: Colors.green),
      title: Text(
        donation.displayDescription,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('Status: ${donation.statusText}'),
      trailing: Chip(
        label: Text(donation.statusText),
        backgroundColor: _getStatusColor(donation.status),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'matched':
        return Colors.blue;
      case 'scheduled':
        return Colors.orange;
      case 'picked_up':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatIcon(String label) {
    switch (label.toLowerCase()) {
      case 'available':
        return Icons.list_alt;
      case 'matched':
        return Icons.handshake;
      case 'accepted':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  void _showDonationDetails(Donation donation, DonationProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Donation Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              donation.displayDescription,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Quantity', donation.quantityText),
            _buildDetailRow('Type', donation.type),
            if (donation.categories.isNotEmpty)
              _buildDetailRow('Categories', donation.categories.join(', ')),
            if (donation.tags.isNotEmpty)
              _buildDetailRow('Tags', donation.tags.join(', ')),
            if (donation.aiAnalysis != null) ...[
              const SizedBox(height: 12),
              const Text('AI Analysis:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (donation.aiAnalysis!['freshnessScore'] != null)
                _buildDetailRow('Freshness',
                    '${(donation.aiAnalysis!['freshnessScore'] * 100).toInt()}%'),
              if (donation.aiAnalysis!['safetyWarnings'] != null &&
                  donation.aiAnalysis!['safetyWarnings'].isNotEmpty)
                _buildSafetyWarnings(donation.aiAnalysis!['safetyWarnings']),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _acceptDonation(donation.id!, provider);
                },
                child: const Text('Accept Donation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSafetyWarnings(List<dynamic> warnings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...warnings.map((warning) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(child: Text(warning.toString())),
                ],
              ),
            ))
      ],
    );
  }

  Future<void> _acceptDonation(
      String donationId, DonationProvider provider) async {
    try {
      await provider.acceptDonation(donationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation accepted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDashboardData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept donation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
