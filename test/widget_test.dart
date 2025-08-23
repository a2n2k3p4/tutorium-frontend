import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:tutorium_frontend/main.dart';
import 'package:tutorium_frontend/home/learner_home_page.dart';
import 'package:tutorium_frontend/widgets/schedule_card.dart';

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

  testWidgets('LearnerHomePage shows correctly', (WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: LearnerHomePage(
            onSwitch: () {}, // callback สำหรับปุ่ม switch
          ),
        ),
      );

      // ตรวจสอบ AppBar title
      expect(find.text('Learner Home'), findsOneWidget);

      // ตรวจสอบ Upcoming Schedule title
      expect(find.text('Upcoming Schedule'), findsOneWidget);

      // ตรวจสอบว่า ScheduleCard ปรากฏ
      expect(find.byType(ScheduleCard), findsWidgets);

      // ตรวจสอบปุ่ม switch และไอคอน school
      expect(find.byIcon(Icons.change_circle), findsOneWidget);
      expect(find.byIcon(Icons.school_rounded), findsOneWidget);
    });
  });
}
