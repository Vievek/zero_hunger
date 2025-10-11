import 'package:flutter/foundation.dart';
import '../models/logistics_model.dart';
import '../services/api_service.dart';

class LogisticsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService(); // ✅ Use singleton instance

  List<LogisticsTask> _tasks = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _volunteerStats = {};
  final Map<String, bool> _updatingTasks = {};

  List<LogisticsTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get volunteerStats => _volunteerStats;
  bool isUpdating(String taskId) => _updatingTasks[taskId] == true;

  Future<void> fetchMyTasks() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.getMyTasks();
      _tasks = (response['data'] as List)
          .map((item) => LogisticsTask.fromJson(item))
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

  Future<void> updateTaskStatus(String taskId, String status,
      {Map<String, dynamic>? additionalData}) async {
    try {
      _updatingTasks[taskId] = true;
      _error = null;
      notifyListeners();

      final updateData = <String, dynamic>{'status': status};
      if (additionalData != null) {
        updateData.addAll(additionalData);
      }

      await _apiService.updateTaskStatus(taskId, status);

      // Update local state immediately for better UX
      final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
      if (taskIndex != -1) {
        _tasks[taskIndex] = LogisticsTask(
          id: _tasks[taskIndex].id,
          donationId: _tasks[taskIndex].donationId,
          volunteerId: _tasks[taskIndex].volunteerId,
          status: status,
          pickupLocation: _tasks[taskIndex].pickupLocation,
          dropoffLocation: _tasks[taskIndex].dropoffLocation,
          optimizedRoute: _tasks[taskIndex].optimizedRoute,
          scheduledPickupTime: _tasks[taskIndex].scheduledPickupTime,
          actualPickupTime: status == 'picked_up'
              ? DateTime.now()
              : _tasks[taskIndex].actualPickupTime,
          actualDeliveryTime: status == 'delivered'
              ? DateTime.now()
              : _tasks[taskIndex].actualDeliveryTime,
          routeSequence: _tasks[taskIndex].routeSequence,
          createdAt: _tasks[taskIndex].createdAt,
        );
      }

      _updatingTasks[taskId] = false;
      notifyListeners();
    } catch (error) {
      _updatingTasks[taskId] = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOptimizedRoute(String taskId) async {
    try {
      final response = await _apiService.getOptimizedRoute(taskId);
      return response['data'];
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateVolunteerLocation(double lat, double lng,
      {String? address}) async {
    try {
      await _apiService.updateVolunteerLocation(lat, lng, address: address);
    } catch (error) {
      if (kDebugMode) {
        print('Failed to update location: $error');
      }
      // Don't throw error for location updates to avoid breaking main functionality
    }
  }

  Future<void> fetchVolunteerStats() async {
    try {
      final response = await _apiService.getVolunteerStats();
      _volunteerStats = Map<String, dynamic>.from(response['data']);
      notifyListeners();
    } catch (error) {
      if (kDebugMode) {
        print('Failed to fetch volunteer stats: $error');
      }
    }
  }

  Future<Map<String, dynamic>> getTaskDetails(String taskId) async {
    try {
      final response = await _apiService.getTaskDetails(taskId);
      return response['data'];
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateSafetyChecklist(
      String taskId, List<Map<String, dynamic>> checklist) async {
    try {
      await _apiService.updateSafetyChecklist(taskId, checklist);

      // Update local task if it exists
      final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
      if (taskIndex != -1) {
        // Note: This would require adding safetyChecklist to LogisticsTask model
        notifyListeners();
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRouteUpdate(
      String taskId, double currentLat, double currentLng) async {
    try {
      final response =
          await _apiService.getRouteUpdate(taskId, currentLat, currentLng);
      return response['data'];
    } catch (error) {
      rethrow;
    }
  }

  Future<void> submitTaskFeedback(
    String taskId, {
    required int rating,
    String? feedback,
    int? completionTime,
  }) async {
    try {
      await _apiService.submitTaskFeedback(
        taskId,
        rating: rating,
        feedback: feedback,
        completionTime: completionTime,
      );
    } catch (error) {
      rethrow;
    }
  }

  Future<void> fetchPerformanceMetrics() async {
    try {
      final response = await _apiService.getPerformanceMetrics();
      _volunteerStats = Map<String, dynamic>.from(response['data']);
      notifyListeners();
    } catch (error) {
      if (kDebugMode) {
        print('Failed to fetch performance metrics: $error');
      }
    }
  }

  // Helper methods
  List<LogisticsTask> get pendingTasks =>
      _tasks.where((task) => task.isPending).toList();
  List<LogisticsTask> get assignedTasks =>
      _tasks.where((task) => task.isAssigned).toList();
  List<LogisticsTask> get inProgressTasks =>
      _tasks.where((task) => task.isPickedUp || task.isInTransit).toList();
  List<LogisticsTask> get completedTasks =>
      _tasks.where((task) => task.isDelivered).toList();

  Map<String, int> get taskStats {
    return {
      'total': _tasks.length,
      'assigned': assignedTasks.length,
      'in_progress': inProgressTasks.length,
      'completed': completedTasks.length,
    };
  }

  LogisticsTask? getTaskById(String taskId) {
    try {
      return _tasks.firstWhere((task) => task.id == taskId);
    } catch (e) {
      return null;
    }
  }

  List<LogisticsTask> getUrgentTasks() {
    return _tasks.where((task) {
      // This would need to be implemented with actual task details
      // For now, return all tasks as a placeholder
      return true;
    }).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refresh specific task
  Future<void> refreshTask(String taskId) async {
    try {
      final updatedTaskData = await getTaskDetails(taskId);
      final updatedTask = LogisticsTask.fromJson(updatedTaskData);

      final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
      if (taskIndex != -1) {
        _tasks[taskIndex] = updatedTask;
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Failed to refresh task: $error');
      }
    }
  }
}
