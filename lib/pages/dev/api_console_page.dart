import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/base_api_service.dart';
import '../../services/api_config.dart';
import '../../services/api_provider.dart';
import '../../models/user_models.dart';

class ApiConsolePage extends StatefulWidget {
  const ApiConsolePage({super.key});

  @override
  State<ApiConsolePage> createState() => _ApiConsolePageState();
}

class _ApiConsolePageState extends State<ApiConsolePage> {
  final _api = BaseApiService();
  final _pathCtrl = TextEditingController(text: '/health');
  final _bodyCtrl = TextEditingController();
  String _method = 'GET';
  bool _includeAuth = false;

  String _output = '';
  bool _sending = false;
  bool _syncingSpec = false;
  bool _showFavorites = true;
  bool _showSpecEndpoints = true;
  String _filterText = '';
  String? _tokenPreview;
  Duration? _lastDuration;

  // Dynamic endpoints
  List<EndpointItem> _endpoints = List.of(_knownEndpoints);
  List<SavedRequest> _favorites = [];

  // Quick login form fields
  final _loginUserCtrl = TextEditingController(text: 'b6610505511');
  final _loginPassCtrl = TextEditingController(text: 'mySecretPassword');
  final _loginFirstCtrl = TextEditingController(text: 'Alice');
  final _loginLastCtrl = TextEditingController(text: 'Smith');
  final _loginPhoneCtrl = TextEditingController(text: '+66912345678');
  final _loginGenderCtrl = TextEditingController(text: 'Female');
  final _tokenPasteCtrl = TextEditingController();

  @override
  void dispose() {
    _pathCtrl.dispose();
    _bodyCtrl.dispose();
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    _loginFirstCtrl.dispose();
    _loginLastCtrl.dispose();
    _loginPhoneCtrl.dispose();
    _loginGenderCtrl.dispose();
    _tokenPasteCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refreshTokenPreview();
    _loadFavorites();
  }

  Future<void> _send() async {
    final path = _normalizePath(_pathCtrl.text);
    Map<String, dynamic> body = {};
    if (_method == 'POST' || _method == 'PUT') {
      if (_bodyCtrl.text.trim().isNotEmpty) {
        try {
          body = json.decode(_bodyCtrl.text) as Map<String, dynamic>;
        } catch (e) {
          setState(() {
            _output = 'Invalid JSON body: $e';
          });
          return;
        }
      }
    }

    final startedAt = DateTime.now();
    setState(() {
      _sending = true;
      _output = 'Sending $_method $path...';
      });

    try {
      final response = switch (_method) {
        'GET' => await _api.get(path, includeAuth: _includeAuth),
        'POST' => await _api.post(path, body, includeAuth: _includeAuth),
        'PUT' => await _api.put(path, body, includeAuth: _includeAuth),
        'DELETE' => await _api.delete(path, includeAuth: _includeAuth),
        _ => throw Exception('Unsupported method'),
      };

      final bodyPreview = response.body.isNotEmpty ? response.body : '<empty>';
      _lastDuration = DateTime.now().difference(startedAt);
      setState(() {
        _output = 'URL: ${ApiConfig.baseUrl}$path\n'
            'Status: ${response.statusCode} ${response.reasonPhrase}  '
            '(${_lastDuration!.inMilliseconds} ms)\n'
            '${_prettyPreview(bodyPreview)}';
      });
    } catch (e) {
      _lastDuration = DateTime.now().difference(startedAt);
      setState(() {
        _output = 'Error: $e (${_lastDuration!.inMilliseconds} ms)';
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  String _normalizePath(String p) {
    if (p.trim().isEmpty) return '/health';
    if (p.startsWith('http')) return Uri.parse(p).path; // allow paste full URL
    return p.startsWith('/') ? p : '/$p';
  }

  String _prettyPreview(String raw) {
    try {
      final decoded = json.decode(raw);
      final encoder = const JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final endpoints = _visibleEndpoints;
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Console'),
        actions: [
          IconButton(
            tooltip: 'Sync from Swagger',
            onPressed: _syncingSpec ? null : _loadSwaggerSpec,
            icon: _syncingSpec
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Copy cURL',
            onPressed: _copyCurl,
            icon: const Icon(Icons.copy_all),
          ),
          IconButton(
            tooltip: 'Copy URL',
            onPressed: _copyUrl,
            icon: const Icon(Icons.link),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildEnvBanner(),
          _buildAuthBar(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _method,
                  onChanged: (v) => setState(() => _method = v ?? 'GET'),
                  items: const [
                    DropdownMenuItem(value: 'GET', child: Text('GET')),
                    DropdownMenuItem(value: 'POST', child: Text('POST')),
                    DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                    DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _pathCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Path (e.g. /admins or /admins/1)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Text('Bearer'),
                    Switch(
                      value: _includeAuth,
                      onChanged: (v) => setState(() => _includeAuth = v),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Save as favorite',
                  onPressed: _saveFavorite,
                  icon: const Icon(Icons.star_border),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _bodyCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'JSON Body (POST/PUT)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildListsHeader(),
          Expanded(
            child: Row(
              children: [
                Flexible(flex: 2, child: _buildEndpointList(endpoints)),
                const VerticalDivider(width: 1),
                Flexible(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SingleChildScrollView(
                      child: Text(
                        _output,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEnvBanner() {
    return Container(
      width: double.infinity,
      color: Colors.green.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Base URL: ${ApiConfig.baseUrl}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_lastDuration != null)
            Text('${_lastDuration!.inMilliseconds} ms',
                style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildAuthBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _tokenPreview == null
                      ? 'Not authenticated'
                      : 'Authenticated (token: ${_maskToken(_tokenPreview!)})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: _refreshTokenPreview,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Check'),
              ),
              TextButton.icon(
                onPressed: _clearToken,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tokenPasteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Paste JWT token (without Bearer)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyManualToken,
                child: const Text('Use Token'),
              )
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Quick Login'),
            children: [
              Wrap(
                runSpacing: 8,
                spacing: 8,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _loginUserCtrl,
                      decoration: const InputDecoration(
                        labelText: 'username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _loginPassCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _loginFirstCtrl,
                      decoration: const InputDecoration(
                        labelText: 'first_name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _loginLastCtrl,
                      decoration: const InputDecoration(
                        labelText: 'last_name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _loginPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'phone_number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _loginGenderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'gender',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          const Text('Endpoints'),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text('Favorites'),
            selected: _showFavorites,
            onSelected: (v) => setState(() => _showFavorites = v),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('Swagger'),
            selected: _showSpecEndpoints,
            onSelected: (v) => setState(() => _showSpecEndpoints = v),
          ),
          const Spacer(),
          SizedBox(
            width: 240,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter (e.g. users get)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filterText = v.toLowerCase()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndpointList(List<EndpointItem> endpoints) {
    final items = _filterEndpoints(endpoints);
    return ListView.builder(
      itemCount: items.length + (_showFavorites ? _favorites.length + 1 : 0),
      itemBuilder: (context, index) {
        if (_showFavorites) {
          if (index == 0) {
            return const ListTile(
              dense: true,
              title: Text('Favorites'),
            );
          }
          final favIndex = index - 1;
          if (favIndex < _favorites.length) {
            final f = _favorites[favIndex];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text('${f.method} ${f.path}'),
              subtitle: Text('Saved'),
              onTap: () => _loadFavorite(f),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteFavorite(f),
              ),
            );
          }
        }
        final i = index - (_showFavorites ? _favorites.length + 1 : 0);
        final e = items[i];
        return ListTile(
          dense: true,
          title: Text('${e.method} ${e.path}'),
          subtitle: Text(e.group),
          trailing: e.includeAuth ? const Icon(Icons.lock) : null,
          onTap: () {
            setState(() {
              _method = e.method;
              _includeAuth = e.includeAuth;
              _pathCtrl.text = e.path;
              _bodyCtrl.text = e.exampleBody ?? '';
            });
          },
        );
      },
    );
  }

  List<EndpointItem> get _visibleEndpoints => _showSpecEndpoints ? _endpoints : _knownEndpoints;

  List<EndpointItem> _filterEndpoints(List<EndpointItem> list) {
    final q = _filterText.trim();
    if (q.isEmpty) return list;
    return list.where((e) {
      final s = '${e.group} ${e.method} ${e.path}'.toLowerCase();
      return s.contains(q);
    }).toList();
  }

  Future<void> _login() async {
    try {
      final req = LoginRequest(
        username: _loginUserCtrl.text.trim(),
        password: _loginPassCtrl.text.trim(),
        firstName: _loginFirstCtrl.text.trim(),
        lastName: _loginLastCtrl.text.trim(),
        phoneNumber: _loginPhoneCtrl.text.trim(),
        gender: _loginGenderCtrl.text.trim(),
      );
      final res = await API.auth.login(req);
      setState(() {
        _includeAuth = true;
        _tokenPreview = res.token;
        _output = 'Login OK: user #${res.user.id}\nToken saved';
      });
    } catch (e) {
      setState(() => _output = 'Login failed: $e');
    }
  }

  Future<void> _refreshTokenPreview() async {
    final token = await _api.getToken();
    setState(() => _tokenPreview = token);
  }

  Future<void> _clearToken() async {
    await _api.removeToken();
    await _refreshTokenPreview();
  }

  Future<void> _applyManualToken() async {
    final t = _tokenPasteCtrl.text.trim();
    if (t.isEmpty) return;
    await _api.saveToken(t.replaceAll('Bearer ', ''));
    await _refreshTokenPreview();
    setState(() => _includeAuth = true);
  }

  Future<void> _copyUrl() async {
    final url = '${ApiConfig.baseUrl}${_normalizePath(_pathCtrl.text)}';
    await Clipboard.setData(ClipboardData(text: url));
    _snack('URL copied');
  }

  Future<void> _copyCurl() async {
    final path = _normalizePath(_pathCtrl.text);
    final url = '${ApiConfig.baseUrl}$path';
    final accept = '-H "accept: application/json"';
    final content = '-H "content-type: application/json"';
    final token = await _api.getToken();
    final auth = (_includeAuth && token != null)
        ? '-H "Authorization: Bearer $token"'
        : '';
    final data = (_method == 'POST' || _method == 'PUT') && _bodyCtrl.text.trim().isNotEmpty
        ? "-d '${_bodyCtrl.text.replaceAll("'", "'\\''")}'"
        : '';
    final curl = 'curl -X \"$_method\" \\\n+  \"$url\" \\\n+  $accept \\\n+  $content \\\n+  $auth \\\n+  $data';
    await Clipboard.setData(ClipboardData(text: curl));
    _snack('cURL copied');
  }

  Future<void> _loadSwaggerSpec() async {
    setState(() => _syncingSpec = true);
    try {
      // Direct HTTP call (no auth), use BaseApiService to keep headers consistent
      final res = await _api.get('/swagger/doc.json', includeAuth: false);
      final data = json.decode(res.body) as Map<String, dynamic>;
      final items = _parseSwagger(data);
      setState(() {
        _endpoints = items;
        _syncingSpec = false;
      });
      _snack('Swagger synced: ${items.length} endpoints');
    } catch (e) {
      setState(() => _syncingSpec = false);
      _snack('Sync failed: $e');
    }
  }

  List<EndpointItem> _parseSwagger(Map<String, dynamic> spec) {
    final paths = (spec['paths'] as Map<String, dynamic>? ?? {});
    final out = <EndpointItem>[];
    for (final entry in paths.entries) {
      final path = entry.key;
      final methods = entry.value as Map<String, dynamic>;
      for (final m in methods.entries) {
        final method = m.key.toUpperCase();
        if (!['GET', 'POST', 'PUT', 'DELETE', 'PATCH'].contains(method)) continue;
        final meta = m.value as Map<String, dynamic>;
        final tags = (meta['tags'] as List?)?.cast() ?? [];
        final group = tags.isNotEmpty ? tags.first.toString() : 'General';
        final security = (meta['security'] as List?) ?? (spec['security'] as List?);
        final includeAuth = security != null && security.isNotEmpty;
        String? exampleBody;
        final params = (meta['parameters'] as List?)?.cast<Map<String, dynamic>>();
        final bodyParam = params?.firstWhere(
          (p) => p['in'] == 'body',
          orElse: () => {},
        );
        if (bodyParam != null && bodyParam.isNotEmpty) {
          // Try schema + example (best effort)
          exampleBody = _buildExampleFromSchema(bodyParam['schema'] as Map<String, dynamic>?, spec);
        }
        out.add(EndpointItem(group, method, path, exampleBody: exampleBody, includeAuth: includeAuth));
      }
    }
    // Deterministic order: group, path, method
    out.sort((a, b) {
      final g = a.group.compareTo(b.group);
      if (g != 0) return g;
      final p = a.path.compareTo(b.path);
      if (p != 0) return p;
      return a.method.compareTo(b.method);
    });
    return out;
  }

  String? _buildExampleFromSchema(Map<String, dynamic>? schema, Map<String, dynamic> spec) {
    if (schema == null) return null;
    try {
      final definitions = (spec['definitions'] as Map<String, dynamic>? ?? {});
      Map<String, dynamic> example = {};

      Map<String, dynamic>? resolveRef(String ref) {
        final key = ref.replaceAll('#/definitions/', '');
        return definitions[key] as Map<String, dynamic>?;
      }

      Map<String, dynamic> buildFromDef(Map<String, dynamic> def) {
        final props = (def['properties'] as Map<String, dynamic>? ?? {});
        final obj = <String, dynamic>{};
        props.forEach((k, v) {
          final prop = v as Map<String, dynamic>;
          if (prop.containsKey('example')) {
            obj[k] = prop['example'];
          } else {
            final type = prop['type'];
            if (type == 'string') obj[k] = '';
            else if (type == 'integer') obj[k] = 0;
            else if (type == 'number') obj[k] = 0;
            else if (type == 'boolean') obj[k] = false;
            else if (type == 'array') obj[k] = [];
            else if (type == 'object') obj[k] = {};
          }
        });
        return obj;
      }

      if (schema['\$ref'] != null) {
        final def = resolveRef(schema['\$ref']);
        if (def != null) example = buildFromDef(def);
      } else if (schema['type'] == 'object') {
        example = buildFromDef(schema);
      }

      return example.isEmpty ? null : json.encode(example);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveFavorite() async {
    final s = SavedRequest(
      method: _method,
      path: _normalizePath(_pathCtrl.text),
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text,
      includeAuth: _includeAuth,
    );
    setState(() => _favorites.add(s));
    await _persistFavorites();
    _snack('Saved favorite');
  }

  void _loadFavorite(SavedRequest s) {
    setState(() {
      _method = s.method;
      _includeAuth = s.includeAuth;
      _pathCtrl.text = s.path;
      _bodyCtrl.text = s.body ?? '';
    });
  }

  void _deleteFavorite(SavedRequest s) async {
    setState(() => _favorites.remove(s));
    await _persistFavorites();
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _favorites.map((e) => e.toJson()).toList();
    await prefs.setString('api_console_favorites', json.encode(data));
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('api_console_favorites');
    if (raw == null) return;
    try {
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      setState(() {
        _favorites = list.map(SavedRequest.fromJson).toList();
      });
    } catch (_) {}
  }

  String _maskToken(String token) {
    if (token.length <= 12) return token;
    final head = token.substring(0, 6);
    final tail = token.substring(max(0, token.length - 6));
    return '$head…$tail';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}

class EndpointItem {
  final String group;
  final String method;
  final String path;
  final String? exampleBody;
  final bool includeAuth;

  const EndpointItem(
    this.group,
    this.method,
    this.path, {
    this.exampleBody,
    this.includeAuth = true,
  });
}

const List<EndpointItem> _knownEndpoints = [
  // Health
  EndpointItem('Payments', 'GET', '/health', includeAuth: false),

  // Auth
  EndpointItem(
    'Login',
    'POST',
    '/login',
    includeAuth: false,
    exampleBody:
        '{"username":"b6610505511","password":"mySecretPassword","first_name":"Alice","last_name":"Smith","phone_number":"+66912345678","gender":"Female"}',
  ),

  // Admins
  EndpointItem('Admins', 'GET', '/admins'),
  EndpointItem('Admins', 'POST', '/admins', exampleBody: '{"id":0,"user_id":5}'),
  EndpointItem('Admins', 'GET', '/admins/1'),
  EndpointItem('Admins', 'DELETE', '/admins/1'),

  // BanLearners
  EndpointItem('BanLearners', 'GET', '/banlearners'),
  EndpointItem(
    'BanLearners',
    'POST',
    '/banlearners',
    exampleBody:
        '{"id":0,"learner_id":42,"ban_start":"2025-08-20T12:00:00Z","ban_end":"2025-08-30T12:00:00Z","ban_description":"Spamming"}',
  ),
  EndpointItem('BanLearners', 'GET', '/banlearners/1'),
  EndpointItem(
    'BanLearners',
    'PUT',
    '/banlearners/1',
    exampleBody:
        '{"id":1,"learner_id":42,"ban_start":"2025-08-20T12:00:00Z","ban_end":"2025-08-30T12:00:00Z","ban_description":"Updated"}',
  ),
  EndpointItem('BanLearners', 'DELETE', '/banlearners/1'),

  // BanTeachers
  EndpointItem('BanTeachers', 'GET', '/banteachers'),
  EndpointItem(
    'BanTeachers',
    'POST',
    '/banteachers',
    exampleBody:
        '{"id":0,"teacher_id":7,"ban_start":"2025-08-20T12:00:00Z","ban_end":"2025-08-30T12:00:00Z","ban_description":"Violation"}',
  ),
  EndpointItem('BanTeachers', 'GET', '/banteachers/1'),
  EndpointItem(
    'BanTeachers',
    'PUT',
    '/banteachers/1',
    exampleBody:
        '{"id":1,"teacher_id":7,"ban_start":"2025-08-20T12:00:00Z","ban_end":"2025-08-30T12:00:00Z","ban_description":"Updated"}',
  ),
  EndpointItem('BanTeachers', 'DELETE', '/banteachers/1'),

  // Class Categories
  EndpointItem('ClassCategories', 'GET', '/class_categories'),
  EndpointItem(
    'ClassCategories',
    'POST',
    '/class_categories',
    exampleBody: '{"id":0,"class_category":"Mathematics"}',
  ),
  EndpointItem('ClassCategories', 'GET', '/class_categories/1'),
  EndpointItem(
    'ClassCategories',
    'PUT',
    '/class_categories/1',
    exampleBody: '{"id":1,"class_category":"Updated"}',
  ),
  EndpointItem('ClassCategories', 'DELETE', '/class_categories/1'),

  // Class Sessions
  EndpointItem('ClassSessions', 'GET', '/class_sessions'),
  EndpointItem(
    'ClassSessions',
    'POST',
    '/class_sessions',
    exampleBody:
        '{"id":0,"class_id":12,"class_start":"2025-09-05T14:00:00Z","class_finish":"2025-09-05T16:00:00Z","enrollment_deadline":"2025-09-01T23:59:59Z","class_status":"Scheduled","description":"desc","learner_limit":50,"price":1999.99}',
  ),
  EndpointItem('ClassSessions', 'GET', '/class_sessions/1'),
  EndpointItem(
    'ClassSessions',
    'PUT',
    '/class_sessions/1',
    exampleBody:
        '{"id":1,"class_id":12,"class_start":"2025-09-05T14:00:00Z","class_finish":"2025-09-05T16:00:00Z","enrollment_deadline":"2025-09-01T23:59:59Z","class_status":"Scheduled","description":"updated","learner_limit":50,"price":1999.99}',
  ),
  EndpointItem('ClassSessions', 'DELETE', '/class_sessions/1'),

  // Classes
  EndpointItem('Classes', 'GET', '/classes'),
  EndpointItem(
    'Classes',
    'POST',
    '/classes',
    exampleBody:
        '{"id":0,"class_name":"Advanced Python","class_description":"desc","banner_picture":null,"rating":4.7,"teacher_id":7}',
  ),
  EndpointItem('Classes', 'GET', '/classes/1'),
  EndpointItem(
    'Classes',
    'PUT',
    '/classes/1',
    exampleBody:
        '{"id":1,"class_name":"Updated","class_description":"desc","banner_picture":null,"rating":4.7,"teacher_id":7}',
  ),
  EndpointItem('Classes', 'DELETE', '/classes/1'),

  // Enrollments
  EndpointItem('Enrollments', 'GET', '/enrollments'),
  EndpointItem(
    'Enrollments',
    'POST',
    '/enrollments',
    exampleBody:
        '{"id":0,"learner_id":42,"class_session_id":21,"enrollment_status":"active"}',
  ),
  EndpointItem('Enrollments', 'GET', '/enrollments/1'),
  EndpointItem(
    'Enrollments',
    'PUT',
    '/enrollments/1',
    exampleBody:
        '{"id":1,"learner_id":42,"class_session_id":21,"enrollment_status":"active"}',
  ),
  EndpointItem('Enrollments', 'DELETE', '/enrollments/1'),

  // Learners
  EndpointItem('Learners', 'GET', '/learners'),
  EndpointItem('Learners', 'POST', '/learners', exampleBody: '{"id":0,"user_id":5,"flag_count":0}'),
  EndpointItem('Learners', 'GET', '/learners/1'),
  EndpointItem('Learners', 'DELETE', '/learners/1'),

  // Notifications
  EndpointItem('Notifications', 'GET', '/notifications'),
  EndpointItem(
    'Notifications',
    'POST',
    '/notifications',
    exampleBody:
        '{"id":0,"user_id":42,"notification_type":"System Alert","notification_description":"desc","notification_date":"2025-08-20T15:04:05Z","read_flag":false}',
  ),
  EndpointItem('Notifications', 'GET', '/notifications/1'),
  EndpointItem(
    'Notifications',
    'PUT',
    '/notifications/1',
    exampleBody:
        '{"id":1,"user_id":42,"notification_type":"System Alert","notification_description":"updated","notification_date":"2025-08-20T15:04:05Z","read_flag":false}',
  ),
  EndpointItem('Notifications', 'DELETE', '/notifications/1'),

  // Reports
  EndpointItem('Reports', 'GET', '/reports'),
  EndpointItem(
    'Reports',
    'POST',
    '/reports',
    exampleBody:
        '{"id":0,"report_user_id":5,"reported_user_id":8,"class_session_id":20,"report_type":"Abuse","report_reason":"teacher_absent","report_description":"desc","report_picture":null,"report_date":"2025-08-20T14:30:00Z","report_status":"pending"}',
  ),
  EndpointItem('Reports', 'GET', '/reports/1'),
  EndpointItem(
    'Reports',
    'PUT',
    '/reports/1',
    exampleBody:
        '{"id":1,"report_user_id":5,"reported_user_id":8,"class_session_id":20,"report_type":"Abuse","report_reason":"teacher_absent","report_description":"updated","report_picture":null,"report_date":"2025-08-20T14:30:00Z","report_status":"pending"}',
  ),
  EndpointItem('Reports', 'DELETE', '/reports/1'),

  // Reviews
  EndpointItem('Reviews', 'GET', '/reviews'),
  EndpointItem(
    'Reviews',
    'POST',
    '/reviews',
    exampleBody:
        '{"id":0,"learner_id":42,"class_id":9,"rating":5,"comment":"Great!"}',
  ),
  EndpointItem('Reviews', 'GET', '/reviews/1'),
  EndpointItem(
    'Reviews',
    'PUT',
    '/reviews/1',
    exampleBody:
        '{"id":1,"learner_id":42,"class_id":9,"rating":5,"comment":"Updated"}',
  ),
  EndpointItem('Reviews', 'DELETE', '/reviews/1'),

  // Teachers
  EndpointItem('Teachers', 'GET', '/teachers'),
  EndpointItem(
    'Teachers',
    'POST',
    '/teachers',
    exampleBody:
        '{"id":0,"user_id":5,"email":"teacher@example.com","description":"Experienced","flag_count":0}',
  ),
  EndpointItem('Teachers', 'GET', '/teachers/1'),
  EndpointItem(
    'Teachers',
    'PUT',
    '/teachers/1',
    exampleBody:
        '{"id":1,"user_id":5,"email":"teacher@example.com","description":"Updated","flag_count":0}',
  ),
  EndpointItem('Teachers', 'DELETE', '/teachers/1'),

  // Users
  EndpointItem('Users', 'GET', '/users'),
  EndpointItem(
    'Users',
    'POST',
    '/users',
    exampleBody:
        '{"id":0,"first_name":"Alice","last_name":"Smith","student_id":"6610505511","phone_number":"+66912345678","gender":"Female","profile_picture":null,"balance":0.0,"ban_count":0}',
  ),
  EndpointItem('Users', 'GET', '/users/1'),
  EndpointItem(
    'Users',
    'PUT',
    '/users/1',
    exampleBody:
        '{"id":1,"first_name":"Alice","last_name":"Smith","student_id":"6610505511","phone_number":"+66912345678","gender":"Female","profile_picture":null,"balance":0.0,"ban_count":0}',
  ),
  EndpointItem('Users', 'DELETE', '/users/1'),

  // Payments
  EndpointItem(
    'Payments',
    'POST',
    '/payments/charge',
    exampleBody:
        '{"amount":10000,"currency":"THB","paymentType":"promptpay","description":"desc","user_id":5}',
  ),
  EndpointItem('Payments', 'GET', '/payments/transactions', includeAuth: false),
  EndpointItem('Payments', 'GET', '/payments/transactions/chrg_test', includeAuth: false),
  EndpointItem('Payments', 'POST', '/payments/transactions/chrg_test/refund', exampleBody: '{"amount":1000}'),

  // Webhooks (no auth)
  EndpointItem('Payments', 'POST', '/webhooks/omise', includeAuth: false, exampleBody: '{"object":"event","data":{}}'),
];

class SavedRequest {
  final String method;
  final String path;
  final String? body;
  final bool includeAuth;

  SavedRequest({
    required this.method,
    required this.path,
    required this.includeAuth,
    this.body,
  });

  Map<String, dynamic> toJson() => {
        'method': method,
        'path': path,
        'body': body,
        'includeAuth': includeAuth,
      };

  static SavedRequest fromJson(Map<String, dynamic> json) => SavedRequest(
        method: json['method'] as String,
        path: json['path'] as String,
        body: json['body'] as String?,
        includeAuth: (json['includeAuth'] as bool?) ?? true,
      );
}
