import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/home/teacher_home.dart';
import 'package:tutorium_frontend/util/connectivity_service.dart';
import 'home/learner_home.dart';
// import 'home/teacher/teacher_home.dart';
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

  late final PageController _pageController;
  late final LearnerHomePage _learnerHomePage;
  late final TeacherHomePage _teacherHomePage;
  late final Widget _searchPage;
  late final Widget _notificationPage;
  late final Widget _profilePage;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _learnerHomePage = LearnerHomePage(
      key: const PageStorageKey('learner_home'),
      onSwitch: toggleRole,
    );
    _teacherHomePage = TeacherHomePage(
      key: const PageStorageKey('teacher_home'),
      onSwitch: toggleRole,
    );
    _searchPage = const SearchPage(key: PageStorageKey('search_page'));
    _notificationPage = const NotificationPage(
      key: PageStorageKey('notification_page'),
    );
    _profilePage = const ProfilePage(key: PageStorageKey('profile_page'));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void toggleRole() {
    setState(() {
      isLearner = !isLearner;
    });
  }

  void _handleBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
      if (_currentIndex == 0) {
        // Ensure we always land back on learner mode when returning home via nav bar.
        isLearner = true;
      }
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildHomePage() {
    final Widget currentHome = isLearner
        ? KeyedSubtree(
            key: const ValueKey('learner_home_view'),
            child: _learnerHomePage,
          )
        : KeyedSubtree(
            key: const ValueKey('teacher_home_view'),
            child: _teacherHomePage,
          );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetAnimation =
            Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
            );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: currentHome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildHomePage(),
      _searchPage,
      _notificationPage,
      _profilePage,
    ];

    return ConnectivityWrapper(
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          allowImplicitScrolling: true,
          onPageChanged: _handlePageChanged,
          children: pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _handleBottomNavTap,
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
      ),
    );
  }
}
