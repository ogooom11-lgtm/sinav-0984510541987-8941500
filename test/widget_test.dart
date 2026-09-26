import 'package:basira/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Basira boots with an Arabic RTL learning shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const BasiraApp());

    expect(find.byType(BasiraApp), findsOneWidget);
    expect(find.byType(LessonsHome), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('ar'));
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);

    // Only test bootstrap here. Dispose the loading animation explicitly;
    // engine/content suites cover the bank without waiting on platform assets.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
