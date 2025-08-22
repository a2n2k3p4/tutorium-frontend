// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutorium_frontend/main.dart';

void main() {
  testWidgets('App shows HomePage initially and can navigate', (WidgetTester tester) async {
    // 1. Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that the HomePage is visible.
    // We look for a 'Home' Text widget that is a descendant of an AppBar.
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Home')), findsOneWidget);

    // This check is still good because "Home Page" is unique.
    expect(find.text('Home Page'), findsOneWidget);

    // 3. Verify that the SearchPage is not visible.
    expect(find.text('Search Page'), findsNothing);

    // 4. Find the 'Search' icon in the bottom navigation bar and tap it.
    await tester.tap(find.byIcon(Icons.search));

    // 5. Rebuild the widget tree after the tap.
    await tester.pump();

    // 6. Verify that navigation was successful.
    expect(find.text('Search Page'), findsOneWidget);
    expect(find.text('Home Page'), findsNothing);
  });
}
