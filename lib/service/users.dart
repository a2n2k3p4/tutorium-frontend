import 'package:tutorium_frontend/service/api_client.dart';

class User {
  final int id;
  final String? studentId;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? phoneNumber;
  final double balance;
  final int banCount;
  final String? profilePicture;
  final Teacher? teacher;
  final Learner? learner;

  const User({
    required this.id,
    this.studentId,
    this.firstName,
    this.lastName,
    this.gender,
    this.phoneNumber,
    required this.balance,
    required this.banCount,
    this.profilePicture,
    this.teacher,
    this.learner,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['ID'] ?? json['id'] ?? 0,
      studentId: json['student_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      gender: json['gender'],
      phoneNumber: json['phone_number'],
      balance: _parseDouble(json['balance']),
      banCount: json['ban_count'] ?? 0,
      profilePicture: json['profile_picture'],
      teacher: json['Teacher'] != null
          ? Teacher.fromJson(json['Teacher'] as Map<String, dynamic>)
          : null,
      learner: json['Learner'] != null
          ? Learner.fromJson(json['Learner'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'student_id': studentId,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'phone_number': phoneNumber,
      'balance': balance,
      'ban_count': banCount,
      'profile_picture': profilePicture,
    };
    map.removeWhere((_, value) => value == null);
    return map;
  }

  User copyWith({
    String? studentId,
    String? firstName,
    String? lastName,
    String? gender,
    String? phoneNumber,
    double? balance,
    int? banCount,
    String? profilePicture,
    Teacher? teacher,
    Learner? learner,
  }) {
    return User(
      id: id,
      studentId: studentId ?? this.studentId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      banCount: banCount ?? this.banCount,
      profilePicture: profilePicture ?? this.profilePicture,
      teacher: teacher ?? this.teacher,
      learner: learner ?? this.learner,
    );
  }

  static final ApiClient _client = ApiClient();

  /// GET /users
  static Future<List<User>> fetchAll({Map<String, dynamic>? query}) async {
    final response = await _client.getJsonList(
      '/users',
      queryParameters: query,
    );
    return response.map(User.fromJson).toList();
  }

  /// GET /users/:id
  static Future<User> fetchById(int id) async {
    final response = await _client.getJsonMap('/users/$id');
    return User.fromJson(response);
  }

  /// POST /users
  static Future<User> create(User user) async {
    final response = await _client.postJsonMap('/users', body: user.toJson());
    return User.fromJson(response);
  }

  /// PUT /users/:id
  static Future<User> update(int id, User user) async {
    final response = await _client.putJsonMap(
      '/users/$id',
      body: user.toJson(),
    );
    return User.fromJson(response);
  }

  /// DELETE /users/:id
  static Future<void> delete(int id) async {
    await _client.delete('/users/$id');
  }
}

class Teacher {
  final int id;
  final int userId;
  final String? description;
  final int? flagCount;
  final String? email;

  const Teacher({
    required this.id,
    required this.userId,
    this.description,
    this.flagCount,
    this.email,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['ID'] ?? json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      description: json['description'],
      flagCount: json['flag_count'],
      email: json['email'],
    );
  }
}

class Learner {
  final int id;
  final int userId;
  final int? flagCount;

  const Learner({required this.id, required this.userId, this.flagCount});

  factory Learner.fromJson(Map<String, dynamic> json) {
    return Learner(
      id: json['ID'] ?? json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      flagCount: json['flag_count'],
    );
  }
}

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}
