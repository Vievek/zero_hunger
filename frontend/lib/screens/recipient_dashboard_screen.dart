import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';
import '../providers/auth_provider.dart';
import 'welcome_screen.dart';

class RecipientDashboardScreen extends StatefulWidget {
  const RecipientDashboardScreen({super.key});

  @override
  State<RecipientDashboardScreen> createState() =>
      _RecipientDashboardScreenState();
}

class _RecipientDashboardScreenState extends State<RecipientDashboardScreen> {
  int _currentPage = 1;
  final int _limit = 10;
  String? _searchQuery;
  List<String>? _selectedCategories;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDonations();
      Provider.of<DonationProvider>(context, listen: false)
          .fetchDonationStats();
    });
  }

  Future<void> _loadDonations() async {
    await Provider.of<DonationProvider>(context, listen: false)
        .fetchAvailableDonations(
      page: _currentPage,
      limit: _limit,
      query: _searchQuery,
      categories: _selectedCategories,
    );
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
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (route) => false,
            );
          },
          child: const Text('Logout', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );}

  @override
  Widget build(BuildContext context) {
    final donationProvider = Provider.of<DonationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipient Dashboard'),
        actions: [
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
                // Welcome Header
                _buildWelcomeHeader(),

                // Search and Filter Section
                _buildSearchSection(),

                // Stats Overview
                _buildStatsCard(donationProvider),

                const SizedBox(height: 16),

                // Donations List
                Expanded(
                  child: _buildDonationsList(
                      donationProvider.availableDonations, donationProvider),
                ),

                // Pagination
                _buildPagination(donationProvider),
              ],
            ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
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
            'Available Donations 🍽️',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Accept donations matched for your organization',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search donations...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.isEmpty ? null : value;
              });
            },
            onSubmitted: (_) => _loadDonations(),
          ),

          const SizedBox(height: 12),

          // Category Filter Chips
          _buildCategoryFilter(),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      'prepared-meal',
      'fruits',
      'vegetables',
      'baked-goods',
      'dairy',
      'meat',
      'seafood',
      'grains',
      'beverages'
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: categories.map((category) {
        final isSelected = _selectedCategories?.contains(category) == true;
        return FilterChip(
          label: Text(category.replaceAll('-', ' ')),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedCategories ??= [];
              if (selected) {
                _selectedCategories!.add(category);
              } else {
                _selectedCategories!.remove(category);
              }
            });
            _loadDonations();
          },
        );
      }).toList(),
    );
  }

  Widget _buildStatsCard(DonationProvider provider) {
   // final stats = provider.donationStatsSummary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                  'Total', provider.availableDonations.length, Colors.blue),
              _buildStatItem(
                'High Match',
                provider.availableDonations
                    .where((d) => _getMaxMatchScore(d) > 0.8)
                    .length,
                Colors.green,
              ),
              _buildStatItem(
                'Urgent',
                provider.availableDonations
                    .where(
                        (d) => d.urgency == 'critical' || d.urgency == 'high')
                    .length,
                Colors.orange,
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

  IconData _getStatIcon(String label) {
    switch (label.toLowerCase()) {
      case 'total':
        return Icons.list_alt;
      case 'high match':
        return Icons.star;
      case 'urgent':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  Widget _buildDonationsList(
      List<Donation> donations, DonationProvider provider) {
    if (donations.isEmpty) {
      return _buildEmptyState(provider);
    }

    return RefreshIndicator(
      onRefresh: _loadDonations,
      child: ListView.builder(
        itemCount: donations.length,
        itemBuilder: (context, index) {
          final donation = donations[index];
          return _buildDonationCard(donation, provider);
        },
      ),
    );
  }

  Widget _buildEmptyState(DonationProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fastfood, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No donations available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery != null || _selectedCategories != null
                ? 'Try adjusting your search filters'
                : 'New donations will appear here when matched with your organization',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_searchQuery != null || _selectedCategories != null)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = null;
                  _selectedCategories = null;
                });
                _loadDonations();
              },
              child: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildDonationCard(Donation donation, DonationProvider provider) {
    final matchScore = _getMaxMatchScore(donation);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Food Image
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
                    ],
                  ),
                ),
                _buildMatchScoreChip(matchScore),
                if (donation.urgency == 'critical' ||
                    donation.urgency == 'high')
                  _buildUrgencyBadge(donation.urgency!),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.scale, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Quantity: ${donation.quantityText}'),
                const Spacer(),
                const Icon(Icons.category, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                if (donation.categories.isNotEmpty)
                  Text(
                    donation.categories.first,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    donation.pickupAddress,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (donation.handlingWindow != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Use by: ${_formatTimeRemaining(donation.handlingWindow!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getTimeRemainingColor(donation.handlingWindow!),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (donation.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: donation.tags
                    .take(3)
                    .map((tag) => Chip(
                          label:
                              Text(tag, style: const TextStyle(fontSize: 10)),
                          backgroundColor: Colors.blue.withAlpha(25),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showDonationDetails(donation),
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
                        : const Text('Accept Donation'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchScoreChip(double score) {
    Color color;
    String text;

    if (score > 0.8) {
      color = Colors.green;
      text = 'High Match';
    } else if (score > 0.6) {
      color = Colors.orange;
      text = 'Good Match';
    } else {
      color = Colors.blue;
      text = 'Match';
    }

    return Chip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
    final color = urgency == 'critical' ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(left: 4),
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

  double _getMaxMatchScore(Donation donation) {
    if (donation.matchedRecipients.isEmpty) return 0.0;
    return donation.matchedRecipients
        .map((match) => match.matchScore ?? 0.0)
        .reduce((a, b) => a > b ? a : b);
  }

  String _getDonorName(Donation donation) {
    if (donation.donor != null && donation.donor!['name'] != null) {
      return donation.donor!['name'];
    }
    return 'Donor';
  }

  String _formatTimeRemaining(Map<String, dynamic> handlingWindow) {
    try {
      final end = DateTime.parse(handlingWindow['end']);
      final now = DateTime.now();
      final difference = end.difference(now);

      if (difference.inDays > 0) {
        return '${difference.inDays} days';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours';
      } else {
        return '${difference.inMinutes} minutes';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getTimeRemainingColor(Map<String, dynamic> handlingWindow) {
    try {
      final end = DateTime.parse(handlingWindow['end']);
      final now = DateTime.now();
      final difference = end.difference(now);

      if (difference.inHours < 2) return Colors.red;
      if (difference.inHours < 6) return Colors.orange;
      return Colors.green;
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildPagination(DonationProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                    _loadDonations();
                  }
                : null,
          ),
          Text('Page $_currentPage'),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: provider.availableDonations.length == _limit
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                    _loadDonations();
                  }
                : null,
          ),
        ],
      ),
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
      }

      // Refresh the list
      _loadDonations();
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

  void _showDonationDetails(Donation donation) {
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
              _buildDetailRow('Categories', donation.categories.join(', ')),
              if (donation.tags.isNotEmpty)
                _buildDetailRow('Tags', donation.tags.join(', ')),
              if (donation.aiAnalysis != null) ...[
                const SizedBox(height: 8),
                const Text('AI Analysis:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (donation.aiAnalysis!['safetyWarnings'] != null &&
                    donation.aiAnalysis!['safetyWarnings'].isNotEmpty)
                  _buildSafetyWarnings(donation.aiAnalysis!['safetyWarnings']),
                if (donation.aiAnalysis!['suggestedHandling'] != null)
                  _buildDetailRow(
                      'Handling', donation.aiAnalysis!['suggestedHandling']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptDonation(donation.id!,
                  Provider.of<DonationProvider>(context, listen: false));
            },
            child: const Text('ACCEPT DONATION'),
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
        ...warnings
            .map((warning) => Padding(
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
            ,
      ],
    );
  }
}
