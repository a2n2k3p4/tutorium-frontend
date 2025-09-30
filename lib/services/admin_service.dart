import '../models/other_models.dart';
import '../services/api_config.dart';
import '../services/base_api_service.dart';

class AdminService extends BaseApiService {
  // Get all admins
  Future<List<Admin>> getAdmins() async {
    final response = await get(ApiConfig.admins);
    final data = handleListResponse(response);
    return data.map((json) => Admin.fromJson(json)).toList();
  }

  // Get admin by ID
  Future<Admin> getAdminById(int id) async {
    final response = await get('${ApiConfig.admins}/$id');
    final data = handleResponse(response);
    return Admin.fromJson(data);
  }

  // Create new admin
  Future<Admin> createAdmin(Admin admin) async {
    final response = await post(ApiConfig.admins, admin.toJson());
    final data = handleResponse(response);
    return Admin.fromJson(data);
  }

  // Delete admin
  Future<void> deleteAdmin(int id) async {
    await delete('${ApiConfig.admins}/$id');
  }
}

class BanService extends BaseApiService {
  // Ban Learners

  // Get all banned learners
  Future<List<BanDetailsLearner>> getBanLearners() async {
    final response = await get(ApiConfig.banLearners);
    final data = handleListResponse(response);
    return data.map((json) => BanDetailsLearner.fromJson(json)).toList();
  }

  // Get banned learner by ID
  Future<BanDetailsLearner> getBanLearnerById(int id) async {
    final response = await get('${ApiConfig.banLearners}/$id');
    final data = handleResponse(response);
    return BanDetailsLearner.fromJson(data);
  }

  // Create new ban learner record
  Future<BanDetailsLearner> createBanLearner(
    BanDetailsLearner banLearner,
  ) async {
    final response = await post(ApiConfig.banLearners, banLearner.toJson());
    final data = handleResponse(response);
    return BanDetailsLearner.fromJson(data);
  }

  // Update ban learner record
  Future<BanDetailsLearner> updateBanLearner(
    int id,
    BanDetailsLearner banLearner,
  ) async {
    final response = await put(
      '${ApiConfig.banLearners}/$id',
      banLearner.toJson(),
    );
    final data = handleResponse(response);
    return BanDetailsLearner.fromJson(data);
  }

  // Delete ban learner record
  Future<void> deleteBanLearner(int id) async {
    await delete('${ApiConfig.banLearners}/$id');
  }

  // Ban Teachers

  // Get all banned teachers
  Future<List<BanDetailsTeacher>> getBanTeachers() async {
    final response = await get(ApiConfig.banTeachers);
    final data = handleListResponse(response);
    return data.map((json) => BanDetailsTeacher.fromJson(json)).toList();
  }

  // Get banned teacher by ID
  Future<BanDetailsTeacher> getBanTeacherById(int id) async {
    final response = await get('${ApiConfig.banTeachers}/$id');
    final data = handleResponse(response);
    return BanDetailsTeacher.fromJson(data);
  }

  // Create new ban teacher record
  Future<BanDetailsTeacher> createBanTeacher(
    BanDetailsTeacher banTeacher,
  ) async {
    final response = await post(ApiConfig.banTeachers, banTeacher.toJson());
    final data = handleResponse(response);
    return BanDetailsTeacher.fromJson(data);
  }

  // Update ban teacher record
  Future<BanDetailsTeacher> updateBanTeacher(
    int id,
    BanDetailsTeacher banTeacher,
  ) async {
    final response = await put(
      '${ApiConfig.banTeachers}/$id',
      banTeacher.toJson(),
    );
    final data = handleResponse(response);
    return BanDetailsTeacher.fromJson(data);
  }

  // Delete ban teacher record
  Future<void> deleteBanTeacher(int id) async {
    await delete('${ApiConfig.banTeachers}/$id');
  }
}
