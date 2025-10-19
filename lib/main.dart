import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tutorium_frontend/pages/login/login_ku.dart';
import 'package:tutorium_frontend/pages/main_nav_page.dart';
import 'package:tutorium_frontend/util/local_storage.dart';
import 'package:tutorium_frontend/util/cache_user.dart';
import 'package:tutorium_frontend/util/connectivity_service.dart';
import 'package:tutorium_frontend/service/Users.dart' as user_api;
// import 'package:tutorium_frontend/pages/widgets/noti_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // NotiService().initNotification();
  await dotenv.load(fileName: ".env");

  // เริ่มต้น ConnectivityService
  await ConnectivityService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KU Tutorium',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const AuthChecker(),
      routes: {
        '/login': (context) => const LoginKuPage(),
        '/home': (context) => const MainNavPage(),
      },
    );
  }
}

/// AuthChecker - ตรวจสอบว่าผู้ใช้เคย login ไว้หรือไม่
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // 1. ตรวจสอบ userId และ token จาก local storage
      final userId = await LocalStorage.getUserId();
      final token = await LocalStorage.getToken();

      debugPrint('DEBUG AuthChecker: userId=$userId, hasToken=${token != null}');

      if (userId == null || token == null) {
        // ถ้าไม่มี userId หรือ token -> ไปหน้า Login
        debugPrint('DEBUG AuthChecker: No userId or token found -> go to Login');
        _navigateToLogin();
        return;
      }

      // 2. พยายาม restore user จาก cache/local storage
      debugPrint('DEBUG AuthChecker: Attempting to restore user from cache...');

      // Try to get user from cache (this will also check local storage)
      final cachedUser = await UserCache().getUser(userId, forceRefresh: false);

      if (cachedUser != null) {
        debugPrint(
          'DEBUG AuthChecker: User restored successfully - ${cachedUser.firstName} ${cachedUser.lastName}',
        );

        // อัพเดท cache ด้วยข้อมูลที่ได้
        UserCache().saveUser(cachedUser);

        // ไปหน้าหลัก
        _navigateToHome();
      } else {
        // ถ้า restore ไม่ได้ -> ลบข้อมูลเก่าและไปหน้า Login
        debugPrint('DEBUG AuthChecker: Failed to restore user -> clear and go to Login');
        await LocalStorage.clear();
        UserCache().clear();
        _navigateToLogin();
      }
    } catch (e) {
      debugPrint('ERROR AuthChecker: Error during auth check - $e');
      // ถ้าเกิด error -> ลบข้อมูลและไปหน้า Login
      await LocalStorage.clear();
      UserCache().clear();
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;
    setState(() {
      _isChecking = false;
    });

    // Delay เล็กน้อยเพื่อให้ UI render ก่อน navigate
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  void _navigateToHome() {
    if (!mounted) return;
    setState(() {
      _isChecking = false;
    });

    // Delay เล็กน้อยเพื่อให้ UI render ก่อน navigate
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/KT.png",
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 40),
            if (_isChecking) ...[
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                'กำลังโหลด...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
