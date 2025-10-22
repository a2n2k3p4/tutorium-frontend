import 'package:flutter/material.dart';
import 'package:tutorium_frontend/models/models.dart';
import 'package:tutorium_frontend/pages/home/teacher/my_classes_page.dart';
import 'package:tutorium_frontend/pages/home/teacher/create_class_page.dart';
import 'package:tutorium_frontend/pages/home/teacher/create_session_page.dart';
import 'package:tutorium_frontend/pages/home/teacher/register/payment_screen.dart';
import 'package:tutorium_frontend/service/users.dart' as user_api;
import 'package:tutorium_frontend/pages/widgets/api_service.dart' as legacy_api;
import 'package:tutorium_frontend/util/cache_user.dart';
import 'package:tutorium_frontend/util/local_storage.dart';
import 'package:tutorium_frontend/util/class_cache_manager.dart';

class TeacherHomePage extends StatefulWidget {
  final VoidCallback onSwitch;

  const TeacherHomePage({super.key, required this.onSwitch});

  @override
  TeacherHomePageState createState() => TeacherHomePageState();
}

class TeacherHomePageState extends State<TeacherHomePage> {
  List<ClassModel> _classes = [];
  bool _isLoading = true;
  int? _teacherId;
  bool _isTeacher = true;
  String? _errorMessage;
  String? _teacherDisplayName;
  final _classCache = ClassCacheManager();

  @override
  void initState() {
    super.initState();
    _classCache.initialize();
    _loadTeacherData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Public method to refresh data when network reconnects
  void refreshData() {
    debugPrint('🔄 [TeacherHome] Refreshing data due to network reconnection');
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isTeacher = true;
        _errorMessage = null;
      });
    }

    try {
      final userId = await LocalStorage.getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final cachedUser = UserCache().user;
      final shouldRefresh = cachedUser == null || cachedUser.teacher == null;
      final user = await UserCache().getUser(
        userId,
        forceRefresh: shouldRefresh,
      );

      final teacher = user.teacher;
      if (teacher == null) {
        if (mounted) {
          setState(() {
            _teacherId = null;
            _isTeacher = false;
            _classes = [];
            _isLoading = false;
          });
        }
        return;
      }

      _teacherId = teacher.id;
      _teacherDisplayName = _buildTeacherName(user);
      await _loadClasses();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load teacher data: $e';
        });
      }
    }
  }

  Future<void> _loadClasses() async {
    if (_teacherId == null) return;

    // Don't show loading spinner on refresh, just load in background
    final isInitialLoad = _classes.isEmpty;
    if (mounted && isInitialLoad) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      debugPrint(
        '📚 Loading classes for teacher $_teacherId (isInitialLoad: $isInitialLoad)',
      );

      // Use cache manager - it handles parallel fetching internally
      final cachedClasses = await _classCache.getClassesByTeacher(
        _teacherId!,
        teacherName: _teacherDisplayName,
        forceRefresh: isInitialLoad, // Force refresh on initial load
      );

      debugPrint('📚 Loaded ${cachedClasses.length} classes');
      debugPrint(
        '📚 Classes: ${cachedClasses.map((c) => c.className).toList()}',
      );

      final classes = cachedClasses
          .map(
            (cached) => ClassModel(
              id: cached.id,
              className: cached.className,
              classDescription: cached.classDescription,
              bannerPicture: cached.bannerPictureUrl,
              rating: cached.rating,
              teacherId: cached.teacherId,
            ),
          )
          .toList();

      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading classes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading classes: $e';
        });
        if (isInitialLoad) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error loading classes: $e')));
        }
      }
    }
  }

  String? _buildTeacherName(user_api.User user) {
    final first = user.firstName?.trim();
    final last = user.lastName?.trim();
    final parts = [first, last]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  Future<void> _navigateToCreateClass() async {
    if (_teacherId == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateClassPage(teacherId: _teacherId!),
      ),
    );

    if (result == true) {
      _loadClasses();
    }
  }

  Future<void> _navigateToCreateSession(ClassModel classModel) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSessionPage(classModel: classModel),
      ),
    );

    if (result == true) {
      _loadClasses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: isMediumScreen ? 70 : 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                child: Text(
                  "Teacher Home",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: isSmallScreen
                        ? 20.0
                        : isMediumScreen
                        ? 24.0
                        : 28.0,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 8,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                      child: Icon(
                        Icons.co_present,
                        color: Colors.green,
                        size: isSmallScreen ? 24 : 32,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.change_circle,
                        color: Colors.green,
                        size: isSmallScreen ? 24 : 32,
                      ),
                      onPressed: widget.onSwitch,
                      tooltip: 'Switch to Learner Mode',
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isTeacher
          ? _buildNoTeacherState()
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadClasses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions Section
                      _buildQuickActions(),
                      const SizedBox(height: 24),

                      // My Classes Section
                      _buildMyClassesSection(),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton:
          (_isLoading ||
              !_isTeacher ||
              _teacherId == null ||
              _errorMessage != null)
          ? null
          : FloatingActionButton.extended(
              onPressed: _navigateToCreateClass,
              backgroundColor: Colors.blue[700],
              icon: const Icon(Icons.add),
              label: const Text(
                'Create Class',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'View Sessions',
                Icons.event_note,
                Colors.purple,
                () {
                  if (_teacherId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MyClassesPage(teacherId: _teacherId!),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Withdraw',
                Icons.account_balance_wallet,
                Colors.green,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Withdraw - Coming Soon')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyClassesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Classes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (_classes.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  if (_teacherId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MyClassesPage(teacherId: _teacherId!),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_classes.isEmpty)
          _buildEmptyClasses()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _classes.length > 3 ? 3 : _classes.length,
            itemBuilder: (context, index) {
              return _buildClassCard(_classes[index]);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyClasses() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.class_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Classes Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first class to start teaching!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _navigateToCreateClass,
            icon: const Icon(Icons.add),
            label: const Text('Create Class'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (_teacherId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyClassesPage(teacherId: _teacherId!),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildClassThumbnail(classModel),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classModel.className,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classModel.classDescription,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          classModel.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle,
                  color: Colors.green[700],
                  size: 32,
                ),
                onPressed: () => _navigateToCreateSession(classModel),
                tooltip: 'Add Session',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassThumbnail(ClassModel classModel) {
    const double size = 70;
    final imageUrl = classModel.bannerPicture;

    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildClassThumbnailPlaceholder(size: size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _buildClassThumbnailPlaceholder(size: size),
      ),
    );
  }

  Widget _buildClassThumbnailPlaceholder({double size = 70}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image, color: Colors.blue[700], size: size * 0.5),
    );
  }

  Future<void> _registerAsTeacher() async {
    try {
      final userId = await LocalStorage.getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Get user's current balance
      final user = await UserCache().getUser(userId, forceRefresh: true);

      // Check if user has enough balance (200 THB)
      if (user.balance < 200) {
        if (!mounted) return;

        // Show dialog asking to top up
        final shouldTopUp = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.orange[700],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'เงินไม่เพียงพอ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              content: Text(
                'คุณต้องการ 200 บาทเพื่อสมัครเป็นครู\nยอดเงินปัจจุบัน: ${user.balance.toStringAsFixed(2)} บาท\n\nต้องการเติมเงินหรือไม่?',
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'เติมเงิน',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );

        if (shouldTopUp == true && mounted) {
          // Navigate to payment screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(userId: userId),
            ),
          );

          // If payment successful, try registering again
          if (result == true) {
            _registerAsTeacher();
          }
        }
        return;
      }

      // User has enough balance, proceed with payment and registration
      if (!mounted) return;

      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.school, color: Colors.green[700], size: 28),
                const SizedBox(width: 12),
                const Text(
                  'สมัครเป็นครู',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            content: Text(
              'ค่าสมัครเป็นครู: 200 บาท\nยอดเงินปัจจุบัน: ${user.balance.toStringAsFixed(2)} บาท\n\nต้องการดำเนินการต่อหรือไม่?',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'ยืนยัน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      if (shouldProceed != true) return;

      if (!mounted) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Create teacher registration
      final response = await legacy_api.ApiService.registerTeacher(
        userId: userId,
        email: '',
        description: '',
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (response['success'] == true) {
        // Clear cache to force refresh
        UserCache().clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครเป็นครูสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload teacher data
        _loadTeacherData();
      } else {
        throw Exception(response['message'] ?? 'Failed to register as teacher');
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildNoTeacherState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 72, color: Colors.blueGrey[200]),
            const SizedBox(height: 16),
            const Text(
              'สมัครเป็นครู',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'ค่าสมัครเป็นครู: 200 บาท',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'สมัครเป็นครูเพื่อเริ่มสร้างคลาสเรียนและสอนนักเรียน',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _registerAsTeacher,
              icon: const Icon(Icons.person_add),
              label: const Text('สมัครเป็นครู (200 บาท)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onSwitch,
              icon: const Icon(Icons.arrow_back),
              label: const Text('กลับไปหน้าผู้เรียน'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueGrey[700],
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadTeacherData,
              child: const Text('รีเฟรช'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTeacherData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
