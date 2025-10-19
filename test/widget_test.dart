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

  testWidgets('App bootstraps without navigation errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
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

      // Wait for initial render and hero animations.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      // 1. Check LearnerHomePage
      expect(find.text('Learner Home').evaluate().isNotEmpty, isTrue);
      expect(find.text('My Classes').evaluate().isNotEmpty, isTrue);

      // 2. Switch to TeacherHomePage
      await tester.tap(find.byTooltip('Switch to Teacher Mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      // 3. Check TeacherHomePage
      expect(find.text('Teacher Home').evaluate().isNotEmpty, isTrue);

      // 4. Switch back to LearnerHomePage
      await tester.tap(find.byTooltip('Switch to Learner Mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      // 5. Check LearnerHomePage again
      expect(find.text('Learner Home').evaluate().isNotEmpty, isTrue);
      expect(find.text('Teacher Home').evaluate().isEmpty, isTrue);
    },
  );
}
