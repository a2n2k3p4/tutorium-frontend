// User Models
class User {
  final int id;
  final String firstName;
  final String lastName;
  final String studentId;
  final String phoneNumber;
  final String gender;
  final String? profilePicture;
  final double balance;
  final int banCount;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.studentId,
    required this.phoneNumber,
    required this.gender,
    this.profilePicture,
    required this.balance,
    required this.banCount,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      studentId: json['student_id'],
      phoneNumber: json['phone_number'],
      gender: json['gender'],
      profilePicture: json['profile_picture'],
      balance: (json['balance'] ?? 0).toDouble(),
      banCount: json['ban_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'student_id': studentId,
      'phone_number': phoneNumber,
      'gender': gender,
      'profile_picture': profilePicture,
      'balance': balance,
      'ban_count': banCount,
    };
  }
}

// Login Models
class LoginRequest {
  final String username;
  final String password;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String gender;
  final String? profilePicture;

  LoginRequest({
    required this.username,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.gender,
    this.profilePicture,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'gender': gender,
      'profile_picture': profilePicture,
    };
  }
}

class LoginResponse {
  final String token;
  final User user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'],
      user: User.fromJson(json['user']),
    );
  }
}

// Teacher Model
class Teacher {
  final int id;
  final int userId;
  final String email;
  final String description;
  final int flagCount;

  Teacher({
    required this.id,
    required this.userId,
    required this.email,
    required this.description,
    required this.flagCount,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'],
      userId: json['user_id'],
      email: json['email'],
      description: json['description'],
      flagCount: json['flag_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'email': email,
      'description': description,
      'flag_count': flagCount,
    };
  }
}

// Learner Model
class Learner {
  final int id;
  final int userId;
  final int flagCount;

  Learner({required this.id, required this.userId, required this.flagCount});

  factory Learner.fromJson(Map<String, dynamic> json) {
    return Learner(
      id: json['id'],
      userId: json['user_id'],
      flagCount: json['flag_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'user_id': userId, 'flag_count': flagCount};
  }
}
