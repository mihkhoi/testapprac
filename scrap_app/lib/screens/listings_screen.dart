import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api.dart';
import '../models.dart'; // <-- rất quan trọng: để có class Listing

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});
  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final api = Api();

  // form đăng bán
  final _title = TextEditingController();
  final _desc  = TextEditingController();
  final _price = TextEditingController(text: '7000');

  // form tìm kiếm
  final _q = TextEditingController();
  double _radius = 5;

  // vị trí hiện tại dùng cho đăng / search
  Position? _pos;

  // danh sách kết quả search
  List<Listing> _items = [];

  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _q.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(m)));
  }

  // xin quyền + lấy toạ độ
  Future<void> _ensurePos() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _toast('Chưa có quyền vị trí');
      return;
    }

    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    setState(() {
      _pos = p;
    });
  }

  // gọi API tạo listing mới
  Future<void> _create() async {
    final price = double.tryParse(_price.text) ?? 0;

    setState(() => _busy = true);

    await api.createListing(
      _title.text.trim(),
      _desc.text.trim(),
      price,
      lat: _pos?.latitude,
      lng: _pos?.longitude,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    // reset form
    _title.clear();
    _desc.clear();
    _price.text = '7000';

    _toast('Đã đăng');
  }

  // tìm kiếm listing quanh bán kính
  Future<void> _search() async {
    setState(() => _busy = true);

    // nếu chưa có vị trí thì xin
    if (_pos == null) {
      await _ensurePos();
    }

    final list = await api.searchListings(
      q: _q.text.trim().isEmpty ? null : _q.text.trim(),
      lat: _pos?.latitude,
      lng: _pos?.longitude,
      radiusKm: _pos == null ? null : _radius,
    );

    if (!mounted) return;
    setState(() {
      _items = list;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nguồn cung phế liệu')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ====== KHU ĐĂNG BÁN ======
              const _Section(title: 'Đăng bán'),
              const SizedBox(height: 8),

              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _price,
                decoration: const InputDecoration(
                  labelText: 'Giá/kg',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _ensurePos,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Lấy vị trí'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Đăng'),
                  ),
                ],
              ),

              const Divider(height: 32),

              // ====== KHU TÌM KIẾM ======
              const _Section(title: 'Tìm kiếm'),
              const SizedBox(height: 8),

              TextField(
                controller: _q,
                decoration: const InputDecoration(
                  labelText: 'Từ khoá (nhựa, giấy,...)',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Text('Bán kính:'),
                  Expanded(
                    child: Slider(
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: '${_radius.toStringAsFixed(0)} km',
                      value: _radius,
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                  ),
                  FilledButton(
                    onPressed: _search,
                    child: const Text('Tìm'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ====== KẾT QUẢ LISTINGS ======
              ..._items.map(
                (e) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(
                      e.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(e.description),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            '${e.pricePerKg.toStringAsFixed(0)} đ/kg',
                          ),
                        ),
                        if (e.lat != null && e.lng != null)
                          const SizedBox(height: 6),
                        if (e.lat != null && e.lng != null)
                          const Icon(
                            Icons.place_outlined,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),

          if (_busy)
            Container(
              // withValues() đã ok vì bạn đang dùng Flutter mới.
              color: Colors.black.withValues(alpha: 0.06),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}
