import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});
  @override
  State<ManagementScreen> createState() => _S();
}

class _S extends State<ManagementScreen> with SingleTickerProviderStateMixin {
  final api = Api();
  late final TabController _tab;
  List<Customer> _customers = [];
  // mỗi company là Map: {id,name,contactPhone,address,collectors:[{id,fullName,phone,companyId}, ...]}
  List<Map<String, dynamic>> _companies = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {})); // để FAB đổi theo tab
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _customers = await api.getCustomers();
    _companies = await api.getCompanies(); // <-- dùng API công khai
    setState(() {});
  }

  // ---- UI helpers
  Future<void> _addCustomer() async {
    final name = await _prompt('Tên KH');
    if (name == null || name.isEmpty) return;
    final phone = await _prompt('Điện thoại');
    if (phone == null || phone.isEmpty) return;
    await api.createCustomer(name, phone, null);
    await _load();
  }

  Future<void> _editCustomer(Customer c) async {
    final name = await _prompt('Tên KH', initial: c.fullName);
    if (name == null || name.isEmpty) return;
    final phone = await _prompt('Điện thoại', initial: c.phone);
    if (phone == null || phone.isEmpty) return;
    await api.updateCustomer(c.id, {
      'id': c.id,
      'fullName': name,
      'phone': phone,
      'address': c.address
    });
    await _load();
  }

  Future<void> _delCustomer(Customer c) async {
    await api.deleteCustomer(c.id);
    await _load();
  }

  Future<String?> _prompt(String label, {String? initial}) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  // Companies/Collectors gọn nhẹ
  Future<void> _addCompany() async {
    final n = await _prompt('Tên công ty');
    if (n == null || n.isEmpty) return;
    final p = await _prompt('Điện thoại');
    if (p == null || p.isEmpty) return;
    await api.createCompany(n, p, null);
    await _load();
  }

  Future<void> _addCollector(int companyId) async {
    final n = await _prompt('Tên collector');
    if (n == null || n.isEmpty) return;
    final p = await _prompt('Điện thoại');
    if (p == null || p.isEmpty) return;
    await api.createCollector(companyId, n, p);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isTabCustomers = _tab.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý'),
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(text: 'Khách hàng'),
          Tab(text: 'DN & Collector'),
        ]),
      ),
      floatingActionButton: isTabCustomers
          ? FloatingActionButton(
              onPressed: _addCustomer,
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              onPressed: _addCompany,
              child: const Icon(Icons.add_business),
            ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ---- Tab KH ----
          ListView.separated(
            itemCount: _customers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = _customers[i];
              return ListTile(
                title: Text('${c.fullName} • ${c.phone}'),
                subtitle: Text(c.address ?? ''),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    TextButton(
                      onPressed: () => _editCustomer(c),
                      child: const Text('Sửa'),
                    ),
                    TextButton(
                      onPressed: () => _delCustomer(c),
                      child: const Text('Xoá'),
                    ),
                  ],
                ),
              );
            },
          ),

          // ---- Tab DN & Collector ----
          ListView.builder(
            itemCount: _companies.length,
            itemBuilder: (_, i) {
              final co = _companies[i];
              final List cols = (co['collectors'] ?? []) as List;
              return Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('#${co['id']} ${co['name']} • ${co['contactPhone'] ?? ''}'),
                        ),
                        TextButton(
                          onPressed: () => _addCollector(co['id'] as int),
                          child: const Text('Thêm collector'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await api.deleteCompany(co['id'] as int);
                            await _load();
                          },
                          child: const Text('Xoá DN'),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      ...cols.map((cl) => ListTile(
                            title: Text('#${cl['id']} ${cl['fullName']} • ${cl['phone']}'),
                            trailing: TextButton(
                              onPressed: () async {
                                await api.deleteCollector(cl['id'] as int);
                                await _load();
                              },
                              child: const Text('Xoá'),
                            ),
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
