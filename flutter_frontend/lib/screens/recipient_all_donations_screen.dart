import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';

class RecipientAllDonationsScreen extends StatefulWidget {
  const RecipientAllDonationsScreen({super.key});

  @override
  State<RecipientAllDonationsScreen> createState() =>
      _RecipientAllDonationsScreenState();
}

class _RecipientAllDonationsScreenState
    extends State<RecipientAllDonationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _selectedCategories = [];
  int _currentPage = 1;
  final int _limit = 10;
  bool _isLoadingMore = false;

  final List<String> _availableCategories = [
    'prepared-meal',
    'fruits',
    'vegetables',
    'baked-goods',
    'dairy',
    'meat',
    'seafood',
    'grains',
    'beverages',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllDonations();
    });
  }

  Future<void> _loadAllDonations() async {
    debugPrint("🔄 Loading all donations...");
    try {
      await Provider.of<DonationProvider>(context, listen: false)
          .fetchAllAvailableDonations(
        page: _currentPage,
        limit: _limit,
        categories: _selectedCategories.isEmpty ? null : _selectedCategories,
        query: _searchController.text.isEmpty ? null : _searchController.text,
      );
    } catch (e) {
      debugPrint("❌ Error loading all donations: $e");
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      await Provider.of<DonationProvider>(context, listen: false)
          .fetchAllAvailableDonations(
        page: _currentPage,
        limit: _limit,
        categories: _selectedCategories.isEmpty ? null : _selectedCategories,
        query: _searchController.text.isEmpty ? null : _searchController.text,
        append: true, // Append to existing list
      );
    } catch (e) {
      debugPrint("❌ Error loading more donations: $e");
      _currentPage--; // Revert page on error
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final donationProvider = Provider.of<DonationProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchSection(),

          // Category Filter
          _buildCategoryFilter(),

          // Donations List
          Expanded(
            child: donationProvider.isLoading && _currentPage == 1
                ? const Center(child: CircularProgressIndicator())
                : _buildDonationsList(donationProvider),
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
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search donations...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _currentPage = 1;
                  _loadAllDonations();
                },
              ),
            ),
            onSubmitted: (value) {
              _currentPage = 1;
              _loadAllDonations();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadAllDonations,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    _selectedCategories.clear();
                    _currentPage = 1;
                    _loadAllDonations();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Category:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _availableCategories.map((category) {
              final isSelected = _selectedCategories.contains(category);
              return FilterChip(
                label: Text(category.replaceAll('-', ' ')),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                  _currentPage = 1;
                  _loadAllDonations();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationsList(DonationProvider provider) {
    final donations = provider.availableDonations;
    final pagination = provider.donationPagination;

    if (donations.isEmpty) {
      return _buildEmptyState(provider);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification &&
            scrollNotification.metrics.pixels ==
                scrollNotification.metrics.maxScrollExtent &&
            pagination['hasNext'] == true &&
            !_isLoadingMore) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: donations.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == donations.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

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
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Donations Found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategories.isNotEmpty || _searchController.text.isNotEmpty
                ? 'Try adjusting your search filters'
                : 'Check back later for new donations',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              _selectedCategories.clear();
              _currentPage = 1;
              _loadAllDonations();
            },
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCard(Donation donation, DonationProvider provider) {
    final matchInfo = _getMatchInfo(donation);

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
                // Food Image
                donation.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          donation.images.first,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
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
                        width: 80,
                        height: 80,
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
                      const SizedBox(height: 4),
                      if (matchInfo != null) ...[
                        _buildMatchScoreChip(matchInfo['score']),
                        if (matchInfo['reasons'] != null &&
                            matchInfo['reasons'].isNotEmpty)
                          Text(
                            'Match reasons: ${matchInfo['reasons'].join(', ')}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green[700]),
                          ),
                      ],
                    ],
                  ),
                ),
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

  Map<String, dynamic>? _getMatchInfo(Donation donation) {
    // Check if this donation is matched with current recipient
    for (final match in donation.matchedRecipients) {
      // This needs to be fixed - we need recipient context
      return {
        'score': match.matchScore,
        'reasons': [], // matchReasons is not available in the current model
        'method': 'ai' // matchingMethod is not available in the current model
      };
    }
    return null;
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
        '$text (${(score * 100).toInt()}%)',
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
              _buildDetailRow('Type', donation.type),
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
              _acceptDonation(donation.id!, provider);
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
        // Refresh the list
        _currentPage = 1;
        _loadAllDonations();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
