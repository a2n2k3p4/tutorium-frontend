import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/users.dart' as user_api;
import 'package:tutorium_frontend/util/cache_user.dart';

/// UserStreamBuilder - Widget สำหรับ listen การเปลี่ยนแปลงของ user data
/// อัพเดท UI อัตโนมัติเมื่อข้อมูล user เปลี่ยน (เช่น balance, teacher status)
///
/// ตัวอย่างการใช้งาน:
/// ```dart
/// UserStreamBuilder(
///   builder: (context, user) {
///     if (user == null) {
///       return Text('Not logged in');
///     }
///     return Text('Balance: ${user.balance}');
///   },
/// )
/// ```
class UserStreamBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, user_api.User? user) builder;
  final Widget? loadingWidget;

  const UserStreamBuilder({
    super.key,
    required this.builder,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<user_api.User?>(
      stream: UserCache().userStream,
      initialData: UserCache().user,
      builder: (context, snapshot) {
        // ถ้ากำลังรอข้อมูล (แต่ไม่ควรเกิดเพราะมี initialData)
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }

        // Build UI ด้วยข้อมูล user ล่าสุด
        return builder(context, snapshot.data);
      },
    );
  }
}

/// UserBalanceText - Widget สำหรับแสดงยอดเงินที่อัพเดทอัตโนมัติ
class UserBalanceText extends StatelessWidget {
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const UserBalanceText({
    super.key,
    this.style,
    this.prefix = '',
    this.suffix = ' THB',
  });

  @override
  Widget build(BuildContext context) {
    return UserStreamBuilder(
      builder: (context, user) {
        final balance = user?.balance ?? 0.0;
        return Text(
          '$prefix${balance.toStringAsFixed(2)}$suffix',
          style: style,
        );
      },
    );
  }
}

/// UserRoleChecker - Widget สำหรับแสดง UI ต่างๆ ตาม role
class UserRoleChecker extends StatelessWidget {
  final Widget Function(BuildContext context)? teacherBuilder;
  final Widget Function(BuildContext context)? learnerBuilder;
  final Widget Function(BuildContext context)? bothBuilder;
  final Widget Function(BuildContext context)? noneBuilder;

  const UserRoleChecker({
    super.key,
    this.teacherBuilder,
    this.learnerBuilder,
    this.bothBuilder,
    this.noneBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return UserStreamBuilder(
      builder: (context, user) {
        if (user == null) {
          return noneBuilder?.call(context) ?? const SizedBox.shrink();
        }

        final hasTeacher = user.teacher != null;
        final hasLearner = user.learner != null;

        if (hasTeacher && hasLearner && bothBuilder != null) {
          return bothBuilder!(context);
        } else if (hasTeacher && teacherBuilder != null) {
          return teacherBuilder!(context);
        } else if (hasLearner && learnerBuilder != null) {
          return learnerBuilder!(context);
        } else {
          return noneBuilder?.call(context) ?? const SizedBox.shrink();
        }
      },
    );
  }
}
