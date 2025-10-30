import 'dart:convert';
import 'package:flutter/foundation.dart';

enum TeacherAvatarType { network, memory, none }

class TeacherAvatarSource {
  final TeacherAvatarType type;
  final String? url;
  final Uint8List? bytes;

  const TeacherAvatarSource._({required this.type, this.url, this.bytes});

  const TeacherAvatarSource.none() : this._(type: TeacherAvatarType.none);

  const TeacherAvatarSource.network(String url)
    : this._(type: TeacherAvatarType.network, url: url);

  const TeacherAvatarSource.memory(Uint8List bytes)
    : this._(type: TeacherAvatarType.memory, bytes: bytes);

  bool get hasImage => type != TeacherAvatarType.none;

  @override
  String toString() {
    switch (type) {
      case TeacherAvatarType.network:
        return 'TeacherAvatarSource(network, url=$url)';
      case TeacherAvatarType.memory:
        return 'TeacherAvatarSource(memory, bytes=${bytes?.lengthInBytes ?? 0})';
      case TeacherAvatarType.none:
        return 'TeacherAvatarSource(none)';
    }
  }
}

/// Resolve the best avatar source for teacher profiles with detailed logging.
class TeacherAvatarResolver {
  static const String _tag = '🖼️ [TeacherAvatar]';

  static TeacherAvatarSource resolve(String? raw) {
    debugPrint(
      '$_tag START resolve(raw=${raw == null ? 'null' : _describe(raw)})',
    );

    if (raw == null || raw.trim().isEmpty) {
      debugPrint('$_tag ❔ No avatar provided, using placeholder');
      return const TeacherAvatarSource.none();
    }

    final value = raw.trim();
    if (value.startsWith('http')) {
      debugPrint('$_tag 🌐 Detected remote avatar: $value');
      return TeacherAvatarSource.network(value);
    }

    try {
      final payload = value.startsWith('data:image')
          ? value.split(',').last
          : value;
      final decoded = base64Decode(payload);
      if (decoded.isEmpty) {
        debugPrint('$_tag ⚠️ Base64 decode produced empty bytes');
        return const TeacherAvatarSource.none();
      }
      debugPrint('$_tag ✅ Base64 avatar decoded (${decoded.length} bytes)');
      return TeacherAvatarSource.memory(decoded);
    } catch (e, stack) {
      debugPrint('$_tag ❌ Failed to decode avatar: $e');
      debugPrint('$_tag Stack: $stack');
      return const TeacherAvatarSource.none();
    }
  }

  static String _describe(String value) {
    if (value.startsWith('http')) {
      return 'url';
    }
    if (value.startsWith('data:image')) {
      return 'data-uri(${value.length} chars)';
    }
    return 'base64(${value.length} chars)';
  }
}
