import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../models.dart'; // <-- thêm dòng này để có LiveData, CollectorLive, PendingJob

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final api = Api();

  bool _loading = false;
  LiveData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final d = await api.getLiveData(); // gọi API /api/dispatch/live

    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tâm mặc định: Sài Gòn
    LatLng center = const LatLng(10.776, 106.700);

    // Nếu có collector đầu tiên có toạ độ -> lấy làm tâm
    if (_data != null && _data!.collectors.isNotEmpty) {
      final first = _data!.collectors.first;
      if (first.currentLat != null && first.currentLng != null) {
        center = LatLng(first.currentLat!, first.currentLng!);
      }
    }

    // Build markers
    final List<Marker> markers = [];

    if (_data != null) {
      // 1. Marker cho collector (màu xanh dương)
      for (final c in _data!.collectors) {
        if (c.currentLat != null && c.currentLng != null) {
          markers.add(
            Marker(
              width: 60,
              height: 60,
              point: LatLng(c.currentLat!, c.currentLng!),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_pin_circle,
                    color: Colors.blue,
                    size: 32,
                  ),
                  Text(
                    c.fullName,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }
      }

      // 2. Marker cho pickup Pending (màu cam)
      for (final job in _data!.pendingJobs) {
        markers.add(
          Marker(
            width: 60,
            height: 60,
            point: LatLng(job.lat, job.lng),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.orange,
                  size: 32,
                ),
                Text(
                  '#${job.id} ${job.scrapType}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ điều phối'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
            ),
            children: [
              // Lớp nền bản đồ (OpenStreetMap)
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.scrap_app',
              ),

              // Các marker (collectors + pendingJobs)
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),

          if (_loading)
            Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
