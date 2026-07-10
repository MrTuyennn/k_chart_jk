import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('renders chart demo shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // App bar luôn hiển thị symbol đang xem.
    expect(find.text('BTC/USDT'), findsOneWidget);

    // Môi trường test chặn HTTP (mock client trả 400) → bootstrap REST fail
    // → hiển thị error view kèm nút retry thay vì crash.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
