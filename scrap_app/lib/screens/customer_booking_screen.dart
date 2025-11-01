import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../models.dart';
import 'my_bookings_screen.dart';

class CustomerBookingScreen extends StatefulWidget {
  const CustomerBookingScreen({super.key});
  @override
  State<CustomerBookingScreen> createState() => _S();
}

class _S extends State<CustomerBookingScreen> {
  final api = Api();
  final _f = GlobalKey<FormState>();

  Customer? _current;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _addr = TextEditingController();

  final _kg = TextEditingController(text: '10');
  final _note = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  String _scrapType = 'Giấy';
  DateTime _time = DateTime.now().add(const Duration(hours: 2));

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _addr.dispose();
    _kg.dispose();
    _note.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _getGeo() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      _toast('Chưa có quyền vị trí');
      return;
    }

    final p = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (!mounted) return;
    _lat.text = p.latitude.toStringAsFixed(6);
    _lng.text = p.longitude.toStringAsFixed(6);
  }

  Future<void> _saveCustomer() async {
    if (!_f.currentState!.validate()) return;

    setState(() => _saving = true);

    final c = await api.createCustomer(
      _name.text.trim(),
      _phone.text.trim(),
      _addr.text.trim().isEmpty ? null : _addr.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _current = c;
      _saving = false;
    });
    _toast('Đã lưu khách #${c.id}');
  }

  Future<void> _book() async {
    if (_current == null) {
      _toast('Hãy lưu khách trước');
      return;
    }
    if (_lat.text.isEmpty || _lng.text.isEmpty) {
      _toast('Thiếu toạ độ');
      return;
    }
    if (!_f.currentState!.validate()) return;

    setState(() => _saving = true);

    final res = await api.createPickup(
      customerId: _current!.id,
      scrapType: _scrapType,
      quantityKg: double.parse(_kg.text),
      pickupTime: _time,
      lat: double.parse(_lat.text),
      lng: double.parse(_lng.text),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    _toast('Đặt lịch thành công #${res.id}');
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lịch thu gom')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _f,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(title: 'Thông tin khách'),
                  const SizedBox(height: 8),

                  // Họ tên
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Họ tên',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Nhập họ tên'
                            : null,
                  ),
                  const SizedBox(height: 8),

                  // Điện thoại
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Điện thoại',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Nhập điện thoại'
                            : null,
                  ),
                  const SizedBox(height: 8),

                  // Địa chỉ
                  TextFormField(
                    controller: _addr,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ (tuỳ chọn)',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Hàng nút Lưu KH + chip KH + nút Lịch của tôi
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _saveCustomer,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Lưu / dùng khách này'),
                      ),
                      const SizedBox(width: 12),

                      if (_current != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              avatar: const Icon(
                                Icons.verified_outlined,
                                size: 18,
                              ),
                              label: Text('KH #${_current!.id}'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MyBookingsScreen(
                                      customerId: _current!.id,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Lịch của tôi'),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _Section(title: 'Lịch thu gom'),
                  const SizedBox(height: 8),

                  // Loại phế liệu
                  DropdownButtonFormField<String>(
                    initialValue: _scrapType,
                    items: const [
                      'Giấy',
                      'Nhựa',
                      'Kim loại',
                      'Điện tử',
                      'Khác'
                    ]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _scrapType = v ?? 'Giấy'),
                    decoration: const InputDecoration(
                      labelText: 'Loại phế liệu',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Số kg
                  TextFormField(
                    controller: _kg,
                    decoration: const InputDecoration(
                      labelText: 'Số kg (ước lượng)',
                      prefixIcon:
                          Icon(Icons.monitor_weight_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final d = double.tryParse(v ?? '');
                      return (d == null || d <= 0)
                          ? 'Số kg > 0'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Chọn thời gian
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Thời gian: ${df.format(_time)}'),
                    trailing: const Icon(Icons.schedule),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 30)),
                        initialDate: _time,
                      );
                      if (d == null) return;
                      if (!context.mounted) return;

                      final t = await showTimePicker(
                        context: context,
                        initialTime:
                            TimeOfDay.fromDateTime(_time),
                      );
                      if (t == null) return;
                      if (!mounted) return;

                      setState(() {
                        _time = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          t.hour,
                          t.minute,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  // Ghi chú
                  TextFormField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Lat / Lng
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lat,
                          decoration: const InputDecoration(
                            labelText: 'Vĩ độ (lat)',
                            prefixIcon:
                                Icon(Icons.my_location_outlined),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (double.tryParse(v ?? '') == null)
                                  ? 'Nhập Lat'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _lng,
                          decoration: const InputDecoration(
                            labelText: 'Kinh độ (lng)',
                            prefixIcon:
                                Icon(Icons.location_on_outlined),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (double.tryParse(v ?? '') == null)
                                  ? 'Nhập Lng'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // nút lấy vị trí + đặt lịch
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _getGeo,
                        icon: const Icon(Icons.gps_fixed),
                        label: const Text('Lấy vị trí'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _book,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Đặt lịch'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          if (_saving)
            Container(
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
