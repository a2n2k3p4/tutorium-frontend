import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:tutorium_frontend/home/learner_home_page.dart';
import 'package:tutorium_frontend/widgets/schedule_card.dart';

void main() {
  testWidgets('LearnerHomePage shows correctly', (WidgetTester tester) async {
    // Mock network images
    await mockNetworkImagesFor(() async {
      // Build LearnerHomePage
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
