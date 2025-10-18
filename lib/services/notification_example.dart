/// Example usage of LocalNotificationService
///
/// This file demonstrates how to use the notification service
/// for various scenarios in the app.

import 'package:flutter/material.dart';
import 'local_notification_service.dart';

class NotificationExamplePage extends StatefulWidget {
  const NotificationExamplePage({super.key});

  @override
  State<NotificationExamplePage> createState() =>
      _NotificationExamplePageState();
}

class _NotificationExamplePageState extends State<NotificationExamplePage> {
  final _service = LocalNotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Examples')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Immediate Notifications'),
          _buildButton(
            'Show Simple Notification',
            Colors.blue,
            _showSimpleNotification,
          ),
          _buildButton(
            'Show Enrollment Success',
            Colors.green,
            _showEnrollmentSuccess,
          ),
          _buildButton(
            'Show Class Starting Now',
            Colors.orange,
            _showClassStartingNow,
          ),
          _buildButton('Show Class Cancelled', Colors.red, _showClassCancelled),

          const SizedBox(height: 24),
          _buildSection('Scheduled Notifications'),
          _buildButton(
            'Schedule in 10 seconds',
            Colors.purple,
            _scheduleIn10Seconds,
          ),
          _buildButton(
            'Schedule in 1 minute',
            Colors.indigo,
            _scheduleIn1Minute,
          ),
          _buildButton(
            'Schedule Class Reminders',
            Colors.teal,
            _scheduleClassReminders,
          ),

          const SizedBox(height: 24),
          _buildSection('Management'),
          _buildButton(
            'View Pending Notifications',
            Colors.grey,
            _viewPendingNotifications,
          ),
          _buildButton(
            'Cancel All Notifications',
            Colors.brown,
            _cancelAllNotifications,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }

  // Example 1: Simple notification
  Future<void> _showSimpleNotification() async {
    await _service.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Hello!',
      body: 'This is a simple test notification 👋',
      payload: 'simple_test',
    );

    _showSnackBar('Notification shown!');
  }

  // Example 2: Enrollment success
  Future<void> _showEnrollmentSuccess() async {
    await _service.showEnrollmentSuccess(
      className: 'Advanced Mathematics',
      classStartTime: DateTime.now().add(const Duration(hours: 24)),
    );

    _showSnackBar('Enrollment notification shown!');
  }

  // Example 3: Class starting now
  Future<void> _showClassStartingNow() async {
    await _service.showClassStartingNow(
      classSessionId: 123,
      className: 'Physics 101',
    );

    _showSnackBar('Class starting notification shown!');
  }

  // Example 4: Class cancelled
  Future<void> _showClassCancelled() async {
    await _service.showClassCancelled(
      className: 'Chemistry Lab',
      reason: 'Instructor is unavailable',
    );

    _showSnackBar('Cancellation notification shown!');
  }

  // Example 5: Schedule in 10 seconds
  Future<void> _scheduleIn10Seconds() async {
    final scheduledTime = DateTime.now().add(const Duration(seconds: 10));

    await _service.scheduleNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '⏰ Scheduled Notification',
      body: 'This notification was scheduled 10 seconds ago!',
      scheduledTime: scheduledTime,
      payload: 'scheduled_10s',
    );

    _showSnackBar('Notification scheduled for 10 seconds from now');
  }

  // Example 6: Schedule in 1 minute
  Future<void> _scheduleIn1Minute() async {
    final scheduledTime = DateTime.now().add(const Duration(minutes: 1));

    await _service.scheduleNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '⏰ 1 Minute Reminder',
      body: 'One minute has passed since you scheduled this!',
      scheduledTime: scheduledTime,
      payload: 'scheduled_1min',
    );

    _showSnackBar('Notification scheduled for 1 minute from now');
  }

  // Example 7: Schedule class reminders (full flow)
  Future<void> _scheduleClassReminders() async {
    // Schedule a class 2 hours from now
    final classStartTime = DateTime.now().add(const Duration(hours: 2));

    await _service.scheduleClassReminders(
      classSessionId: 999,
      className: 'Introduction to Flutter',
      classStartTime: classStartTime,
    );

    _showSnackBar(
      'Class reminders scheduled!\n'
      'You will receive notifications at:\n'
      '- 1 hour before\n'
      '- 30 minutes before\n'
      '- 10 minutes before\n'
      '- 5 minutes before\n'
      '- 1 minute before',
    );
  }

  // Example 8: View pending notifications
  Future<void> _viewPendingNotifications() async {
    final pending = await _service.getPendingNotifications();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending Notifications'),
        content: pending.isEmpty
            ? const Text('No pending notifications')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  itemBuilder: (context, index) {
                    final notification = pending[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${notification.id}')),
                      title: Text(notification.title ?? 'No title'),
                      subtitle: Text(notification.body ?? 'No body'),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Example 9: Cancel all notifications
  Future<void> _cancelAllNotifications() async {
    await _service.cancelAllNotifications();
    _showSnackBar('All notifications cancelled!');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
