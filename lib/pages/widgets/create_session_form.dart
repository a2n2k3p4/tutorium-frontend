import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/class_sessions.dart';
import 'package:tutorium_frontend/util/schedule_validator.dart';
import 'package:tutorium_frontend/pages/widgets/schedule_conflict_dialog.dart';

/// Form สำหรับสร้าง Class Session พร้อมตรวจสอบเวลาทับกัน
class CreateSessionForm extends StatefulWidget {
  final int classId;
  final int teacherId;
  final Function(ClassSession)? onSessionCreated;

  const CreateSessionForm({
    super.key,
    required this.classId,
    required this.teacherId,
    this.onSessionCreated,
  });

  @override
  State<CreateSessionForm> createState() => _CreateSessionFormState();
}

class _CreateSessionFormState extends State<CreateSessionForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _learnerLimitController = TextEditingController();

  DateTime? _classStart;
  DateTime? _classFinish;
  DateTime? _enrollmentDeadline;
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _learnerLimitController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (isStartTime) {
            _classStart = selectedDateTime;
          } else {
            _classFinish = selectedDateTime;
          }
        });
      }
    }
  }

  Future<void> _selectEnrollmentDeadline(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: _classStart ?? DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          _enrollmentDeadline = selectedDateTime;
        });
      }
    }
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_classStart == null ||
        _classFinish == null ||
        _enrollmentDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันและเวลาให้ครบถ้วน')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. ตรวจสอบเวลาทับกันก่อน
      final validationResult =
          await ScheduleValidator.validateBeforeCreateSession(
            teacherId: widget.teacherId,
            classStart: _classStart!,
            classFinish: _classFinish!,
          );

      if (!validationResult['valid']) {
        // แสดง dialog เวลาทับกัน
        if (mounted) {
          ScheduleConflictDialog.show(
            context,
            message: validationResult['message'] ?? 'พบเวลาทับกัน',
            conflictSessions: validationResult['conflictSessions'],
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. สร้าง session
      final newSession = ClassSession(
        id: 0,
        createdAt: '',
        updatedAt: '',
        classId: widget.classId,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        learnerLimit: int.parse(_learnerLimitController.text),
        enrollmentDeadline: _enrollmentDeadline!.toIso8601String(),
        classStart: _classStart!.toIso8601String(),
        classFinish: _classFinish!.toIso8601String(),
        classStatus: 'scheduled',
        classUrl: '',
      );

      final createdSession = await ClassSession.create(newSession);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('สร้าง Class Session สำเร็จ!')),
        );
        widget.onSessionCreated?.call(createdSession);
        Navigator.of(context).pop(createdSession);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้าง Class Session')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'คำอธิบาย',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกคำอธิบาย';
                }
                return null;
              },
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Price
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'ราคา (บาท)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกราคา';
                }
                if (double.tryParse(value) == null) {
                  return 'กรุณากรอกตัวเลข';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Learner Limit (จำกัดไม่เกิน 20 คน)
            TextFormField(
              controller: _learnerLimitController,
              decoration: const InputDecoration(
                labelText: 'จำนวนที่รับ (สูงสุด 20 คน)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
                helperText: 'จำกัดไม่เกิน 20 คนต่อ session',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกจำนวนที่รับ';
                }
                final limit = int.tryParse(value);
                if (limit == null) {
                  return 'กรุณากรอกตัวเลข';
                }
                if (limit <= 0) {
                  return 'จำนวนต้องมากกว่า 0';
                }
                if (limit > 20) {
                  return 'จำนวนไม่สามารถเกิน 20 คนต่อ session';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Class Start Time
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('เวลาเริ่มคลาส'),
                subtitle: Text(
                  _classStart != null
                      ? ScheduleValidator.formatDateTime(_classStart!)
                      : 'กรุณาเลือกเวลา',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDateTime(context, true),
              ),
            ),
            const SizedBox(height: 8),

            // Class Finish Time
            Card(
              child: ListTile(
                leading: const Icon(Icons.stop),
                title: const Text('เวลาจบคลาส'),
                subtitle: Text(
                  _classFinish != null
                      ? ScheduleValidator.formatDateTime(_classFinish!)
                      : 'กรุณาเลือกเวลา',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDateTime(context, false),
              ),
            ),
            const SizedBox(height: 8),

            // Enrollment Deadline
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('เวลาปิดรับสมัคร'),
                subtitle: Text(
                  _enrollmentDeadline != null
                      ? ScheduleValidator.formatDateTime(_enrollmentDeadline!)
                      : 'กรุณาเลือกเวลา',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectEnrollmentDeadline(context),
              ),
            ),
            const SizedBox(height: 24),

            // Create Button
            ElevatedButton(
              onPressed: _isLoading ? null : _createSession,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('สร้าง Class Session'),
            ),
          ],
        ),
      ),
    );
  }
}
