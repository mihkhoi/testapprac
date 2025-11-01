// // This is a basic Flutter widget test.
// //
// // To perform an interaction with a widget in your test, use the WidgetTester
// // utility in the flutter_test package. For example, you can send tap and scroll
// // gestures. You can also use WidgetTester to find child widgets in the widget
// // tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';

// import 'package:scrap_app/main.dart';

// void main() {
//   testWidgets('Counter increments smoke test', (WidgetTester tester) async {
//     // Build our app and trigger a frame.
//     await tester.pumpWidget(const ScrapApp());

//     // Verify that our counter starts at 0.
//     expect(find.text('0'), findsOneWidget);
//     expect(find.text('1'), findsNothing);

//     // Tap the '+' icon and trigger a frame.
//     await tester.tap(find.byIcon(Icons.add));
//     await tester.pump();

//     // Verify that our counter has incremented.
//     expect(find.text('0'), findsNothing);
//     expect(find.text('1'), findsOneWidget);
//   });
// }

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scrap_app/main.dart';

void main() {
  testWidgets('ScrapApp renders home tiles for admin', (WidgetTester tester) async {
    // Pump app như một admin
    await tester.pumpWidget(
      MaterialApp(
        home: ScrapApp(
          role: 'admin',
          customerId: null,
          collectorId: null,
          onLogout: () async {}, // <-- phải trả Future<void>
        ),
      ),
    );

    // Kiểm tra có tile dành cho admin
    expect(find.textContaining('Quản lý KH'), findsOneWidget);
    expect(find.textContaining('Bản đồ điều phối'), findsOneWidget);

    // Kiểm tra AppBar hiển thị role
    expect(find.textContaining('admin'), findsOneWidget);
  });
}
