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
