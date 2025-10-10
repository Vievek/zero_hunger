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
  final Map<String, dynamic>? donor; // Added donor field
  final String? urgency; // Added urgency field
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
    this.donor,
    this.urgency,
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
      donor: json['donor'] != null
          ? Map<String, dynamic>.from(json['donor'])
          : null,
      urgency: json['urgency'],
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
      'urgency': urgency,
    };
  }

  // CopyWith method for immutability
  Donation copyWith({
    String? id,
    String? donorId,
    String? type,
    String? status,
    List<String>? images,
    String? aiDescription,
    List<String>? categories,
    List<String>? tags,
    Map<String, dynamic>? quantity,
    Map<String, dynamic>? handlingWindow,
    String? expectedQuantity,
    DateTime? scheduledPickup,
    String? pickupAddress,
    Map<String, dynamic>? location,
    Map<String, dynamic>? aiAnalysis,
    List<dynamic>? matchedRecipients,
    String? acceptedBy,
    String? assignedVolunteer,
    Map<String, dynamic>? donor,
    String? urgency,
    DateTime? createdAt,
  }) {
    return Donation(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      type: type ?? this.type,
      status: status ?? this.status,
      images: images ?? this.images,
      aiDescription: aiDescription ?? this.aiDescription,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      quantity: quantity ?? this.quantity,
      handlingWindow: handlingWindow ?? this.handlingWindow,
      expectedQuantity: expectedQuantity ?? this.expectedQuantity,
      scheduledPickup: scheduledPickup ?? this.scheduledPickup,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      location: location ?? this.location,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      matchedRecipients: matchedRecipients ?? this.matchedRecipients,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      assignedVolunteer: assignedVolunteer ?? this.assignedVolunteer,
      donor: donor ?? this.donor,
      urgency: urgency ?? this.urgency,
      createdAt: createdAt ?? this.createdAt,
    );
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

  // Check if donation is expiring soon
  bool get isExpiringSoon {
    if (handlingWindow == null) return false;

    try {
      final end = DateTime.parse(handlingWindow!['end']);
      final now = DateTime.now();
      final timeRemaining = end.difference(now);

      // Consider expiring soon if less than 4 hours remaining
      return timeRemaining.inHours <= 4 && timeRemaining.inHours > 0;
    } catch (e) {
      return false;
    }
  }
}
