import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/notification/noti_detail.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Map<String, List<Map<String, dynamic>>> notificationData = {
    "learner": [
      {
        "id": "1",
        "title": "New Assignment Available",
        "text": "Mathematics - Chapter 5 homework has been assigned",
        "time": "2 hours ago",
        "isRead": false,
      },
      {
        "id": "2",
        "title": "Grade Updated",
        "text": "Your Physics quiz grade has been updated: A-",
        "time": "1 day ago",
        "isRead": true,
      },
      {
        "id": "3",
        "title": "Class Reminder",
        "text": "Chemistry lab session starts in 30 minutes",
        "time": "3 days ago",
        "isRead": false,
      },
    ],
    "teacher": [
      {
        "id": "4",
        "title": "Student Submission",
        "text": "John Doe submitted Assignment 3 for review",
        "time": "1 hour ago",
        "isRead": false,
      },
      {
        "id": "5",
        "title": "Class Schedule Update",
        "text": "Tomorrow's Biology class has been moved to Room 204",
        "time": "4 hours ago",
        "isRead": true,
      },
      {
        "id": "6",
        "title": "Parent Meeting Request",
        "text": "Sarah's parent requested a meeting to discuss progress",
        "time": "2 days ago",
        "isRead": false,
      },
    ],
    "system": [
      {
        "id": "7",
        "title": "System Maintenance",
        "text": "Scheduled maintenance will occur tonight from 2-4 AM",
        "time": "6 hours ago",
        "isRead": true,
      },
      {
        "id": "8",
        "title": "App Update Available",
        "text": "Version 2.1.0 is now available with new features",
        "time": "1 day ago",
        "isRead": false,
      },
      {
        "id": "9",
        "title": "Security Alert",
        "text": "New login detected from unknown device",
        "time": "3 days ago",
        "isRead": true,
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int getUnreadCount(String tabKey) {
    return notificationData[tabKey]!
        .where((n) => n["isRead"] == false)
        .length;
  }

  Widget buildNotificationCard(Map<String, dynamic> notification) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: notification["isRead"] ? Colors.white : Colors.grey[100],
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: !notification["isRead"]
            ? const Icon(Icons.circle, color: Colors.red, size: 12)
            : null,
        title: Text(
          notification["title"],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: notification["isRead"] ? Colors.black : Colors.blueAccent,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification["text"]),
            const SizedBox(height: 4),
            Text(
              notification["time"],
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          setState(() {
            notification["isRead"] = true; // mark as read
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotiDetail(notification: notification),
            ),
          );
        },
      ),
    );
  }

  Widget buildTabContent(String tabKey) {
    final notifications = notificationData[tabKey]!;
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: notifications.map(buildNotificationCard).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold),),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Learner"),
                  if (getUnreadCount("learner") > 0) ...[
                    const SizedBox(width: 6),
                    badge(getUnreadCount("learner")),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Teacher"),
                  if (getUnreadCount("teacher") > 0) ...[
                    const SizedBox(width: 6),
                    badge(getUnreadCount("teacher")),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("System"),
                  if (getUnreadCount("system") > 0) ...[
                    const SizedBox(width: 6),
                    badge(getUnreadCount("system")),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildTabContent("learner"),
          buildTabContent("teacher"),
          buildTabContent("system"),
        ],
      ),
    );
  }

  Widget badge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "$count",
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
