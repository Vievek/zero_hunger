import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';

class RecipientMatchedDonationsScreen extends StatefulWidget {
  const RecipientMatchedDonationsScreen({super.key});

  @override
  State<RecipientMatchedDonationsScreen> createState() =>
      _RecipientMatchedDonationsScreenState();
}

class _RecipientMatchedDonationsScreenState
    extends State<RecipientMatchedDonationsScreen> {
  String _selectedStatus = 'offered'; // 'offered', 'accepted', 'declined'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMatchedDonations();
    });
  }

  Future<void> _loadMatchedDonations() async {
    debugPrint("🔄 Loading matched donations with status: $_selectedStatus");
    try {
      await Provider.of<DonationProvider>(context, listen: false)
          .fetchMatchedDonations(status: _selectedStatus);
    } catch (e) {
      debugPrint("❌ Error loading matched donations: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final donationProvider = Provider.of<DonationProvider>(context);

    return Column(
      children: [
        // Status Filter
        _buildStatusFilter(),

        // Donations List
        Expanded(
          child: donationProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildDonationsList(donationProvider),
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Match Status:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildStatusChip('offered', 'Offered', Colors.orange),
              _buildStatusChip('accepted', 'Accepted', Colors.green),
              _buildStatusChip('declined', 'Declined', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String label, Color color) {
    final isSelected = _selectedStatus == status;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatus = status;
          });
          _loadMatchedDonations();
        }
      },
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildDonationsList(DonationProvider provider) {
    final donations = provider.matchedDonations;

    if (donations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadMatchedDonations,
      child: ListView.builder(
        itemCount: donations.length,
        itemBuilder: (context, index) {
          final donation = donations[index];
          return _buildMatchedDonationCard(donation, provider);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_selectedStatus) {
      case 'offered':
        message = 'No donation offers at the moment';
        icon = Icons.handshake;
        break;
      case 'accepted':
        message = 'No accepted donations yet';
        icon = Icons.check_circle;
        break;
      case 'declined':
        message = 'No declined donations';
        icon = Icons.cancel;
        break;
      default:
        message = 'No matched donations';
        icon = Icons.search_off;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (_selectedStatus == 'offered')
            const Text(
              'New offers will appear here when matched with your organization',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadMatchedDonations,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh),
                SizedBox(width: 8),
                Text('Refresh'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedDonationCard(
      Donation donation, DonationProvider provider) {
    final match = _getRecipientMatch(donation);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                donation.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          donation.images.first,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.fastfood,
                                  color: Colors.grey),
                            );
                          },
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fastfood, color: Colors.grey),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donation.displayDescription,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From: ${_getDonorName(donation)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (match != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildMatchScoreChip(match.matchScore),
                            const SizedBox(width: 8),
                            Text(
                              'Match: ${(match.matchScore * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusBadge(_selectedStatus),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.scale, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Quantity: ${donation.quantityText}'),
                const Spacer(),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                // ignore: unnecessary_null_comparison
                if (donation.createdAt != null)
                  Text(
                    _formatDate(donation.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            if (match != null && match.respondedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Responded: ${_formatDate(match.respondedAt ?? DateTime.now())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (_selectedStatus == 'offered')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showDonationDetails(donation, provider),
                      child: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: provider.isLoading
                          ? null
                          : () => _acceptDonation(donation.id!, provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept Offer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _declineDonation(donation.id!, provider),
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Decline Offer',
                  ),
                ],
              )
            else if (_selectedStatus == 'accepted')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showDonationDetails(donation, provider),
                      child: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      donation.statusText.toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(donation.status),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  MatchedRecipient? _getRecipientMatch(Donation donation) {
    // This needs to be implemented based on your data structure
    // For now, return the first match or null
    return donation.matchedRecipients.isNotEmpty
        ? donation.matchedRecipients.first
        : null;
  }

  Widget _buildMatchScoreChip(double score) {
    Color color;
    if (score > 0.8) {
      color = Colors.green;
    } else if (score > 0.6) {
      color = Colors.orange;
    } else {
      color = Colors.blue;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'offered':
        color = Colors.orange;
        text = 'OFFERED';
        break;
      case 'accepted':
        color = Colors.green;
        text = 'ACCEPTED';
        break;
      case 'declined':
        color = Colors.red;
        text = 'DECLINED';
        break;
      default:
        color = Colors.grey;
        text = 'UNKNOWN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
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

  String _getDonorName(Donation donation) {
    if (donation.donor != null && donation.donor!['name'] != null) {
      return donation.donor!['name'];
    }
    return 'Donor';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDonationDetails(Donation donation, DonationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Donation Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                donation.displayDescription,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Donor', _getDonorName(donation)),
              _buildDetailRow('Quantity', donation.quantityText),
              _buildDetailRow('Status', donation.statusText),
              _buildDetailRow('Categories', donation.categories.join(', ')),
              if (donation.aiAnalysis != null) ...[
                const SizedBox(height: 8),
                const Text('AI Analysis:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (donation.aiAnalysis!['safetyWarnings'] != null &&
                    donation.aiAnalysis!['safetyWarnings'].isNotEmpty)
                  _buildSafetyWarnings(donation.aiAnalysis!['safetyWarnings']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          if (_selectedStatus == 'offered')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptDonation(donation.id!, provider);
              },
              child: const Text('ACCEPT OFFER'),
            ),
        ],
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
            width: 80,
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
        const SizedBox(height: 4),
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
            )),
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
        _loadMatchedDonations(); // Refresh the list
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

  Future<void> _declineDonation(
      String donationId, DonationProvider provider) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Donation'),
        content:
            const Text('Are you sure you want to decline this donation offer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // This would call a decline API endpoint
                // For now, we'll just show a message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Donation offer declined'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                _loadMatchedDonations(); // Refresh the list
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to decline donation: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DECLINE'),
          ),
        ],
      ),
    );
  }
}
