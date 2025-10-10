import 'package:flutter/foundation.dart';
import '../models/donation_model.dart';
import '../services/api_service.dart';

class DonationProvider with ChangeNotifier {
  final ApiService _apiService =
      ApiService(); // ✅ Now shares singleton instance

  List<Donation> _donations = [];
  bool _isLoading = false;
  String? _error;
  final Map<String, bool> _processingDonations = {};

  List<Donation> get donations => _donations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, bool> get processingDonations => _processingDonations;

  // ❌ REMOVED setAuthToken method - No longer needed with singleton

  Future<void> createDonation(
      Donation donation, List<String> imagePaths) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Upload images first if any
      List<String> imageUrls = [];
      if (imagePaths.isNotEmpty) {
        imageUrls = await _apiService.uploadImages(imagePaths);
      }

      // Create donation with image URLs
      final donationData = donation.toJson();
      donationData['images'] = imageUrls;

      final response = await _apiService.createDonation(donationData);
      final newDonation = Donation.fromJson(response['data']);

      // Add to donations list
      _donations.insert(0, newDonation);

      // Track AI processing status
      if (newDonation.status == 'ai_processing') {
        _processingDonations[newDonation.id!] = true;

        // Start polling for AI completion
        _startPollingDonationStatus(newDonation.id!);
      }

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchMyDonations() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      debugPrint('📦 fetchMyDonations() called');

      // ✅ Check if we have the auth token in this ApiService instance
      debugPrint('📦 About to call _apiService.getMyDonations()');

      final response = await _apiService.getMyDonations();
      _donations = (response['data']['donations'] as List)
          .map((item) => Donation.fromJson(item))
          .toList();

      // Update processing status
      _updateProcessingStatus();

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      debugPrint('📦 ❌ fetchMyDonations ERROR: $error');
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> acceptDonation(String donationId) async {
    try {
      _error = null;
      notifyListeners();

      await _apiService.acceptDonation(donationId);

      // Refresh donations list to get updated status
      await fetchMyDonations();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Donation> getDonationDetails(String donationId) async {
    try {
      final response = await _apiService.getDonationDetails(donationId);
      return Donation.fromJson(response['data']);
    } catch (error) {
      throw Exception('Failed to fetch donation details: $error');
    }
  }

  // Poll donation status for AI processing
  void _startPollingDonationStatus(String donationId) {
    const pollingInterval = Duration(seconds: 5);
    const maxPollingDuration = Duration(minutes: 2); // Stop after 2 minutes

    int pollCount = 0;
    final maxPolls = maxPollingDuration.inSeconds ~/ pollingInterval.inSeconds;

    Future<void> pollStatus() async {
      if (pollCount >= maxPolls) {
        // Stop polling after max duration
        _processingDonations.remove(donationId);
        notifyListeners();
        return;
      }

      await Future.delayed(pollingInterval);

      try {
        final updatedDonation = await getDonationDetails(donationId);

        // Find and update the donation in the list
        final index = _donations.indexWhere((d) => d.id == donationId);
        if (index != -1) {
          _donations[index] = updatedDonation;
        }

        // Check if AI processing is complete
        if (updatedDonation.status != 'ai_processing') {
          _processingDonations.remove(donationId);
        } else {
          // Continue polling
          pollCount++;
          pollStatus();
        }

        notifyListeners();
      } catch (error) {
        debugPrint('Polling error for donation $donationId: $error');
        // Continue polling despite errors
        pollCount++;
        pollStatus();
      }
    }

    // Start polling
    pollStatus();
  }

  // Update processing status for all donations
  void _updateProcessingStatus() {
    _processingDonations.clear();
    for (final donation in _donations) {
      if (donation.status == 'ai_processing') {
        _processingDonations[donation.id!] = true;
        _startPollingDonationStatus(donation.id!);
      }
    }
  }

  // Check if a donation is currently being processed by AI
  bool isProcessing(String donationId) {
    return _processingDonations[donationId] == true;
  }

  // Get donation statistics
  Map<String, int> get donationStats {
    return {
      'total': _donations.length,
      'active': _donations
          .where((d) => ['active', 'matched', 'scheduled'].contains(d.status))
          .length,
      'completed': _donations.where((d) => d.status == 'delivered').length,
      'pending': _donations
          .where((d) => ['pending', 'ai_processing'].contains(d.status))
          .length,
    };
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
