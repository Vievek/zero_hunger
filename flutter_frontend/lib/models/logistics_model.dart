import 'package:flutter/foundation.dart';
import 'dart:math' as math; // Add this import

@immutable
class LogisticsTask {
  final String? id;
  final String? donationId;
  final String? volunteerId;
  final String status;
  final Map<String, dynamic> pickupLocation;
  final Map<String, dynamic> dropoffLocation;
  final Map<String, dynamic>? optimizedRoute;
  final DateTime? scheduledPickupTime;
  final DateTime? actualPickupTime;
  final DateTime? actualDeliveryTime;
  final int? routeSequence;
  final DateTime? createdAt;
  final String? urgency;
  final String? specialInstructions;
  final List<String>? requiredEquipment;
  final List<dynamic>? safetyChecklist;

  const LogisticsTask({
    this.id,
    this.donationId,
    this.volunteerId,
    required this.status,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.optimizedRoute,
    this.scheduledPickupTime,
    this.actualPickupTime,
    this.actualDeliveryTime,
    this.routeSequence,
    this.createdAt,
    this.urgency,
    this.specialInstructions,
    this.requiredEquipment,
    this.safetyChecklist,
  });

  factory LogisticsTask.fromJson(Map<String, dynamic> json) {
    // Handle pickup location with null safety
    final pickupLocation = json['pickupLocation'] ?? {};
    final dropoffLocation = json['dropoffLocation'] ?? {};

    // Parse dates safely
    DateTime? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is DateTime) return date;
      if (date is String) {
        try {
          return DateTime.parse(date);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return LogisticsTask(
      id: json['_id']?.toString(),
      donationId: json['donation']?.toString(),
      volunteerId: json['volunteer']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      pickupLocation: {
        'address': (pickupLocation['address'] ?? 'Unknown Address').toString(),
        'lat': (pickupLocation['lat'] ?? 0.0).toDouble(),
        'lng': (pickupLocation['lng'] ?? 0.0).toDouble(),
        'instructions': pickupLocation['instructions']?.toString(),
      },
      dropoffLocation: {
        'address': (dropoffLocation['address'] ?? 'Unknown Address').toString(),
        'lat': (dropoffLocation['lat'] ?? 0.0).toDouble(),
        'lng': (dropoffLocation['lng'] ?? 0.0).toDouble(),
        'contactPerson': dropoffLocation['contactPerson']?.toString(),
        'phone': dropoffLocation['phone']?.toString(),
      },
      optimizedRoute: json['optimizedRoute'] is Map
          ? Map<String, dynamic>.from(json['optimizedRoute'])
          : null,
      scheduledPickupTime: parseDate(json['scheduledPickupTime']),
      actualPickupTime: parseDate(json['actualPickupTime']),
      actualDeliveryTime: parseDate(json['actualDeliveryTime']),
      routeSequence:
          json['routeSequence'] is int ? json['routeSequence'] : null,
      createdAt: parseDate(json['createdAt']),
      urgency: json['urgency']?.toString(),
      specialInstructions: json['specialInstructions']?.toString(),
      requiredEquipment: json['requiredEquipment'] is List
          ? List<String>.from(json['requiredEquipment'] ?? [])
          : [],
      safetyChecklist: json['safetyChecklist'] is List
          ? List<dynamic>.from(json['safetyChecklist'] ?? [])
          : [],
    );
  }

  LogisticsTask copyWith({
    String? id,
    String? donationId,
    String? volunteerId,
    String? status,
    Map<String, dynamic>? pickupLocation,
    Map<String, dynamic>? dropoffLocation,
    Map<String, dynamic>? optimizedRoute,
    DateTime? scheduledPickupTime,
    DateTime? actualPickupTime,
    DateTime? actualDeliveryTime,
    int? routeSequence,
    DateTime? createdAt,
    String? urgency,
    String? specialInstructions,
    List<String>? requiredEquipment,
    List<dynamic>? safetyChecklist,
  }) {
    return LogisticsTask(
      id: id ?? this.id,
      donationId: donationId ?? this.donationId,
      volunteerId: volunteerId ?? this.volunteerId,
      status: status ?? this.status,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      optimizedRoute: optimizedRoute ?? this.optimizedRoute,
      scheduledPickupTime: scheduledPickupTime ?? this.scheduledPickupTime,
      actualPickupTime: actualPickupTime ?? this.actualPickupTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
      routeSequence: routeSequence ?? this.routeSequence,
      createdAt: createdAt ?? this.createdAt,
      urgency: urgency ?? this.urgency,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      safetyChecklist: safetyChecklist ?? this.safetyChecklist,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (donationId != null) 'donation': donationId,
      if (volunteerId != null) 'volunteer': volunteerId,
      'status': status,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      if (optimizedRoute != null) 'optimizedRoute': optimizedRoute,
      if (scheduledPickupTime != null)
        'scheduledPickupTime': scheduledPickupTime!.toIso8601String(),
      if (actualPickupTime != null)
        'actualPickupTime': actualPickupTime!.toIso8601String(),
      if (actualDeliveryTime != null)
        'actualDeliveryTime': actualDeliveryTime!.toIso8601String(),
      if (routeSequence != null) 'routeSequence': routeSequence,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (urgency != null) 'urgency': urgency,
      if (specialInstructions != null)
        'specialInstructions': specialInstructions,
      if (requiredEquipment != null) 'requiredEquipment': requiredEquipment,
      if (safetyChecklist != null) 'safetyChecklist': safetyChecklist,
    };
  }

  // Helper getters
  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isPickedUp => status == 'picked_up';
  bool get isInTransit => status == 'in_transit';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';

  // Distance calculation helper
  double? calculateDistanceFrom(double lat, double lng) {
    try {
      final pickupLat = pickupLocation['lat'] ?? 0.0;
      final pickupLng = pickupLocation['lng'] ?? 0.0;

      if (pickupLat == 0.0 || pickupLng == 0.0) return null;

      return _calculateDistance(lat, lng, pickupLat, pickupLng);
    } catch (e) {
      return null;
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogisticsTask && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
