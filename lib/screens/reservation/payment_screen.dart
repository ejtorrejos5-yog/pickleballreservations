import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/court_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/constants/app_constants.dart';
import '../../services/paymongo_service.dart';
import 'receipt_screen.dart';

class PaymentScreen extends StatefulWidget {
  final CourtModel court;
  final DateTime date;
  final Set<DateTime> slots;

  const PaymentScreen({
    super.key,
    required this.court,
    required this.date,
    required this.slots,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymongoService _paymongoService = PaymongoService();
  Timer? _statusTimer;

  bool _isLoadingLink = true;
  bool _isProcessingBooking = false;
  bool _isPaymentLaunched = false;
  String? _paymongoLinkId;
  String? _checkoutUrl;
  String? _referenceNumber;
  String? _errorMessage;

  double get _pricePerSlot => widget.court.pricePerHour;
  double get _totalAmount => widget.slots.length * _pricePerSlot;

  @override
  void initState() {
    super.initState();
    _initiatePayment();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _isLoadingLink = true;
      _errorMessage = null;
    });

    final sorted = widget.slots.toList()..sort();
    final timeStr = widget.slots.length == 1
        ? DateHelpers.toTimeString(sorted.first)
        : '${DateHelpers.toTimeString(sorted.first)} – ${DateHelpers.toTimeString(sorted.last.add(const Duration(minutes: AppConstants.slotDurationMinutes)))}';

    final description =
        'Pickleball Booking: ${widget.court.name} ($timeStr) on ${DateHelpers.toShortDate(widget.date)}';

    final result = await _paymongoService.createPaymentLink(
      amount: _totalAmount,
      description: description,
    );

    if (result == null) {
      if (mounted) {
        setState(() {
          _isLoadingLink = false;
          _errorMessage = kIsWeb
              ? 'Could not connect to PayMongo.\n\nRun the web launcher to auto-start everything:\n  .\\run_web.ps1\n\nOR manually start the proxy:\n  dart run bin/cors_proxy.dart'
              : 'Could not connect to PayMongo. Please check your internet connection and try again.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _paymongoLinkId = result['id'];
        _checkoutUrl = result['checkoutUrl'];
        _referenceNumber = result['referenceNumber'];
        _isLoadingLink = false;
      });

      // Automatically launch PayMongo checkout
      _launchCheckoutUrl();
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_paymongoLinkId == null) return;

      final status =
          await _paymongoService.checkPaymentStatus(_paymongoLinkId!);
      if (status == 'paid') {
        _statusTimer?.cancel();
        if (mounted) {
          _completeBooking();
        }
      }
    });
  }

  Future<void> _launchCheckoutUrl() async {
    if (_checkoutUrl == null) return;
    final uri = Uri.parse(_checkoutUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        setState(() => _isPaymentLaunched = true);
        // Start polling after launching
        _startStatusPolling();
      }
    } else {
      if (mounted) {
        setState(() => _isPaymentLaunched = true);
        _startStatusPolling();
      }
    }
  }

  Future<void> _completeBooking() async {
    if (_isProcessingBooking) return; // prevent double-calls
    setState(() => _isProcessingBooking = true);

    try {
      final sorted = widget.slots.toList()..sort();
      final startTime = sorted.first;
      final endTime = sorted.last
          .add(const Duration(minutes: AppConstants.slotDurationMinutes));

      final authProvider = context.read<AuthProvider>();
      final resProvider = context.read<ReservationProvider>();
      final user = authProvider.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() => _isProcessingBooking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to complete your reservation.'),
              backgroundColor: AppTheme.statusInUse,
            ),
          );
        }
        return;
      }

      final ref = _referenceNumber ?? _paymongoLinkId ?? 'paymongo_ref';

      final createdRes = await resProvider.createReservation(
        court: widget.court,
        userId: user.uid,
        userName: user.name,
        date: widget.date,
        startTime: startTime,
        endTime: endTime,
        status: 'confirmed',
        paymentMethod: 'paymongo',
        paymentReference: ref,
        amount: _totalAmount,
      );

      if (createdRes != null) {
        if (mounted) {
          setState(() => _isProcessingBooking = false);
          // Direct route to Receipt & Entrance QR Screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ReceiptScreen(
                court: widget.court,
                reservation: createdRes,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isProcessingBooking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(resProvider.error ?? 'Failed to complete booking record.'),
              backgroundColor: AppTheme.statusInUse,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving reservation: $e'),
            backgroundColor: AppTheme.statusInUse,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = widget.slots.toList()..sort();
    final timeRange = DateHelpers.toTimeRange(
      sorted.first,
      sorted.last.add(const Duration(minutes: AppConstants.slotDurationMinutes)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('PayMongo Payment'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: _isProcessingBooking
            ? _buildProcessingState()
            : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Summary Card ───────────────────────────────────
                            _buildSummaryCard(timeRange),
                            const SizedBox(height: 20),
                            // ── Payment Status Section ─────────────────────────
                            _buildPaymentStatusSection(),
                          ],
                        ),
                      ),
                    ),
                    // ── Footer actions ───────────────────────────────
                    if (!_isLoadingLink && _errorMessage == null)
                      _buildFooterBar(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 20),
          const Text(
            'Payment confirmed!',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Creating your reservation and\ngenerating entrance QR code...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_rounded, color: AppTheme.primary, size: 20),
                SizedBox(width: 10),
                Text(
                  'Your check-in QR pass is being prepared',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSummaryCard(String timeRange) {
    final hours = widget.slots.length;
    final rate = widget.court.pricePerHour;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 18),
                  SizedBox(width: 8),
                  Text('Booking Summary',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
              Text(
                '₱${_totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22),
              ),
            ],
          ),
          const Divider(color: AppTheme.cardBorder, height: 24),
          _summaryRow(Icons.sports_tennis_rounded, 'Court', widget.court.name),
          const SizedBox(height: 10),
          _summaryRow(Icons.calendar_month_rounded, 'Date',
              DateHelpers.toShortDate(widget.date)),
          const SizedBox(height: 10),
          _summaryRow(Icons.schedule_rounded, 'Time', timeRange),
          const SizedBox(height: 10),
          _summaryRow(Icons.timer_outlined, 'Duration',
              '$hours hr${hours > 1 ? 's' : ''} (${hours * AppConstants.slotDurationMinutes} mins)'),
          const SizedBox(height: 10),
          _summaryRow(
            Icons.calculate_rounded,
            'Rate',
            '₱${rate.toStringAsFixed(0)}/hr × $hours hr${hours > 1 ? 's' : ''} = ₱${_totalAmount.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 10),
          _summaryRow(Icons.payment_rounded, 'Payment', 'PayMongo (QR Ph)'),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }


  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ',
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }

  Widget _buildPaymentStatusSection() {
    if (_isLoadingLink) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 14),
            Text(
              'Creating PayMongo payment link...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.glassCard,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.statusInUse.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppTheme.statusInUse,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cannot Connect to PayMongo',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'The app needs a local proxy to process payments on web.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1A0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.statusAvailable.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terminal_rounded,
                            color: AppTheme.statusAvailable, size: 14),
                        const SizedBox(width: 6),
                        const Text(
                          'Quick Fix — Run this once:',
                          style: TextStyle(
                            color: AppTheme.statusAvailable,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'dart run bin/cors_proxy.dart',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'OR double-click run_web.bat in the project folder',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _initiatePayment,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry Payment',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Payment link is ready — show waiting/redirected state
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard,
      child: Column(
        children: [
          // ── Status Icon ──
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
            ),
            child: const Icon(
              Icons.open_in_browser_rounded,
              color: AppTheme.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _isPaymentLaunched
                ? 'PayMongo Checkout Opened'
                : 'Ready to Pay',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            _isPaymentLaunched
                ? 'Complete your payment on the PayMongo checkout page.\nThis screen will automatically detect your payment.'
                : 'Tap the button below to open PayMongo checkout\nand complete your payment.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          if (_isPaymentLaunched) ...[
            const SizedBox(height: 24),
            // ── Polling indicator ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Waiting for payment confirmation...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_referenceNumber != null && _referenceNumber!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Text(
                'Ref: $_referenceNumber',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(color: AppTheme.cardBorder),
          const SizedBox(height: 16),

          // ── How it works ──
          const Text(
            'How it works:',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _stepItem('1', 'Pay via PayMongo checkout',
              'You will be redirected to PayMongo\'s secure payment page. Pay using GCash, Maya, or any QR Ph supported bank.'),
          const SizedBox(height: 10),
          _stepItem('2', 'Payment auto-detected',
              'Once your payment is confirmed, this app will automatically detect it.'),
          const SizedBox(height: 10),
          _stepItem('3', 'Receive check-in QR pass',
              'A unique QR pass is generated for check-in and payment verification when you arrive at the court.'),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _stepItem(String number, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary action: Open / Re-open PayMongo checkout
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _launchCheckoutUrl,
              icon: Icon(
                _isPaymentLaunched
                    ? Icons.refresh_rounded
                    : Icons.open_in_new_rounded,
                size: 18,
              ),
              label: Text(_isPaymentLaunched
                  ? 'Re-open PayMongo Checkout'
                  : 'Pay Now via PayMongo'),
            ),
          ),
          // Show verify button only after payment has been launched
          if (_isPaymentLaunched) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  if (_paymongoLinkId == null) return;
                  final status = await _paymongoService.checkPaymentStatus(
                    _paymongoLinkId!,
                  );
                  if (status == 'paid') {
                    _completeBooking();
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Payment not detected yet. Please complete payment on PayMongo first.'),
                          backgroundColor: AppTheme.statusReserved,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: AppTheme.primary),
                label: const Text(
                  'I Have Already Paid',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
