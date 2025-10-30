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

  final GlobalKey<LearnerHomePageState> _learnerHomeKey =
      GlobalKey<LearnerHomePageState>();
  final GlobalKey<TeacherHomePageState> _teacherHomeKey =
      GlobalKey<TeacherHomePageState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _learnerHomePage = LearnerHomePage(
      key: _learnerHomeKey,
      onSwitch: toggleRole,
    );
    _teacherHomePage = TeacherHomePage(
      key: _teacherHomeKey,
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

  void _refreshAllPages() {
    // Refresh learner home page
    _learnerHomeKey.currentState?.refreshData();
    // Refresh teacher home page
    _teacherHomeKey.currentState?.refreshData();
  }

  void _handleBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
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
      onReconnect: _refreshAllPages,
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
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 360;
            return BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _handleBottomNavTap,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.green,
              unselectedItemColor: Colors.grey,
              selectedFontSize: isSmallScreen ? 11 : 14,
              unselectedFontSize: isSmallScreen ? 10 : 12,
              iconSize: isSmallScreen ? 22 : 24,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: "Search",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: "Notification",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Profile",
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
