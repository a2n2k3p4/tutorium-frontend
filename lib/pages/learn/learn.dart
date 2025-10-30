import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorium_frontend/pages/learn/mandatory_review_page.dart';
import 'package:tutorium_frontend/service/class_sessions.dart'
    as class_sessions;
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

/// Learn Page - Simple Video Conferencing Interface
/// Integrates with Jitsi Meet for live tutoring sessions
class LearnPage extends StatefulWidget {
  final int classSessionId;
  final String className;
  final String teacherName;
  final bool isTeacher;
  final String jitsiMeetingUrl;

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
  String? _userProfilePicture;
  int? _learnerId;

  class_sessions.ClassSession? _classSession;
  Timer? _copyResetTimer;
  bool _reviewShown = false;

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
      debugPrint('👤 Loading user data...');

      // Try to get user profile from LocalStorage first
      final userProfile = await LocalStorage.getUserProfile();
      debugPrint(
        '   Profile from LocalStorage: ${userProfile != null ? "Found" : "Not found"}',
      );

      String? userName;
      String? userEmail;
      String? userProfilePicture;

      if (userProfile != null) {
        // Extract name from profile
        final firstName =
            userProfile['first_name'] ?? userProfile['firstName'] ?? '';
        final lastName =
            userProfile['last_name'] ?? userProfile['lastName'] ?? '';
        final email = userProfile['email'] ?? '';
        final profilePicture =
            userProfile['profile_picture'] ?? userProfile['profilePicture'];

        debugPrint('   First name: "$firstName"');
        debugPrint('   Last name: "$lastName"');
        debugPrint('   Email: "$email"');
        debugPrint(
          '   Profile Picture: ${profilePicture != null ? "Found" : "Not found"}',
        );

        // Combine first and last name
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          userName = '$firstName $lastName'.trim();
        }

        if (email.isNotEmpty) {
          userEmail = email;
        }

        if (profilePicture != null && profilePicture.toString().isNotEmpty) {
          userProfilePicture = profilePicture.toString();
        }
      }

      // Fallback to SharedPreferences if profile not found
      if (userName == null || userEmail == null) {
        debugPrint('   Fallback to SharedPreferences...');
        final prefs = await SharedPreferences.getInstance();
        userName ??= prefs.getString('userName');
        userEmail ??= prefs.getString('userEmail');
        debugPrint('   userName from prefs: "$userName"');
        debugPrint('   userEmail from prefs: "$userEmail"');
      }

      // Get learner ID
      final learnerId = await LocalStorage.getLearnerId();
      debugPrint('   Learner ID: $learnerId');

      if (!mounted) return;

      setState(() {
        _userName = userName;
        _userEmail = userEmail;
        _userProfilePicture = userProfilePicture;
        _learnerId = learnerId;
        if (!widget.isTeacher && learnerId == null) {
          _errorMessage = 'ไม่พบ Learner ID โปรดเข้าสู่ระบบใหม่';
        }
      });

      debugPrint('✅ User data loaded successfully');
      debugPrint('   Final userName: "$_userName"');
      debugPrint('   Final userEmail: "$_userEmail"');
      debugPrint(
        '   Final profilePicture: ${_userProfilePicture != null ? "Found" : "Not found"}',
      );
    } catch (e) {
      debugPrint('❌ Failed to load user data: $e');
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

      if (!mounted) return;

      setState(() {
        _classSession = session;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูลคลาสได้: $e';
      });
    }
  }

  String? _joinDisabledReason() {
    if (widget.jitsiMeetingUrl.trim().isEmpty) {
      return 'ไม่พบลิงก์ห้องเรียนจากระบบ';
    }

    // Allow joining at any time (before, during, or after class)
    return null;
  }

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

  Future<void> _handleConferenceTerminated(Object? error) async {
    if (widget.isTeacher) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    // For learners, allow leaving at any time and show review
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
    while (!submitted) {
      if (!mounted) break;

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
    },
    videoMutedChanged: (isMuted) {
      debugPrint('📹 Video muted: $isMuted');
    },
    screenShareToggled: (participantId, isSharing) {
      debugPrint('🖥️ Screen share toggled by $participantId: $isSharing');
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

  Future<void> _joinConference() async {
    debugPrint('🎯 ========== JOIN CONFERENCE START ==========');
    debugPrint(
      '👨‍🏫 Role: ${widget.isTeacher ? "TEACHER (Full Admin)" : "LEARNER (Speak/Listen Only)"}',
    );
    debugPrint('📚 Class: ${widget.className}');
    debugPrint('🆔 Session ID: ${widget.classSessionId}');

    final reason = _joinDisabledReason();
    if (reason != null) {
      debugPrint('❌ Join disabled: $reason');
      _showErrorDialog(reason);
      return;
    }

    // ===== STEP 1: Validate User Data =====
    // Handle cases where email might be the string "null"
    if (_userEmail == null || _userEmail!.toLowerCase() == 'null') {
      _userEmail = '';
    }

    // Handle profile picture if it's the string "null"
    if (_userProfilePicture != null &&
        _userProfilePicture!.toLowerCase() == 'null') {
      _userProfilePicture = null;
    }

    if (_userName == null || _userName!.trim().isEmpty) {
      debugPrint('❌ User data missing: userName=$_userName, email=$_userEmail');
      _showErrorDialog('กรุณาตั้งชื่อ-นามสกุลในโปรไฟล์ก่อนเข้าห้องเรียน');
      return;
    }

    // ===== STEP 2: Validate Real Name =====
    debugPrint('🔍 Validating real name...');
    final name = _userName!.trim();
    debugPrint('   Name: "$name"');

    // Check if name looks real (at least 2 words, not just numbers)
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final hasMinWords = words.length >= 2;
    final notOnlyNumbers = !RegExp(r'^\d+$').hasMatch(name);
    final notDefaultName = ![
      'student',
      'user',
      'guest',
      'test',
    ].contains(name.toLowerCase());

    debugPrint('   - Word count: ${words.length} ${hasMinWords ? "✓" : "✗"}');
    debugPrint(
      '   - Not only numbers: $notOnlyNumbers ${notOnlyNumbers ? "✓" : "✗"}',
    );
    debugPrint(
      '   - Not default name: $notDefaultName ${notDefaultName ? "✓" : "✗"}',
    );

    if (!hasMinWords || !notOnlyNumbers || !notDefaultName) {
      debugPrint('❌ Real name validation FAILED');
      _showErrorDialog(
        'กรุณาใช้ชื่อ-นามสกุลจริงในโปรไฟล์ก่อนเข้าห้องเรียน\n\n'
        'ตัวอย่าง: "สมชาย ใจดี" (อย่างน้อย 2 คำ)',
      );
      return;
    }
    debugPrint('✅ Real name validation PASSED');

    // ===== STEP 3: Parse Meeting URL =====
    debugPrint('🔗 Parsing meeting URL...');
    final meetingConfig = _parseJitsiMeetingUrl(widget.jitsiMeetingUrl);
    if (meetingConfig == null) {
      debugPrint('❌ Invalid meeting URL: ${widget.jitsiMeetingUrl}');
      setState(() {
        _isLoading = false;
        _errorMessage = 'ลิงก์ห้องเรียนไม่ถูกต้องหรือขาดข้อมูลที่จำเป็น';
      });
      _showErrorDialog(_errorMessage!);
      return;
    }
    debugPrint('✅ Meeting URL parsed successfully');
    debugPrint('   Server: ${meetingConfig.serverUrl}');
    debugPrint('   Room: ${meetingConfig.roomName}');
    debugPrint(
      '   Token: ${meetingConfig.token != null ? "Present (${meetingConfig.token!.length} chars)" : "None"}',
    );

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ===== STEP 4: Build Conference Options =====
      debugPrint('⚙️ Building conference options...');

      // Define toolbar buttons based on role
      final toolbarButtons = widget.isTeacher
          ? [
              'microphone',
              'camera',
              'chat',
              'participants-pane',
              'security',
              'invite',
              'recording',
              'livestreaming',
              'desktop',
              'videoquality',
              'tileview',
              'stats',
              'settings',
              'help',
              'hangup',
            ]
          : ['microphone', 'camera', 'hangup'];

      debugPrint('🔘 Toolbar buttons (${toolbarButtons.length}):');
      for (final btn in toolbarButtons) {
        debugPrint('   - $btn');
      }

      final options = JitsiMeetConferenceOptions(
        serverURL: meetingConfig.serverUrl,
        room: meetingConfig.roomName,
        token: meetingConfig.token,
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          "subject": widget.className,

          // ===== Permission Controls =====
          "requireDisplayName": true, // Force display name
          "disableRemoteMute": !widget.isTeacher, // Learner can't mute others
          "disableInviteFunctions": !widget.isTeacher, // Learner can't invite
          "disableModeratorIndicator":
              !widget.isTeacher, // Hide moderator badge for learners
          "enableClosePage": widget.isTeacher, // Only teacher can end for all
          // ===== UI Controls =====
          "hideConferenceSubject": false,
          "hideConferenceTimer": false,
          "toolbarButtons": toolbarButtons,
        },
        featureFlags: {
          // ===== Core Audio/Video (Both roles) =====
          FeatureFlags.audioMuteButtonEnabled: true,
          FeatureFlags.videoMuteEnabled: true,
          FeatureFlags.audioFocusDisabled: false,
          FeatureFlags.audioOnlyButtonEnabled: true,

          // ===== Teacher-Only Admin Features =====
          FeatureFlags.kickOutEnabled: widget.isTeacher,
          FeatureFlags.inviteEnabled: widget.isTeacher,
          FeatureFlags.addPeopleEnabled: widget.isTeacher,
          FeatureFlags.recordingEnabled: widget.isTeacher,
          FeatureFlags.iosRecordingEnabled: widget.isTeacher,
          FeatureFlags.liveStreamingEnabled: widget.isTeacher,
          FeatureFlags.securityOptionEnabled: widget.isTeacher,
          FeatureFlags.replaceParticipant: widget.isTeacher,
          FeatureFlags.lobbyModeEnabled: false,
          FeatureFlags.meetingPasswordEnabled: false,

          // ===== Learner-Restricted Features =====
          FeatureFlags.chatEnabled: widget.isTeacher,
          FeatureFlags.raiseHandEnabled: widget.isTeacher,
          FeatureFlags.reactionsEnabled: widget.isTeacher,
          FeatureFlags.androidScreenSharingEnabled: widget.isTeacher,
          FeatureFlags.iosScreenSharingEnabled: widget.isTeacher,
          FeatureFlags.videoShareEnabled: widget.isTeacher,
          FeatureFlags.helpButtonEnabled: widget.isTeacher,
          FeatureFlags.overflowMenuEnabled: widget.isTeacher,
          FeatureFlags.settingsEnabled: widget.isTeacher,
          FeatureFlags.closeCaptionsEnabled: widget.isTeacher,
          FeatureFlags.speakerStatsEnabled: widget.isTeacher,
          FeatureFlags.pipWhileScreenSharingEnabled: widget.isTeacher,

          // ===== View & Layout (Both roles) =====
          FeatureFlags.fullScreenEnabled: true,
          FeatureFlags.filmstripEnabled: true,
          FeatureFlags.tileViewEnabled: true,
          FeatureFlags.toolboxEnabled: true,
          FeatureFlags.toolboxAlwaysVisible: false,
          FeatureFlags.pipEnabled: true,
          FeatureFlags.conferenceTimerEnabled: true,
          FeatureFlags.meetingNameEnabled: true,

          // ===== System Settings =====
          FeatureFlags.resolution: FeatureFlagVideoResolutions.resolution720p,
          FeatureFlags.notificationEnabled: true,
          FeatureFlags.calenderEnabled: false,
          FeatureFlags.callIntegrationEnabled: false,
          FeatureFlags.carModeEnabled: false,
          FeatureFlags.welcomePageEnabled: false,
          FeatureFlags.preJoinPageEnabled: false,
          FeatureFlags.preJoinPageHideDisplayName: false,
          FeatureFlags.unsafeRoomWarningEnabled: false,
          FeatureFlags.serverUrlChangeEnabled: false,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: _userName!,
          email: _userEmail ?? '',
          avatar:
              _userProfilePicture ??
              "https://api.dicebear.com/7.x/avataaars/png?seed=$_userName",
        ),
      );

      // ===== STEP 5: Log Feature Flags Summary =====
      debugPrint('🎛️ Feature Flags Summary:');
      debugPrint('   Admin Features (Teacher only):');
      debugPrint('     - Kick out: ${widget.isTeacher}');
      debugPrint('     - Invite: ${widget.isTeacher}');
      debugPrint('     - Recording: ${widget.isTeacher}');
      debugPrint('     - Live Streaming: ${widget.isTeacher}');
      debugPrint('     - Security: ${widget.isTeacher}');
      debugPrint('   Interactive Features (Teacher only):');
      debugPrint('     - Chat: ${widget.isTeacher}');
      debugPrint('     - Raise Hand: ${widget.isTeacher}');
      debugPrint('     - Reactions: ${widget.isTeacher}');
      debugPrint('     - Screen Share: ${widget.isTeacher}');
      debugPrint('     - Video Share: ${widget.isTeacher}');
      debugPrint('     - Settings: ${widget.isTeacher}');
      debugPrint('   Core Features (Both roles):');
      debugPrint('     - Audio Mute: ✓');
      debugPrint('     - Video Mute: ✓');
      debugPrint('     - Tile View: ✓');
      debugPrint('     - Full Screen: ✓');

      // ===== STEP 6: Join Conference =====
      debugPrint('🚀 Joining conference...');
      await _jitsiMeet.join(options, _eventListener);

      debugPrint('✅ ========== JOIN CONFERENCE SUCCESS ==========');
      debugPrint('👤 Display Name: $_userName');
      debugPrint('📧 Email: $_userEmail');
      debugPrint('🎬 Room: ${meetingConfig.roomName}');
      debugPrint('🌐 Server: ${meetingConfig.serverUrl}');
      debugPrint('👨‍🏫 Role: ${widget.isTeacher ? "TEACHER" : "LEARNER"}');
      debugPrint('================================================');
    } catch (e) {
      debugPrint('❌ ========== JOIN CONFERENCE FAILED ==========');
      debugPrint('Error: $e');
      debugPrint('==============================================');
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

  Future<void> _leaveConference() async {
    // Allow leaving at any time for both teachers and learners
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
              'ตกลง',
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
    _copyResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            widget.isTeacher ? Colors.purple.shade100 : Colors.blue.shade100,
            widget.isTeacher ? Colors.pink.shade100 : Colors.cyan.shade100,
            widget.isTeacher ? Colors.purple.shade50 : Colors.blue.shade50,
          ],
        ),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (value * 0.2),
              child: Opacity(
                opacity: value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            widget.isTeacher
                                ? Colors.purple.shade50
                                : Colors.blue.shade50,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (widget.isTeacher ? Colors.purple : Colors.blue)
                                    .withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 20,
                            spreadRadius: -5,
                            offset: const Offset(-10, -10),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              strokeWidth: 5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.isTeacher
                                    ? Colors.purple.shade500
                                    : Colors.blue.shade500,
                              ),
                              backgroundColor:
                                  (widget.isTeacher
                                          ? Colors.purple
                                          : Colors.blue)
                                      .withValues(alpha: 0.1),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: widget.isTeacher
                                    ? [
                                        Colors.purple.shade400,
                                        Colors.pink.shade400,
                                      ]
                                    : [
                                        Colors.blue.shade400,
                                        Colors.cyan.shade400,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (widget.isTeacher
                                              ? Colors.purple
                                              : Colors.blue)
                                          .withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.videocam_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.9),
                            Colors.white.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: widget.isTeacher
                                        ? [
                                            Colors.purple.shade400,
                                            Colors.pink.shade400,
                                          ]
                                        : [
                                            Colors.blue.shade400,
                                            Colors.cyan.shade400,
                                          ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'กำลังเข้าสู่ห้องเรียน',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'กำลังเชื่อมต่อกับ Jitsi Meet...',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: widget.isTeacher
                                    ? [
                                        Colors.purple.shade400,
                                        Colors.pink.shade400,
                                      ]
                                    : [
                                        Colors.blue.shade400,
                                        Colors.cyan.shade400,
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (widget.isTeacher
                                              ? Colors.purple
                                              : Colors.blue)
                                          .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
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
          bottom: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 20.0,
              bottom: 32.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
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

                // Meeting Link Card
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

                // Join Button
                _buildJoinButtonSection(),
                const SizedBox(height: 16),

                // Back Button
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
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
                      'แชร์หรือเปิดผ่านเบราว์เซอร์ได้',
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
                    ? 'คัดลอกสำเร็จ! วางลิงก์นี้บนเบราว์เซอร์ได้เลย'
                    : 'แตะที่กล่องลิงก์หรือปุ่มคัดลอก ระบบจะบันทึกลงคลิปบอร์ด',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
            ),
          if (!hasLink)
            Text(
              'ยังไม่มีลิงก์จากระบบ โปรดตรวจสอบกับผู้ดูแล',
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

  Widget _buildInConferenceView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade500,
            Colors.teal.shade500,
            Colors.green.shade600,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Success Icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.5 + (value * 0.5),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.green.shade50],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 10,
                              offset: const Offset(0, 15),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: -5,
                              offset: const Offset(-10, -10),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 100,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Status Container
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.25),
                      Colors.white.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.6),
                                blurRadius: 15,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'กำลังอยู่ในห้องเรียน',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        widget.className,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Info Card
              Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.video_camera_front_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Jitsi Meet กำลังทำงานในหน้าต่างแยก',
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'การประชุมวิดีโอทำงานอยู่เบื้องหลัง\nกรุณาเปิดแอปพลิเคชัน Jitsi Meet',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Leave Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 25,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _leaveConference,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                  ),
                  icon: const Icon(Icons.call_end_rounded, size: 28),
                  label: const Text(
                    'ออกจากห้องเรียน',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
