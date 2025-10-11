class Donation {
  final String? id;
  final String donorId;
  final Map<String, dynamic>? donor;
  final String type;
  final String status;
  final List<String> images;
  final String? description;
  final String? aiDescription;
  final List<String> categories;
  final List<String> tags;
  final Map<String, dynamic> quantity;
  final Map<String, dynamic>? handlingWindow;
  final String? expectedQuantity;
  final DateTime? scheduledPickup;
  final String pickupAddress;
  final Map<String, dynamic> location;
  final Map<String, dynamic>? aiAnalysis;
  final List<MatchedRecipient> matchedRecipients;
  final String? acceptedBy;
  final Map<String, dynamic>? acceptedByUser;
  final String? assignedVolunteer;
  final String? urgency;
  final DateTime createdAt;

  Donation({
    this.id,
    required this.donorId,
    this.donor,
    required this.type,
    required this.status,
    required this.images,
    this.description,
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
    this.acceptedByUser,
    this.assignedVolunteer,
    this.urgency,
    required this.createdAt,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['_id'],
      donorId: _parseDonorId(json['donor']),
      donor: _parseDonorObject(json['donor']),
      type: json['type'] ?? 'normal',
      status: json['status'] ?? 'pending',
      images: List<String>.from(json['images'] ?? []),
      description: json['description'],
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
      pickupAddress: json['pickupAddress'] ?? '',
      location: Map<String, dynamic>.from(json['location'] ?? {}),
      aiAnalysis: json['aiAnalysis'] != null
          ? Map<String, dynamic>.from(json['aiAnalysis'])
          : null,
      matchedRecipients:
          _parseMatchedRecipients(json['matchedRecipients'] ?? []),
      acceptedBy: json['acceptedBy'] is String ? json['acceptedBy'] : null,
      acceptedByUser: json['acceptedBy'] is Map
          ? Map<String, dynamic>.from(json['acceptedBy'])
          : null,
      assignedVolunteer: json['assignedVolunteer'],
      urgency: json['urgency'],
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  static String _parseDonorId(dynamic donor) {
    if (donor == null) return '';
    if (donor is String) return donor;
    if (donor is Map) {
      return donor['_id']?.toString() ?? donor['id']?.toString() ?? '';
    }
    return donor.toString();
  }

  static Map<String, dynamic>? _parseDonorObject(dynamic donor) {
    if (donor is Map) {
      return Map<String, dynamic>.from(donor);
    }
    return null;
  }

  static List<MatchedRecipient> _parseMatchedRecipients(
      List<dynamic> recipients) {
    return recipients.map((item) {
      if (item is Map) {
        return MatchedRecipient.fromJson(Map<String, dynamic>.from(item));
      }
      return MatchedRecipient(
        recipientId: item.toString(),
        matchScore: 0.0,
        status: 'offered',
      );
    }).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'donor': donorId,
      'type': type,
      'status': status,
      'images': images,
      'description': description,
      'aiDescription': aiDescription,
      'categories': categories,
      'tags': tags,
      'quantity': quantity,
      'handlingWindow': handlingWindow,
      'expectedQuantity': expectedQuantity,
      'scheduledPickup': scheduledPickup?.toIso8601String(),
      'pickupAddress': pickupAddress,
      'location': location,
      'urgency': urgency,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Donation copyWith({
    String? id,
    String? donorId,
    Map<String, dynamic>? donor,
    String? type,
    String? status,
    List<String>? images,
    String? description,
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
    List<MatchedRecipient>? matchedRecipients,
    String? acceptedBy,
    Map<String, dynamic>? acceptedByUser,
    String? assignedVolunteer,
    String? urgency,
    DateTime? createdAt,
  }) {
    return Donation(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      donor: donor ?? this.donor,
      type: type ?? this.type,
      status: status ?? this.status,
      images: images ?? this.images,
      description: description ?? this.description,
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
      acceptedByUser: acceptedByUser ?? this.acceptedByUser,
      assignedVolunteer: assignedVolunteer ?? this.assignedVolunteer,
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
    return aiDescription ?? description ?? 'Food Donation';
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
      final end = handlingWindow!['end'] is String
          ? DateTime.parse(handlingWindow!['end'])
          : DateTime.fromMillisecondsSinceEpoch(handlingWindow!['end']);
      final now = DateTime.now();
      final timeRemaining = end.difference(now);

      // Consider expiring soon if less than 4 hours remaining
      return timeRemaining.inHours <= 4 && timeRemaining.inHours > 0;
    } catch (e) {
      return false;
    }
  }

  // Get match for current recipient
  MatchedRecipient? getMatchForRecipient(String recipientId) {
    try {
      return matchedRecipients.firstWhere(
        (match) => match.recipientId == recipientId,
      );
    } catch (e) {
      return null;
    }
  }
}

class MatchedRecipient {
  final String recipientId;
  final Map<String, dynamic>? recipient;
  final double matchScore;
  final String status;
  final DateTime? respondedAt;
  final String? declineReason;
  final String? matchingMethod;
  final List<String>? matchReasons;

  MatchedRecipient({
    required this.recipientId,
    this.recipient,
    required this.matchScore,
    required this.status,
    this.respondedAt,
    this.declineReason,
    this.matchingMethod,
    this.matchReasons,
  });

  factory MatchedRecipient.fromJson(Map<String, dynamic> json) {
    return MatchedRecipient(
      recipientId: _parseRecipientId(json['recipient']),
      recipient: _parseRecipientObject(json['recipient']),
      matchScore: (json['matchScore'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'offered',
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
      declineReason: json['declineReason'],
      matchingMethod: json['matchingMethod'],
      matchReasons: json['matchReasons'] != null
          ? List<String>.from(json['matchReasons'])
          : null,
    );
  }

  static String _parseRecipientId(dynamic recipient) {
    if (recipient == null) return '';
    if (recipient is String) return recipient;
    if (recipient is Map) {
      return recipient['_id']?.toString() ?? recipient['id']?.toString() ?? '';
    }
    return recipient.toString();
  }

  static Map<String, dynamic>? _parseRecipientObject(dynamic recipient) {
    if (recipient is Map) {
      return Map<String, dynamic>.from(recipient);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'recipient': recipientId,
      'matchScore': matchScore,
      'status': status,
      'respondedAt': respondedAt?.toIso8601String(),
      'declineReason': declineReason,
      'matchingMethod': matchingMethod,
      'matchReasons': matchReasons,
    };
  }
}

class Donor {
  final String id;
  final String name;
  final String email;
  final Map<String, dynamic>? contactInfo;
  final Map<String, dynamic>? donorDetails;

  Donor({
    required this.id,
    required this.name,
    required this.email,
    this.contactInfo,
    this.donorDetails,
  });

  factory Donor.fromJson(Map<String, dynamic> json) {
    return Donor(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      contactInfo: json['contactInfo'] != null
          ? Map<String, dynamic>.from(json['contactInfo'])
          : null,
      donorDetails: json['donorDetails'] != null
          ? Map<String, dynamic>.from(json['donorDetails'])
          : null,
    );
  }
}
