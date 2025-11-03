import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../models.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _api = Api();

  bool _loading = false;
  String? _error;

  LiveData? _live;

  // Map controller để zoom/pan
  final MapController _mapController = MapController();

  // tâm mặc định (HCM tạm thời)
  LatLng _center = const LatLng(10.77653, 106.70098);
  double _zoom = 13;

  @override
  void initState() {
    super.initState();
    _loadLive();
  }

  Future<void> _loadLive() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getLiveData();

      // sau khi có data, thử canh bản đồ
      final bounds = _calcBoundsFromLive(data);
      if (bounds != null) {
        // lấy trung tâm đơn giản = midpoint của bounds
        final midLat = (bounds.sw.latitude + bounds.ne.latitude) / 2;
        final midLng = (bounds.sw.longitude + bounds.ne.longitude) / 2;
        _center = LatLng(midLat, midLng);
        _zoom = 13; // bạn muốn có thể tự tính zoom theo bounds sau
        // (flutter_map có fitBounds nhưng cần builder async một chút,
        // ở bản cơ bản mình chỉ set state để camera start ở đó)
      }

      if (!mounted) return;
      setState(() {
        _live = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được dữ liệu bản đồ: $e';
        _loading = false;
      });
    }
  }

  // Gom tất cả vị trí collector + pickup để tính bounding box
  _LatLngBounds? _calcBoundsFromLive(LiveData data) {
    final allPoints = <LatLng>[];

    for (final c in data.collectors) {
      if (c.currentLat != null && c.currentLng != null) {
        allPoints.add(LatLng(c.currentLat!, c.currentLng!));
      }
    }

    for (final j in data.pendingJobs) {
        allPoints.add(LatLng(j.lat, j.lng));
    }

    if (allPoints.isEmpty) return null;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return _LatLngBounds(
      sw: LatLng(minLat, minLng),
      ne: LatLng(maxLat, maxLng),
    );
  }

  // Marker list cho flutter_map
  List<Marker> _buildMarkers() {
    final list = <Marker>[];
    if (_live == null) return list;

    // 1. collector markers (xanh lá)
    for (final c in _live!.collectors) {
      if (c.currentLat == null || c.currentLng == null) continue;

      list.add(
        Marker(
          point: LatLng(c.currentLat!, c.currentLng!),
          width: 48,
          height: 48,
          child: _CollectorMarkerWidget(
            name: c.fullName.isNotEmpty ? c.fullName : 'NV #${c.id}',
            phone: c.phone,
          ),
        ),
      );
    }

    // 2. job markers (cam)
    for (final job in _live!.pendingJobs) {
      list.add(
        Marker(
          point: LatLng(job.lat, job.lng),
          width: 48,
          height: 48,
          child: _JobMarkerWidget(
            jobId: job.id,
            scrapType: job.scrapType,
            kg: job.quantityKg,
            customerName: job.customerName,
            customerPhone: job.customerPhone,
          ),
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();

    Widget mapLayer;
    if (_live == null && _loading) {
      mapLayer = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _live == null) {
      mapLayer = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      mapLayer = FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: _zoom,
          // you can allow user gesture, tap, etc.
        ),
        children: [
          // Tile layer sử dụng OpenStreetMap free
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.scrap_app',
          ),

          // markers
          MarkerLayer(
            markers: markers,
          ),
        ],
      );
    }

    // cái panel nhỏ dưới cùng giống "dashboard"
    final bottomPanel = Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Điều phối hiện tại",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Nhân viên đang online: ${_live?.collectors.length ?? 0}",
                ),
                Text(
                  "Yêu cầu chưa xong: ${_live?.pendingJobs.length ?? 0}",
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Cảnh báo: $_error",
                    style: const TextStyle(
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _loadLive,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Làm mới"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bản đồ điều phối"),
        actions: [
          IconButton(
            onPressed: _loadLive,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: mapLayer),

          bottomPanel,

          if (_loading && _live != null)
            Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// Widget marker cho Collector
class _CollectorMarkerWidget extends StatelessWidget {
  final String name;
  final String phone;

  const _CollectorMarkerWidget({
    required this.name,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // bubble info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Icon(
          Icons.man_2_rounded,
          color: Colors.green.shade700,
          size: 28,
        ),
      ],
    );
  }
}

// Widget marker cho Job/Pickup
class _JobMarkerWidget extends StatelessWidget {
  final int jobId;
  final String scrapType;
  final double kg;
  final String customerName;
  final String customerPhone;

  const _JobMarkerWidget({
    required this.jobId,
    required this.scrapType,
    required this.kg,
    required this.customerName,
    required this.customerPhone,
  });

  @override
  Widget build(BuildContext context) {
    final detail = "$scrapType / ${kg.toStringAsFixed(1)}kg";

    return Column(
      children: [
        // bubble info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "#$jobId $detail",
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Icon(
          Icons.location_on,
          color: Colors.orange.shade700,
          size: 28,
        ),
      ],
    );
  }
}

// helper class để giữ bounds
class _LatLngBounds {
  final LatLng sw;
  final LatLng ne;
  const _LatLngBounds({required this.sw, required this.ne});
}
