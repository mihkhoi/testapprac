// class Env {
//   // ====== cấu hình backend ======
//   //
//   // 1) Chạy bằng emulator Android:
//   //    DÙNG 10.0.2.2 (đây là "PC của bạn" nhìn từ emulator)
//   //
//   static const String baseUrlEmulator = 'http://10.0.2.2:5245';

//   // 2) Chạy trên điện thoại thật chung Wi-Fi với PC:
//   //    Đổi YOUR_PC_IP thành IPv4 của máy tính (ví dụ 192.168.1.5)
//   //    Nhớ mở API với 0.0.0.0:5245 trong launchSettings.json như mình sửa lúc nãy
//   //
//   static const String baseUrlDevice = 'http://192.168.1.13:5245';

//   // ====== chọn URL đang xài ======
//   //
//   // Nếu bạn đang test bằng emulator -> để = baseUrlEmulator
//   // Nếu bạn đang test bằng điện thoại thật -> đổi lại = baseUrlDevice
//   //
//   static const String baseUrl = baseUrlDevice;
// }


// import 'dart:convert';
// import 'dart:io';

// class Env {
//   // biến lưu baseUrl thật sự sẽ dùng sau khi detect
//   static String? _baseUrlResolved;

//   // hàm log chỉ chạy ở debug build
//   static void _log(String msg) {
//     assert(() {
//       // ignore: avoid_print
//       print(msg);
//       return true;
//     }());
//   }

//   // đọc baseUrl đã chọn
//   static String get baseUrl {
//     if (_baseUrlResolved == null) {
//       throw Exception('Env.init() chưa chạy, chưa biết baseUrl');
//     }
//     return _baseUrlResolved!;
//   }

//   // ====== DANH SÁCH ỨNG VIÊN ======
//   // NOTE:
//   // 1) Emulator Android -> 10.0.2.2
//   // 2) Điện thoại thật -> IP LAN của PC (ví dụ 192.168.1.13)
//   // 3) Desktop test (Flutter Windows/Web trên máy dev) -> localhost
//   //
//   // Chỉ cần đổi IP này nếu IP máy PC đổi trong mạng Wi-Fi.
//   static const String yourPcLanIp = '192.168.1.13'; // <-- cập nhật IP máy bạn

//   static List<String> _candidates() {
//     return [
//       'http://10.0.2.2:5245',        // emulator Android nhìn PC
//       'http://$yourPcLanIp:5245',    // device thật nhìn PC qua Wi-Fi
//       'http://localhost:5245',       // chạy app desktop/web trên chính PC
//     ];
//   }

//   // ====== Gọi thử /health trên server ======
//   static Future<bool> _checkHealth(String base) async {
//     try {
//       final uri = Uri.parse('$base/health');

//       final client = HttpClient()
//         ..connectionTimeout = const Duration(seconds: 1); // timeout ngắn

//       final req = await client.getUrl(uri);
//       final resp = await req.close();

//       if (resp.statusCode != 200) {
//         return false;
//       }

//       final body = await resp.transform(const Utf8Decoder()).join();
//       // backend trả {"status":"OK"}
//       return body.contains('OK');
//     } catch (_) {
//       return false;
//     }
//   }

//   // ====== gọi 1 lần lúc app start (trước khi dùng Api) ======
//   static Future<void> init() async {
//     for (final cand in _candidates()) {
//       final ok = await _checkHealth(cand);
//       if (ok) {
//         _baseUrlResolved = cand;
//         _log('Env.init(): chọn baseUrl = $cand');
//         return;
//       }
//     }

//     // không tìm ra backend sống
//     throw Exception(
//       'Không tìm được backend. Kiểm tra: backend đã chạy chưa? cùng Wi-Fi chưa?',
//     );
//   }
// }


import 'dart:convert';
import 'dart:io';

class Env {
  // URL backend đã chọn sau khi init()
  static String? _baseUrlResolved;

  // gọi cái này để lấy baseUrl dùng cho Api
  static String get baseUrl {
    final v = _baseUrlResolved;
    if (v == null) {
      throw Exception('Env.init() chưa chạy, chưa biết baseUrl');
    }
    return v;
  }

  // helper log debug (chỉ in ở debug mode)
  static void _debug(String msg) {
    assert(() {
      // ignore: avoid_print
      print(msg);
      return true;
    }());
  }

  // =========================
  // 1. THỬ NHANH CÁC HOST QUEN THUỘC
  // =========================
  //
  // - Emulator Android -> 10.0.2.2
  // - App chạy trên Windows laptop -> localhost
  //
  // Nếu một trong 2 cái này chạy /health OK => done, khỏi scan LAN.
  //
  static Future<bool> _tryKnownHosts() async {
    final known = [
      'http://10.0.2.2:5245',   // emulator Android nhìn PC
      'http://localhost:5245',  // chạy app ngay trên PC
      'http://127.0.0.1:5245',
    ];

    for (final cand in known) {
      final ok = await _checkHealth(cand);
      if (ok) {
        _baseUrlResolved = cand;
        _debug('[Env] dùng known host: $cand');
        return true;
      }
    }

    return false;
  }

  // =========================
  // 2. QUÉT MẠNG LAN
  // =========================
  //
  // Áp dụng cho TRƯỜNG HỢP ĐIỆN THOẠI THẬT:
  // - Điện thoại không có 10.0.2.2
  // - "localhost" trên điện thoại chỉ là điện thoại, không phải PC
  // => Ta brute force thử 192.168.1.1 -> 192.168.1.254 (hoặc 192.168.0.x, 10.0.0.x)
  //
  static Future<bool> _scanLan() async {
    // Các prefix LAN phổ biến. Bạn có thể thêm/bớt nếu mạng nhà bạn khác:
    final prefixes = [
      '192.168.1',
      '192.168.0',
      '10.0.0',
    ];

    for (final prefix in prefixes) {
      final ok = await _scanOnePrefix(prefix);
      if (ok) return true;
    }
    return false;
  }

  static Future<bool> _scanOnePrefix(String prefix) async {
    _debug('[Env] scan subnet $prefix.x ...');

    // quét từ .1 tới .254
    for (var i = 1; i < 255; i++) {
      final host = '$prefix.$i';
      final cand = 'http://$host:5245';
      final ok = await _checkHealth(cand);
      if (ok) {
        _baseUrlResolved = cand;
        _debug('[Env] tìm thấy backend tại $cand');
        return true;
      }
    }

    return false;
  }

  // =========================
  // 3. /health checker
  // =========================
  //
  // Gọi GET {base}/health
  // backend của bạn trả { "status": "OK" }
  //
  static Future<bool> _checkHealth(String base) async {
    try {
      final uri = Uri.parse('$base/health');

      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 800);

      final req = await client.getUrl(uri);
      final resp = await req.close();

      if (resp.statusCode != 200) return false;

      final body = await resp.transform(const Utf8Decoder()).join();
      // rất đơn giản: chỉ cần chứa "OK" là coi như khỏe
      return body.contains('OK');
    } catch (_) {
      return false;
    }
  }

  // =========================
  // 4. HÀM KHỞI TẠO - GỌI 1 LẦN Ở main()
  // =========================
  //
  // Logic:
  // - B1: thử known hosts (nhanh)
  // - B2: nếu fail thì quét LAN
  // - Nếu vẫn fail => throw (bạn sẽ thấy dialog lỗi)
  //
  static Future<void> init() async {
    // Nếu đã init trước đó rồi -> bỏ qua
    if (_baseUrlResolved != null) return;

    // B1
    final okKnown = await _tryKnownHosts();
    if (okKnown) return;

    // B2
    final okLan = await _scanLan();
    if (okLan) return;

    // Thua
    throw Exception(
      'Không tìm được backend.\n'
      '• Backend đã chạy chưa?\n'
      '• Điện thoại và PC có cùng Wi-Fi không?\n'
      '• Port 5245 có đang mở firewall không?',
    );
  }
}
