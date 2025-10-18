import 'package:tutorium_frontend/service/api_client.dart';

class ClassInfo {
  final String bannerPicture;
  final String classDescription;
  final String className;
  final double rating;
  final int teacherId;
  final List<String> categories;

  ClassInfo({
    required this.bannerPicture,
    required this.classDescription,
    required this.className,
    required this.rating,
    required this.teacherId,
    this.categories = const [],
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['Categories'] ?? json['categories'];
    return ClassInfo(
      bannerPicture: json['banner_picture'] ?? json['banner_picture_url'] ?? '',
      classDescription: json['class_description'] ?? '',
      className: json['class_name'] ?? '',
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : double.tryParse('${json['rating']}') ?? 0,
      teacherId: json['teacher_id'] ?? json['Teacher']?['user_id'] ?? 0,
      categories: rawCategories is List
          ? rawCategories
                .map(
                  (e) => e is Map<String, dynamic>
                      ? (e['class_category'] ?? e['category'] ?? '').toString()
                      : e.toString(),
                )
                .where((name) => name.isNotEmpty)
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'banner_picture': bannerPicture,
      'class_description': classDescription,
      'class_name': className,
      'rating': rating,
      'teacher_id': teacherId,
      if (categories.isNotEmpty) 'categories': categories,
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

  /// GET /classes/:id (200, 400, 404, 500)
  static Future<ClassInfo> fetchById(int id) async {
    final response = await _client.getJsonMap('/classes/$id');
    return ClassInfo.fromJson(response);
  }

  /// POST /classes (201, 400, 500)
  static Future<ClassInfo> create(ClassInfo info) async {
    final response = await _client.postJsonMap('/classes', body: info.toJson());
    return ClassInfo.fromJson(response);
  }

  /// PUT /classes/:id (200, 400, 404, 500)
  static Future<ClassInfo> update(int id, ClassInfo info) async {
    final response = await _client.putJsonMap(
      '/classes/$id',
      body: info.toJson(),
    );
    return ClassInfo.fromJson(response);
  }

  /// DELETE /classes/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    await _client.delete('/classes/$id');
  }
}
