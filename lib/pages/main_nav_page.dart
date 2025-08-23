import 'package:flutter/material.dart';
import 'home/learner_home.dart';
import 'home/teacher_home.dart';
import 'search/search_page.dart';
import 'notification/notification_page.dart';
import 'profile/profile_page.dart';

class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  int _currentIndex = 0;
  bool isLearner = true;

  void toggleRole() {
    setState(() {
      isLearner = !isLearner;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      isLearner
          ? LearnerHomePage(onSwitch: toggleRole)
          : TeacherHomePage(onSwitch: toggleRole),
      const SearchPage(),
      const NotificationPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (_currentIndex == 0) {
              isLearner = true;
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Notification",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
