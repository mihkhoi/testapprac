import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';

class CollectorScreen extends StatefulWidget {
  const CollectorScreen({super.key});
  @override
  State<CollectorScreen> createState() => _CollectorScreenState();
}

class _CollectorScreenState extends State<CollectorScreen>
    with SingleTickerProviderStateMixin {
  final api = Api();

  List<Collector> _collectors = [];
  Collector? _selected; // collector đang chọn
  int? _statusFilter; // lọc theo trạng thái
  List<PickupRequest> _items = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);

    _collectors = await api.getCollectors();
    if (_collectors.isNotEmpty) {
      _selected = _collectors.first;
    }

    await _loadPickups();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// tải danh sách pickup (mặc định: tất cả, không filter theo collectorId)
  Future<void> _loadPickups() async {
    setState(() => _loading = true);

    _items = await api.getPickups(
      status: _statusFilter,
      // nếu muốn chỉ lấy job của collector đang chọn thì đổi thành _selected?.id
      collectorId: null,
    );

    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// collector nhận job thủ công
  Future<void> _accept(int pickupId) async {
    if (_selected == null) return;
    setState(() => _loading = true);

    await api.acceptPickup(pickupId, _selected!.id);
    await _loadPickups();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// đổi trạng thái job
  Future<void> _setStatus(int pickupId, int status) async {
    setState(() => _loading = true);

    await api.setStatus(pickupId, status);
    await _loadPickups();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// tự động gán job Pending cho người gần nhất
  Future<void> _autoDispatch(PickupRequest p) async {
    // lat/lng trong model là non-nullable double (theo code backend),
    // nên mình lấy thẳng:
    final double jobLat = p.lat;
    final double jobLng = p.lng;

    setState(() => _loading = true);
    try {
      await api.dispatchNearest(
        p.id,
        jobLat: jobLat,
        jobLng: jobLng,
        radiusKm: 10,
        // nếu muốn giới hạn theo doanh nghiệp của collector đang chọn:
        // companyId: _selected?.companyId,
        companyId: null,
      );
      await _loadPickups();
      _toast('Đã auto-dispatch');
    } catch (e) {
      _toast('Auto-dispatch lỗi: $e');
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _statusName(int s) => const [
        'Pending',
        'Accepted',
        'InProgress',
        'Completed',
        'Cancelled'
      ][s];

  Color _statusColor(int s) {
    // nền nhạt cho Chip
    return switch (s) {
      0 => Colors.orangeAccent.withValues(alpha: 0.15),
      1 => Colors.blueAccent.withValues(alpha: 0.15),
      2 => Colors.amber.withValues(alpha: 0.15),
      3 => Colors.greenAccent.withValues(alpha: 0.15),
      _ => Colors.grey.withValues(alpha: 0.2),
    };
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final dropdownCollector = DropdownButton<Collector>(
      value: _selected,
      items: _collectors
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text('#${c.id} - ${c.fullName}'),
            ),
          )
          .toList(),
      onChanged: (v) async {
        setState(() => _selected = v);
        // nếu muốn chế độ "chỉ job của collector này" thì bạn có thể
        // viết thêm _loadMyPickups() và gọi ở đây thay cho _loadPickups()
        await _loadPickups();
      },
    );

    final dropdownStatus = DropdownButton<int?>(
      value: _statusFilter,
      items: const [
        DropdownMenuItem(value: null, child: Text('(Tất cả)')),
        DropdownMenuItem(value: 0, child: Text('Pending')),
        DropdownMenuItem(value: 1, child: Text('Accepted')),
        DropdownMenuItem(value: 2, child: Text('InProgress')),
        DropdownMenuItem(value: 3, child: Text('Completed')),
        DropdownMenuItem(value: 4, child: Text('Cancelled')),
      ],
      onChanged: (v) async {
        _statusFilter = v;
        await _loadPickups();
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch thu gom')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    dropdownCollector,
                    dropdownStatus,
                    FilledButton.icon(
                      onPressed: _loadPickups,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tải danh sách'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final p = _items[i];

                    // Vì model Flutter hiện chưa có acceptedByCollectorId,
                    // mình sẽ suy luận dựa theo status:
                    final collectorInfo = switch (p.status) {
                      0 => '(chưa nhận)', // Pending
                      _ => 'Đang xử lý',   // Accepted / InProgress / ...
                    };

                    return ListTile(
                      isThreeLine: true,
                      title: Text(
                        'Yêu cầu #${p.id} • ${p.scrapType} • ${p.quantityKg} kg',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Khách: ${p.customer?.fullName ?? ''} (${p.customer?.phone ?? ''})\n'
                        'Thời gian: ${p.pickupTime}\n'
                        'Phụ trách: $collectorInfo',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Chip trạng thái
                          Chip(
                            label: Text(_statusName(p.status)),
                            backgroundColor: _statusColor(p.status),
                            side: BorderSide.none,
                          ),

                          // Pending -> auto-dispatch hoặc nhận tay
                          if (p.status == 0)
                            TextButton(
                              onPressed: () => _autoDispatch(p),
                              child: const Text('Auto-dispatch'),
                            ),

                          if (p.status == 0)
                            OutlinedButton(
                              onPressed: () => _accept(p.id),
                              child: const Text('Nhận'),
                            ),

                          // Accepted -> Bắt đầu
                          if (p.status == 1)
                            OutlinedButton(
                              onPressed: () => _setStatus(p.id, 2),
                              child: const Text('Bắt đầu'),
                            ),

                          // InProgress -> Hoàn tất
                          if (p.status == 2)
                            FilledButton(
                              onPressed: () => _setStatus(p.id, 3),
                              child: const Text('Hoàn tất'),
                            ),

                          // Pending/Accepted/InProgress -> Huỷ
                          if (p.status <= 2)
                            TextButton(
                              onPressed: () => _setStatus(p.id, 4),
                              child: const Text('Huỷ'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
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
