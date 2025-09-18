import '../models/class_models.dart';
import '../services/api_config.dart';
import '../services/base_api_service.dart';

class ClassService extends BaseApiService {
  // Get all classes with optional filters
  Future<List<ClassModel>> getClasses({
    List<String>? categories,
    double? minRating,
    double? maxRating,
  }) async {
    String endpoint = ApiConfig.classes;
    List<String> queryParams = [];

    if (categories != null && categories.isNotEmpty) {
      queryParams.add('category=${categories.join(',')}');
    }
    if (minRating != null) {
      queryParams.add('min_rating=$minRating');
    }
    if (maxRating != null) {
      queryParams.add('max_rating=$maxRating');
    }

    if (queryParams.isNotEmpty) {
      endpoint += '?${queryParams.join('&')}';
    }

    final response = await get(endpoint);
    final data = handleListResponse(response);
    return data.map((json) => ClassModel.fromJson(json)).toList();
  }

  // Get class by ID
  Future<ClassModel> getClassById(int id) async {
    final response = await get('${ApiConfig.classes}/$id');
    final data = handleResponse(response);
    return ClassModel.fromJson(data);
  }

  // Create new class
  Future<ClassModel> createClass(ClassModel classModel) async {
    final response = await post(ApiConfig.classes, classModel.toJson());
    final data = handleResponse(response);
    return ClassModel.fromJson(data);
  }

  // Update class
  Future<ClassModel> updateClass(int id, ClassModel classModel) async {
    final response = await put('${ApiConfig.classes}/$id', classModel.toJson());
    final data = handleResponse(response);
    return ClassModel.fromJson(data);
  }

  // Delete class
  Future<void> deleteClass(int id) async {
    await delete('${ApiConfig.classes}/$id');
  }
}

class ClassCategoryService extends BaseApiService {
  // Get all class categories
  Future<List<ClassCategory>> getClassCategories() async {
    final response = await get(ApiConfig.classCategories);
    final data = handleListResponse(response);
    return data.map((json) => ClassCategory.fromJson(json)).toList();
  }

  // Get class category by ID
  Future<ClassCategory> getClassCategoryById(int id) async {
    final response = await get('${ApiConfig.classCategories}/$id');
    final data = handleResponse(response);
    return ClassCategory.fromJson(data);
  }

  // Create new class category
  Future<ClassCategory> createClassCategory(ClassCategory category) async {
    final response = await post(ApiConfig.classCategories, category.toJson());
    final data = handleResponse(response);
    return ClassCategory.fromJson(data);
  }

  // Update class category
  Future<ClassCategory> updateClassCategory(
    int id,
    ClassCategory category,
  ) async {
    final response = await put(
      '${ApiConfig.classCategories}/$id',
      category.toJson(),
    );
    final data = handleResponse(response);
    return ClassCategory.fromJson(data);
  }

  // Delete class category
  Future<void> deleteClassCategory(int id) async {
    await delete('${ApiConfig.classCategories}/$id');
  }
}

class ClassSessionService extends BaseApiService {
  // Get all class sessions
  Future<List<ClassSession>> getClassSessions() async {
    final response = await get(ApiConfig.classSessions);
    final data = handleListResponse(response);
    return data.map((json) => ClassSession.fromJson(json)).toList();
  }

  // Get class session by ID
  Future<ClassSession> getClassSessionById(int id) async {
    final response = await get('${ApiConfig.classSessions}/$id');
    final data = handleResponse(response);
    return ClassSession.fromJson(data);
  }

  // Create new class session
  Future<ClassSession> createClassSession(ClassSession session) async {
    final response = await post(ApiConfig.classSessions, session.toJson());
    final data = handleResponse(response);
    return ClassSession.fromJson(data);
  }

  // Update class session
  Future<ClassSession> updateClassSession(int id, ClassSession session) async {
    final response = await put(
      '${ApiConfig.classSessions}/$id',
      session.toJson(),
    );
    final data = handleResponse(response);
    return ClassSession.fromJson(data);
  }

  // Delete class session
  Future<void> deleteClassSession(int id) async {
    await delete('${ApiConfig.classSessions}/$id');
  }
}

class EnrollmentService extends BaseApiService {
  // Get all enrollments
  Future<List<Enrollment>> getEnrollments() async {
    final response = await get(ApiConfig.enrollments);
    final data = handleListResponse(response);
    return data.map((json) => Enrollment.fromJson(json)).toList();
  }

  // Get enrollment by ID
  Future<Enrollment> getEnrollmentById(int id) async {
    final response = await get('${ApiConfig.enrollments}/$id');
    final data = handleResponse(response);
    return Enrollment.fromJson(data);
  }

  // Create new enrollment
  Future<Enrollment> createEnrollment(Enrollment enrollment) async {
    final response = await post(ApiConfig.enrollments, enrollment.toJson());
    final data = handleResponse(response);
    return Enrollment.fromJson(data);
  }

  // Update enrollment
  Future<Enrollment> updateEnrollment(int id, Enrollment enrollment) async {
    final response = await put(
      '${ApiConfig.enrollments}/$id',
      enrollment.toJson(),
    );
    final data = handleResponse(response);
    return Enrollment.fromJson(data);
  }

  // Delete enrollment
  Future<void> deleteEnrollment(int id) async {
    await delete('${ApiConfig.enrollments}/$id');
  }
}

class ReviewService extends BaseApiService {
  // Get all reviews
  Future<List<Review>> getReviews() async {
    final response = await get(ApiConfig.reviews);
    final data = handleListResponse(response);
    return data.map((json) => Review.fromJson(json)).toList();
  }

  // Get review by ID
  Future<Review> getReviewById(int id) async {
    final response = await get('${ApiConfig.reviews}/$id');
    final data = handleResponse(response);
    return Review.fromJson(data);
  }

  // Create new review
  Future<Review> createReview(Review review) async {
    final response = await post(ApiConfig.reviews, review.toJson());
    final data = handleResponse(response);
    return Review.fromJson(data);
  }

  // Update review
  Future<Review> updateReview(int id, Review review) async {
    final response = await put('${ApiConfig.reviews}/$id', review.toJson());
    final data = handleResponse(response);
    return Review.fromJson(data);
  }

  // Delete review
  Future<void> deleteReview(int id) async {
    await delete('${ApiConfig.reviews}/$id');
  }
}
