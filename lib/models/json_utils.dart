int readInt(
  Map<String, dynamic> json,
  List<String> keys, {
  int defaultValue = 0,
}) {
  final value = _readValue(json, keys);
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

double? readDouble(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? readString(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

bool? readBool(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed != 0;
    }
  }
  return null;
}

DateTime? readDate(Map<String, dynamic> json, List<String> keys) {
  final value = readString(json, keys);
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

Map<String, dynamic>? readMap(Map<String, dynamic> json, List<String> keys) {
  final value = _readValue(json, keys);
  if (value is Map<String, dynamic>) {
    return value;
  }
  return null;
}

dynamic _readValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _lookup(json, key);
    if (value != null) {
      return value;
    }
  }
  return null;
}

dynamic _lookup(Map<String, dynamic> json, String key) {
  if (key.contains('.')) {
    final segments = key.split('.');
    Map<String, dynamic>? current = json;
    dynamic value;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (current == null) {
        return null;
      }
      value = _lookupSingle(current, segment);
      if (i < segments.length - 1) {
        if (value is Map<String, dynamic>) {
          current = value;
        } else {
          return null;
        }
      }
    }
    return value;
  }
  return _lookupSingle(json, key);
}

dynamic _lookupSingle(Map<String, dynamic> json, String rawKey) {
  if (json.containsKey(rawKey)) return json[rawKey];

  final camel = _toCamelCase(rawKey);
  if (json.containsKey(camel)) return json[camel];

  final title = _toTitleCase(rawKey);
  if (json.containsKey(title)) return json[title];

  final upper = rawKey.toUpperCase();
  if (json.containsKey(upper)) return json[upper];

  return null;
}

String _toCamelCase(String key) {
  if (!key.contains('_')) return key;
  final parts = key.split('_');
  if (parts.isEmpty) return key;
  final buffer = StringBuffer(parts.first);
  for (final part in parts.skip(1)) {
    if (part.isEmpty) continue;
    buffer.write(part[0].toUpperCase());
    if (part.length > 1) {
      buffer.write(part.substring(1));
    }
  }
  return buffer.toString();
}

String _toTitleCase(String key) {
  if (key.isEmpty) return key;
  return key[0].toUpperCase() + key.substring(1);
}
