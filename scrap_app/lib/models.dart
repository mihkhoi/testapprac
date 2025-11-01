class Customer {
  final int id;
  final String fullName;
  final String phone;
  final String? address;

  Customer({required this.id, required this.fullName, required this.phone, this.address});

  factory Customer.fromJson(Map<String, dynamic> j) =>
      Customer(id: j['id'], fullName: j['fullName'], phone: j['phone'], address: j['address']);
}

enum PickupStatus { pending, accepted, inProgress, completed, cancelled }

class PickupRequest {
  final int id;
  final Customer? customer;
  final String scrapType;
  final double quantityKg;
  final DateTime pickupTime;
  final double lat;
  final double lng;
  final String? note;
  final int status; // 0..4

  PickupRequest({
    required this.id, required this.customer, required this.scrapType, required this.quantityKg,
    required this.pickupTime, required this.lat, required this.lng, this.note, required this.status
  });

  factory PickupRequest.fromJson(Map<String, dynamic> j) => PickupRequest(
    id: j['id'],
    customer: j['customer'] == null ? null : Customer.fromJson(j['customer']),
    scrapType: j['scrapType'],
    quantityKg: (j['quantityKg'] as num).toDouble(),
    pickupTime: DateTime.parse(j['pickupTime']),
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    note: j['note'],
    status: j['status'],
  );
}

class Collector {
  final int id; final String fullName;
  Collector(this.id, this.fullName);
  factory Collector.fromJson(Map<String,dynamic> j) => Collector(j['id'], j['fullName']);
}

class Listing {
  final int id;
  final String title;
  final String description;
  final double pricePerKg;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.pricePerKg,
    required this.createdAt,
    this.lat,
    this.lng,
  });

  factory Listing.fromJson(Map<String, dynamic> j) {
    return Listing(
      id: j['id'] as int,
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      pricePerKg: (j['pricePerKg'] as num).toDouble(),
      lat: j['lat'] == null ? null : (j['lat'] as num).toDouble(),
      lng: j['lng'] == null ? null : (j['lng'] as num).toDouble(),
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'pricePerKg': pricePerKg,
        'lat': lat,
        'lng': lng,
        'createdAt': createdAt.toIso8601String(),
      };
}


class CollectorLive {
  final int id;
  final String fullName;
  final String phone;
  final double? currentLat;
  final double? currentLng;
  final DateTime? lastSeenAt;

  CollectorLive({
    required this.id,
    required this.fullName,
    required this.phone,
    this.currentLat,
    this.currentLng,
    this.lastSeenAt,
  });

  factory CollectorLive.fromJson(Map<String, dynamic> j) {
    return CollectorLive(
      id: j['id'] as int,
      fullName: j['fullName'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      currentLat: j['currentLat'] == null
          ? null
          : (j['currentLat'] as num).toDouble(),
      currentLng: j['currentLng'] == null
          ? null
          : (j['currentLng'] as num).toDouble(),
      lastSeenAt: j['lastSeenAt'] == null
          ? null
          : DateTime.parse(j['lastSeenAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'phone': phone,
        'currentLat': currentLat,
        'currentLng': currentLng,
        'lastSeenAt': lastSeenAt?.toIso8601String(),
      };
}

class PendingJob {
  final int id;
  final String scrapType;
  final double quantityKg;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final String customerName;
  final String customerPhone;

  PendingJob({
    required this.id,
    required this.scrapType,
    required this.quantityKg,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
  });

  factory PendingJob.fromJson(Map<String, dynamic> j) {
    return PendingJob(
      id: j['id'] as int,
      scrapType: j['scrapType'] as String? ?? '',
      quantityKg: (j['quantityKg'] as num).toDouble(),
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      customerName: j['customerName'] as String? ?? '',
      customerPhone: j['customerPhone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scrapType': scrapType,
        'quantityKg': quantityKg,
        'lat': lat,
        'lng': lng,
        'createdAt': createdAt.toIso8601String(),
        'customerName': customerName,
        'customerPhone': customerPhone,
      };
}

class LiveData {
  final List<CollectorLive> collectors;
  final List<PendingJob> pendingJobs;

  LiveData({
    required this.collectors,
    required this.pendingJobs,
  });

  factory LiveData.fromJson(Map<String, dynamic> j) {
    final List cols = j['collectors'] as List? ?? [];
    final List jobs = j['pendingJobs'] as List? ?? [];

    return LiveData(
      collectors: cols
          .map((e) => CollectorLive.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingJobs: jobs
          .map((e) => PendingJob.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'collectors': collectors.map((e) => e.toJson()).toList(),
        'pendingJobs': pendingJobs.map((e) => e.toJson()).toList(),
      };
}
