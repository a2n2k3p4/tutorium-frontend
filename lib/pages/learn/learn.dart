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
        Navigator.of(context).pop();
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

  // Join Conference - Direct join without prejoin
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
          "hideConferenceTimer": false,
          "disableInviteFunctions": !widget.isTeacher,
          "prejoinPageEnabled": false,
          "requireDisplayName": false,
          "enableWelcomePage": false,
          "startScreenSharing": false,
          "startAudioOnly": false,
          "toolbarButtons": widget.isTeacher
              ? [
                  'camera',
                  'chat',
                  'desktop',
                  'filmstrip',
                  'fullscreen',
                  'hangup',
                  'microphone',
                  'participants-pane',
                  'raisehand',
                  'recording',
                  'settings',
                  'tileview',
                  'toggle-camera',
                  'videoquality',
                ]
              : [
                  'camera',
                  'chat',
                  'desktop',
                  'microphone',
                  'hangup',
                  'raisehand',
                  'tileview',
                  'settings',
                ],
        },
        featureFlags: {
          "unsaferoomwarning.enabled": false,
          "welcomepage.enabled": false,
          "prejoinpage.enabled": false, // ปิด prejoin
          "security-options.enabled": false, // ปิด security options
          "lobby-mode.enabled": false, // ปิด lobby mode
          "chat.enabled": true,
          "live-streaming.enabled": widget.isTeacher,
          "recording.enabled": widget.isTeacher,
          "calendar.enabled": false,
          "call-integration.enabled": false,
          "meeting-name.enabled": true,
          "meeting-password.enabled": false, // ปิด password
          "pip.enabled": true,
          "kick-out.enabled": widget.isTeacher,
          "tile-view.enabled": true,
          "raise-hand.enabled": true,
          "video-share.enabled": true,
          "screen-sharing.enabled": true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: _userName!, // ส่งชื่อผ่าน parameter
          email: _userEmail!, // ส่ง email ผ่าน parameter
          avatar: widget.isTeacher
              ? "https://api.dicebear.com/7.x/avataaars/png?seed=$_userName"
              : "https://api.dicebear.com/7.x/avataaars/png?seed=$_userName",
        ),
      );

      // Join conference and listen to events
      await _jitsiMeet.join(options, _eventListener);

      debugPrint("you are you in root");
      debugPrint('👤 Display Name: $_userName');
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
          Navigator.of(context).pop();
        }
      } catch (e) {
        _showErrorDialog('Failed to leave conference: $e');
      }
    }
  }

  // Toggle Audio
  Future<void> _toggleAudio() async {
    try {
      await _jitsiMeet.setAudioMuted(!_isAudioMuted);
      setState(() {
        _isAudioMuted = !_isAudioMuted;
      });
    } catch (e) {
      _showErrorDialog('Failed to toggle audio: $e');
    }
  }

  // Toggle Video
  Future<void> _toggleVideo() async {
    try {
      await _jitsiMeet.setVideoMuted(!_isVideoMuted);
      setState(() {
        _isVideoMuted = !_isVideoMuted;
      });
    } catch (e) {
      _showErrorDialog('Failed to toggle video: $e');
    }
  }

  // Toggle Screen Share
  Future<void> _toggleScreenShare() async {
    try {
      await _jitsiMeet.toggleScreenShare(!_isScreenSharing);
      setState(() {
        _isScreenSharing = !_isScreenSharing;
      });
    } catch (e) {
      _showErrorDialog('Failed to toggle screen share: $e');
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
              ? _buildConferenceView()
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

  Widget _buildConferenceView() {
    return Column(
      children: [
        // Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.className,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(_sessionDuration),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.people,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_participants.length + 1}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _leaveConference,
                icon: const Icon(Icons.close),
                color: Colors.red,
                tooltip: 'Leave Class',
              ),
            ],
          ),
        ),

        // Conference Placeholder
        Expanded(
          child: Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam,
                    size: 100,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Conference is running in Jitsi Meet window',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Control Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
                label: _isAudioMuted ? 'Unmute' : 'Mute',
                onPressed: _toggleAudio,
                isActive: !_isAudioMuted,
                color: _isAudioMuted ? Colors.red : Colors.blue,
              ),
              _buildControlButton(
                icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                label: _isVideoMuted ? 'Start Video' : 'Stop Video',
                onPressed: _toggleVideo,
                isActive: !_isVideoMuted,
                color: _isVideoMuted ? Colors.red : Colors.blue,
              ),
              _buildControlButton(
                icon: _isScreenSharing
                    ? Icons.stop_screen_share
                    : Icons.screen_share,
                label: _isScreenSharing ? 'Stop Share' : 'Share',
                onPressed: _toggleScreenShare,
                isActive: _isScreenSharing,
                color: widget.isTeacher ? Colors.purple : Colors.blueGrey,
              ),
              _buildControlButton(
                icon: Icons.call_end,
                label: 'Leave',
                onPressed: _leaveConference,
                isActive: false,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isActive ? color : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(50),
          elevation: isActive ? 4 : 0,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Icon(
                icon,
                color: isActive ? Colors.white : Colors.grey.shade600,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
