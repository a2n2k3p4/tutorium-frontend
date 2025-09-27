import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutorium_frontend/main.dart';
import 'package:tutorium_frontend/pages/main_nav_page.dart';
import 'package:tutorium_frontend/pages/widgets/schedule_card.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.loadFromString(envString: '''
      API_URL=http://xxx.xxx.xxx.xxx
      PORT=xxxxx
      LOGIN_API=http://xxx.xxx.xxx.xxx/login
    ''');
  });

  testWidgets('App shows LearnerPage initially and can navigate', (
    WidgetTester tester,
  ) async {
    // 1. Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that the AppBar title is "Learner Home".
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Learner Home'),
      ),
      findsOneWidget,
    );

    // 3. Verify that the "Upcoming Schedule" text is visible.
    expect(find.text('Upcoming Schedule'), findsOneWidget);

    // 4. Verify that the SearchPage is not visible.
    expect(find.text('Search Class'), findsNothing);

    // 5. Tap the 'Search' icon in the bottom navigation bar.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    // 6. Verify that navigation was successful.
    expect(find.text('Search Class'), findsOneWidget);
    expect(find.text('Upcoming Schedule'), findsNothing);
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

      // 1. Check LearnerHomePage
      expect(find.text('Learner Home'), findsOneWidget);
      expect(find.text('Upcoming Schedule'), findsOneWidget);
      expect(find.byType(ScheduleCard), findsWidgets);

      // 2. Switch to TeacherHomePage
      await tester.tap(find.byIcon(Icons.change_circle));
      await tester.pumpAndSettle();

      // 3. Check TeacherHomePage
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Teacher Home'),
        ),
        findsOneWidget,
      );

      // 4. Switch back to LearnerHomePage
      await tester.tap(find.byIcon(Icons.change_circle));
      await tester.pumpAndSettle();

      // 5. Check LearnerHomePage again
      expect(find.text('Learner Home'), findsOneWidget);
      expect(find.text('Teacher Home'), findsNothing);
    },
  );
}
