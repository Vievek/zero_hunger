import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/dashboard_appbar.dart';
import 'create_donation_screen.dart';

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
      Provider.of<DonationProvider>(context, listen: false)
          .fetchDonationStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final donationProvider = Provider.of<DonationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateDonationScreen()),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      appBar: const DashboardAppBar(
        title: 'Donor Dashboard',
      ),
      body: donationProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Welcome Header
                _buildWelcomeHeader(authProvider.user?.name ?? 'Donor'),

                // Stats Overview
                _buildStatsCard(donationProvider),

                const SizedBox(height: 16),

                // Donations List
                Expanded(
                  child: _buildDonationsList(
                      donationProvider.donations, donationProvider),
                ),
              ],
            ),
    );
  }

  Widget _buildWelcomeHeader(String userName) {
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
            'Welcome back, $userName! 👋',
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
    final stats = provider.donationStatsSummary;
    final detailedStats = provider.donationStats;

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
                  _buildStatItem('Total', stats['total'] ?? 0, Colors.blue),
                  _buildStatItem('Active', stats['active'] ?? 0, Colors.green),
                  _buildStatItem(
                      'Completed', stats['completed'] ?? 0, Colors.purple),
                  _buildStatItem(
                      'Pending', stats['pending'] ?? 0, Colors.orange),
                ],
              ),
              if (detailedStats.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildImpactItem(
                        'Total Impact',
                        '${detailedStats['totalImpact'] ?? 0} meals',
                        Icons.people),
                    _buildImpactItem(
                        'Total Quantity',
                        '${detailedStats['totalQuantity'] ?? 0} units',
                        Icons.scale),
                  ],
                ),
              ],
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

  Widget _buildDonationsList(
      List<Donation> donations, DonationProvider provider) {
    if (donations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchMyDonations();
        await provider.fetchDonationStats();
      },
      child: ListView.builder(
        itemCount: donations.length,
        itemBuilder: (context, index) {
          final donation = donations[index];
          return _buildDonationCard(donation, provider);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fastfood, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No donations yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first donation to get started!',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CreateDonationScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create First Donation'),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCard(Donation donation, DonationProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildDonationLeading(donation, provider),
        title: Text(
          donation.displayDescription,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
                ],
                if (donation.urgency == 'critical' ||
                    donation.urgency == 'high') ...[
                  const SizedBox(width: 4),
                  _buildUrgencyBadge(donation.urgency!),
                ],
              ],
            ),
          ],
        ),
        trailing: _getStatusIcon(donation.status),
        onTap: () => _showDonationDetails(donation, provider),
      ),
    );
  }

  Widget _buildDonationLeading(Donation donation, DonationProvider provider) {
    if (provider.isProcessing(donation.id!)) {
      return SizedBox(
        width: 50,
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      );
    }

    return donation.images.isNotEmpty
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
      case 'scheduled':
        chipColor = Colors.teal;
        statusText = 'Scheduled';
        break;
      case 'picked_up':
        chipColor = Colors.deepOrange;
        statusText = 'Picked Up';
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

  Widget _buildUrgencyBadge(String urgency) {
    final color = urgency == 'critical' ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        urgency.toUpperCase(),
        style: const TextStyle(
          fontSize: 8,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
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
      case 'scheduled':
        return const Icon(Icons.event, color: Colors.teal);
      case 'picked_up':
        return const Icon(Icons.inventory_2, color: Colors.deepOrange);
      default:
        return const Icon(Icons.pending, color: Colors.grey);
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

            // Donation Image
            if (donation.images.isNotEmpty)
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(donation.images.first),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Donation Information
            _buildDetailItem('Description', donation.displayDescription),
            _buildDetailItem('Status', donation.statusText),
            _buildDetailItem('Quantity', donation.quantityText),
            _buildDetailItem('Type', donation.type),

            if (donation.categories.isNotEmpty)
              _buildDetailItem('Categories', donation.categories.join(', ')),

            if (donation.tags.isNotEmpty)
              _buildDetailItem('Tags', donation.tags.join(', ')),

            if (donation.urgency != null && donation.urgency != 'normal')
              _buildDetailItem(
                  'Priority', '${donation.urgency!.toUpperCase()} PRIORITY'),

            if (donation.aiAnalysis != null) ...[
              const SizedBox(height: 16),
              const Text('AI Analysis:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (donation.aiAnalysis!['freshnessScore'] != null)
                _buildDetailItem('Freshness',
                    '${(donation.aiAnalysis!['freshnessScore'] * 100).toInt()}%'),
              if (donation.aiAnalysis!['suggestedHandling'] != null)
                _buildDetailItem(
                    'Handling', donation.aiAnalysis!['suggestedHandling']),
              if (donation.aiAnalysis!['safetyWarnings'] != null &&
                  donation.aiAnalysis!['safetyWarnings'].isNotEmpty)
                _buildSafetyWarnings(donation.aiAnalysis!['safetyWarnings']),
            ],

            // Matched Recipients
            if (donation.matchedRecipients.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Matched Organizations:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...donation.matchedRecipients
                  .map((match) => _buildRecipientMatch(match))
            ],

            const SizedBox(height: 20),

            // Action Buttons
            if (donation.status == 'active')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _updateDonationStatus(
                      donation.id!, 'cancelled', provider),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Cancel Donation'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
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

  Widget _buildRecipientMatch(dynamic match) {
    final status = match['status'];
    final score = match['matchScore'] ?? 0.0;

    Color statusColor;
    String statusText;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'Accepted';
        break;
      case 'declined':
        statusColor = Colors.red;
        statusText = 'Declined';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Offered';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match['recipient']?['name'] ?? 'Organization',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Match Score: ${(score * 100).toInt()}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(statusText,
                style: const TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: statusColor,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _updateDonationStatus(
      String donationId, String status, DonationProvider provider) async {
    try {
      await provider.updateDonationStatus(donationId, status);

      if (mounted) {
        Navigator.pop(context); // Close the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Donation $status successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update donation: $e')),
        );
      }
    }
  }
}
