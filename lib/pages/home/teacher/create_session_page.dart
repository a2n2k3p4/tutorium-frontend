import 'package:flutter/material.dart';
import 'package:tutorium_frontend/models/models.dart';
import 'package:tutorium_frontend/pages/widgets/class_session_service.dart';
import 'package:tutorium_frontend/util/schedule_validator.dart';

class CreateSessionPage extends StatefulWidget {
  final ClassModel classModel;

  const CreateSessionPage({super.key, required this.classModel});

  @override
  State<CreateSessionPage> createState() => _CreateSessionPageState();
}

class _CreateSessionPageState extends State<CreateSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _learnerLimitController = TextEditingController();

  DateTime _selectedStartDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedStartTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _selectedEndDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedEndTime = const TimeOfDay(hour: 12, minute: 0);
  DateTime _enrollmentDeadline = DateTime.now().add(const Duration(hours: 12));

  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _learnerLimitController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _selectedStartDate : _selectedEndDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _selectedStartTime : _selectedEndTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartTime = picked;
        } else {
          _selectedEndTime = picked;
        }
      });
    }
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final startDateTime = _combineDateTime(
      _selectedStartDate,
      _selectedStartTime,
    );
    final endDateTime = _combineDateTime(_selectedEndDate, _selectedEndTime);

    // Validate times
    if (endDateTime.isBefore(startDateTime) ||
        endDateTime.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_enrollmentDeadline.isAfter(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enrollment deadline must be before class start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Check for teacher schedule conflicts
    final validationResult =
        await ScheduleValidator.validateBeforeCreateSession(
          teacherId: widget.classModel.teacherId,
          classStart: startDateTime,
          classFinish: endDateTime,
        );

    if (!validationResult['valid']) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationResult['message'] ?? 'พบเวลาทับกัน'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    try {
      // Convert to UTC and format properly for backend
      // Backend expects: "2025-09-05T16:00:00Z"
      final startUtc = startDateTime.toUtc();
      final endUtc = endDateTime.toUtc();
      final deadlineUtc = _enrollmentDeadline.toUtc();

      // Ensure ISO8601 format with Z suffix
      String formatDateTime(DateTime dt) {
        final iso = dt.toIso8601String();
        return iso.endsWith('Z') ? iso : '${iso}Z';
      }

      final sessionData = {
        'class_id': widget.classModel.id,
        'class_start': formatDateTime(startUtc),
        'class_finish': formatDateTime(endUtc),
        'enrollment_deadline': formatDateTime(deadlineUtc),
        'class_status': 'Scheduled',
        'description': _descriptionController.text.trim(),
        'learner_limit': int.parse(_learnerLimitController.text),
        'price': double.parse(_priceController.text),
      };

      debugPrint('📤 Creating session with data: $sessionData');
      await ClassSessionService.createSession(sessionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating session: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Create Session',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Class Info Card
                _buildClassInfoCard(),
                const SizedBox(height: 24),

                // Description
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Session Description',
                  icon: Icons.description,
                  hint: 'e.g., Week 1: Introduction to Python',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter session description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Start Date & Time
                _buildDateTimePicker(
                  'Start Date & Time',
                  _selectedStartDate,
                  _selectedStartTime,
                  true,
                ),
                const SizedBox(height: 20),

                // End Date & Time
                _buildDateTimePicker(
                  'End Date & Time',
                  _selectedEndDate,
                  _selectedEndTime,
                  false,
                ),
                const SizedBox(height: 20),

                // Enrollment Deadline
                _buildEnrollmentDeadlinePicker(),
                const SizedBox(height: 20),

                // Price & Learner Limit
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _priceController,
                        label: 'Price (฿)',
                        icon: Icons.attach_money,
                        hint: '0',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price < 0) {
                            return 'Invalid price';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _learnerLimitController,
                        label: 'Max Students',
                        icon: Icons.people,
                        hint: '30',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final limit = int.tryParse(value);
                          if (limit == null || limit < 1) {
                            return 'Must be > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Create Button
                _buildCreateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Creating session for:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            widget.classModel.className,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.classModel.rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.blue[700], size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePicker(
    String label,
    DateTime date,
    TimeOfDay time,
    bool isStart,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 2, child: _buildDateButton(date, isStart)),
            const SizedBox(width: 12),
            Expanded(child: _buildTimeButton(time, isStart)),
          ],
        ),
      ],
    );
  }

  Widget _buildDateButton(DateTime date, bool isStart) {
    return InkWell(
      onTap: () => _selectDate(context, isStart),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
            const SizedBox(width: 8),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(TimeOfDay time, bool isStart) {
    return InkWell(
      onTap: () => _selectTime(context, isStart),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, color: Colors.blue[700], size: 20),
            const SizedBox(width: 8),
            Text(time.format(context), style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollmentDeadlinePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enrollment Deadline',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _enrollmentDeadline,
              firstDate: DateTime.now(),
              lastDate: _selectedStartDate,
            );
            if (!mounted) return;
            if (picked != null) {
              final timePicked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_enrollmentDeadline),
              );
              if (!mounted) return;
              if (timePicked != null) {
                setState(() {
                  _enrollmentDeadline = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    timePicked.hour,
                    timePicked.minute,
                  );
                });
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available,
                  color: Colors.orange[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDateTime(_enrollmentDeadline),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _createSession,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle, size: 24),
                SizedBox(width: 8),
                Text(
                  'Create Session',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
