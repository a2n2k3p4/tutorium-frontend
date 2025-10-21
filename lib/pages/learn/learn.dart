import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorium_frontend/pages/learn/mandatory_review_page.dart';
import 'package:tutorium_frontend/pages/learn/class_participants_page.dart';
import 'package:tutorium_frontend/service/class_sessions.dart'
    as class_sessions;
import 'package:tutorium_frontend/service/class_readiness_service.dart';
import 'package:tutorium_frontend/util/local_storage.dart';
import 'package:tutorium_frontend/service/classes.dart' as classes;

class _JitsiMeetingConfig {
  const _JitsiMeetingConfig({
    required this.serverUrl,
    required this.roomName,
    this.token,
  });

  final String serverUrl;
  final String roomName;
  final String? token;
}

/// Learn Page - Beautiful Video Conferencing Interface
/// Integrates with Jitsi Meet for live tutoring sessions
class LearnPage extends StatefulWidget {
  final int classSessionId;
  final String className;
  final String teacherName;
  final bool isTeacher;
  final String jitsiMeetingUrl; // Jitsi Meeting URL from Backend

  const LearnPage({
    super.key,
    required this.classSessionId,
    required this.className,
    required this.teacherName,
    required this.jitsiMeetingUrl,
    this.isTeacher = false,
  });

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage>
    with SingleTickerProviderStateMixin {
  final JitsiMeet _jitsiMeet = JitsiMeet();
  final List<String> _participants = [];
  final List<ChatMessage> _chatMessages = [];

  bool _isInConference = false;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isScreenSharing = false;
  bool _isLoading = true;
  bool _showChat = false;
  String? _errorMessage;
  bool _isCopyingLink = false;
  bool _hasCopiedLink = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Timer? _sessionTimer;
  Duration _sessionDuration = Duration.zero;

  String? _userName;
  String? _userEmail;
  int? _userId;
  int? _learnerId;

  class_sessions.ClassSession? _classSession;
  DateTime? _classStart;
  DateTime? _classFinish;
  Timer? _countdownTimer;
  Timer? _broadcastTimer;
  Timer? _copyResetTimer;
  Duration? _timeUntilStart;
  bool _teacherReady = false;
  bool _learnerReady = false;
  bool _hasBroadcastReady = false;
  bool _isClassCompleted = false;
  bool _reviewShown = false;
  bool _isMarkingReady = false;
  bool _isMarkingLearnerReady = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializePage();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  Future<void> _initializePage() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await _loadUserData();
      await _loadSessionInformation();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString('userName') ?? 'Student';
      final storedEmail = prefs.getString('userEmail') ?? 'student@ku.th';
      final userId = await LocalStorage.getUserId();
      final learnerId = await LocalStorage.getLearnerId();
      final readyKey = _learnerReadyPrefKey(learnerId);
      final storedReady = readyKey != null
          ? prefs.getBool(readyKey) ?? false
          : false;

      if (!mounted) return;

      setState(() {
        _userName = storedName;
        _userEmail = storedEmail;
        _userId = userId;
        _learnerId = learnerId;
        if (storedReady) {
          _learnerReady = true;
        }
        if (!widget.isTeacher && learnerId == null) {
          _errorMessage = 'ไม่พบ Learner ID โปรดเข้าสู่ระบบใหม่';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
      });
    }
  }

  Future<void> _loadSessionInformation() async {
    try {
      final session = await class_sessions.ClassSession.fetchById(
        widget.classSessionId,
      );

      final normalized = ClassReadinessService.normalizeStatus(
        session.classStatus,
      );
      final start = _parseDateTime(session.classStart);
      final finish = _parseDateTime(session.classFinish);
      final teacherReady =
          normalized == ClassReadinessService.statusTeacherReady ||
          normalized == ClassReadinessService.statusLive ||
          normalized == ClassReadinessService.statusCompleted;
      final isCompleted = normalized == ClassReadinessService.statusCompleted;
      final broadcastAlready =
          normalized == ClassReadinessService.statusLive ||
          normalized == ClassReadinessService.statusCompleted;

      if (!mounted) return;

      setState(() {
        _classSession = session;
        _classStart = start;
        _classFinish = finish;
        _teacherReady = teacherReady;
        _isClassCompleted = isCompleted;
        if (broadcastAlready) {
          _hasBroadcastReady = true;
        }
      });

      _startCountdown();
      _scheduleBroadcastTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูลคลาสได้: $e';
      });
    }
  }

  DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final parsed = DateTime.parse(raw);
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return null;
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateCountdown();
    if (_classStart == null) {
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (!mounted) return;

    if (_classStart == null) {
      setState(() {
        _timeUntilStart = null;
      });
      return;
    }

    final now = DateTime.now();
    final diff = _classStart!.difference(now);

    setState(() {
      _timeUntilStart = diff;
    });

    _checkBroadcastCondition(now);
  }

  void _checkBroadcastCondition(DateTime now) {
    if (!widget.isTeacher) return;
    if (_hasBroadcastReady) return;
    if (!_teacherReady) return;
    if (_classStart == null) return;

    final broadcastTime = _classStart!.subtract(const Duration(minutes: 5));
    if (!now.isBefore(broadcastTime)) {
      _broadcastTeacherReady();
    }
  }

  void _scheduleBroadcastTimer() {
    _broadcastTimer?.cancel();

    if (!widget.isTeacher) return;
    if (_hasBroadcastReady) return;
    if (!_teacherReady) return;
    if (_classStart == null) return;

    final now = DateTime.now();
    final broadcastTime = _classStart!.subtract(const Duration(minutes: 5));

    if (!now.isBefore(broadcastTime)) {
      _broadcastTeacherReady();
      return;
    }

    final delay = broadcastTime.difference(now);
    _broadcastTimer = Timer(delay, () {
      _broadcastTeacherReady();
    });
  }

  Future<void> _broadcastTeacherReady() async {
    if (!widget.isTeacher) return;
    if (_hasBroadcastReady) return;
    if (_classSession == null) return;

    _broadcastTimer?.cancel();

    try {
      await ClassReadinessService.broadcastTeacherReady(
        classSessionId: widget.classSessionId,
        className: widget.className,
        teacherName: widget.teacherName,
      );

      if (!mounted) return;

      setState(() {
        _hasBroadcastReady = true;
      });

      _showSnackBar(
        'แจ้งผู้เรียนแล้วว่าคลาสพร้อมเริ่ม',
        Icons.campaign_rounded,
        Colors.purple.shade600,
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('ส่งประกาศไม่สำเร็จ: $e');
    }
  }

  Future<void> _handleTeacherReady() async {
    if (_teacherReady) {
      _showSnackBar(
        'ประกาศสถานะ "พร้อมสอน" แล้ว',
        Icons.check_circle_outline,
        Colors.purple.shade400,
      );
      return;
    }

    if (!_isTeacherWindowOpen()) {
      _showErrorDialog('กดพร้อมสอนได้ล่วงหน้า 10 นาทีเท่านั้น');
      return;
    }

    if (_classSession == null) {
      await _loadSessionInformation();
    }

    if (_classSession == null) {
      _showErrorDialog('ไม่พบข้อมูลคลาสสำหรับตั้งค่าพร้อมสอน');
      return;
    }

    if (mounted) {
      setState(() {
        _isMarkingReady = true;
      });
    }

    final wasLate = _isTeacherTooLateToMarkReady();

    try {
      final updated = await ClassReadinessService.markTeacherReady(
        _classSession!,
      );

      if (!mounted) return;

      setState(() {
        _classSession = updated;
        _teacherReady = true;
        _isClassCompleted =
            ClassReadinessService.normalizeStatus(updated.classStatus) ==
            ClassReadinessService.statusCompleted;
      });

      _scheduleBroadcastTimer();

      final message = wasLate
          ? 'ตั้งสถานะพร้อมสอนแล้ว (เกินเวลา 10 นาที)'
          : 'ตั้งสถานะพร้อมสอนแล้ว';

      _showSnackBar(message, Icons.school_rounded, Colors.purple.shade600);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('ตั้งค่าว่าพร้อมสอนไม่สำเร็จ: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingReady = false;
        });
      }
    }
  }

  Future<void> _handleLearnerReady() async {
    if (_learnerReady) {
      _showSnackBar(
        'ยืนยันแล้วว่าพร้อมเรียน',
        Icons.check_circle_outline,
        Colors.blue.shade500,
      );
      return;
    }

    if (!_teacherReady) {
      _showErrorDialog('รอผู้สอนกดยืนยันว่าพร้อมก่อน');
      return;
    }

    if (!_isLearnerReadyWindowOpen()) {
      _showErrorDialog('ยืนยันได้ก่อนเวลาเริ่ม 5 นาที');
      return;
    }

    if (mounted) {
      setState(() {
        _isMarkingLearnerReady = true;
      });
    }

    try {
      if (!mounted) return;
      setState(() {
        _learnerReady = true;
      });
      await _persistLearnerReady(true);
      _showSnackBar(
        'พร้อมเข้าเรียนแล้ว! กดเข้าห้องได้เลย',
        Icons.emoji_emotions_rounded,
        Colors.blue.shade600,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingLearnerReady = false;
        });
      }
    }
  }

  String? _learnerReadyPrefKey(int? learnerId) {
    if (learnerId == null) return null;
    return 'learner_ready_${widget.classSessionId}_$learnerId';
  }

  Future<void> _persistLearnerReady(bool value) async {
    final key = _learnerReadyPrefKey(_learnerId);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  bool get _isTeacher => widget.isTeacher;

  bool _isTeacherWindowOpen() {
    if (_classStart == null) return true;
    final now = DateTime.now();
    final earliest = _classStart!.subtract(const Duration(minutes: 10));
    return !now.isBefore(earliest);
  }

  bool _isTeacherTooLateToMarkReady() {
    if (_classStart == null) return false;
    final latest = _classStart!.add(const Duration(minutes: 10));
    return DateTime.now().isAfter(latest);
  }

  bool _isLearnerReadyWindowOpen() {
    if (_classStart == null) return true;
    final now = DateTime.now();
    final openAt = _classStart!.subtract(const Duration(minutes: 5));
    return !now.isBefore(openAt);
  }

  bool _canLearnerLeave() {
    if (_isClassCompleted) return true;
    if (_classFinish == null) return true;
    return !DateTime.now().isBefore(_classFinish!);
  }

  bool _canJoinClass() {
    return _joinDisabledReason() == null;
  }

  String? _joinDisabledReason() {
    if (widget.jitsiMeetingUrl.trim().isEmpty) {
      return 'ไม่พบลิงก์ห้องเรียนจากระบบ';
    }

    if (_isTeacher) {
      if (!_teacherReady) {
        return 'กดปุ่ม "พร้อมสอน" เพื่อเปิดห้อง';
      }
      return null;
    }

    if (!_teacherReady) {
      return 'รอผู้สอนกดยืนยันว่าพร้อมเริ่มคลาส';
    }

    if (!_learnerReady) {
      return 'กดปุ่ม "ฉันพร้อมเรียน" ก่อนเข้าห้อง';
    }

    if (!_isLearnerReadyWindowOpen()) {
      return 'เข้าห้องได้ก่อนเวลาเริ่ม 5 นาที';
    }

    return null;
  }

  bool _hasValidMeetingLink() => widget.jitsiMeetingUrl.trim().isNotEmpty;

  Future<void> _copyMeetingLink() async {
    final link = widget.jitsiMeetingUrl.trim();

    if (link.isEmpty) {
      _showSnackBar(
        'ไม่พบลิงก์ห้องเรียน',
        Icons.link_off_rounded,
        Colors.red.shade400,
      );
      return;
    }

    _copyResetTimer?.cancel();

    if (mounted) {
      setState(() {
        _isCopyingLink = true;
        _hasCopiedLink = false;
      });
    }

    try {
      await Clipboard.setData(ClipboardData(text: link));

      if (!mounted) return;

      setState(() {
        _hasCopiedLink = true;
      });

      _showSnackBar(
        'คัดลอกลิงก์ห้องเรียนแล้ว',
        Icons.check_circle_rounded,
        Colors.green.shade500,
      );

      _copyResetTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _hasCopiedLink = false;
        });
      });
    } catch (error) {
      debugPrint('Failed to copy meeting link: $error');

      if (mounted) {
        _showSnackBar(
          'คัดลอกลิงก์ไม่สำเร็จ โปรดลองอีกครั้ง',
          Icons.error_outline,
          Colors.red.shade400,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCopyingLink = false;
        });
      }
    }
  }

  String _formatCountdown(Duration? duration) {
    if (duration == null) {
      return '--:--:--';
    }
    final abs = duration.abs();
    final hours = abs.inHours;
    final minutes = abs.inMinutes.remainder(60);
    final seconds = abs.inSeconds.remainder(60);
    final prefix = duration.isNegative ? '-' : '';
    return '$prefix${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTimeDisplay(DateTime? dt) {
    if (dt == null) return '-';
    final date = dt;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute น.';
  }

  Future<void> _refreshSessionStatus() async {
    try {
      await _loadSessionInformation();
    } catch (_) {
      // Ignore refresh errors; UI already shows latest known state.
    }
  }

  Future<void> _onConferenceJoined() async {
    if (!widget.isTeacher) return;
    if (_classSession == null) return;

    try {
      final updated = await ClassReadinessService.markClassLive(_classSession!);
      if (!mounted) return;
      setState(() {
        _classSession = updated;
        _isClassCompleted =
            ClassReadinessService.normalizeStatus(updated.classStatus) ==
            ClassReadinessService.statusCompleted;
      });
    } catch (e) {
      debugPrint('❌ [LearnPage] Failed to mark class live: $e');
    }
  }

  Future<void> _maybeMarkClassCompleted() async {
    if (!widget.isTeacher) return;
    if (_classSession == null) return;

    final shouldComplete =
        _isClassCompleted ||
        (_classFinish != null && !DateTime.now().isBefore(_classFinish!));

    if (!shouldComplete) return;

    try {
      final updated = await ClassReadinessService.markClassCompleted(
        _classSession!,
      );
      if (!mounted) return;
      setState(() {
        _classSession = updated;
        _isClassCompleted = true;
      });
    } catch (e) {
      debugPrint('❌ [LearnPage] Failed to mark class complete: $e');
    }
  }

  Future<void> _handleConferenceTerminated(Object? error) async {
    await _refreshSessionStatus();

    if (widget.isTeacher) {
      await _maybeMarkClassCompleted();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (!_canLearnerLeave()) {
      if (mounted) {
        _showErrorDialog('คลาสยังไม่จบ ระบบจะพาคุณกลับเข้าเรียน');
      }
      await Future.delayed(const Duration(seconds: 1));
      await _joinConference();
      return;
    }

    await _openMandatoryReview();
  }

  Future<void> _handleReadyToClose() async {
    await _handleConferenceTerminated(null);
  }

  Future<void> _openMandatoryReview() async {
    if (_reviewShown) {
      return;
    }

    if (_learnerId == null) {
      if (mounted) {
        _showErrorDialog('ไม่พบ Learner ID สำหรับสร้างรีวิว');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    if (_classSession == null) {
      await _loadSessionInformation();
    }

    final classId = _classSession?.classId ?? 0;
    if (classId == 0) {
      if (mounted) {
        _showErrorDialog('ไม่พบ Class ID สำหรับรีวิว');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    _reviewShown = true;

    // Get teacher info from class
    int? teacherId;
    String? teacherName = widget.teacherName;
    try {
      final classInfo = await classes.ClassInfo.fetchById(classId);
      teacherId = classInfo.teacherId;
      if (classInfo.teacherName != null && classInfo.teacherName!.isNotEmpty) {
        teacherName = classInfo.teacherName;
      }
    } catch (e) {
      debugPrint('Failed to fetch class info for report: $e');
    }

    var submitted = false;
    while (!submitted && mounted) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => MandatoryReviewPage(
            classId: classId,
            className: widget.className,
            learnerId: _learnerId!,
            classSessionId: widget.classSessionId,
            teacherId: teacherId,
            teacherName: teacherName,
          ),
        ),
      );
      submitted = result == true;
    }

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Event listener for Jitsi Meet
  JitsiMeetEventListener get _eventListener => JitsiMeetEventListener(
    conferenceJoined: (url) {
      debugPrint('✅ Conference joined: $url');
      if (mounted) {
        setState(() {
          _isInConference = true;
          _isLoading = false;
          _errorMessage = null;
        });
        _startSessionTimer();
        unawaited(_onConferenceJoined());
      }
    },
    conferenceTerminated: (url, error) {
      debugPrint('❌ Conference terminated: $url, error: $error');
      if (mounted) {
        setState(() {
          _isInConference = false;
          _participants.clear();
          _chatMessages.clear();
        });
        _stopSessionTimer();
        unawaited(_handleConferenceTerminated(error));
        if (error != null) {
          _showErrorDialog('Conference ended with error: $error');
        }
      }
    },
    conferenceWillJoin: (url) {
      debugPrint('⏳ Conference will join: $url');
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    },
    participantJoined: (email, name, role, participantId) {
      debugPrint(
        '👤 Participant joined: $name ($email) - Role: $role, ID: $participantId',
      );
      if (mounted &&
          participantId != null &&
          !_participants.contains(participantId)) {
        setState(() {
          _participants.add(participantId);
        });
        final displayName = name ?? 'Someone';
        _showSnackBar(
          '$displayName joined the class',
          Icons.person_add,
          Colors.green,
        );
      }
    },
    participantLeft: (participantId) {
      debugPrint('👋 Participant left: $participantId');
      if (mounted && participantId != null) {
        setState(() {
          _participants.remove(participantId);
        });
        _showSnackBar('A participant left', Icons.person_remove, Colors.orange);
      }
    },
    audioMutedChanged: (isMuted) {
      debugPrint('🎤 Audio muted: $isMuted');
      if (mounted) {
        setState(() {
          _isAudioMuted = isMuted;
        });
      }
    },
    videoMutedChanged: (isMuted) {
      debugPrint('📹 Video muted: $isMuted');
      if (mounted) {
        setState(() {
          _isVideoMuted = isMuted;
        });
      }
    },
    screenShareToggled: (participantId, isSharing) {
      debugPrint('🖥️ Screen share toggled by $participantId: $isSharing');
      if (mounted) {
        setState(() {
          _isScreenSharing = isSharing;
        });
      }
    },
    chatMessageReceived: (senderId, message, isPrivate, privateRecipient) {
      debugPrint(
        '💬 Chat message: from $senderId, message: $message, private: $isPrivate',
      );
      if (mounted) {
        setState(() {
          _chatMessages.add(
            ChatMessage(
              senderId: senderId,
              message: message,
              isPrivate: isPrivate,
              timestamp: DateTime.now(),
            ),
          );
        });
        if (!_showChat) {
          _showSnackBar(
            'New message received',
            Icons.message,
            Colors.blue.shade700,
          );
        }
      }
    },
    chatToggled: (isOpen) {
      debugPrint('💬 Chat toggled: $isOpen');
      if (mounted) {
        setState(() {
          _showChat = isOpen;
        });
      }
    },
    participantsInfoRetrieved: (participantsInfo) {
      debugPrint('📊 Participants info: $participantsInfo');
    },
    readyToClose: () {
      debugPrint('🚪 Ready to close');
      unawaited(_handleReadyToClose());
    },
  );

  // Session Timer
  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sessionDuration = Duration(seconds: _sessionDuration.inSeconds + 1);
      });
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  // Join Conference - Full Jitsi SDK with ALL features enabled
  Future<void> _joinConference() async {
    final reason = _joinDisabledReason();
    if (reason != null) {
      _showErrorDialog(reason);
      return;
    }

    if (_userName == null || _userEmail == null) {
      _showErrorDialog('กรุณาตรวจสอบข้อมูลผู้ใช้');
      return;
    }

    if (_classSession == null) {
      await _loadSessionInformation();
    }

    final meetingConfig = _parseJitsiMeetingUrl(widget.jitsiMeetingUrl);
    if (meetingConfig == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ลิงก์ห้องเรียนไม่ถูกต้องหรือขาดข้อมูลที่จำเป็น';
      });
      _showErrorDialog(_errorMessage!);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final options = JitsiMeetConferenceOptions(
        serverURL: meetingConfig.serverUrl,
        room: meetingConfig.roomName,
        token: meetingConfig.token,
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          "subject": widget.className,

          // Role-based permissions in config
          "disableRemoteMute":
              !widget.isTeacher, // Learner ไม่สามารถ mute คนอื่นได้
          "disableModeratorIndicator":
              !widget.isTeacher, // ซ่อน moderator indicator สำหรับ Learner
          "hideConferenceSubject": false, // แสดงชื่อคลาสเสมอ
          "hideConferenceTimer": false, // แสดงเวลาเสมอ
          // Disable invite functions for Learner
          "disableInviteFunctions": !widget.isTeacher,

          // Only Teacher can end meeting for everyone
          "enableClosePage": widget.isTeacher, // Teacher สามารถปิดห้องได้
        },
        featureFlags: {
          // Enable ALL feature flags for full Jitsi experience
          // Role-based permissions: Teacher has full control, Learner is restricted

          // People & Participants
          FeatureFlags.addPeopleEnabled:
              widget.isTeacher, // เชิญคนเข้าห้อง (Teacher only)
          FeatureFlags.inviteEnabled:
              widget.isTeacher, // ส่งคำเชิญ (Teacher only)
          FeatureFlags.kickOutEnabled:
              widget.isTeacher, // เตะคนออกจากห้อง (Teacher only)
          // Video & Audio Quality
          FeatureFlags.resolution: FeatureFlagVideoResolutions.resolution720p,
          FeatureFlags.audioFocusDisabled: false,
          FeatureFlags.audioMuteButtonEnabled: true,
          FeatureFlags.audioOnlyButtonEnabled: true,
          FeatureFlags.videoMuteEnabled: true,
          FeatureFlags.fullScreenEnabled: true,

          // Screen Sharing
          FeatureFlags.androidScreenSharingEnabled: true,
          FeatureFlags.iosScreenSharingEnabled: true,
          FeatureFlags.videoShareEnabled: true,
          FeatureFlags.pipEnabled: true,
          FeatureFlags.pipWhileScreenSharingEnabled: true,

          // Communication Features (Available to all)
          FeatureFlags.chatEnabled: true,
          FeatureFlags.raiseHandEnabled: true,
          FeatureFlags.reactionsEnabled: true,
          FeatureFlags.closeCaptionsEnabled: true,

          // Recording & Streaming (Teacher only - Full control)
          FeatureFlags.recordingEnabled: widget.isTeacher,
          FeatureFlags.iosRecordingEnabled: widget.isTeacher,
          FeatureFlags.liveStreamingEnabled: widget.isTeacher,

          // UI & Layout
          FeatureFlags.filmstripEnabled: true,
          FeatureFlags.tileViewEnabled: true,
          FeatureFlags.toolboxEnabled: true,
          FeatureFlags.toolboxAlwaysVisible: false,
          FeatureFlags.overflowMenuEnabled: true,

          // Settings & Info
          FeatureFlags.settingsEnabled: true,
          FeatureFlags.helpButtonEnabled: true,
          FeatureFlags.speakerStatsEnabled: true,
          FeatureFlags.conferenceTimerEnabled: true,
          FeatureFlags.meetingNameEnabled: true,

          // Calendar & Integration
          FeatureFlags.calenderEnabled: true,
          FeatureFlags.callIntegrationEnabled: true,
          FeatureFlags.carModeEnabled: true,

          // Security & Admin (Teacher only - Full control)
          FeatureFlags.securityOptionEnabled:
              widget.isTeacher, // Security menu (Teacher only)
          FeatureFlags.lobbyModeEnabled: false, // ไม่ใช้ lobby mode
          FeatureFlags.meetingPasswordEnabled: false, // ไม่ใช้รหัสผ่าน
          FeatureFlags.replaceParticipant:
              widget.isTeacher, // แทนที่ participant (Teacher only)
          // Pre-join & Welcome
          FeatureFlags.welcomePageEnabled: false,
          FeatureFlags.preJoinPageEnabled: false,
          FeatureFlags.preJoinPageHideDisplayName: false,
          FeatureFlags.unsafeRoomWarningEnabled: false,

          // Notifications
          FeatureFlags.notificationEnabled: true,

          // Server Settings
          FeatureFlags.serverUrlChangeEnabled: false, // ไม่ให้เปลี่ยน server
        },
        userInfo: JitsiMeetUserInfo(
          displayName: _userName!,
          email: _userEmail!,
          avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=$_userName",
        ),
      );

      // Join conference with event listener
      await _jitsiMeet.join(options, _eventListener);

      debugPrint('🚀 Joined Jitsi conference successfully');
      debugPrint('👤 Display Name: $_userName');
      debugPrint('📧 Email: $_userEmail');
      debugPrint('🎬 Room: ${meetingConfig.roomName}');
      debugPrint('🌐 Server: ${meetingConfig.serverUrl}');

      if (!widget.isTeacher && !_learnerReady) {
        setState(() {
          _learnerReady = true;
        });
        unawaited(_persistLearnerReady(true));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ไม่สามารถเข้าห้องเรียนได้: $e';
      });
      _showErrorDialog(_errorMessage!);
    }
  }

  _JitsiMeetingConfig? _parseJitsiMeetingUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return null;
    }

    final pathSegments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (pathSegments.isEmpty) {
      return null;
    }

    final roomName = Uri.decodeComponent(pathSegments.last);
    final baseSegments = pathSegments.length > 1
        ? pathSegments.sublist(0, pathSegments.length - 1)
        : const <String>[];

    final buffer = StringBuffer()..write('${uri.scheme}://${uri.host}');
    if (uri.hasPort) {
      buffer.write(':${uri.port}');
    }
    if (baseSegments.isNotEmpty) {
      buffer
        ..write('/')
        ..write(baseSegments.map(Uri.encodeComponent).join('/'));
    }

    final token = uri.queryParameters['jwt'] ?? uri.queryParameters['token'];

    return _JitsiMeetingConfig(
      serverUrl: buffer.toString(),
      roomName: roomName,
      token: token,
    );
  }

  // Leave Conference
  Future<void> _leaveConference() async {
    if (!widget.isTeacher && !_canLearnerLeave()) {
      _showErrorDialog('คลาสยังไม่จบ ไม่สามารถออกก่อนเวลาได้');
      return;
    }

    final shouldLeave = await _showLeaveDialog();
    if (shouldLeave == true) {
      try {
        await _jitsiMeet.hangUp();
        setState(() {
          _isInConference = false;
        });
        await _handleConferenceTerminated(null);
      } catch (e) {
        _showErrorDialog('ไม่สามารถออกจากห้องได้: $e');
      }
    }
  }

  // Utility Methods
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.error_rounded,
                color: Colors.red.shade600,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text('เกิดข้อผิดพลาด', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'ตลกด้วย',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showLeaveDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.exit_to_app_rounded,
                color: Colors.orange.shade600,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text('ออกจากห้องเรียน', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการออกจากห้องเรียน?',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'ออกจากห้อง',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _sessionTimer?.cancel();
    _countdownTimer?.cancel();
    _broadcastTimer?.cancel();
    _copyResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When in conference, Jitsi SDK takes over the entire screen
    // We only show pre-join and loading screens
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingView()
              : _isInConference
              ? _buildInConferenceView()
              : _buildPreJoinView(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.isTeacher ? Colors.purple.shade50 : Colors.blue.shade50,
            widget.isTeacher ? Colors.pink.shade50 : Colors.cyan.shade50,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Loading Circle
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isTeacher ? Colors.purple : Colors.blue)
                        .withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isTeacher
                            ? Colors.purple.shade400
                            : Colors.blue.shade400,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.videocam_rounded,
                    size: 32,
                    color: widget.isTeacher
                        ? Colors.purple.shade400
                        : Colors.blue.shade400,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'กำลังเข้าสู่ห้องเรียน...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'กรุณารอสักครู่',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreJoinView() {
    final roomUrl = widget.jitsiMeetingUrl;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.isTeacher ? Colors.purple.shade50 : Colors.blue.shade50,
              widget.isTeacher ? Colors.pink.shade50 : Colors.cyan.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Animated Header Card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Animated Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.isTeacher
                                ? [Colors.purple.shade400, Colors.pink.shade400]
                                : [Colors.blue.shade400, Colors.cyan.shade400],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (widget.isTeacher
                                          ? Colors.purple
                                          : Colors.blue)
                                      .withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.video_call_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Class Name
                      Text(
                        widget.className,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                              letterSpacing: -0.5,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Teacher Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.teacherName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.isTeacher
                                ? [Colors.purple.shade400, Colors.pink.shade400]
                                : [Colors.blue.shade400, Colors.cyan.shade400],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (widget.isTeacher
                                          ? Colors.purple
                                          : Colors.blue)
                                      .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isTeacher
                                  ? Icons.school_rounded
                                  : Icons.person_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isTeacher ? 'โหมดผู้สอน' : 'โหมดผู้เรียน',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // User Info Card
                _buildUserInfoCard(),
                const SizedBox(height: 24),

                if (_buildCountdownCard() != null) ...[
                  _buildCountdownCard()!,
                  const SizedBox(height: 20),
                ],

                widget.isTeacher
                    ? _buildTeacherReadyCard()
                    : _buildLearnerReadyCard(),
                const SizedBox(height: 24),

                _buildMeetingLinkCard(roomUrl),
                const SizedBox(height: 32),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_rounded,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Join Button - Big and Beautiful
                _buildJoinButtonSection(),
                const SizedBox(height: 16),

                // Report Button - Optional for teachers
                if (widget.isTeacher) ...[
                  _buildReportButton(),
                  const SizedBox(height: 8),
                ],

                // Back Button - Subtle
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'กลับ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isTeacher
                    ? [Colors.purple.shade100, Colors.pink.shade100]
                    : [Colors.blue.shade100, Colors.cyan.shade100],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.account_circle_rounded,
              size: 40,
              color: widget.isTeacher
                  ? Colors.purple.shade600
                  : Colors.blue.shade600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เข้าร่วมในนาม',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userName ?? 'กำลังโหลด...',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userEmail ?? '',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildCountdownCard() {
    if (_classStart == null) return null;
    final statusText = (_timeUntilStart != null && _timeUntilStart!.isNegative)
        ? 'คลาสเริ่มไปแล้ว'
        : 'เริ่มใน';
    final bool isUrgent =
        _timeUntilStart != null && _timeUntilStart!.inMinutes <= 5;
    final material = isUrgent ? Colors.orange : Colors.blue;
    final Color accentTone = material.shade400;
    final Color strongTone = material.shade700;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentTone.withValues(alpha: 0.15), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentTone.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentTone,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.timer_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: strongTone,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCountdown(_timeUntilStart),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: strongTone,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'เริ่มเวลา ${_formatDateTimeDisplay(_classStart)}',
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherReadyCard() {
    final windowOpen = _isTeacherWindowOpen();
    final tooLate = _isTeacherTooLateToMarkReady();
    final canPress =
        !_teacherReady && !_isMarkingReady && windowOpen && !tooLate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: 22,
                  color: Colors.purple.shade500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'เตรียมคลาสให้พร้อม',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.purple.shade600,
                ),
              ),
              const Spacer(),
              Chip(
                backgroundColor: _teacherReady
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                avatar: Icon(
                  _teacherReady ? Icons.check_circle : Icons.hourglass_top,
                  size: 18,
                  color: _teacherReady
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
                label: Text(
                  _teacherReady ? 'พร้อมแล้ว' : 'ยังไม่พร้อม',
                  style: TextStyle(
                    color: _teacherReady
                        ? Colors.green.shade700
                        : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'กดปุ่ม "พร้อมสอน" อย่างน้อย 10 นาทีก่อนเริ่มห้อง เพื่อให้ผู้เรียนรับทราบและเตรียมตัวเข้าชั้นเรียน',
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canPress ? _handleTeacherReady : null,
              icon: _isMarkingReady
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.rocket_launch_rounded),
              label: Text(
                _teacherReady ? 'พร้อมสอนแล้ว' : 'กดพร้อมสอน',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teacherReady
                    ? Colors.green.shade500
                    : Colors.purple.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!windowOpen && !_teacherReady)
            Text(
              'กดได้ตั้งแต่ ${_classStart != null ? _formatDateTimeDisplay(_classStart!.subtract(const Duration(minutes: 10))) : '-'}',
              style: TextStyle(color: Colors.red.shade400, fontSize: 12),
            ),
          if (tooLate && !_teacherReady)
            Text(
              'เลยเวลาเริ่มคลาสเกิน 10 นาทีแล้ว โปรดรีบกดพร้อมและเข้าห้อง',
              style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildLearnerReadyCard() {
    final canPress = !_learnerReady && !_isMarkingLearnerReady && _teacherReady;
    final windowOpen = _isLearnerReadyWindowOpen();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.self_improvement_rounded,
                  size: 22,
                  color: Colors.blue.shade500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'เตรียมตัวก่อนเข้าเรียน',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.blue.shade600,
                ),
              ),
              const Spacer(),
              Chip(
                backgroundColor: _teacherReady
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                avatar: Icon(
                  _teacherReady ? Icons.check_circle : Icons.access_time,
                  size: 18,
                  color: _teacherReady
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
                label: Text(
                  _teacherReady ? 'ครูพร้อมแล้ว' : 'รอผู้สอน',
                  style: TextStyle(
                    color: _teacherReady
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'กดปุ่ม "ฉันพร้อมเรียน" ก่อนเริ่ม 5 นาที เพื่อให้ระบบเตรียมห้องเรียนและล็อกอินชื่อของคุณให้ตรงกับแอป',
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (canPress && windowOpen) ? _handleLearnerReady : null,
              icon: _isMarkingLearnerReady
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.emoji_emotions_rounded),
              label: Text(
                _learnerReady ? 'พร้อมเรียนแล้ว' : 'ฉันพร้อมเรียน',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _learnerReady
                    ? Colors.green.shade500
                    : Colors.blue.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'สายเท่าไรก็ได้ แต่ถ้าออกก่อนจบคลาส ระบบจะพากลับเข้าห้องเรียนอัตโนมัติ',
            style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
          ),
          if (!windowOpen && !_learnerReady)
            Text(
              'กดได้เมื่อถึงช่วง 5 นาทีก่อนเริ่มคลาส',
              style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
            ),
          if (_learnerReady)
            Text(
              'เยี่ยม! กดปุ่มเข้าห้องเมื่อพร้อมได้เลย',
              style: TextStyle(color: Colors.green.shade600, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildJoinButtonSection() {
    final disabledReason = _joinDisabledReason();
    final canJoin = disabledReason == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: canJoin
                  ? [Colors.green.shade500, Colors.green.shade600]
                  : [Colors.grey.shade300, Colors.grey.shade400],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (canJoin ? Colors.green : Colors.grey).withValues(
                  alpha: 0.4,
                ),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -2,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: canJoin ? _joinConference : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam_rounded, size: 28),
                ),
                const SizedBox(width: 16),
                const Text(
                  'เข้าห้องเรียน',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (disabledReason != null) ...[
          const SizedBox(height: 12),
          Text(
            disabledReason,
            style: TextStyle(
              color: Colors.red.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildReportButton() {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ClassParticipantsPage(
              classSessionId: widget.classSessionId,
              className: widget.className,
            ),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        foregroundColor: Colors.orange.shade700,
        side: BorderSide(color: Colors.orange.shade300, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.flag_outlined, size: 20),
      label: const Text(
        'รายงานผู้เรียน (ไม่บังคับ)',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMeetingLinkCard(String roomUrl) {
    final hasLink = roomUrl.trim().isNotEmpty;
    final primaryColor = widget.isTeacher
        ? Colors.purple.shade600
        : Colors.blue.shade600;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.12),
                      primaryColor.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.link_rounded, color: primaryColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ลิงก์ห้องเรียน',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'แชร์หรือเปิดผ่านเบราว์เซอร์ได้โดยคัดลอกอัตโนมัติทั้งบนมือถือและเว็บ',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: hasLink && !_isCopyingLink ? _copyMeetingLink : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      hasLink ? roomUrl : 'รอลิงก์จากระบบ',
                      style: TextStyle(
                        color: hasLink
                            ? Colors.grey.shade900
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isCopyingLink
                        ? SizedBox(
                            key: const ValueKey('copying'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                primaryColor,
                              ),
                            ),
                          )
                        : Icon(
                            _hasCopiedLink
                                ? Icons.check_circle_rounded
                                : Icons.copy_rounded,
                            key: ValueKey(_hasCopiedLink ? 'copied' : 'copy'),
                            color: _hasCopiedLink
                                ? Colors.green.shade500
                                : primaryColor,
                            size: 24,
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (hasLink)
            FilledButton.tonalIcon(
              onPressed: _isCopyingLink ? null : _copyMeetingLink,
              icon: Icon(
                _hasCopiedLink
                    ? Icons.task_alt_rounded
                    : Icons.copy_all_rounded,
              ),
              label: Text(
                _hasCopiedLink ? 'คัดลอกแล้ว' : 'คัดลอกลิงก์ห้องเรียน',
              ),
              style: FilledButton.styleFrom(
                foregroundColor: primaryColor,
                backgroundColor: primaryColor.withValues(
                  alpha: _hasCopiedLink ? 0.24 : 0.12,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          if (hasLink)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _hasCopiedLink
                    ? 'คัดลอกสำเร็จ! วางลิงก์นี้บนเบราว์เซอร์หรือส่งให้เพื่อนได้เลย'
                    : 'แตะที่กล่องลิงก์หรือปุ่มคัดลอก ระบบจะบันทึกลงคลิปบอร์ดให้อัตโนมัติ',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
            ),
          if (!hasLink)
            Text(
              'ยังไม่มีลิงก์จากระบบ โปรดตรวจสอบกับผู้ดูแลหรือผู้สอน',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  // Simple in-conference view - Jitsi SDK takes over the screen
  Widget _buildInConferenceView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade600, Colors.teal.shade600],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success Icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 80,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 32),

            // Conference Active Message
            Text(
              'กำลังอยู่ในห้องเรียน',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Class Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.className,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Session Info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(
                  Icons.access_time_rounded,
                  _formatDuration(_sessionDuration),
                ),
                const SizedBox(width: 16),
                _buildInfoChip(
                  Icons.people_rounded,
                  '${_participants.length + 1} คน',
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Info Text
            Text(
              'Jitsi Meet กำลังทำงานในหน้าต่างแยก',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'การประชุมวิดีโอทำงานอยู่เบื้องหลัง',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 48),

            // Leave Button
            ElevatedButton.icon(
              onPressed: _leaveConference,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
              icon: const Icon(Icons.call_end_rounded, size: 24),
              label: const Text(
                'ออกจากห้องเรียน',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Chat Message Model
class ChatMessage {
  final String senderId;
  final String message;
  final bool isPrivate;
  final DateTime timestamp;

  ChatMessage({
    required this.senderId,
    required this.message,
    required this.isPrivate,
    required this.timestamp,
  });
}
