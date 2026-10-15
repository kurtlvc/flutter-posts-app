import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finals_laboratory_exam/main.dart';

void main() {
  testWidgets('App loads Posts screen with AppBar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PostReaderApp());
    await tester.pump();

    expect(find.text('Posts Reader'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
