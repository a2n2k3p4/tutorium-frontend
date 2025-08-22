import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutorium_frontend/main.dart';

void main() {
  testWidgets('App shows HomePage initially and can navigate', (WidgetTester tester) async {
    // 1. Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that the HomePage is visible.
    // We expect to find the text 'Home' in the AppBar and 'Home Page' in the body.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Home Page'), findsOneWidget);

    // 3. Verify that the SearchPage is not visible.
    expect(find.text('Search Page'), findsNothing);

    // 4. Find the 'Search' icon in the bottom navigation bar and tap it.
    await tester.tap(find.byIcon(Icons.search));

    // 5. Rebuild the widget tree after the tap.
    await tester.pump();

    // 6. Verify that navigation was successful.
    // We now expect to see the SearchPage.
    expect(find.text('Search Page'), findsOneWidget);

    // And the HomePage should no longer be visible.
    expect(find.text('Home Page'), findsNothing);
  });
}
