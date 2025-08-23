// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:tutorium_frontend/main.dart';
import 'package:tutorium_frontend/pages/home/learner_home.dart';
import 'package:tutorium_frontend/pages/home/teacher_home.dart';
import 'package:tutorium_frontend/pages/main_nav_page.dart';
import 'package:tutorium_frontend/pages/widgets/schedule_card.dart';

void main() {
  testWidgets('App shows HomePage initially and can navigate', (
    WidgetTester tester,
  ) async {
    // 1. Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that the HomePage is visible.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Home')),
      findsOneWidget,
    );
    expect(find.text('Home Page'), findsOneWidget);

    // 3. Verify that the SearchPage is not visible.
    expect(find.text('Search Page'), findsNothing);

    // 4. Tap the 'Search' icon in the bottom navigation bar.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    // 5. Verify that navigation was successful.
    expect(find.text('Search Page'), findsOneWidget);
    expect(find.text('Home Page'), findsNothing);
  });

  testWidgets(
    'MainNavPage shows LearnerHomePage and can switch to TeacherHomePage',
    (WidgetTester tester) async {
      await mockNetworkImagesFor(() async {
        // 1. Build MainNavPage
        await tester.pumpWidget(const MaterialApp(home: MainNavPage()));

        // 2. Verify LearnerHomePage is visible
        expect(find.text('Learner Home'), findsOneWidget);
        expect(find.text('Upcoming Schedule'), findsOneWidget);
        expect(find.byType(ScheduleCard), findsWidgets);

        // 3. Tap the change role button to switch to TeacherHomePage
        await tester.tap(find.byIcon(Icons.change_circle));
        await tester.pumpAndSettle();

        // 4. Verify TeacherHomePage is visible
        expect(find.text('Teacher Home'), findsOneWidget);
        expect(find.text('Learner Home'), findsNothing);

        // 5. Tap the change role button again to switch back to LearnerHomePage
        await tester.tap(find.byIcon(Icons.change_circle));
        await tester.pumpAndSettle();

        // 6. Verify LearnerHomePage is visible again
        expect(find.text('Learner Home'), findsOneWidget);
        expect(find.text('Teacher Home'), findsNothing);
      });
    },
  );
}
