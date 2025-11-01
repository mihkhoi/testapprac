import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';
import 'ui/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/customer_booking_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/collector_screen.dart';
import 'screens/management_screen.dart';
import 'screens/map_screen.dart';
import 'screens/listings_screen.dart';
import 'session.dart';

// MAIN async
Future<void> main() async {

  const String.fromEnvironment('FLUTTER_COMPOSITION_RENDERING', defaultValue: 'legacy');
  
  WidgetsFlutterBinding.ensureInitialized();

  // rất quan trọng: dò backend trước khi chạy app
  await Env.init();

  runApp(const RootApp());
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});
  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  String? _role;
  int? _customerId;
  int? _collectorId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('jwt');
    final role = sp.getString('role');
    final customerId = sp.getInt('customerId');
    final collectorId = sp.getInt('collectorId');

    setState(() {
      if (token != null && role != null) {
        _role = role;
        _customerId = customerId;
        _collectorId = collectorId;
      } else {
        _role = null;
        _customerId = null;
        _collectorId = null;
      }
      _loaded = true;
    });
  }

  Future<void> _handleLoggedOut() async {
    await Session.logout();
    setState(() {
      _role = null;
      _customerId = null;
      _collectorId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrap App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: !_loaded
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : (_role == null
              ? const LoginScreen()
              : ScrapApp(
                  role: _role!,
                  customerId: _customerId,
                  collectorId: _collectorId,
                  onLogout: _handleLoggedOut,
                )),
    );
  }
}

class ScrapApp extends StatefulWidget {
  final String role; // admin | customer | collector
  final int? customerId;
  final int? collectorId;
  final Future<void> Function() onLogout;

  const ScrapApp({
    super.key,
    required this.role,
    this.customerId,
    this.collectorId,
    required this.onLogout,
  });

  @override
  State<ScrapApp> createState() => _ScrapAppState();
}

class _ScrapAppState extends State<ScrapApp> {
  Future<void> _logout() async {
    await Session.logout();
    await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <_HomeTile>[];

    // customer / admin
    if (widget.role == 'customer' || widget.role == 'admin') {
      tiles.addAll([
        _HomeTile(
          icon: Icons.event_available,
          label: 'Đặt lịch thu gom',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerBookingScreen(),
              ),
            );
          },
        ),
        if (widget.customerId != null)
          _HomeTile(
            icon: Icons.history,
            label: 'Lịch của tôi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyBookingsScreen(
                    customerId: widget.customerId!,
                  ),
                ),
              );
            },
          ),
        _HomeTile(
          icon: Icons.store,
          label: 'Nguồn cung / Listings',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ListingsScreen(),
              ),
            );
          },
        ),
      ]);
    }

    // collector / admin
    if (widget.role == 'collector' || widget.role == 'admin') {
      tiles.add(
        _HomeTile(
          icon: Icons.delivery_dining,
          label: 'Lịch thu gom (Collector)',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CollectorScreen(),
              ),
            );
          },
        ),
      );
    }

    // admin only
    if (widget.role == 'admin') {
      tiles.addAll([
        _HomeTile(
          icon: Icons.business,
          label: 'Quản lý KH / DN / Collector',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManagementScreen(),
              ),
            );
          },
        ),
        _HomeTile(
          icon: Icons.map_outlined,
          label: 'Bản đồ điều phối',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MapScreen(),
              ),
            );
          },
        ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Xin chào (${widget.role})'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc muốn đăng xuất không?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Huỷ'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );

              if (ok == true) {
                await _logout();
              }
            },
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: tiles.map((t) {
          return InkWell(
            onTap: t.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Card(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      t.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HomeTile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _HomeTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
