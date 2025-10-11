import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String _pendingRequestsKey = 'pending_requests';
  static const String _cachedDataKey = 'cached_data';
  static const String _lastSyncKey = 'last_sync';

  // Store pending requests for when device comes online
  Future<void> storePendingRequest(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingRequests = await getPendingRequests();

      final request = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'endpoint': endpoint,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      };

      pendingRequests.add(request);

      await prefs.setString(_pendingRequestsKey, json.encode(pendingRequests));
      debugPrint('📱 Offline: Stored pending request for $endpoint');
    } catch (error) {
      debugPrint('❌ Offline: Error storing pending request: $error');
    }
  }

  // Get all pending requests
  Future<List<dynamic>> getPendingRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestsJson = prefs.getString(_pendingRequestsKey);

      if (requestsJson != null) {
        return json.decode(requestsJson) as List;
      }
    } catch (error) {
      debugPrint('❌ Offline: Error getting pending requests: $error');
    }

    return [];
  }

  // Remove a pending request (after successful sync)
  Future<void> removePendingRequest(String requestId) async {
    try {
      final pendingRequests = await getPendingRequests();
      final updatedRequests =
          pendingRequests.where((req) => req['id'] != requestId).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingRequestsKey, json.encode(updatedRequests));

      debugPrint('📱 Offline: Removed pending request $requestId');
    } catch (error) {
      debugPrint('❌ Offline: Error removing pending request: $error');
    }
  }

  // Cache data for offline access
  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = await getCachedData();

      cachedData[key] = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_cachedDataKey, json.encode(cachedData));
      debugPrint('📱 Offline: Cached data for key: $key');
    } catch (error) {
      debugPrint('❌ Offline: Error caching data: $error');
    }
  }

  // Get cached data
  Future<Map<String, dynamic>> getCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataJson = prefs.getString(_cachedDataKey);

      if (cachedDataJson != null) {
        return Map<String, dynamic>.from(json.decode(cachedDataJson));
      }
    } catch (error) {
      debugPrint('❌ Offline: Error getting cached data: $error');
    }

    return {};
  }

  // Get specific cached item
  Future<dynamic> getCachedItem(String key) async {
    try {
      final cachedData = await getCachedData();
      final item = cachedData[key];

      if (item != null) {
        final timestamp = DateTime.parse(item['timestamp']);
        final age = DateTime.now().difference(timestamp);

        // Return data if it's less than 1 hour old
        if (age.inHours < 1) {
          debugPrint('📱 Offline: Using cached data for: $key');
          return item['data'];
        } else {
          // Remove expired cache
          await removeCachedItem(key);
        }
      }
    } catch (error) {
      debugPrint('❌ Offline: Error getting cached item: $error');
    }

    return null;
  }

  // Remove cached item
  Future<void> removeCachedItem(String key) async {
    try {
      final cachedData = await getCachedData();
      cachedData.remove(key);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedDataKey, json.encode(cachedData));

      debugPrint('📱 Offline: Removed cached item: $key');
    } catch (error) {
      debugPrint('❌ Offline: Error removing cached item: $error');
    }
  }

  // Store last sync timestamp
  Future<void> setLastSync(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, timestamp.toIso8601String());
    } catch (error) {
      debugPrint('❌ Offline: Error setting last sync: $error');
    }
  }

  // Get last sync timestamp
  Future<DateTime?> getLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(_lastSyncKey);

      if (lastSyncString != null) {
        return DateTime.parse(lastSyncString);
      }
    } catch (error) {
      debugPrint('❌ Offline: Error getting last sync: $error');
    }

    return null;
  }

  // Check if data is stale (older than maxAge)
  Future<bool> isDataStale(String key, Duration maxAge) async {
    try {
      final cachedData = await getCachedData();
      final item = cachedData[key];

      if (item != null) {
        final timestamp = DateTime.parse(item['timestamp']);
        final age = DateTime.now().difference(timestamp);
        return age > maxAge;
      }
    } catch (error) {
      debugPrint('❌ Offline: Error checking data staleness: $error');
    }

    return true; // Consider stale if no data exists
  }

  // Store donor donations for offline access
  Future<void> cacheDonorDonations(List<dynamic> donations) async {
    await cacheData('donor_donations', donations);
  }

  // Get cached donor donations
  Future<List<dynamic>> getCachedDonorDonations() async {
    final cached = await getCachedItem('donor_donations');
    return cached != null ? List<dynamic>.from(cached) : [];
  }

  // Store volunteer tasks for offline access
  Future<void> cacheVolunteerTasks(List<dynamic> tasks) async {
    await cacheData('volunteer_tasks', tasks);
  }

  // Get cached volunteer tasks
  Future<List<dynamic>> getCachedVolunteerTasks() async {
    final cached = await getCachedItem('volunteer_tasks');
    return cached != null ? List<dynamic>.from(cached) : [];
  }

  // Store available donations for offline access
  Future<void> cacheAvailableDonations(List<dynamic> donations) async {
    await cacheData('available_donations', donations);
  }

  // Get cached available donations
  Future<List<dynamic>> getCachedAvailableDonations() async {
    final cached = await getCachedItem('available_donations');
    return cached != null ? List<dynamic>.from(cached) : [];
  }

  // Store user profile for offline access
  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    await cacheData('user_profile', profile);
  }

  // Get cached user profile
  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    final cached = await getCachedItem('user_profile');
    return cached != null ? Map<String, dynamic>.from(cached) : null;
  }

  // Check if device is likely offline (simple implementation)
  Future<bool> isOffline() async {
    // This is a simplified check
    // In a real app, you'd use connectivity_plus package or similar
    final lastSync = await getLastSync();
    if (lastSync != null) {
      final timeSinceLastSync = DateTime.now().difference(lastSync);
      return timeSinceLastSync.inMinutes > 5; // Offline if no sync in 5 minutes
    }
    return false;
  }

  // Clear all offline data
  Future<void> clearAllOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingRequestsKey);
      await prefs.remove(_cachedDataKey);
      await prefs.remove(_lastSyncKey);

      debugPrint('📱 Offline: Cleared all offline data');
    } catch (error) {
      debugPrint('❌ Offline: Error clearing offline data: $error');
    }
  }

  // Get offline storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final pendingRequests = await getPendingRequests();
      final cachedData = await getCachedData();
      final lastSync = await getLastSync();

      return {
        'pendingRequests': pendingRequests.length,
        'cachedItems': cachedData.length,
        'lastSync': lastSync?.toIso8601String(),
        'totalStorageSize':
            'N/A', // Would need to calculate actual storage size
      };
    } catch (error) {
      debugPrint('❌ Offline: Error getting storage stats: $error');
      return {};
    }
  }

  // Sync pending requests when back online
  Future<void> syncPendingRequests(
      Function(String, Map<String, dynamic>) syncFunction) async {
    try {
      final pendingRequests = await getPendingRequests();
      debugPrint(
          '📱 Offline: Syncing ${pendingRequests.length} pending requests');

      for (final request in pendingRequests) {
        try {
          await syncFunction(request['endpoint'], request['data']);
          await removePendingRequest(request['id']);
          debugPrint(
              '📱 Offline: Successfully synced request ${request['id']}');
        } catch (error) {
          debugPrint(
              '❌ Offline: Failed to sync request ${request['id']}: $error');

          // Increment retry count
          final updatedRequests = await getPendingRequests();
          final requestIndex =
              updatedRequests.indexWhere((req) => req['id'] == request['id']);
          if (requestIndex != -1) {
            updatedRequests[requestIndex]['retryCount'] =
                (updatedRequests[requestIndex]['retryCount'] ?? 0) + 1;

            // Remove if too many retries
            if (updatedRequests[requestIndex]['retryCount'] > 3) {
              updatedRequests.removeAt(requestIndex);
              debugPrint(
                  '📱 Offline: Removed request ${request['id']} after 3 failed retries');
            }

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
                _pendingRequestsKey, json.encode(updatedRequests));
          }
        }

        // Small delay between requests to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await setLastSync(DateTime.now());
      debugPrint('📱 Offline: Sync completed');
    } catch (error) {
      debugPrint('❌ Offline: Error during sync: $error');
    }
  }
}
