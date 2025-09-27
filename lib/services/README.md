# KU Tutorium API Services

## Installation and Usage

### 1. Required Imports
```dart
import 'package:your_app/services/api_provider.dart';
import 'package:your_app/models/models.dart';
```

### 2. Basic Usage

#### Login
```dart
try {
  final loginRequest = LoginRequest(
    username: 'b6610505511',
    password: 'yourPassword',
    firstName: 'FirstName',
    lastName: 'LastName',
    phoneNumber: '+66812345678',
    gender: 'Male',
  );

  final response = await API.auth.login(loginRequest);
  print('Login successful: ${response.user.firstName}');
} catch (e) {
  print('Login failed: $e');
}
```

#### Fetching Class Data
```dart
// Get all classes
final classes = await API.classService.getClasses();

// Get classes with filters
final filteredClasses = await API.classService.getClasses(
  categories: ['Mathematics', 'Science'],
  minRating: 4.0,
  maxRating: 5.0,
);

// Get class by ID
final classDetail = await API.classService.getClassById(1);
```

#### Enroll in a Class
```dart
final enrollment = Enrollment(
  id: 0,
  learnerId: 42,
  classSessionId: 21,
  enrollmentStatus: 'active',
);

final result = await API.enrollment.createEnrollment(enrollment);
```

#### Create a Review
```dart
final review = Review(
  id: 0,
  learnerId: 42,
  classId: 21,
  rating: 5,
  comment: 'Great class, highly recommended!',
);

await API.review.createReview(review);
```

#### Payment
```dart
final payment = PaymentRequest(
  amount: 199900, // 1999 Baht (in satang)
  currency: 'THB',
  paymentType: 'credit_card',
  description: 'Tuition fee',
  userId: 5,
  token: 'omise_token_here',
);

final result = await API.payment.createCharge(payment);
```

### 3. Error Handling

```dart
try {
  final result = await API.user.getUserById(1);
} catch (e) {
  if (e is ApiException) {
    switch (e.statusCode) {
      case 400:
        print('Invalid data');
        break;
      case 401:
        print('Please log in again');
        break;
      case 404:
        print('Data not found');
        break;
      case 500:
        print('Server error');
        break;
    }
  }
}
```

### 4. Available Services

- **API.auth** - Authentication (login/logout)
- **API.user** - User management
- **API.teacher** - Teacher management
- **API.learner** - Learner management
- **API.classService** - Class management
- **API.classCategory** - Class category management
- **API.classSession** - Session management
- **API.enrollment** - Enrollment
- **API.review** - Reviews and ratings
- **API.notification** - Notifications
- **API.payment** - Payments
- **API.admin** - Admin system
- **API.ban** - Ban system

### 5. Token Management

Tokens are handled automatically:
- Saved after successful login
- Sent with all authenticated requests
- Removed on logout

### 6. Configuration

Update the base URL in `lib/services/api_config.dart`:
```dart
static const String baseUrl = 'http://xxx.xxx.xxx.xxx:port/api';
```

### 7. Important Models

- **User, Teacher, Learner** - User data
- **ClassModel, ClassCategory, ClassSession** - Class data
- **Enrollment** - Enrollment
- **Review** - Reviews and ratings
- **NotificationModel** - Notifications
- **PaymentRequest, Transaction** - Payments
- **Report** - Reporting
- **BanDetailsLearner, BanDetailsTeacher** - Ban details

### 8. Usage Tips

1. Always check login status before calling APIs:
```dart
final isLoggedIn = await API.auth.isLoggedIn();
```

2. Always use try-catch when calling APIs

3. Use loading states in the UI while waiting for API responses

4. Handle errors gracefully for better user experience
