import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutorium_frontend/main.dart';
import 'package:tutorium_frontend/pages/main_nav_page.dart';
import 'package:tutorium_frontend/pages/widgets/schedule_card.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.loadFromString(
      envString: '''
      API_URL=http://xxx.xxx.xxx.xxx
      PORT=xxxxx
      LOGIN_API=http://xxx.xxx.xxx.xxx/login
    ''',
    );
  });

  testWidgets('App shows LearnerPage initially and can navigate', (
    WidgetTester tester,
  ) async {
    // 1. Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // App starts on LoginKuPage now; verify key UI is present.
    expect(find.text('KU ALL Login'), findsOneWidget);
    expect(find.text('Trouble signing in?'), findsOneWidget);
    // Ensure we are not already on a main page.
    expect(find.text('Learner Home'), findsNothing);
    expect(find.text('Search Class'), findsNothing);
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

      // Wait for initial render
      await tester.pump();

      // 1. Check LearnerHomePage
      expect(find.text('Learner Home'), findsOneWidget);
      expect(find.text('My Classes'), findsOneWidget);

      // 2. Switch to TeacherHomePage
      await tester.tap(find.byIcon(Icons.change_circle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Check LearnerHomePage again
      expect(find.text('Learner Home'), findsOneWidget);
      expect(find.text('Teacher Home'), findsNothing);
    },
  );
}
