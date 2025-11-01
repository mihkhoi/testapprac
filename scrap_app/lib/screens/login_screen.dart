import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart'; // để điều hướng sang RootApp sau login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final api = Api();
  final _user = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  String? _err;

  Future<void> _doLogin() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      // gọi API đăng nhập -> API sẽ lưu jwt, role, ... vào SharedPreferences luôn
      final res = await api.login(
        _user.text.trim(),
        _pass.text.trim(),
      );

      // debug cho chắc
      debugPrint('LOGIN OK role=${res.role} '
          'customerId=${res.customerId} collectorId=${res.collectorId}');

      if (!mounted) return;

      // Sau khi login thành công:
      // Thay vì tạo ScrapApp thủ công (cần onLogout),
      // mình reset navigation stack về RootApp.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootApp()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('LOGIN ERROR = $e');

      if (!mounted) return;
      setState(() {
        _err = 'Đăng nhập thất bại';
      });
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _user,
            decoration: const InputDecoration(
              labelText: 'Tài khoản / SĐT',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          if (_err != null)
            Text(
              _err!,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _doLogin,
            icon: const Icon(Icons.login),
            label: const Text("Đăng nhập"),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Đăng nhập")),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(child: body),
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