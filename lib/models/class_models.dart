// Class Models
class ClassModel {
  final int id;
  final String className;
  final String classDescription;
  final String? bannerPicture;
  final double rating;
  final int teacherId;

  ClassModel({
    required this.id,
    required this.className,
    required this.classDescription,
    this.bannerPicture,
    required this.rating,
    required this.teacherId,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] ?? json['ID'] ?? 0,
      className: json['class_name'] ?? '',
      classDescription: json['class_description'] ?? '',
      bannerPicture: json['banner_picture'] ?? json['banner_picture_url'],
      rating: _parseDouble(json['rating'] ?? json['average_rating']),
      teacherId:
          json['teacher_id'] ??
          json['Teacher']?['ID'] ??
          json['Teacher']?['id'] ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_name': className,
      'class_description': classDescription,
      'banner_picture': bannerPicture,
      'rating': rating,
      'teacher_id': teacherId,
    };
  }
}

double _parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

// Class Category Model
class ClassCategory {
  final int id;
  final String classCategory;
  final List<ClassModel>? classes;

  ClassCategory({required this.id, required this.classCategory, this.classes});

  factory ClassCategory.fromJson(Map<String, dynamic> json) {
    return ClassCategory(
      id: json['id'],
      classCategory: json['class_category'],
      classes: json['classes'] != null
          ? (json['classes'] as List)
                .map((e) => ClassModel.fromJson(e))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_category': classCategory,
      'classes': classes?.map((e) => e.toJson()).toList(),
    };
  }
}

// Class Session Model
class ClassSession {
  final int id;
  final int classId;
  final DateTime classStart;
  final DateTime classFinish;
  final DateTime enrollmentDeadline;
  final String classStatus;
  final String description;
  final int learnerLimit;
  final double price;
  final String? classUrl;

  ClassSession({
    required this.id,
    required this.classId,
    required this.classStart,
    required this.classFinish,
    required this.enrollmentDeadline,
    required this.classStatus,
    required this.description,
    required this.learnerLimit,
    required this.price,
    this.classUrl,
  });

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      id: json['id'],
      classId: json['class_id'],
      classStart: DateTime.parse(json['class_start']),
      classFinish: DateTime.parse(json['class_finish']),
      enrollmentDeadline: DateTime.parse(json['enrollment_deadline']),
      classStatus: json['class_status'],
      description: json['description'],
      learnerLimit: json['learner_limit'],
      price: (json['price'] ?? 0).toDouble(),
      classUrl: json['class_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'class_start': classStart.toIso8601String(),
      'class_finish': classFinish.toIso8601String(),
      'enrollment_deadline': enrollmentDeadline.toIso8601String(),
      'class_status': classStatus,
      'description': description,
      'learner_limit': learnerLimit,
      'price': price,
      'class_url': classUrl,
    };
  }
}

// Enrollment Model
class Enrollment {
  final int id;
  final int learnerId;
  final int classSessionId;
  final String enrollmentStatus;

  Enrollment({
    required this.id,
    required this.learnerId,
    required this.classSessionId,
    required this.enrollmentStatus,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    return Enrollment(
      id: json['id'],
      learnerId: json['learner_id'],
      classSessionId: json['class_session_id'],
      enrollmentStatus: json['enrollment_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'learner_id': learnerId,
      'class_session_id': classSessionId,
      'enrollment_status': enrollmentStatus,
    };
  }
}

// Review Model
class Review {
  final int id;
  final int learnerId;
  final int classId;
  final int rating;
  final String comment;

  Review({
    required this.id,
    required this.learnerId,
    required this.classId,
    required this.rating,
    required this.comment,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      learnerId: json['learner_id'],
      classId: json['class_id'],
      rating: json['rating'],
      comment: json['comment'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'learner_id': learnerId,
      'class_id': classId,
      'rating': rating,
      'comment': comment,
    };
  }
}
