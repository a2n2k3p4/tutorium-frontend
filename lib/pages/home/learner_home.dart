import 'package:flutter/material.dart';
import '../widgets/schedule_card.dart';

class LearnerHomePage extends StatelessWidget {
  final VoidCallback onSwitch;
  const LearnerHomePage({super.key, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> scheduleData = [
      {
        'className': 'Guitar class by Jane',
        'enrolledLearner': 10,
        'teacherName': 'Jane Frost',
        'date': '2025-07-25',
        'startTime': '13:00',
        'endTime': '16:00',
        'imageUrl':
            'https://images.unsplash.com/photo-1511376777868-611b54f68947?auto=format&fit=crop&w=120&h=100&q=80',
      },
      {
        'className': 'Piano class by Jane',
        'enrolledLearner': 10,
        'teacherName': 'Jane Frost',
        'date': '2025-07-26',
        'startTime': '13:00',
        'endTime': '16:00',
        'imageUrl':
            'https://images.unsplash.com/photo-1513883049090-d0b7439799bf?auto=format&fit=crop&w=120&h=100&q=80',
      },
    ];

    DateTime parseDate(String dateStr) => DateTime.parse(dateStr);
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: const Text(
                "Learner Home",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 36.0,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_rounded,
                    color: Colors.amber,
                    size: 50,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.change_circle,
                      color: Colors.amber,
                      size: 50,
                    ),
                    onPressed: onSwitch,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Upcoming Schedule",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 3),
              Container(height: 2, width: 200, color: Colors.black),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: scheduleData.length,
                  itemBuilder: (context, index) {
                    final item = scheduleData[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: ScheduleCard(
                        className: item['className'],
                        enrolledLearner: item['enrolledLearner'],
                        teacherName: item['teacherName'],
                        date: parseDate(item['date']),
                        startTime: parseTime(item['startTime']),
                        endTime: parseTime(item['endTime']),
                        imageUrl: item['imageUrl'],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
