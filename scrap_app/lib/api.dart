import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';
import 'models.dart';

class Api {
  final _client = http.Client();
  String? _token; // JWT sau khi login

  Api() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('jwt');
  }

  Future<void> _saveToken(String t) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('jwt', t);
    _token = t;
  }

  Map<String, String> _headersJson() {
    final h = {'Content-Type': 'application/json'};
    if (_token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Env.baseUrl}$path').replace(queryParameters: q);

  // =========================
  // AUTH
  // =========================

  // login -> gọi /api/auth/login
  // trả về tuple style (role, customerId, collectorId)
  Future<({String role, int? customerId, int? collectorId})> login(
    String username,
    String password,
  ) async {
    final r = await _client.post(
      _u('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (r.statusCode != 200) {
      throw Exception('Login failed: ${r.body}');
    }

    final j = jsonDecode(r.body);
    final token = j['token'] as String;
    await _saveToken(token); // lưu JWT local

    final role = j['role'] as String;
    final customerId = j['customerId'];   // có thể null
    final collectorId = j['collectorId']; // có thể null

    // Lưu thêm role / id vào SharedPreferences để Home dùng
    final sp = await SharedPreferences.getInstance();
    await sp.setString('role', role);
    if (customerId != null) {
      await sp.setInt('customerId', customerId);
    }
    if (collectorId != null) {
      await sp.setInt('collectorId', collectorId);
    }

    return (
      role: role,
      customerId: (customerId is int) ? customerId : null,
      collectorId: (collectorId is int) ? collectorId : null,
    );
  }

  // =========================
  // CUSTOMERS
  // =========================

  Future<List<Customer>> getCustomers() async {
    final r = await _client.get(
      _u('/api/customers'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);

    final List a = jsonDecode(r.body);
    return a.map((e) => Customer.fromJson(e)).toList();
  }

  Future<Customer> createCustomer(
    String name,
    String phone,
    String? addr,
  ) async {
    final r = await _client.post(
      _u('/api/customers'),
      headers: _headersJson(),
      body: jsonEncode({
        'fullName': name,
        'phone': phone,
        'address': addr,
      }),
    );
    if (r.statusCode != 201) throw Exception(r.body);

    return Customer.fromJson(jsonDecode(r.body));
  }

  Future<Customer> getCustomer(int id) async {
    final r = await _client.get(
      _u('/api/customers/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);

    return Customer.fromJson(jsonDecode(r.body));
  }

  Future<Customer> updateCustomer(int id, Map<String, dynamic> body) async {
    final r = await _client.put(
      _u('/api/customers/$id'),
      headers: _headersJson(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception(r.body);

    return Customer.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteCustomer(int id) async {
    final r = await _client.delete(
      _u('/api/customers/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 204) throw Exception(r.body);
  }

  Future<void> updateCustomerLocation(int id, double lat, double lng) async {
    final r = await _client.post(
      _u('/api/customers/$id/location', {
        'lat': '$lat',
        'lng': '$lng'
      }),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  // =========================
  // PICKUPS
  // =========================

  Future<PickupRequest> createPickup({
    required int customerId,
    required String scrapType,
    required double quantityKg,
    required DateTime pickupTime,
    required double lat,
    required double lng,
    String? note,
  }) async {
    final r = await _client.post(
      _u('/api/pickups'),
      headers: _headersJson(),
      body: jsonEncode({
        'customerId': customerId,
        'scrapType': scrapType,
        'quantityKg': quantityKg,
        'pickupTime': pickupTime.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'note': note
      }),
    );
    if (r.statusCode != 201) throw Exception(r.body);

    return PickupRequest.fromJson(jsonDecode(r.body));
  }

  // status / collectorId / customerId đều optional
  Future<List<PickupRequest>> getPickups({
    int? status,
    int? collectorId,
    int? customerId,
  }) async {
    final q = <String, String>{};
    if (status != null) q['status'] = '$status';
    if (collectorId != null) q['collectorId'] = '$collectorId';
    if (customerId != null) q['customerId'] = '$customerId';

    final r = await _client.get(
      _u('/api/pickups', q.isEmpty ? null : q),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);

    final List a = jsonDecode(r.body);
    return a.map((e) => PickupRequest.fromJson(e)).toList();
  }

  Future<void> acceptPickup(int id, int collectorId) async {
    final r = await _client.post(
      _u('/api/pickups/$id/accept', {'collectorId': '$collectorId'}),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  Future<void> setStatus(int id, int status) async {
    final r = await _client.post(
      _u('/api/pickups/$id/status', {'status': '$status'}),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  // =========================
  // COMPANIES + COLLECTORS (quản lý DN & nhân viên)
  // =========================

  /// Thêm HÀM NÀY để CollectorScreen dùng dropdown collector
  Future<List<Collector>> getCollectors() async {
    final r = await _client.get(
      _u('/api/collectors'),
      headers: _headersJson(),
    );

    if (r.statusCode != 200) {
      throw Exception('getCollectors failed: ${r.body}');
    }

    final List data = jsonDecode(r.body);
    return data.map((e) => Collector.fromJson(e)).toList();
  }

  /// Lấy danh sách công ty + kèm collectors
  /// /api/companies trả:
  /// [
  ///   { "id":1, "name":"...", "contactPhone":"...", "address":"...",
  ///     "collectors":[{"id":10,"fullName":"...","phone":"...","companyId":1}, ...]
  ///   },
  ///   ...
  /// ]
  Future<List<Map<String, dynamic>>> getCompanies() async {
    final r = await _client.get(
      _u('/api/companies'),
      headers: _headersJson(),
    );

    if (r.statusCode != 200) {
      throw Exception('getCompanies failed: ${r.body}');
    }

    final List data = jsonDecode(r.body);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Tạo công ty mới
  Future<void> createCompany(
    String name,
    String phone,
    String? addr,
  ) async {
    final r = await _client.post(
      _u('/api/companies'),
      headers: _headersJson(),
      body: jsonEncode({
        'name': name,
        'contactPhone': phone,
        'address': addr
      }),
    );
    if (r.statusCode != 201) {
      throw Exception('createCompany failed: ${r.body}');
    }
  }

  /// Cập nhật công ty
  Future<void> updateCompany(
    int id,
    String name,
    String phone,
    String? addr,
  ) async {
    final r = await _client.put(
      _u('/api/companies/$id'),
      headers: _headersJson(),
      body: jsonEncode({
        'id': id,
        'name': name,
        'contactPhone': phone,
        'address': addr
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('updateCompany failed: ${r.body}');
    }
  }

  /// Xoá công ty
  Future<void> deleteCompany(int id) async {
    final r = await _client.delete(
      _u('/api/companies/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 204) {
      throw Exception('deleteCompany failed: ${r.body}');
    }
  }

  /// Tạo collector mới cho công ty
  Future<void> createCollector(
    int companyId,
    String fullName,
    String phone,
  ) async {
    final r = await _client.post(
      _u('/api/collectors'),
      headers: _headersJson(),
      body: jsonEncode({
        'companyId': companyId,
        'fullName': fullName,
        'phone': phone
      }),
    );
    if (r.statusCode != 201) {
      throw Exception('createCollector failed: ${r.body}');
    }
  }

  /// Cập nhật collector
  Future<void> updateCollector(
    int id,
    int companyId,
    String fullName,
    String phone,
  ) async {
    final r = await _client.put(
      _u('/api/collectors/$id'),
      headers: _headersJson(),
      body: jsonEncode({
        'id': id,
        'companyId': companyId,
        'fullName': fullName,
        'phone': phone
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('updateCollector failed: ${r.body}');
    }
  }

  /// Xoá collector
  Future<void> deleteCollector(int id) async {
    final r = await _client.delete(
      _u('/api/collectors/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 204) {
      throw Exception('deleteCollector failed: ${r.body}');
    }
  }

  // =========================
  // COLLECTOR helpers (ứng dụng cho nhân viên thu gom)
  // =========================

  Future<void> updateCollectorLocation(int id, double lat, double lng) async {
    final r = await _client.post(
      _u('/api/collectors/$id/location', {
        'lat': '$lat',
        'lng': '$lng',
      }),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  Future<List<PickupRequest>> getMyPickups(
    int collectorId, {
    int? status,
  }) async {
    final q = <String, String>{};
    if (status != null) q['status'] = '$status';

    final r = await _client.get(
      _u('/api/collectors/$collectorId/pickups', q.isEmpty ? null : q),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);

    final List a = jsonDecode(r.body);
    return a.map((e) => PickupRequest.fromJson(e)).toList();
  }

  // =========================
  // LISTINGS (nguồn cung rao bán)
  // =========================

  Future<void> createListing(
    String title,
    String desc,
    double pricePerKg, {
    double? lat,
    double? lng,
  }) async {
    final r = await _client.post(
      _u('/api/listings'),
      headers: _headersJson(),
      body: jsonEncode({
        'title': title,
        'description': desc,
        'pricePerKg': pricePerKg,
        'lat': lat,
        'lng': lng,
      }),
    );
    if (r.statusCode != 201) throw Exception(r.body);
  }

  Future<List<Listing>> searchListings({
    String? q,
    double? lat,
    double? lng,
    double? radiusKm,
    int? top,
  }) async {
    final qp = <String, String>{};
    if (q != null && q.isNotEmpty) qp['q'] = q;
    if (lat != null && lng != null && radiusKm != null) {
      qp['lat'] = '$lat';
      qp['lng'] = '$lng';
      qp['radiusKm'] = '$radiusKm';
    }
    if (top != null) qp['top'] = '$top';

    final r = await _client.get(
      _u('/api/listings/search', qp.isEmpty ? null : qp),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);

    final List a = jsonDecode(r.body);
    return a.map((e) => Listing.fromJson(e)).toList();
  }

  // =========================
  // Điều phối tự động
  // =========================

  Future<void> dispatchNearest(
    int pickupId, {
    required double jobLat,
    required double jobLng,
    double radiusKm = 10,
    int? companyId,
  }) async {
    final q = {
      'jobLat': '$jobLat',
      'jobLng': '$jobLng',
      'radiusKm': '$radiusKm',
      if (companyId != null) 'companyId': '$companyId'
    };
    final r = await _client.post(
      _u('/api/pickups/$pickupId/dispatch-nearest', q),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  // =========================
  // LIVE MAP (bản đồ điều phối)
  // =========================

  Future<LiveData> getLiveData() async {
    final r = await _client.get(
      _u('/api/dispatch/live'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception(r.body);

    final j = jsonDecode(r.body);
    return LiveData.fromJson(j);
  }
}
