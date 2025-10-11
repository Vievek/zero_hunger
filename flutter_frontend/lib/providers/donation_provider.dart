import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/donation_model.dart';
import '../services/api_service.dart';

class DonationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Donation> _donations = [];
  List<Donation> _availableDonations = [];
  bool _isLoading = false;
  String? _error;
  final Map<String, bool> _processingDonations = {};
  Map<String, dynamic> _donationStats = {};

  List<Donation> get donations => _donations;
  List<Donation> get availableDonations => _availableDonations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get donationStats => _donationStats;

  Future<Map<String, dynamic>> analyzeFoodImages(List<File> imageFiles) async {
    try {
      // Upload images first
      List<String> imageUrls = await uploadImages(imageFiles);

      // Call backend AI analysis endpoint
      final response = await _apiService.analyzeFoodImages(imageUrls);
      return response['data'];
    } catch (error) {
      throw Exception('Failed to analyze images: $error');
    }
  }

  Future<List<String>> uploadImages(List<File> imageFiles) async {
    try {
      final response = await _apiService.uploadImages(imageFiles);
      return List<String>.from(response['data']['images']);
    } catch (error) {
      throw Exception('Failed to upload images: $error');
    }
  }

  Future<void> createDonation(Donation donation, List<File> imageFiles) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Upload images first
      List<String> imageUrls = [];
      if (imageFiles.isNotEmpty) {
        imageUrls = await uploadImages(imageFiles);
      }

      // Create donation with enhanced data
      final donationData = donation.toJson();
      donationData['images'] = imageUrls;

      // Add description if available
      if (donation.description != null && donation.description!.isNotEmpty) {
        donationData['description'] = donation.description;
      }

      final response = await _apiService.createDonation(donationData);
      debugPrint('🌐 Create Donation Response in provider: $response');

      // Handle the response properly
      if (response['success'] == true) {
        final newDonation = Donation.fromJson(response['data']);
        debugPrint('🌐 New Donation Created: ${newDonation.id}');

        _donations.insert(0, newDonation);
        _processingDonations[newDonation.id!] = true;

        _isLoading = false;
        notifyListeners();

        // Start polling for AI processing status if images were uploaded
        if (imageFiles.isNotEmpty) {
          _startPollingDonationStatus(newDonation.id!);
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to create donation');
      }
    } catch (error) {
      _isLoading = false;
      debugPrint('❌ Error creating donation: $error');
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

      _updateProcessingStatus();
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchAvailableDonations({
    int page = 1,
    int limit = 10,
    String? query,
    List<String>? categories,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.getAvailableDonations(
        page: page,
        limit: limit,
        query: query,
        categories: categories,
      );

      _availableDonations = (response['data']['donations'] as List)
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

      // Remove from available donations and add to my donations
      final acceptedDonationIndex =
          _availableDonations.indexWhere((d) => d.id == donationId);
      if (acceptedDonationIndex != -1) {
        final acceptedDonation = _availableDonations[acceptedDonationIndex];
        _availableDonations.removeAt(acceptedDonationIndex);
        _donations.insert(0, acceptedDonation.copyWith(status: 'matched'));
      }

      notifyListeners();
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

  Future<void> updateDonationStatus(String donationId, String status) async {
    try {
      await _apiService.updateDonationStatus(donationId, status);

      // Update local state
      final donationIndex = _donations.indexWhere((d) => d.id == donationId);
      if (donationIndex != -1) {
        _donations[donationIndex] =
            _donations[donationIndex].copyWith(status: status);
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Failed to update donation status: $error');
      }
      rethrow;
    }
  }

  Future<void> fetchDonationStats() async {
    try {
      final response = await _apiService.getDonationStats();
      _donationStats = Map<String, dynamic>.from(response['data']);
      notifyListeners();
    } catch (error) {
      if (kDebugMode) {
        print('Failed to fetch donation stats: $error');
      }
    }
  }

  Future<List<Donation>> searchDonations(
    String query, {
    List<String>? categories,
    double? maxDistance,
  }) async {
    try {
      final response = await _apiService.searchDonations(
        query,
        categories: categories,
        maxDistance: maxDistance,
      );
      return (response['data'] as List)
          .map((item) => Donation.fromJson(item))
          .toList();
    } catch (error) {
      rethrow;
    }
  }

  void _startPollingDonationStatus(String donationId) {
    // Implement polling logic for AI processing status
    // This would periodically check the donation status until AI processing is complete
    Future.delayed(const Duration(seconds: 5), () async {
      if (_processingDonations[donationId] == true) {
        try {
          final updatedDonation = await getDonationDetails(donationId);
          final donationIndex =
              _donations.indexWhere((d) => d.id == donationId);
          if (donationIndex != -1) {
            _donations[donationIndex] = updatedDonation;
            notifyListeners();
          }

          // Continue polling if still processing
          if (updatedDonation.status == 'ai_processing') {
            _startPollingDonationStatus(donationId);
          } else {
            _processingDonations.remove(donationId);
          }
        } catch (error) {
          if (kDebugMode) {
            print('Error polling donation status: $error');
          }
          // Stop polling on error
          _processingDonations.remove(donationId);
        }
      }
    });
  }

  void _updateProcessingStatus() {
    _processingDonations.clear();
    for (final donation in _donations) {
      if (donation.status == 'ai_processing') {
        _processingDonations[donation.id!] = true;
        _startPollingDonationStatus(donation.id!);
      }
    }
  }

  bool isProcessing(String donationId) {
    return _processingDonations[donationId] == true;
  }

  Map<String, int> get donationStatsSummary {
    // Use backend stats if available, fallback to local calculation
    if (_donationStats.isNotEmpty) {
      return {
        'total': _donationStats['total'] ?? 0,
        'active': _donationStats['active'] ?? 0,
        'completed': _donationStats['completed'] ?? 0,
        'pending': _donationStats['pending'] ?? 0,
      };
    }

    // Fallback to local calculation if backend stats not available
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

  // Helper getters
  List<Donation> get activeDonations => _donations
      .where((d) => ['active', 'matched', 'scheduled'].contains(d.status))
      .toList();

  List<Donation> get completedDonations =>
      _donations.where((d) => d.status == 'delivered').toList();

  List<Donation> get pendingDonations => _donations
      .where((d) => ['pending', 'ai_processing'].contains(d.status))
      .toList();

  List<Donation> get expiringSoonDonations =>
      _donations.where((d) => d.isActive && d.isExpiringSoon).toList();

  Donation? getDonationById(String donationId) {
    try {
      return _donations.firstWhere((d) => d.id == donationId);
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refresh specific donation
  Future<void> refreshDonation(String donationId) async {
    try {
      final updatedDonation = await getDonationDetails(donationId);
      final donationIndex = _donations.indexWhere((d) => d.id == donationId);
      if (donationIndex != -1) {
        _donations[donationIndex] = updatedDonation;
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Failed to refresh donation: $error');
      }
    }
  }
}
