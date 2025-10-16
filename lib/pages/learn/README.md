# Learn Page - Jitsi Meet Integration

## 📋 Overview

หน้าจอการเรียนการสอนออนไนน์ด้วย **Jitsi Meet SDK แบบเต็มรูปแบบ** พร้อม **Role-based Permissions**

### 🎯 Key Features:
- ✅ **Full Jitsi SDK Integration** - ใช้ Jitsi Meet SDK 100% (ไม่มี Mock UI)
- ✅ **Role-based Permissions** - Teacher = Moderator, Learner = Participant
- ✅ **Teacher Controls** - เตะคนออก, ปิดห้องให้ทุกคน, บันทึกวิดีโอ, ถ่ายทอดสด
- ✅ **Learner Protection** - ไม่สามารถ kick, mute others, หรือ end call for all ได้
- ✅ **Beautiful UI** - Pre-join screen สวยงาม พร้อม loading และ in-conference status

---

## 🚀 Quick Start

### การเรียกใช้หน้า Learn Page

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => LearnPage(
      classSessionId: 123,
      className: 'Advanced Python Programming',
      teacherName: 'อ.สมชาย ใจดี',
      jitsiMeetingUrl: 'https://meet.jit.si/KU-Tutorium-Session-123',
      isTeacher: false,  // หรือ true สำหรับ Teacher
    ),
  ),
);
```

### URL Format Support
Backend ส่ง Jitsi URL มาให้ โดยรองรับรูปแบบ:
- `https://meet.jit.si/RoomName`
- `https://vc.tutorium.io/rooms/session-42`
- `https://meet.jit.si/RoomName?jwt=token123` (with JWT authentication)

Query parameters เช่น `jwt` หรือ `token` จะถูกส่งไปให้ Jitsi อัตโนมัติ

---

## 🎓 Role-based Permissions

### 👨‍🏫 Teacher (Moderator) - Full Control
- ✅ Kick participants
- ✅ End call for all
- ✅ Mute others remotely
- ✅ Recording & Live streaming
- ✅ Invite people
- ✅ Security options
- ✅ Moderator badge

### 👨‍🎓 Learner (Participant) - Restricted
- ✅ Join/Leave class
- ✅ Video/Audio/Screen share (ตัวเอง)
- ✅ Chat, Raise hand, Reactions
- ❌ ไม่สามารถ kick, mute others, end call for all

---

## 📊 Permission Matrix

```
┌────────────────────┬──────────┬────────────┐
│ Feature            │ Teacher  │ Learner    │
├────────────────────┼──────────┼────────────┤
│ Basic Controls     │    ✅    │     ✅     │
│ Kick Participants  │    ✅    │     ❌     │
│ End Call for All   │    ✅    │     ❌     │
│ Mute Others        │    ✅    │     ❌     │
│ Recording          │    ✅    │     ❌     │
│ Live Streaming     │    ✅    │     ❌     │
│ Invite People      │    ✅    │     ❌     │
│ Security Options   │    ✅    │     ❌     │
└────────────────────┴──────────┴────────────┘
```

---

## 📁 Files in this Directory

### 1. **[learn.dart](learn.dart)** - Main Implementation
หน้าจอการเรียนการสอนออนไลน์ด้วย Jitsi Meet SDK

### 2. **[JITSI_INTEGRATION.md](JITSI_INTEGRATION.md)** - Full Documentation
เอกสารฉบับเต็ม: Feature flags, Configuration, Event listeners, Troubleshooting

---

## 🔧 Key Configurations

### Feature Flags (Role-based)
```dart
FeatureFlags.kickOutEnabled: widget.isTeacher
FeatureFlags.recordingEnabled: widget.isTeacher
FeatureFlags.liveStreamingEnabled: widget.isTeacher
FeatureFlags.inviteEnabled: widget.isTeacher
FeatureFlags.securityOptionEnabled: widget.isTeacher
```

### Config Overrides (Role-based)
```dart
"disableRemoteMute": !widget.isTeacher          // Learner ไม่สามารถ mute คนอื่น
"disableInviteFunctions": !widget.isTeacher     // Learner ไม่สามารถเชิญคน
"enableClosePage": widget.isTeacher             // Teacher สามารถปิดห้องให้ทุกคน
```

---

## 📱 UI States

| State | Description |
|-------|-------------|
| **Pre-join View** | หน้าจอก่อนเข้าห้อง - ข้อมูลคลาส, role badge |
| **Loading View** | กำลังเชื่อมต่อกับ Jitsi |
| **In-conference View** | แสดงสถานะขณะอยู่ในห้อง |
| **Jitsi Full Screen** | Jitsi SDK ครอบคลุมหน้าจอเต็มจอ |

---

## 🎯 Event Listeners

แอปรับฟังเหตุการณ์จาก Jitsi SDK:
- `conferenceJoined` - เริ่มจับเวลา
- `participantJoined/Left` - อัพเดทจำนวนผู้เข้าร่วม
- `audioMutedChanged` - ติดตามสถานะเสียง
- `videoMutedChanged` - ติดตามสถานะวิดีโอ
- `chatMessageReceived` - รับข้อความแชท
- `readyToClose` - ปิดหน้าจอ

---

## 🔒 Security

- ✅ JWT Token support (ผ่าน URL parameter)
- ✅ Role-based access control
- ✅ Teacher = Moderator (Full control)
- ✅ Learner = Participant (Restricted)
- ❌ No password/lobby mode (เพื่อความสะดวก)

---

## 🐛 Troubleshooting

| ปัญหา | แก้ไข |
|------|-------|
| ไม่สามารถเข้าห้องได้ | ตรวจสอบ URL และ internet connection |
| ไม่มีเสียง/วิดีโอ | ตรวจสอบ Camera/Microphone permissions |
| Screen share ไม่ทำงาน | ตรวจสอบ Android API level >= 24 |

---

## 📚 เอกสารเพิ่มเติม

อ่านเอกสารฉบับเต็มได้ที่: **[JITSI_INTEGRATION.md](JITSI_INTEGRATION.md)**

---

**Made with ❤️ for KU Tutorium Project**
