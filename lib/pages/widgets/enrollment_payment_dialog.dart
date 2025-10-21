import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/enrollment_with_payment_service.dart';
import 'package:tutorium_frontend/service/class_sessions.dart';
import 'package:tutorium_frontend/service/users.dart';

/// Dialog to confirm enrollment with payment details
class EnrollmentPaymentDialog extends StatefulWidget {
  final int learnerId;
  final int learnerUserId;
  final int classSessionId;
  final String className;
  final VoidCallback onEnrollmentSuccess;

  const EnrollmentPaymentDialog({
    super.key,
    required this.learnerId,
    required this.learnerUserId,
    required this.classSessionId,
    required this.className,
    required this.onEnrollmentSuccess,
  });

  @override
  State<EnrollmentPaymentDialog> createState() =>
      _EnrollmentPaymentDialogState();
}

class _EnrollmentPaymentDialogState extends State<EnrollmentPaymentDialog> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  double _price = 0;
  double _currentBalance = 0;
  bool _canAfford = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentInfo();
  }

  Future<void> _loadPaymentInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await ClassSession.fetchById(widget.classSessionId);
      final user = await User.fetchById(widget.learnerUserId);

      setState(() {
        _price = session.price;
        _currentBalance = user.balance;
        _canAfford = _currentBalance >= _price;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load payment info: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _processEnrollment() async {
    if (!_canAfford) {
      setState(() {
        _errorMessage = 'Insufficient balance. Please top up your account.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await EnrollmentWithPaymentService.enrollWithPayment(
        learnerId: widget.learnerId,
        learnerUserId: widget.learnerUserId,
        classSessionId: widget.classSessionId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onEnrollmentSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully enrolled! ฿${_price.toStringAsFixed(2)} transferred to teacher.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Confirm Enrollment',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class info
                  Text(
                    widget.className,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Payment details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Class Price',
                          '฿${_price.toStringAsFixed(2)}',
                          isHighlight: true,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          'Current Balance',
                          '฿${_currentBalance.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Balance After',
                          '฿${(_currentBalance - _price).toStringAsFixed(2)}',
                          color: _canAfford ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '100% payment to teacher',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Money will be transferred immediately. 100% refund if you cancel.',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _isProcessing || !_canAfford
              ? null
              : _processEnrollment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Enroll & Pay'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 15 : 14,
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: color ?? (isHighlight ? Colors.black : Colors.grey[800]),
          ),
        ),
      ],
    );
  }
}

/// Dialog to confirm enrollment cancellation with refund info
class CancelEnrollmentDialog extends StatefulWidget {
  final int enrollmentId;
  final int learnerUserId;
  final int classSessionId;
  final String className;
  final VoidCallback onCancellationSuccess;

  const CancelEnrollmentDialog({
    super.key,
    required this.enrollmentId,
    required this.learnerUserId,
    required this.classSessionId,
    required this.className,
    required this.onCancellationSuccess,
  });

  @override
  State<CancelEnrollmentDialog> createState() => _CancelEnrollmentDialogState();
}

class _CancelEnrollmentDialogState extends State<CancelEnrollmentDialog> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  double _refundAmount = 0;
  double _currentBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadRefundInfo();
  }

  Future<void> _loadRefundInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await ClassSession.fetchById(widget.classSessionId);
      final user = await User.fetchById(widget.learnerUserId);

      setState(() {
        _refundAmount = session.price;
        _currentBalance = user.balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load refund info: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _processCancellation() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await EnrollmentWithPaymentService.cancelWithRefund(
        enrollmentId: widget.enrollmentId,
        learnerUserId: widget.learnerUserId,
        classSessionId: widget.classSessionId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCancellationSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enrollment cancelled! ฿${_refundAmount.toStringAsFixed(2)} refunded (100%).',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Cancel Enrollment',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to cancel enrollment for:',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.className,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Refund details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[700],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '100% Refund Guaranteed',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[900],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You will receive full refund',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          'Refund Amount',
                          '฿${_refundAmount.toStringAsFixed(2)}',
                          isHighlight: true,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Current Balance',
                          '฿${_currentBalance.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Balance After',
                          '฿${(_currentBalance + _refundAmount).toStringAsFixed(2)}',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Keep Enrollment'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _isProcessing ? null : _processCancellation,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Cancel & Refund'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 15 : 14,
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: color ?? (isHighlight ? Colors.black : Colors.grey[800]),
          ),
        ),
      ],
    );
  }
}
