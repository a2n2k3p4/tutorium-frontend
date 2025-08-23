// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutorium_frontend/main.dart';
import 'package:tutorium_frontend/pages/home/learner_home.dart';
import 'package:tutorium_frontend/pages/home/teacher_home.dart';
import 'package:tutorium_frontend/pages/main_nav_page.dart';
import 'package:tutorium_frontend/pages/widgets/schedule_card.dart';

void main() {
  testWidgets('App shows LearnerPage initially and can navigate', (
    WidgetTester tester,
  ) async {
    // 1. Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that the HomePage is visible.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Home')),
      findsOneWidget,
    );
    expect(find.text('Learner Page'), findsOneWidget);

    // 3. Verify that the SearchPage is not visible.
    expect(find.text('Search Page'), findsNothing);

    // 4. Tap the 'Search' icon in the bottom navigation bar.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    // 5. Verify that navigation was successful.
    expect(find.text('Search Page'), findsOneWidget);
    expect(find.text('Learner Page'), findsNothing);
  });

  testWidgets(
    'MainNavPage shows LearnerHomePage and can switch to TeacherHomePage',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: const MainNavPage(),
          ),
        ),
      );

      // Check LearnerHomePage
      expect(find.text('Learner Home'), findsOneWidget);
      expect(find.text('Upcoming Schedule'), findsOneWidget);
      expect(find.byType(ScheduleCard), findsWidgets);

      // Switch to TeacherHomePage
      await tester.tap(find.byIcon(Icons.change_circle));
      await tester.pumpAndSettle();

      expect(find.text('Teacher Home'), findsOneWidget);
      expect(find.text('Learner Home'), findsNothing);

      // Switch back to LearnerHomePage
      await tester.tap(find.byIcon(Icons.change_circle));
      await tester.pumpAndSettle();

      expect(find.text('Learner Home'), findsOneWidget);
      expect(find.text('Teacher Home'), findsNothing);
    },
  );
}
