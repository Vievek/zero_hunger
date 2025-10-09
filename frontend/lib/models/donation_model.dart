class Donation {
  final String? id;
  final String donorId;
  final String type; // 'normal' or 'bulk'
  final String status;
  final List<String> images;
  final String? aiDescription;
  final List<String> categories;
  final List<String> tags;
  final Map<String, dynamic> quantity;
  final Map<String, dynamic>? handlingWindow;
  final String? expectedQuantity; // For bulk donations
  final DateTime? scheduledPickup;
  final String pickupAddress;
  final Map<String, dynamic> location;
  final Map<String, dynamic>? aiAnalysis;
  final List<dynamic> matchedRecipients;
  final String? acceptedBy;
  final String? assignedVolunteer;
  final DateTime createdAt;

  Donation({
    this.id,
    required this.donorId,
    required this.type,
    required this.status,
    required this.images,
    this.aiDescription,
    required this.categories,
    required this.tags,
    required this.quantity,
    this.handlingWindow,
    this.expectedQuantity,
    this.scheduledPickup,
    required this.pickupAddress,
    required this.location,
    this.aiAnalysis,
    this.matchedRecipients = const [],
    this.acceptedBy,
    this.assignedVolunteer,
    required this.createdAt,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['_id'],
      donorId: json['donor'],
      type: json['type'],
      status: json['status'],
      images: List<String>.from(json['images'] ?? []),
      aiDescription: json['aiDescription'],
      categories: List<String>.from(json['categories'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      quantity: Map<String, dynamic>.from(json['quantity'] ?? {}),
      handlingWindow: json['handlingWindow'] != null
          ? Map<String, dynamic>.from(json['handlingWindow'])
          : null,
      expectedQuantity: json['expectedQuantity'],
      scheduledPickup: json['scheduledPickup'] != null
          ? DateTime.parse(json['scheduledPickup'])
          : null,
      pickupAddress: json['pickupAddress'],
      location: Map<String, dynamic>.from(json['location'] ?? {}),
      aiAnalysis: json['aiAnalysis'] != null
          ? Map<String, dynamic>.from(json['aiAnalysis'])
          : null,
      matchedRecipients: json['matchedRecipients'] ?? [],
      acceptedBy: json['acceptedBy'],
      assignedVolunteer: json['assignedVolunteer'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'images': images,
      'quantity': quantity,
      'expectedQuantity': expectedQuantity,
      'scheduledPickup': scheduledPickup?.toIso8601String(),
      'pickupAddress': pickupAddress,
      'location': location,
      'categories': categories,
      'tags': tags,
    };
  }

  // Helper methods
  bool get isNormal => type == 'normal';
  bool get isBulk => type == 'bulk';
  bool get isPending => status == 'pending';
  bool get isAiProcessing => status == 'ai_processing';
  bool get isActive => status == 'active';
  bool get isMatched => status == 'matched';
  bool get isScheduled => status == 'scheduled';
  bool get isDelivered => status == 'delivered';

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'ai_processing':
        return 'AI Processing';
      case 'active':
        return 'Active - Seeking Recipients';
      case 'matched':
        return 'Matched with Recipient';
      case 'scheduled':
        return 'Scheduled for Pickup';
      case 'picked_up':
        return 'Picked Up';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  // AI analysis helpers
  String get displayDescription {
    return aiDescription ?? 'Food Donation';
  }

  String get quantityText {
    final amount = quantity['amount']?.toString() ?? '0';
    final unit = quantity['unit']?.toString() ?? 'units';
    return '$amount $unit';
  }

  bool get hasAiAnalysis => aiAnalysis != null;

  double? get freshnessScore {
    return aiAnalysis?['freshnessScore']?.toDouble();
  }

  List<String> get allergens {
    return aiAnalysis?['allergens']?.cast<String>() ?? [];
  }

  List<String> get safetyWarnings {
    return aiAnalysis?['safetyWarnings']?.cast<String>() ?? [];
  }

  String get suggestedHandling {
    return aiAnalysis?['suggestedHandling'] ??
        'Handle with standard food safety precautions';
  }
}
