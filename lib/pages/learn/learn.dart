import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Timer? _sessionTimer;
  Duration _sessionDuration = Duration.zero;

  String? _userName;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadUserData();
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

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userName = prefs.getString('userName') ?? 'Student';
        _userEmail = prefs.getString('userEmail') ?? 'student@ku.th';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
        _isLoading = false;
      });
    }
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
      if (mounted) {
        // Navigate back to home page
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
    if (_userName == null || _userEmail == null) {
      _showErrorDialog('กรุณาตรวจสอบข้อมูลผู้ใช้');
      return;
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
          "disableRemoteMute": !widget.isTeacher, // Learner ไม่สามารถ mute คนอื่นได้
          "disableModeratorIndicator": !widget.isTeacher, // ซ่อน moderator indicator สำหรับ Learner
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
          FeatureFlags.addPeopleEnabled: widget.isTeacher, // เชิญคนเข้าห้อง (Teacher only)
          FeatureFlags.inviteEnabled: widget.isTeacher, // ส่งคำเชิญ (Teacher only)
          FeatureFlags.kickOutEnabled: widget.isTeacher, // เตะคนออกจากห้อง (Teacher only)

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
          FeatureFlags.securityOptionEnabled: widget.isTeacher, // Security menu (Teacher only)
          FeatureFlags.lobbyModeEnabled: false, // ไม่ใช้ lobby mode
          FeatureFlags.meetingPasswordEnabled: false, // ไม่ใช้รหัสผ่าน
          FeatureFlags.replaceParticipant: widget.isTeacher, // แทนที่ participant (Teacher only)

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
          avatar:
              "https://api.dicebear.com/7.x/avataaars/png?seed=$_userName",
        ),
      );

      // Join conference with event listener
      await _jitsiMeet.join(options, _eventListener);

      debugPrint('🚀 Joined Jitsi conference successfully');
      debugPrint('👤 Display Name: $_userName');
      debugPrint('📧 Email: $_userEmail');
      debugPrint('🎬 Room: ${meetingConfig.roomName}');
      debugPrint('🌐 Server: ${meetingConfig.serverUrl}');
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
    final shouldLeave = await _showLeaveDialog();
    if (shouldLeave == true) {
      try {
        await _jitsiMeet.hangUp();
        setState(() {
          _isInConference = false;
        });
        if (mounted) {
          // Navigate back to home page
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
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
                Container(
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
                      // Avatar
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

                      // User Details
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
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Room Link Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isTeacher
                          ? Colors.purple.shade200
                          : Colors.blue.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        color: widget.isTeacher
                            ? Colors.purple.shade600
                            : Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ลิงก์ห้องเรียน',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              roomUrl,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade500, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _joinConference,
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
                          'เข้าร่วมห้องเรียนเลย',
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
                const SizedBox(height: 16),

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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
