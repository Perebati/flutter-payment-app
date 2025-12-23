// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_payment_app/src/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Payment app starts with amount screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PaymentApp());

    // Verify that we start on the amount screen
    expect(find.text('Valor do Pagamento'), findsOneWidget);
    expect(find.text('Digite o valor'), findsOneWidget);
  });
}
