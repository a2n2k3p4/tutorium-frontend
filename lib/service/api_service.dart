import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  const ApiService._();

  static Uri endpoint(String path, {Map<String, dynamic>? queryParameters}) {
    final base = _baseUrl();
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$normalizedPath');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final mapped = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) {
        mapped[key] = value.toString();
      }
    });

    if (mapped.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: {...uri.queryParameters, ...mapped});
  }

  static String _baseUrl() {
    final raw = dotenv.env['API_URL'] ?? '';
    final port = dotenv.env['PORT'];

    if (raw.isEmpty) {
      throw StateError('API_URL is not configured');
    }

    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid API_URL: $raw');
    }

    if (port == null || port.isEmpty) {
      return parsed.toString();
    }

    final portNumber = int.tryParse(port);
    if (portNumber == null) {
      throw FormatException('Invalid PORT: $port');
    }

    return parsed.replace(port: portNumber).toString();
  }
}
