import 'package:tutorium_frontend/service/api_client.dart';

class ClassInfo {
  final int id;
  final String className;
  final String classDescription;
  final String? bannerPicture;
  final String? bannerPictureUrl;
  final double rating;
  final int teacherId;
  final String? teacherName;
  final int? enrolledLearners;
  final List<String> categories;

  const ClassInfo({
    required this.id,
    required this.className,
    required this.classDescription,
    this.bannerPicture,
    this.bannerPictureUrl,
    required this.rating,
    required this.teacherId,
    this.teacherName,
    this.enrolledLearners,
    this.categories = const [],
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['Categories'] ?? json['categories'];
    final teacher = json['Teacher'] as Map<String, dynamic>?;
    final teacherFirstName =
        teacher?['first_name'] ?? json['teacher_first_name'];
    final teacherLastName = teacher?['last_name'] ?? json['teacher_last_name'];
    final rawTeacherName = json['teacher_name'] ?? json['teacherName'];

    String? teacherName;
    if (rawTeacherName is String && rawTeacherName.trim().isNotEmpty) {
      teacherName = rawTeacherName.trim();
    } else if (teacherFirstName != null || teacherLastName != null) {
      teacherName = '${teacherFirstName ?? ''} ${teacherLastName ?? ''}'
          .trim()
          .replaceAll(RegExp(r'\s{2,}'), ' ');
      if (teacherName.isEmpty) teacherName = null;
    }

    final enrolled =
        json['enrolled_learners'] ??
        json['enrolledLearners'] ??
        json['enrollment_count'] ??
        json['learner_count'];

    return ClassInfo(
      id: _parseInt(json['ID']) ?? _parseInt(json['id']) ?? 0,
      className: json['class_name']?.toString() ?? '',
      classDescription: json['class_description']?.toString() ?? '',
      bannerPicture: json['banner_picture']?.toString(),
      bannerPictureUrl: json['banner_picture_url']?.toString(),
      rating: _parseDouble(json['average_rating'] ?? json['rating']),
      teacherId:
          _parseInt(json['teacher_id']) ??
          _parseInt(json['Teacher']?['ID']) ??
          _parseInt(json['Teacher']?['id']) ??
          _parseInt(json['teacherId']) ??
          0,
      teacherName: teacherName,
      enrolledLearners: enrolled is num
          ? enrolled.toInt()
          : int.tryParse('$enrolled'),
      categories: _parseCategoryNames(rawCategories),
    );
  }

  ClassInfo copyWith({
    int? id,
    String? className,
    String? classDescription,
    String? bannerPicture,
    String? bannerPictureUrl,
    double? rating,
    int? teacherId,
    String? teacherName,
    int? enrolledLearners,
    List<String>? categories,
  }) {
    return ClassInfo(
      id: id ?? this.id,
      className: className ?? this.className,
      classDescription: classDescription ?? this.classDescription,
      bannerPicture: bannerPicture ?? this.bannerPicture,
      bannerPictureUrl: bannerPictureUrl ?? this.bannerPictureUrl,
      rating: rating ?? this.rating,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      enrolledLearners: enrolledLearners ?? this.enrolledLearners,
      categories: categories ?? this.categories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != 0) 'id': id,
      'class_name': className,
      'class_description': classDescription,
      'rating': rating,
      'teacher_id': teacherId,
      if (bannerPicture != null) 'banner_picture': bannerPicture,
      if (bannerPictureUrl != null) 'banner_picture_url': bannerPictureUrl,
      if (teacherName != null) 'teacher_name': teacherName,
      if (enrolledLearners != null) 'enrolled_learners': enrolledLearners,
      if (categories.isNotEmpty) 'categories': categories,
    };
  }

  Map<String, dynamic> toPayload() {
    return {
      'class_name': className,
      'class_description': classDescription,
      'teacher_id': teacherId,
      if (bannerPicture != null && bannerPicture!.isNotEmpty)
        'banner_picture': bannerPicture,
    };
  }

  static final ApiClient _client = ApiClient();

  // ---------- CRUD ----------

  /// GET /classes (200, 400, 500)
  static Future<List<ClassInfo>> fetchAll({
    List<String>? categories,
    double? minRating,
    double? maxRating,
    double? minPrice,
    double? maxPrice,
    String? search,
    String? sort,
    int? limit,
    int? offset,
    int? teacherId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (categories != null && categories.isNotEmpty) {
      queryParams['category'] = categories.join(',');
    }
    if (minRating != null) queryParams['min_rating'] = minRating;
    if (maxRating != null) queryParams['max_rating'] = maxRating;
    if (minPrice != null) queryParams['min_price'] = minPrice;
    if (maxPrice != null) queryParams['max_price'] = maxPrice;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (sort != null && sort.isNotEmpty) queryParams['sort'] = sort;
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;
    if (teacherId != null) queryParams['teacher_id'] = teacherId;

    final response = await _client.getJsonList(
      '/classes',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    return response.map(ClassInfo.fromJson).toList();
  }

  static Future<List<ClassInfo>> fetchByTeacher(
    int teacherId, {
    String? teacherName,
  }) async {
    // Simply fetch classes filtered by teacherId from backend
    // Backend should return correct teacherId in the response
    final classes = await fetchAll(teacherId: teacherId);

    // Optional: Fill in missing teacherId if teacherName matches
    return classes
        .map(
          (cls) => cls.teacherId != 0
              ? cls
              : (teacherName != null &&
                    cls.teacherName?.toLowerCase().trim() ==
                        teacherName.toLowerCase().trim())
              ? cls.copyWith(teacherId: teacherId)
              : cls,
        )
        .where((cls) => cls.teacherId == teacherId)
        .toList();
  }

  /// GET /classes/:id (200, 400, 404, 500)
  static Future<ClassInfo> fetchById(int id) async {
    final response = await _client.getJsonMap('/classes/$id');
    return ClassInfo.fromJson(response);
  }

  /// POST /classes (201, 400, 500)
  static Future<ClassInfo> create(ClassInfo info) async {
    final response = await _client.postJsonMap(
      '/classes',
      body: info.toPayload(),
    );
    return ClassInfo.fromJson(response);
  }

  /// PUT /classes/:id (200, 400, 404, 500)
  static Future<ClassInfo> update(int id, ClassInfo info) async {
    final response = await _client.putJsonMap(
      '/classes/$id',
      body: info.toPayload(),
    );
    return ClassInfo.fromJson(response);
  }

  /// DELETE /classes/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    try {
      await _client.delete('/classes/$id');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw ApiException(404, 'Class not found');
      } else if (e.statusCode == 400) {
        throw ApiException(400, e.body ?? 'Invalid class ID');
      } else if (e.statusCode == 500) {
        throw ApiException(500, 'Failed to delete class. Please try again.');
      }
      rethrow;
    } catch (e) {
      throw Exception('Failed to delete class: ${e.toString()}');
    }
  }

  static Future<double?> fetchAverageRating(int classId) async {
    try {
      final response = await _client.getJsonMap(
        '/classes/$classId/average_rating',
      );
      return _parseDouble(response['average_rating']);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}

List<String> _parseCategoryNames(dynamic raw) {
  if (raw is List) {
    return raw
        .map(
          (e) => e is Map<String, dynamic>
              ? (e['class_category'] ?? e['category'] ?? '').toString()
              : e.toString(),
        )
        .where((name) => name.isNotEmpty)
        .toList();
  }
  return const [];
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
