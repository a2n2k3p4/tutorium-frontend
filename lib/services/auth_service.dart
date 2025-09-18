import '../models/user_models.dart';
import '../services/api_config.dart';
import '../services/base_api_service.dart';

class AuthService extends BaseApiService {
  // Login with KU/Nisit credentials
  Future<LoginResponse> login(LoginRequest request) async {
    final response = await post(
      ApiConfig.login,
      request.toJson(),
      includeAuth: false,
    );

    final data = handleResponse(response);
    final loginResponse = LoginResponse.fromJson(data);

    // Save token after successful login
    await saveToken(loginResponse.token);

    return loginResponse;
  }

  // Logout
  Future<void> logout() async {
    await removeToken();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
