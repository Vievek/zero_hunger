import 'package:flutter/foundation.dart';
import '../models/donation_model.dart';
import '../services/api_service.dart';

class DonationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Donation> _donations = [];
  bool _isLoading = false;
  String? _error;

  List<Donation> get donations => _donations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> createDonation(
    Donation donation,
    List<String> imagePaths,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Upload images first
      final List<String> imageUrls = [];
      for (final path in imagePaths) {
        final url = await _apiService.uploadImage(path);
        imageUrls.add(url);
      }

      // Create donation with image URLs
      final donationData = donation.toJson();
      donationData['images'] = imageUrls;

      await _apiService.createDonation(donationData);

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

      final response = await _apiService.getMyDonations();
      _donations = (response['data']['donations'] as List)
          .map((item) => Donation.fromJson(item))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (error) {
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

      // Refresh donations list
      await fetchMyDonations();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Get donation statistics
  Map<String, int> get donationStats {
    return {
      'total': _donations.length,
      'active': _donations
          .where((d) => ['active', 'matched'].contains(d.status))
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
