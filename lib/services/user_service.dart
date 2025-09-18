import '../models/user_models.dart';
import '../services/api_config.dart';
import '../services/base_api_service.dart';

class UserService extends BaseApiService {
  // Get all users
  Future<List<User>> getUsers() async {
    final response = await get(ApiConfig.users);
    final data = handleListResponse(response);
    return data.map((json) => User.fromJson(json)).toList();
  }

  // Get user by ID
  Future<User> getUserById(int id) async {
    final response = await get('${ApiConfig.users}/$id');
    final data = handleResponse(response);
    return User.fromJson(data);
  }

  // Create new user
  Future<User> createUser(User user) async {
    final response = await post(ApiConfig.users, user.toJson());
    final data = handleResponse(response);
    return User.fromJson(data);
  }

  // Update user
  Future<User> updateUser(int id, User user) async {
    final response = await put('${ApiConfig.users}/$id', user.toJson());
    final data = handleResponse(response);
    return User.fromJson(data);
  }

  // Delete user
  Future<void> deleteUser(int id) async {
    await delete('${ApiConfig.users}/$id');
  }
}

class TeacherService extends BaseApiService {
  // Get all teachers
  Future<List<Teacher>> getTeachers() async {
    final response = await get(ApiConfig.teachers);
    final data = handleListResponse(response);
    return data.map((json) => Teacher.fromJson(json)).toList();
  }

  // Get teacher by ID
  Future<Teacher> getTeacherById(int id) async {
    final response = await get('${ApiConfig.teachers}/$id');
    final data = handleResponse(response);
    return Teacher.fromJson(data);
  }

  // Create new teacher
  Future<Teacher> createTeacher(Teacher teacher) async {
    final response = await post(ApiConfig.teachers, teacher.toJson());
    final data = handleResponse(response);
    return Teacher.fromJson(data);
  }

  // Update teacher
  Future<Teacher> updateTeacher(int id, Teacher teacher) async {
    final response = await put('${ApiConfig.teachers}/$id', teacher.toJson());
    final data = handleResponse(response);
    return Teacher.fromJson(data);
  }

  // Delete teacher
  Future<void> deleteTeacher(int id) async {
    await delete('${ApiConfig.teachers}/$id');
  }
}

class LearnerService extends BaseApiService {
  // Get all learners
  Future<List<Learner>> getLearners() async {
    final response = await get(ApiConfig.learners);
    final data = handleListResponse(response);
    return data.map((json) => Learner.fromJson(json)).toList();
  }

  // Get learner by ID
  Future<Learner> getLearnerById(int id) async {
    final response = await get('${ApiConfig.learners}/$id');
    final data = handleResponse(response);
    return Learner.fromJson(data);
  }

  // Create new learner
  Future<Learner> createLearner(Learner learner) async {
    final response = await post(ApiConfig.learners, learner.toJson());
    final data = handleResponse(response);
    return Learner.fromJson(data);
  }

  // Delete learner
  Future<void> deleteLearner(int id) async {
    await delete('${ApiConfig.learners}/$id');
  }
}
