# Notification System - Debug Guide

## ✅ สิ่งที่แก้ไขแล้ว

### 1. แก้ไข API Response Structure
**ปัญหา:** API ส่ง `"ID"` (ตัวพิมพ์ใหญ่) แต่ code คาดหวัง `"id"`
**วิธีแก้:** เปลี่ยนจาก `n["id"]` เป็น `n["ID"]`

### 2. Notification Categorization
**ปัญหา:** API ส่ง `notification_type` = `"class"`, `"enrollment"`, `"system"` แต่ UI แยกเป็น 3 tabs: Learner, Teacher, System

**วิธีแก้:** สร้าง helper function `_categorizeNotification()`:
```dart
- "enrollment" → learner tab
- "class" → teacher tab
- "system" → system tab
```

### 3. DateTime Formatting
**เพิ่มเติม:** แปลง ISO datetime เป็นรูปแบบอ่านง่าย
- "Just now" (< 1 นาที)
- "5m ago" (< 1 ชั่วโมง)
- "2h ago" (< 1 วัน)
- "3d ago" (< 7 วัน)
- "26/9/2025" (≥ 7 วัน)

## 🔍 Debug Logs Explained

### Fetch Notifications Flow
```
📱 [PAGE] Starting fetchNotifications...
👤 [PAGE] Getting current user ID (hardcoded for now)
🔵 [DEBUG] Fetching notifications from: http://5.223.57.97:8000/notifications
🔵 [DEBUG] Current userId: 2
🔵 [DEBUG] Response status: 200
🔵 [DEBUG] Total notifications received: 60

🔍 [DEBUG] Processing notification ID: 1
   - user_id: 2
   - notification_type: system
   - read_flag: true
   ✅ Matched! Type: system -> Category: system

🎯 [SUMMARY] Matched: 40, Skipped: 20
🎯 [SUMMARY] Learner: 15
🎯 [SUMMARY] Teacher: 10
🎯 [SUMMARY] System: 15

📱 [PAGE] Received data from service:
   - Learner: 15
   - Teacher: 10
   - System: 15
✅ [PAGE] Notifications loaded successfully
```

### Mark as Read Flow
```
📱 [PAGE] Tapped notification 1
   - Was read: false
📖 [DEBUG] Marking notification as read: 1
📖 [DEBUG] URL: http://5.223.57.97:8000/notifications/1
📖 [DEBUG] Request body: {"notification_date":"...","notification_description":"...","notification_type":"system","read_flag":true,"user_id":2}
📖 [DEBUG] Response status: 200
✅ [SUCCESS] Notification 1 marked as read
   - Mark as read result: true
```

### Delete Flow
```
🗑️  [PAGE] Delete selected called
🗑️  [PAGE] Selected IDs: {1, 2, 3}
🗑️  [PAGE] Deleting notification 1...
🗑️  [DEBUG] Deleting notification ID: 1
🗑️  [DEBUG] DELETE URL: http://5.223.57.97:8000/notifications/1
🗑️  [DEBUG] Delete response status: 200
✅ [SUCCESS] Notification 1 deleted
🗑️  [PAGE] Deletion complete: 3 success, 0 failed
```

## 📊 Notification Categories Mapping

| API `notification_type` | Tab Category | Icon/Badge |
|------------------------|--------------|------------|
| `enrollment` | Learner | 📝 |
| `class_completed` | Learner | ✅ |
| `class_cancelled` | Learner | ❌ |
| `class` | Teacher | 📚 |
| `review` | Teacher | ⭐ |
| `new_enrollment` | Teacher | 👥 |
| `system` | System | ⚙️ |
| `balance` | System | 💰 |
| `password` | System | 🔒 |
| `welcome` | System | 👋 |

## 🧪 Testing Checklist

### ✅ Basic Functions
- [x] Fetch all notifications
- [x] Display in correct tabs (Learner/Teacher/System)
- [x] Show unread badge count
- [x] Mark single notification as read
- [x] Mark multiple notifications as read
- [x] Delete single notification
- [x] Delete multiple notifications
- [x] Pull-to-refresh
- [x] Navigate to detail page

### ✅ Edge Cases
- [x] Empty notifications
- [x] API error handling
- [x] Retry on error
- [x] No notifications selected
- [x] All selected already read
- [x] DateTime formatting edge cases

## 🐛 Common Issues

### Issue 1: No notifications showing
**Check:**
1. Console log: Is API returning data?
2. Console log: Does `user_id` match?
3. Console log: Are notifications categorized correctly?

**Fix:** Check `getCurrentUserId()` in `notification_page.dart:71-75`

### Issue 2: Mark as read not working
**Check:**
1. Console log: Is PUT request successful?
2. Check request body format
3. Check API response

**Fix:** Verify all required fields are sent in PUT request

### Issue 3: Wrong tab categorization
**Check:**
1. Console log: What is `notification_type` from API?
2. Check `_categorizeNotification()` mapping

**Fix:** Update categorization logic in `noti_service.dart:150-167`

## 📝 Next Steps

### TODO for Production:
1. [ ] Replace hardcoded `userId` with actual auth service
2. [ ] Add pagination for large notification lists
3. [ ] Implement push notifications (FCM)
4. [ ] Add notification preferences
5. [ ] Add "Mark all as read" button
6. [ ] Add notification filtering/sorting
7. [ ] Add sound/vibration for new notifications

### Performance Optimization:
- [ ] Cache notifications locally
- [ ] Implement incremental loading
- [ ] Add debouncing for mark as read
- [ ] Optimize rebuild on state changes

## 🔗 Related Files

- `lib/pages/notification/notification_page.dart` - Main notification page
- `lib/pages/notification/noti_detail.dart` - Notification detail view
- `lib/pages/widgets/noti_service.dart` - API service layer
- `lib/models/other_models.dart` - NotificationModel definition

## 📞 API Endpoints Used

- `GET /notifications` - Fetch all notifications
- `GET /notifications/{id}` - Get single notification
- `PUT /notifications/{id}` - Update notification (mark as read)
- `DELETE /notifications/{id}` - Delete notification

## 🎯 Current User ID ✅ FIXED

**Location:** `notification_page.dart:72-85`

```dart
Future<int> getCurrentUserId() async {
  print("👤 [PAGE] Getting current user ID from cache...");
  final userCache = UserCache();

  if (userCache.hasUser && userCache.user != null) {
    final userId = userCache.user!.id;
    print("👤 [PAGE] Found user ID in cache: $userId");
    return userId;
  }

  print("⚠️  [PAGE] No user in cache, returning fallback user ID: 2");
  // Fallback to user ID 2 (Bob Learner) for testing
  return 2;
}
```

**How it works:**
1. ✅ Gets user ID from `UserCache` (logged-in user)
2. 🔄 Fallback to user ID `2` if not logged in

**Available Test Users in API:**
- User ID `2` - Bob Learner (has enrollment notifications)
- User ID `3` - Carol Teacher (has class notifications)
- User ID `6` - Frank Admin (has system notifications)
- User ID `139` - Current logged-in user (lnw army 123)
