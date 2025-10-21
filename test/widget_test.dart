import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutorium_frontend/main.dart';
import 'package:tutorium_frontend/pages/main_nav_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Set up fake SharedPreferences with mock user data
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'learner_id': 1,
      'token': 'mock_token',
    });

    dotenv.loadFromString(
      envString: '''
      API_URL=http://127.0.0.1
      PORT=8080
      LOGIN_API=http://127.0.0.1/login
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

    // Clean up any pending timers from auth check
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('MainNavPage shows LearnerHomePage with teacher mode switch button', (
    WidgetTester tester,
  ) async {
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

    // 2. Verify switch to teacher mode button exists
    final switchButton = find.byTooltip('Switch to Teacher Mode');
    expect(
      switchButton,
      findsOneWidget,
      reason: 'Switch to Teacher Mode button should exist',
    );

    // Note: We don't test the actual switch functionality here because it requires
    // working API endpoints to check teacher eligibility. The switch button existence
    // verifies the UI renders correctly.
  });
}
