import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/notification/noti_detail.dart';
import 'package:tutorium_frontend/pages/widgets/noti_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late NotificationService _notiService;

  bool isLoading = true;
  bool hasError = false;
  bool isMarkingAll = false;
  bool isSelecting = false;
  bool isDeleting = false;

  final Map<String, List<Map<String, dynamic>>> notificationData = {
    "learner": [],
    "teacher": [],
    "system": [],
  };

  final Set<int> selectedNotifications = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _notiService = NotificationService();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    setState(() => isLoading = true);
    try {
      final currentUserId = await getCurrentUserId();
      final data = await _notiService.fetchNotifications(currentUserId);

      setState(() {
        notificationData["learner"] = data["learner"]!;
        notificationData["teacher"] = data["teacher"]!;
        notificationData["system"] = data["system"]!;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
      debugPrint("Error fetching notifications: $e");
    }
  }

  Future<int> getCurrentUserId() async {
    return 1;
  }

  int getUnreadCount(String tabKey) {
    return notificationData[tabKey]!.where((n) => n["isRead"] == false).length;
  }

  /// DELETE SELECTED NOTIFICATIONS
  Future<void> deleteSelected() async {
    if (selectedNotifications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No notifications selected")),
      );
      return;
    }

    setState(() => isDeleting = true);

    for (final id in selectedNotifications) {
      await _notiService.deleteNotification(id);
    }

    // Remove deleted items from local state
    for (final key in notificationData.keys) {
      notificationData[key]!.removeWhere(
        (n) => selectedNotifications.contains(n["id"]),
      );
    }

    selectedNotifications.clear();

    setState(() => isDeleting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Selected notifications deleted")),
    );
  }

  Future<void> markSelectedAsRead() async {
    if (selectedNotifications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No notifications selected")),
      );
      return;
    }

    setState(() => isMarkingAll = true);

    final selected = notificationData.values
        .expand((list) => list)
        .where(
          (n) =>
              selectedNotifications.contains(n["id"]) && n["isRead"] == false,
        )
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All selected are already read")),
      );
      setState(() => isMarkingAll = false);
      return;
    }

    for (final n in selected) {
      n["isRead"] = true;
      await _notiService.markAsRead(n);
    }

    setState(() => isMarkingAll = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Marked ${selected.length} selected as read")),
    );
  }

  Widget buildNotificationCard(Map<String, dynamic> n) {
    final isSelected = selectedNotifications.contains(n["id"]);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: n["isRead"] ? Colors.white : Colors.grey[100],
      child: ListTile(
        leading: isSelecting
            ? Checkbox(
                value: isSelected,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      selectedNotifications.add(n["id"]);
                    } else {
                      selectedNotifications.remove(n["id"]);
                    }
                  });
                },
              )
            : (!n["isRead"]
                  ? const Icon(Icons.circle, color: Colors.red, size: 10)
                  : const SizedBox(width: 10)),
        title: Text(
          n["title"],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: n["isRead"] ? Colors.black : Colors.blueAccent,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n["text"]),
            const SizedBox(height: 4),
            Text(
              n["time"],
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () async {
          if (isSelecting) {
            setState(() {
              if (isSelected) {
                selectedNotifications.remove(n["id"]);
              } else {
                selectedNotifications.add(n["id"]);
              }
            });
          } else {
            setState(() => n["isRead"] = true);
            await _notiService.markAsRead(n);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotiDetail(notification: n),
              ),
            );
          }
        },
      ),
    );
  }

  Widget buildTabContent(String key) {
    final notis = notificationData[key]!;
    if (notis.isEmpty) {
      return const Center(child: Text("No notifications"));
    }
    return RefreshIndicator(
      onRefresh: fetchNotifications,
      child: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: notis.map(buildNotificationCard).toList(),
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Failed to load notifications")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelecting
              ? "${selectedNotifications.length} selected"
              : "Notifications",
        ),
        actions: [
          if (isSelecting)
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      final allIds = notificationData.values
                          .expand((list) => list.map((n) => n["id"] as int))
                          .toList();
                      if (selectedNotifications.length == allIds.length) {
                        selectedNotifications.clear();
                      } else {
                        selectedNotifications.addAll(allIds);
                      }
                    });
                  },
                  child: const Text(
                    "Select All",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isSelecting = false;
                      selectedNotifications.clear();
                    });
                  },
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                if (isDeleting || isMarkingAll)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.mark_email_read,
                          color: Colors.black,
                        ),
                        tooltip: "Mark Selected Read",
                        onPressed: markSelectedAsRead,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: "Delete Selected",
                        onPressed: deleteSelected,
                      ),
                    ],
                  ),
              ],
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.checklist_rtl),
                  tooltip: "Select Notifications",
                  onPressed: () {
                    setState(() {
                      isSelecting = true;
                      selectedNotifications.clear();
                    });
                  },
                ),
              ],
            ),
        ],

        bottom: TabBar(
          controller: _tabController,
          tabs: [
            buildTab("Learner", "learner"),
            buildTab("Teacher", "teacher"),
            buildTab("System", "system"),
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

  Tab buildTab(String label, String key) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (getUnreadCount(key) > 0) ...[
            const SizedBox(width: 6),
            badge(getUnreadCount(key)),
          ],
        ],
      ),
    );
  }
}
