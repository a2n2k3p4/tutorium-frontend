import 'package:tutorium_frontend/service/api_client.dart';

class ClassInfo {
  final int id;
  final String className;
  final String classDescription;
  final double rating;
  final int teacherId;
  final String? bannerPicture;

  const ClassInfo({
    required this.id,
    required this.className,
    required this.classDescription,
    required this.rating,
    required this.teacherId,
    this.bannerPicture,
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    return ClassInfo(
      id: json['id'] ?? json['ID'] ?? 0,
      className: json['class_name'] ?? '',
      classDescription: json['class_description'] ?? '',
      rating: _parseDouble(json['rating']),
      teacherId: json['teacher_id'] ?? 0,
      bannerPicture: json['banner_picture'] ?? json['banner_picture_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_name': className,
      'class_description': classDescription,
      'rating': rating,
      'teacher_id': teacherId,
      if (bannerPicture != null) 'banner_picture': bannerPicture,
    };
  }
}

class ClassCategory {
  final int id;
  final String classCategory;
  final List<ClassInfo> classes;

  const ClassCategory({
    required this.id,
    required this.classCategory,
    this.classes = const [],
  });

  factory ClassCategory.fromJson(Map<String, dynamic> json) {
    return ClassCategory(
      id: json['id'] ?? json['ID'] ?? 0,
      classCategory: json['class_category'] ?? '',
      classes: (json['classes'] as List<dynamic>? ?? const [])
          .map((e) => ClassInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_category': classCategory,
      if (classes.isNotEmpty)
        'classes': classes.map((e) => e.toJson()).toList(),
    };
  }

  static final ApiClient _client = ApiClient();

  static Future<List<ClassCategory>> fetchAll({
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.getJsonList(
      '/class_categories',
      queryParameters: query,
    );
    return response.map(ClassCategory.fromJson).toList();
  }

  static Future<ClassCategory> fetchById(int id) async {
    final response = await _client.getJsonMap('/class_categories/$id');
    return ClassCategory.fromJson(response);
  }

  static Future<ClassCategory> create(ClassCategory category) async {
    final response = await _client.postJsonMap(
      '/class_categories',
      body: category.toJson(),
    );
    return ClassCategory.fromJson(response);
  }

  static Future<ClassCategory> update(int id, ClassCategory category) async {
    final response = await _client.putJsonMap(
      '/class_categories/$id',
      body: category.toJson(),
    );
    return ClassCategory.fromJson(response);
  }

  static Future<void> delete(int id) async {
    await _client.delete('/class_categories/$id');
  }
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
