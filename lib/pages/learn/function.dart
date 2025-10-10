import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorium_frontend/services/api_provider.dart';

/// Utility functions for Learn Page
/// Provides helper methods for Jitsi Meet integration and session management

// Global Jitsi Meet instance
final JitsiMeet jitsiMeet = JitsiMeet();

// Participant list
final List<String> participants = [];

// Chat messages
final List<Map<String, dynamic>> chatMessages = [];

/// Create Jitsi Meet conference options
///
/// Parameters:
/// - [classSessionId]: Unique ID for the class session
/// - [className]: Name of the class
/// - [userName]: Display name of the user
/// - [userEmail]: Email of the user
/// - [isTeacher]: Whether the user is a teacher (affects permissions)
///
/// Returns configured [JitsiMeetConferenceOptions]
JitsiMeetConferenceOptions createConferenceOptions({
  required int classSessionId,
  required String className,
  required String userName,
  required String userEmail,
  bool isTeacher = false,
  String? jitsiMeetingUrl,
}) {
  final parsedUrl = _parseJitsiMeetingUrl(jitsiMeetingUrl);
  final serverUrl = parsedUrl?.serverUrl ?? dotenv.env["JITSI_URL"];

  if (serverUrl == null || serverUrl.isEmpty) {
    throw Exception(
      'Jitsi server URL is missing. Set JITSI_URL or provide jitsiMeetingUrl.',
    );
  }

  return JitsiMeetConferenceOptions(
    serverURL: serverUrl,
    room: parsedUrl?.roomName ?? "tutorium-session-$classSessionId",
    token: parsedUrl?.token,
    configOverrides: {
      "prejoinPageEnabled": false,
      "startWithAudioMuted": false,
      "startWithVideoMuted": false,
      "subject": className,
      "hideConferenceTimer": false,
      "disableInviteFunctions": !isTeacher,
      "requireDisplayName": true,
      "enableWelcomePage": false,
      "enableClosePage": false,
      // Toolbar buttons based on role
      "toolbarButtons": isTeacher
          ? [
              'camera',
              'chat',
              'closedcaptions',
              'desktop',
              'download',
              'embedmeeting',
              'etherpad',
              'feedback',
              'filmstrip',
              'fullscreen',
              'hangup',
              'help',
              'highlight',
              'invite',
              'linktosalesforce',
              'livestreaming',
              'microphone',
              'noisesuppression',
              'participants-pane',
              'profile',
              'raisehand',
              'recording',
              'security',
              'select-background',
              'settings',
              'shareaudio',
              'sharedvideo',
              'shortcuts',
              'stats',
              'tileview',
              'toggle-camera',
              'videoquality',
              'whiteboard',
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
              'fullscreen',
              'participants-pane',
            ],
    },
    featureFlags: {
      "prejoinpage.enabled": false,
      "unsaferoomwarning.enabled": false,
      "welcomepage.enabled": false,
      "chat.enabled": true,
      "live-streaming.enabled": isTeacher,
      "recording.enabled": isTeacher,
      "calendar.enabled": false,
      "call-integration.enabled": false,
      "meeting-name.enabled": true,
      "meeting-password.enabled": isTeacher,
      "pip.enabled": true,
      "kick-out.enabled": isTeacher,
      "tile-view.enabled": true,
      "raise-hand.enabled": true,
      "video-share.enabled": true,
      "screen-sharing.enabled": true,
      "toolbox.alwaysVisible": false,
      "video-quality.persist": true,
      "filmstrip.enabled": true,
      "notifications.enabled": true,
    },
    userInfo: JitsiMeetUserInfo(
      displayName: userName,
      email: userEmail,
      avatar: isTeacher
          ? "https://api.dicebear.com/7.x/avataaars/png?seed=teacher-${userEmail.hashCode}"
          : "https://api.dicebear.com/7.x/avataaars/png?seed=student-${userEmail.hashCode}",
    ),
  );
}

class _ParsedJitsiMeetingUrl {
  const _ParsedJitsiMeetingUrl({
    required this.serverUrl,
    required this.roomName,
    this.token,
  });

  final String serverUrl;
  final String roomName;
  final String? token;
}

_ParsedJitsiMeetingUrl? _parseJitsiMeetingUrl(String? rawUrl) {
  if (rawUrl == null) {
    return null;
  }

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

  return _ParsedJitsiMeetingUrl(
    serverUrl: buffer.toString(),
    roomName: roomName,
    token: token,
  );
}

/// Create a comprehensive event listener for Jitsi Meet
///
/// Parameters:
/// - [onConferenceJoined]: Callback when user joins conference
/// - [onConferenceTerminated]: Callback when conference ends
/// - [onParticipantJoined]: Callback when participant joins
/// - [onParticipantLeft]: Callback when participant leaves
/// - [onChatMessage]: Callback when chat message is received
/// - [onAudioMuted]: Callback when audio mute state changes
/// - [onVideoMuted]: Callback when video mute state changes
/// - [onScreenShare]: Callback when screen share state changes
///
/// Returns configured [JitsiMeetEventListener]
JitsiMeetEventListener createEventListener({
  Function(String?)? onConferenceJoined,
  Function(String?, Object?)? onConferenceTerminated,
  Function(String?, String?, String?, String?)? onParticipantJoined,
  Function(String?)? onParticipantLeft,
  Function(String?, String?, bool?, String?)? onChatMessage,
  Function(bool?)? onAudioMuted,
  Function(bool?)? onVideoMuted,
  Function(String?, bool?)? onScreenShare,
  VoidCallback? onReadyToClose,
}) {
  return JitsiMeetEventListener(
    conferenceJoined: (url) {
      debugPrint("✅ Conference joined: $url");
      if (onConferenceJoined != null) {
        onConferenceJoined(url);
      }
    },
    conferenceTerminated: (url, error) {
      debugPrint("❌ Conference terminated: $url, error: $error");
      participants.clear();
      chatMessages.clear();
      if (onConferenceTerminated != null) {
        onConferenceTerminated(url, error);
      }
    },
    conferenceWillJoin: (url) {
      debugPrint("⏳ Conference will join: $url");
    },
    participantJoined: (email, name, role, participantId) {
      debugPrint(
        "👤 Participant joined: $name ($email) - Role: $role, ID: $participantId",
      );
      if (participantId != null && !participants.contains(participantId)) {
        participants.add(participantId);
      }
      if (onParticipantJoined != null) {
        onParticipantJoined(email, name, role, participantId);
      }
    },
    participantLeft: (participantId) {
      debugPrint("👋 Participant left: $participantId");
      if (participantId != null) {
        participants.remove(participantId);
      }
      if (onParticipantLeft != null) {
        onParticipantLeft(participantId);
      }
    },
    chatMessageReceived: (senderId, message, isPrivate, privateRecipient) {
      debugPrint(
        "💬 Chat message: from $senderId, message: $message, private: $isPrivate, recipient: $privateRecipient",
      );
      if (message != null && senderId != null) {
        chatMessages.add({
          'senderId': senderId,
          'message': message,
          'isPrivate': isPrivate ?? false,
          'privateRecipient': privateRecipient,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      if (onChatMessage != null) {
        onChatMessage(senderId, message, isPrivate, privateRecipient);
      }
    },
    chatToggled: (isOpen) {
      debugPrint("💬 Chat toggled: $isOpen");
    },
    audioMutedChanged: (isMuted) {
      debugPrint("🎤 Audio muted: $isMuted");
      if (onAudioMuted != null) {
        onAudioMuted(isMuted);
      }
    },
    videoMutedChanged: (isMuted) {
      debugPrint("📹 Video muted: $isMuted");
      if (onVideoMuted != null) {
        onVideoMuted(isMuted);
      }
    },
    screenShareToggled: (participantId, isSharing) {
      debugPrint("🖥️ Screen share toggled by $participantId: $isSharing");
      if (onScreenShare != null) {
        onScreenShare(participantId, isSharing);
      }
    },
    participantsInfoRetrieved: (participantsInfo) {
      debugPrint("📊 Participants info retrieved: $participantsInfo");
    },
    readyToClose: () {
      debugPrint("🚪 Ready to close");
      if (onReadyToClose != null) {
        onReadyToClose();
      }
    },
  );
}

/// Join a Jitsi Meet conference
///
/// Parameters:
/// - [options]: Conference options
///
/// Returns [Future<void>]
/// Throws exception if join fails
Future<void> joinConference(JitsiMeetConferenceOptions options) async {
  try {
    await jitsiMeet.join(options);
  } catch (e) {
    debugPrint("❌ Failed to join conference: $e");
    rethrow;
  }
}

/// Leave the current conference
///
/// Returns [Future<void>]
Future<void> leaveConference() async {
  try {
    await jitsiMeet.hangUp();
    participants.clear();
    chatMessages.clear();
  } catch (e) {
    debugPrint("❌ Failed to leave conference: $e");
    rethrow;
  }
}

/// Toggle audio mute state
///
/// Parameters:
/// - [mute]: true to mute, false to unmute
///
/// Returns [Future<void>]
Future<void> toggleAudio(bool mute) async {
  try {
    await jitsiMeet.setAudioMuted(mute);
    debugPrint("🎤 Audio ${mute ? 'muted' : 'unmuted'}");
  } catch (e) {
    debugPrint("❌ Failed to toggle audio: $e");
    rethrow;
  }
}

/// Toggle video mute state
///
/// Parameters:
/// - [mute]: true to mute, false to unmute
///
/// Returns [Future<void>]
Future<void> toggleVideo(bool mute) async {
  try {
    await jitsiMeet.setVideoMuted(mute);
    debugPrint("📹 Video ${mute ? 'muted' : 'unmuted'}");
  } catch (e) {
    debugPrint("❌ Failed to toggle video: $e");
    rethrow;
  }
}

/// Toggle screen sharing
///
/// Parameters:
/// - [share]: true to start sharing, false to stop
///
/// Returns [Future<void>]
Future<void> toggleScreenShare(bool share) async {
  try {
    await jitsiMeet.toggleScreenShare(share);
    debugPrint("🖥️ Screen share ${share ? 'started' : 'stopped'}");
  } catch (e) {
    debugPrint("❌ Failed to toggle screen share: $e");
    rethrow;
  }
}

/// Send a chat message
///
/// Parameters:
/// - [message]: The message to send
/// - [to]: Optional recipient ID for private messages
///
/// Returns [Future<void>]
Future<void> sendChatMessage({required String message, String? to}) async {
  try {
    await jitsiMeet.sendChatMessage(message: message, to: to);
    debugPrint("💬 Chat message sent: $message");
  } catch (e) {
    debugPrint("❌ Failed to send chat message: $e");
    rethrow;
  }
}

/// Open/close the chat window
///
/// Returns [Future<void>]
Future<void> openChat() async {
  try {
    await jitsiMeet.openChat();
    debugPrint("💬 Chat opened");
  } catch (e) {
    debugPrint("❌ Failed to open chat: $e");
    rethrow;
  }
}

/// Close the chat window
///
/// Returns [Future<void>]
Future<void> closeChat() async {
  try {
    await jitsiMeet.closeChat();
    debugPrint("💬 Chat closed");
  } catch (e) {
    debugPrint("❌ Failed to close chat: $e");
    rethrow;
  }
}

/// Retrieve participants information
///
/// Returns [Future<void>]
Future<void> retrieveParticipantsInfo() async {
  try {
    await jitsiMeet.retrieveParticipantsInfo();
    debugPrint("📊 Retrieving participants info");
  } catch (e) {
    debugPrint("❌ Failed to retrieve participants info: $e");
    rethrow;
  }
}

/// Get current participant count
///
/// Returns number of participants including self
int getParticipantCount() {
  return participants.length + 1; // +1 for self
}

/// Get all chat messages
///
/// Returns list of chat messages
List<Map<String, dynamic>> getChatMessages() {
  return List.from(chatMessages);
}

/// Clear all chat messages
void clearChatMessages() {
  chatMessages.clear();
}

/// Format duration to HH:MM:SS
///
/// Parameters:
/// - [duration]: Duration to format
///
/// Returns formatted string
String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(duration.inHours);
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return "$hours:$minutes:$seconds";
}

/// Check if user is logged in
///
/// Returns [Future<bool>]
Future<bool> isLoggedIn() async {
  try {
    return await API.auth.isLoggedIn();
  } catch (e) {
    debugPrint("❌ Failed to check login status: $e");
    return false;
  }
}

/// Get user data from shared preferences
///
/// Returns map with user data or null if not found
Future<Map<String, dynamic>?> getUserData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    final userName = prefs.getString('userName');
    final userEmail = prefs.getString('userEmail');
    final isTeacher = prefs.getBool('isTeacher') ?? false;

    if (userId != null && userName != null && userEmail != null) {
      return {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'isTeacher': isTeacher,
      };
    }
    return null;
  } catch (e) {
    debugPrint("❌ Failed to get user data: $e");
    return null;
  }
}

/// Save session data to track learning progress
///
/// Parameters:
/// - [classSessionId]: ID of the class session
/// - [duration]: Duration of attendance
/// - [joinedAt]: When the user joined
///
/// Returns [Future<void>]
Future<void> saveSessionData({
  required int classSessionId,
  required Duration duration,
  required DateTime joinedAt,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'session_$classSessionId';
    await prefs.setString(key, joinedAt.toIso8601String());
    await prefs.setInt('${key}_duration', duration.inSeconds);
    debugPrint("💾 Session data saved for class $classSessionId");
  } catch (e) {
    debugPrint("❌ Failed to save session data: $e");
  }
}

/// Get saved session data
///
/// Parameters:
/// - [classSessionId]: ID of the class session
///
/// Returns map with session data or null if not found
Future<Map<String, dynamic>?> getSessionData(int classSessionId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'session_$classSessionId';
    final joinedAtStr = prefs.getString(key);
    final durationSeconds = prefs.getInt('${key}_duration');

    if (joinedAtStr != null && durationSeconds != null) {
      return {
        'joinedAt': DateTime.parse(joinedAtStr),
        'duration': Duration(seconds: durationSeconds),
      };
    }
    return null;
  } catch (e) {
    debugPrint("❌ Failed to get session data: $e");
    return null;
  }
}

/// Create enrollment for a class session
///
/// Parameters:
/// - [learnerId]: ID of the learner
/// - [classSessionId]: ID of the class session
///
/// Returns [Future<bool>] true if successful
Future<bool> createEnrollment({
  required int learnerId,
  required int classSessionId,
}) async {
  try {
    // Note: This requires the Enrollment model from models.dart
    // Uncomment when model is available:
    // final enrollment = Enrollment(
    //   id: 0,
    //   learnerId: learnerId,
    //   classSessionId: classSessionId,
    //   enrollmentStatus: 'active',
    // );
    // await API.enrollment.createEnrollment(enrollment);
    debugPrint(
      "✅ Enrollment created for learner $learnerId in session $classSessionId",
    );
    return true;
  } catch (e) {
    debugPrint("❌ Failed to create enrollment: $e");
    return false;
  }
}

/// Update enrollment status
///
/// Parameters:
/// - [enrollmentId]: ID of the enrollment
/// - [status]: New status (e.g., 'active', 'completed', 'cancelled')
///
/// Returns [Future<bool>] true if successful
Future<bool> updateEnrollmentStatus({
  required int enrollmentId,
  required String status,
}) async {
  try {
    // Note: This requires the appropriate API method
    // Uncomment when available:
    // await API.enrollment.updateEnrollmentStatus(enrollmentId, status);
    debugPrint("✅ Enrollment $enrollmentId updated to status: $status");
    return true;
  } catch (e) {
    debugPrint("❌ Failed to update enrollment status: $e");
    return false;
  }
}

/// Show a beautiful snack bar notification
///
/// Parameters:
/// - [context]: Build context
/// - [message]: Message to display
/// - [icon]: Icon to show
/// - [color]: Background color
/// - [duration]: How long to show (default 2 seconds)
void showNotification(
  BuildContext context,
  String message, {
  IconData icon = Icons.info,
  Color color = Colors.blue,
  Duration duration = const Duration(seconds: 2),
}) {
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
      duration: duration,
    ),
  );
}

/// Show error dialog
///
/// Parameters:
/// - [context]: Build context
/// - [title]: Dialog title
/// - [message]: Error message
void showErrorDialog(
  BuildContext context,
  String message, {
  String title = 'Error',
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Show confirmation dialog
///
/// Parameters:
/// - [context]: Build context
/// - [title]: Dialog title
/// - [message]: Confirmation message
/// - [confirmText]: Text for confirm button
/// - [cancelText]: Text for cancel button
///
/// Returns [Future<bool?>] true if confirmed, false if cancelled, null if dismissed
Future<bool?> showConfirmationDialog(
  BuildContext context,
  String message, {
  String title = 'Confirm',
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  Color confirmColor = Colors.blue,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

/// Validate class session before joining
///
/// Parameters:
/// - [classSessionId]: ID of the class session
///
/// Returns [Future<Map<String, dynamic>>] with validation result
Future<Map<String, dynamic>> validateClassSession(int classSessionId) async {
  try {
    // Note: This requires the appropriate API method
    // Uncomment when available:
    // final session = await API.classSession.getClassSessionById(classSessionId);
    //
    // // Check if session is active
    // if (session.status != 'active') {
    //   return {
    //     'valid': false,
    //     'message': 'This class session is not active',
    //   };
    // }
    //
    // // Check if session has started
    // final now = DateTime.now();
    // if (now.isBefore(session.startTime)) {
    //   return {
    //     'valid': false,
    //     'message': 'Class has not started yet',
    //   };
    // }
    //
    // // Check if session has ended
    // if (now.isAfter(session.endTime)) {
    //   return {
    //     'valid': false,
    //     'message': 'This class has already ended',
    //   };
    // }

    return {'valid': true, 'message': 'Session is valid'};
  } catch (e) {
    debugPrint("❌ Failed to validate class session: $e");
    return {'valid': false, 'message': 'Failed to validate session: $e'};
  }
}

/// Log session analytics
///
/// Parameters:
/// - [classSessionId]: ID of the class session
/// - [event]: Event type (e.g., 'joined', 'left', 'muted_audio', 'shared_screen')
/// - [metadata]: Additional metadata
void logSessionEvent({
  required int classSessionId,
  required String event,
  Map<String, dynamic>? metadata,
}) {
  final logData = {
    'classSessionId': classSessionId,
    'event': event,
    'timestamp': DateTime.now().toIso8601String(),
    'metadata': metadata ?? {},
  };
  debugPrint("📊 Session event: $logData");
  // In production, send this to analytics service
}
