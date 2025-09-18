// README สำหรับการใช้งาน API Services
/*
# KU Tutorium API Services

## การติดตั้งและใช้งาน

### 1. Import ที่จำเป็น
```dart
import 'package:your_app/services/api_provider.dart';
import 'package:your_app/models/models.dart';
```

### 2. การใช้งานพื้นฐาน

#### การ Login
```dart
try {
  final loginRequest = LoginRequest(
    username: 'b6610505511',
    password: 'yourPassword',
    firstName: 'ชื่อ',
    lastName: 'นามสกุล',
    phoneNumber: '+66812345678',
    gender: 'Male',
  );

  final response = await API.auth.login(loginRequest);
  print('Login สำเร็จ: ${response.user.firstName}');
} catch (e) {
  print('Login ล้มเหลว: $e');
}
```

#### การดึงข้อมูลคลาสเรียน
```dart
// ดึงคลาสทั้งหมด
final classes = await API.classService.getClasses();

// ดึงคลาสด้วยฟิลเตอร์
final filteredClasses = await API.classService.getClasses(
  categories: ['Mathematics', 'Science'],
  minRating: 4.0,
  maxRating: 5.0,
);

// ดึงคลาสตาม ID
final classDetail = await API.classService.getClassById(1);
```

#### การลงทะเบียนเรียน
```dart
final enrollment = Enrollment(
  id: 0,
  learnerId: 42,
  classSessionId: 21,
  enrollmentStatus: 'active',
);

final result = await API.enrollment.createEnrollment(enrollment);
```

#### การสร้างรีวิว
```dart
final review = Review(
  id: 0,
  learnerId: 42,
  classId: 21,
  rating: 5,
  comment: 'คลาสดีมาก แนะนำเลย!',
);

await API.review.createReview(review);
```

#### การชำระเงิน
```dart
final payment = PaymentRequest(
  amount: 199900, // 1999 บาท (ในหน่วย satang)
  currency: 'THB',
  paymentType: 'credit_card',
  description: 'ค่าเรียน',
  userId: 5,
  token: 'omise_token_here',
);

final result = await API.payment.createCharge(payment);
```

### 3. การจัดการ Error

```dart
try {
  final result = await API.user.getUserById(1);
} catch (e) {
  if (e is ApiException) {
    switch (e.statusCode) {
      case 400:
        print('ข้อมูลไม่ถูกต้อง');
        break;
      case 401:
        print('กรุณาเข้าสู่ระบบใหม่');
        break;
      case 404:
        print('ไม่พบข้อมูล');
        break;
      case 500:
        print('เซิร์ฟเวอร์มีปัญหา');
        break;
    }
  }
}
```

### 4. Services ที่พร้อมใช้งาน

- **API.auth** - การเข้าสู่ระบบ/ออกจากระบบ
- **API.user** - จัดการข้อมูลผู้ใช้
- **API.teacher** - จัดการข้อมูลครู
- **API.learner** - จัดการข้อมูลนักเรียน
- **API.classService** - จัดการคลาสเรียน
- **API.classCategory** - จัดการหมวดหมู่คลาส
- **API.classSession** - จัดการรอบการเรียน
- **API.enrollment** - การลงทะเบียนเรียน
- **API.review** - รีวิวและคะแนน
- **API.notification** - การแจ้งเตือน
- **API.payment** - การชำระเงิน
- **API.admin** - ระบบแอดมิน
- **API.ban** - ระบบแบน

### 5. Token Management

Token จะถูกจัดการอัตโนมัติ:
- บันทึกหลังจาก login สำเร็จ
- ส่งไปกับทุก API request ที่ต้องการ auth
- ลบเมื่อ logout

### 6. การกำหนดค่า

แก้ไข base URL ใน `lib/services/api_config.dart`:
```dart
static const String baseUrl = 'http://65.108.156.197:8000';
```

### 7. Models ที่สำคัญ

- **User, Teacher, Learner** - ข้อมูลผู้ใช้
- **ClassModel, ClassCategory, ClassSession** - ข้อมูลคลาส
- **Enrollment** - การลงทะเบียน
- **Review** - รีวิวและคะแนน
- **NotificationModel** - การแจ้งเตือน
- **PaymentRequest, Transaction** - การชำระเงิน
- **Report** - การรายงาน
- **BanDetailsLearner, BanDetailsTeacher** - ระบบแบน

### 8. Tips การใช้งาน

1. ตรวจสอบสถานะ login ก่อนเรียก API:
```dart
final isLoggedIn = await API.auth.isLoggedIn();
```

2. ใช้ try-catch เสมอเมื่อเรียก API

3. ใช้ loading state ใน UI เมื่อรอ API response

4. จัดการ error ให้เหมาะสมกับ UX

*/
