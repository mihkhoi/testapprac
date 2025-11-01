import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';

class MyBookingsScreen extends StatefulWidget {
  final int customerId;
  const MyBookingsScreen({super.key, required this.customerId});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final api = Api();
  bool _loading = false;
  List<PickupRequest> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _statusName(int s) => const [
        'Pending',
        'Accepted',
        'InProgress',
        'Completed',
        'Cancelled'
      ][s];

  Color _statusColor(int s) {
    switch (s) {
      case 0:
        return Colors.orangeAccent.withValues(alpha: 0.15);
      case 1:
        return Colors.blueAccent.withValues(alpha: 0.15);
      case 2:
        return Colors.amber.withValues(alpha: 0.15);
      case 3:
        return Colors.greenAccent.withValues(alpha: 0.15);
      default:
        return Colors.grey.withValues(alpha: 0.2);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Chỉ lấy các pickup của customer này
    _items = await api.getPickups(customerId: widget.customerId);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _cancel(int id) async {
    // Chuyển trạng thái job -> Cancelled (4)
    setState(() => _loading = true);

    await api.setStatus(id, 4);
    await _load();

    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã huỷ lịch')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch đã đặt')),
      body: Stack(
        children: [
          ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = _items[i];

              return ListTile(
                isThreeLine: true,
                title: Text(
                  'Yêu cầu #${p.id} - ${p.scrapType} ~ ${p.quantityKg} kg',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Thời gian: ${p.pickupTime}\n'
                  'Trạng thái: ${_statusName(p.status)}\n'
                  'Ghi chú: ${p.note ?? ""}',
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(_statusName(p.status)),
                      side: BorderSide.none,
                      backgroundColor: _statusColor(p.status),
                    ),
                    const SizedBox(height: 8),
                    if (p.status <= 2) // Pending / Accepted / InProgress
                      TextButton(
                        onPressed: () => _cancel(p.id),
                        child: const Text('Huỷ'),
                      ),
                  ],
                ),
              );
            },
          ),

          if (_loading)
            Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
