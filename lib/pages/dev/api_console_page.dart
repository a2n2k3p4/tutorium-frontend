import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/base_api_service.dart';

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

  @override
  void dispose() {
    _pathCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
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
      setState(() {
        _output =
            'Status: ${response.statusCode} ${response.reasonPhrase}\n${_prettyPreview(bodyPreview)}';
      });
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
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
    final endpoints = _knownEndpoints;
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Console'),
      ),
      body: Column(
        children: [
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
          Expanded(
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: endpoints.length,
                    itemBuilder: (context, index) {
                      final e = endpoints[index];
                      return ListTile(
                        dense: true,
                        title: Text('${e.method} ${e.path}'),
                        subtitle: Text(e.group),
                        trailing:
                            e.includeAuth ? const Icon(Icons.lock) : null,
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
                  ),
                ),
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

