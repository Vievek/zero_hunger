class LogisticsTask {
  final String? id;
  final String donationId;
  final String? volunteerId;
  final String status;
  final Map<String, dynamic> pickupLocation;
  final Map<String, dynamic> dropoffLocation;
  final Map<String, dynamic>? optimizedRoute;
  final DateTime? scheduledPickupTime;
  final DateTime? actualPickupTime;
  final DateTime? actualDeliveryTime;
  final int? routeSequence;
  final DateTime createdAt;

  LogisticsTask({
    this.id,
    required this.donationId,
    this.volunteerId,
    required this.status,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.optimizedRoute,
    this.scheduledPickupTime,
    this.actualPickupTime,
    this.actualDeliveryTime,
    this.routeSequence,
    required this.createdAt,
  });

  factory LogisticsTask.fromJson(Map<String, dynamic> json) {
    return LogisticsTask(
      id: json['_id'],
      donationId: json['donation'],
      volunteerId: json['volunteer'],
      status: json['status'],
      pickupLocation: Map<String, dynamic>.from(json['pickupLocation']),
      dropoffLocation: Map<String, dynamic>.from(json['dropoffLocation']),
      optimizedRoute: json['optimizedRoute'] != null
          ? Map<String, dynamic>.from(json['optimizedRoute'])
          : null,
      scheduledPickupTime: json['scheduledPickupTime'] != null
          ? DateTime.parse(json['scheduledPickupTime'])
          : null,
      actualPickupTime: json['actualPickupTime'] != null
          ? DateTime.parse(json['actualPickupTime'])
          : null,
      actualDeliveryTime: json['actualDeliveryTime'] != null
          ? DateTime.parse(json['actualDeliveryTime'])
          : null,
      routeSequence: json['routeSequence'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // Add copyWith method
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
    );
  }

  // Helper methods
  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isPickedUp => status == 'picked_up';
  bool get isInTransit => status == 'in_transit';
  bool get isDelivered => status == 'delivered';

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending Assignment';
      case 'assigned':
        return 'Assigned';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}
