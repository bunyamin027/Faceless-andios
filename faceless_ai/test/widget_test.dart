import 'package:flutter_test/flutter_test.dart';

import 'package:faceless_ai/app/app.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FacelessApp());

    // Basic smoke test
    expect(find.byType(FacelessApp), findsOneWidget);
  });
}
