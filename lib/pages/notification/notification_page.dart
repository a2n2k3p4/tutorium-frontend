import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/notification/noti_detail.dart';
import 'package:tutorium_frontend/pages/widgets/noti_service.dart';
import 'package:tutorium_frontend/util/cache_user.dart';

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
    debugPrint("📱 [PAGE] Starting fetchNotifications...");
    setState(() => isLoading = true);
    try {
      final currentUserId = await getCurrentUserId();
      debugPrint("📱 [PAGE] Current user ID: $currentUserId");

      final data = await _notiService.fetchNotifications(currentUserId);
      debugPrint("📱 [PAGE] Received data from service:");
      debugPrint("   - Learner: ${data["learner"]!.length}");
      debugPrint("   - Teacher: ${data["teacher"]!.length}");
      debugPrint("   - System: ${data["system"]!.length}");

      setState(() {
        notificationData["learner"] = data["learner"]!;
        notificationData["teacher"] = data["teacher"]!;
        notificationData["system"] = data["system"]!;
        isLoading = false;
      });

      debugPrint("✅ [PAGE] Notifications loaded successfully");
    } catch (e, stackTrace) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
      debugPrint("❌ [PAGE] Error fetching notifications: $e");
      debugPrint("❌ [PAGE] Stack trace: $stackTrace");
      debugPrint("Error fetching notifications: $e");
    }
  }

  Future<int> getCurrentUserId() async {
    debugPrint("👤 [PAGE] Getting current user ID from cache...");
    final userCache = UserCache();

    if (userCache.hasUser && userCache.user != null) {
      final userId = userCache.user!.id;
      debugPrint("👤 [PAGE] Found user ID in cache: $userId");
      return userId;
    }

    debugPrint("⚠️  [PAGE] No user in cache, returning fallback user ID: 2");
    // Fallback to user ID 2 (Bob Learner) for testing
    return 2;
  }

  int getUnreadCount(String tabKey) {
    return notificationData[tabKey]!.where((n) => n["isRead"] == false).length;
  }

  Future<void> deleteSelected() async {
    debugPrint("🗑️  [PAGE] Delete selected called");
    debugPrint("🗑️  [PAGE] Selected IDs: $selectedNotifications");

    if (selectedNotifications.isEmpty) {
      debugPrint("⚠️  [PAGE] No notifications selected");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No notifications selected")),
      );
      return;
    }

    setState(() => isDeleting = true);

    int successCount = 0;
    int failCount = 0;

    for (final id in selectedNotifications) {
      try {
        debugPrint("🗑️  [PAGE] Deleting notification $id...");
        await _notiService.deleteNotification(id);
        successCount++;
      } catch (e) {
        debugPrint("❌ [PAGE] Failed to delete $id: $e");
        failCount++;
      }
    }

    debugPrint(
      "🗑️  [PAGE] Deletion complete: $successCount success, $failCount failed",
    );

    for (final key in notificationData.keys) {
      final beforeCount = notificationData[key]!.length;
      notificationData[key]!.removeWhere(
        (n) => selectedNotifications.contains(n["id"]),
      );
      final afterCount = notificationData[key]!.length;
      debugPrint("🗑️  [PAGE] $key: $beforeCount -> $afterCount");
    }

    if (!mounted) return;

    selectedNotifications.clear();
    setState(() => isDeleting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Deleted $successCount notification(s)")),
    );
  }

  Future<void> markSelectedAsRead() async {
    debugPrint("📖 [PAGE] Mark selected as read called");
    debugPrint("📖 [PAGE] Selected IDs: $selectedNotifications");

    if (selectedNotifications.isEmpty) {
      debugPrint("⚠️  [PAGE] No notifications selected");
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

    debugPrint(
      "📖 [PAGE] Found ${selected.length} unread notifications to mark",
    );

    if (selected.isEmpty) {
      debugPrint("⚠️  [PAGE] All selected are already read");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All selected are already read")),
      );
      setState(() => isMarkingAll = false);
      return;
    }

    int successCount = 0;
    int failCount = 0;

    for (final n in selected) {
      try {
        debugPrint("📖 [PAGE] Marking notification ${n["id"]} as read...");
        n["isRead"] = true;
        final result = await _notiService.markAsRead(n);
        if (result) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        debugPrint("❌ [PAGE] Failed to mark ${n["id"]} as read: $e");
        failCount++;
      }
    }

    debugPrint(
      "📖 [PAGE] Mark as read complete: $successCount success, $failCount failed",
    );

    if (!mounted) return;

    setState(() => isMarkingAll = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Marked $successCount notification(s) as read")),
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
            debugPrint(
              "📱 [PAGE] Toggling selection for notification ${n["id"]}",
            );
            setState(() {
              if (isSelected) {
                selectedNotifications.remove(n["id"]);
                debugPrint("   ➖ Removed from selection");
              } else {
                selectedNotifications.add(n["id"]);
                debugPrint("   ➕ Added to selection");
              }
            });
          } else {
            debugPrint("📱 [PAGE] Tapped notification ${n["id"]}");
            debugPrint("   - Was read: ${n["isRead"]}");
            setState(() => n["isRead"] = true);
            final result = await _notiService.markAsRead(n);
            debugPrint("   - Mark as read result: $result");
            if (!mounted) return;
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
    debugPrint("📋 [PAGE] Building tab content for: $key");
    final notis = notificationData[key]!;
    debugPrint("📋 [PAGE] $key notifications count: ${notis.length}");

    if (notis.isEmpty) {
      debugPrint("📋 [PAGE] No notifications in $key tab");
      return const Center(child: Text("No notifications"));
    }

    return RefreshIndicator(
      onRefresh: () {
        debugPrint("🔄 [PAGE] Pull to refresh triggered for $key tab");
        return fetchNotifications();
      },
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
    debugPrint("🎨 [PAGE] Building NotificationPage widget");
    debugPrint("   - isLoading: $isLoading");
    debugPrint("   - hasError: $hasError");
    debugPrint("   - isSelecting: $isSelecting");

    if (isLoading) {
      debugPrint("⏳ [PAGE] Showing loading indicator");
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (hasError) {
      debugPrint("⚠️  [PAGE] Showing error state");
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Failed to load notifications"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  debugPrint("🔄 [PAGE] Retry button pressed");
                  setState(() => hasError = false);
                  fetchNotifications();
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
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
