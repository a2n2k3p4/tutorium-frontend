// Notification Model
class NotificationModel {
  final int id;
  final int userId;
  final String notificationType;
  final String notificationDescription;
  final DateTime notificationDate;
  final bool readFlag;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.notificationType,
    required this.notificationDescription,
    required this.notificationDate,
    required this.readFlag,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      notificationType: json['notification_type'],
      notificationDescription: json['notification_description'],
      notificationDate: DateTime.parse(json['notification_date']),
      readFlag: json['read_flag'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'notification_type': notificationType,
      'notification_description': notificationDescription,
      'notification_date': notificationDate.toIso8601String(),
      'read_flag': readFlag,
    };
  }
}

// Report Model
class Report {
  final int id;
  final int reportUserId;
  final int reportedUserId;
  final int? classSessionId;
  final String reportType;
  final String reportReason;
  final String reportDescription;
  final String? reportPicture;
  final DateTime reportDate;
  final String reportStatus;

  Report({
    required this.id,
    required this.reportUserId,
    required this.reportedUserId,
    this.classSessionId,
    required this.reportType,
    required this.reportReason,
    required this.reportDescription,
    this.reportPicture,
    required this.reportDate,
    required this.reportStatus,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      reportUserId: json['report_user_id'],
      reportedUserId: json['reported_user_id'],
      classSessionId: json['class_session_id'],
      reportType: json['report_type'],
      reportReason: json['report_reason'],
      reportDescription: json['report_description'],
      reportPicture: json['report_picture'],
      reportDate: DateTime.parse(json['report_date']),
      reportStatus: json['report_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_user_id': reportUserId,
      'reported_user_id': reportedUserId,
      'class_session_id': classSessionId,
      'report_type': reportType,
      'report_reason': reportReason,
      'report_description': reportDescription,
      'report_picture': reportPicture,
      'report_date': reportDate.toIso8601String(),
      'report_status': reportStatus,
    };
  }
}

// Ban Models
class BanDetailsLearner {
  final int id;
  final int learnerId;
  final DateTime banStart;
  final DateTime banEnd;
  final String banDescription;

  BanDetailsLearner({
    required this.id,
    required this.learnerId,
    required this.banStart,
    required this.banEnd,
    required this.banDescription,
  });

  factory BanDetailsLearner.fromJson(Map<String, dynamic> json) {
    return BanDetailsLearner(
      id: json['id'],
      learnerId: json['learner_id'],
      banStart: DateTime.parse(json['ban_start']),
      banEnd: DateTime.parse(json['ban_end']),
      banDescription: json['ban_description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'learner_id': learnerId,
      'ban_start': banStart.toIso8601String(),
      'ban_end': banEnd.toIso8601String(),
      'ban_description': banDescription,
    };
  }
}

class BanDetailsTeacher {
  final int id;
  final int teacherId;
  final DateTime banStart;
  final DateTime banEnd;
  final String banDescription;

  BanDetailsTeacher({
    required this.id,
    required this.teacherId,
    required this.banStart,
    required this.banEnd,
    required this.banDescription,
  });

  factory BanDetailsTeacher.fromJson(Map<String, dynamic> json) {
    return BanDetailsTeacher(
      id: json['id'],
      teacherId: json['teacher_id'],
      banStart: DateTime.parse(json['ban_start']),
      banEnd: DateTime.parse(json['ban_end']),
      banDescription: json['ban_description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'ban_start': banStart.toIso8601String(),
      'ban_end': banEnd.toIso8601String(),
      'ban_description': banDescription,
    };
  }
}

// Admin Model
class Admin {
  final int id;
  final int userId;

  Admin({required this.id, required this.userId});

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(id: json['id'], userId: json['user_id']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'user_id': userId};
  }
}
