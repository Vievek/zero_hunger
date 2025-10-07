import 'package:flutter/foundation.dart';
import '../models/logistics_model.dart';
import '../services/api_service.dart';

class LogisticsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<LogisticsTask> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<LogisticsTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

  Future<void> updateTaskStatus(String taskId, String status) async {
    try {
      _error = null;
      notifyListeners();

      await _apiService.updateTaskStatus(taskId, status);

      // Refresh tasks list
      await fetchMyTasks();
    } catch (error) {
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

  // Get task statistics
  Map<String, int> get taskStats {
    return {
      'total': _tasks.length,
      'assigned': _tasks.where((t) => t.isAssigned).length,
      'in_progress': _tasks.where((t) => t.isPickedUp || t.isInTransit).length,
      'completed': _tasks.where((t) => t.isDelivered).length,
    };
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
