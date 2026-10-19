import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/reservation_model.dart';
import '../../services/firestore_service.dart';
import '../../services/court_service.dart';
import '../../services/lcd_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/qr_image_decoder.dart';

class AdminQrScannerScreen extends StatefulWidget {
  final String? initialQrData;
  const AdminQrScannerScreen({super.key, this.initialQrData});

  @override
  State<AdminQrScannerScreen> createState() => _AdminQrScannerScreenState();
}

class _AdminQrScannerScreenState extends State<AdminQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQrData != null && widget.initialQrData!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleScannedData(widget.initialQrData!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _handleScannedData(rawValue);
        break;
      }
    }
  }

  Future<void> _handleScannedData(String rawData) async {
    setState(() {
      _isProcessing = true;
    });

    // Pause camera stream while displaying result
    await _controller.stop();

    // Extract reservation ID (handles format 'pickleball_reservation:<id>' or '<id>')
    String reservationId = rawData.trim();
    if (reservationId.startsWith('pickleball_reservation:')) {
      reservationId = reservationId.replaceFirst('pickleball_reservation:', '').trim();
    }

    // Lookup in Firestore / Realtime DB
    try {
      final reservations = await FirestoreService().getAllReservations().first;
      ReservationModel? matched;
      for (final r in reservations) {
        if (r.id == reservationId) {
          matched = r;
          break;
        }
      }

      if (mounted) {
        if (matched != null) {
          _showValidPassModal(matched);
        } else {
          _showInvalidPassModal(reservationId);
        }
      }
    } catch (e) {
      if (mounted) {
        _showInvalidPassModal(reservationId, errorMsg: e.toString());
      }
    }
  }

  void _showValidPassModal(ReservationModel reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        bool isCheckingIn = false;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final isConfirmed = reservation.status == 'confirmed' || reservation.status == 'active';

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF111115),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Verification Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isConfirmed
                            ? AppTheme.statusAvailable.withOpacity(0.15)
                            : AppTheme.statusReserved.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isConfirmed
                              ? AppTheme.statusAvailable.withOpacity(0.5)
                              : AppTheme.statusReserved.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isConfirmed
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded,
                            color: isConfirmed
                                ? AppTheme.statusAvailable
                                : AppTheme.statusReserved,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isConfirmed ? 'VALID ENTRANCE PASS' : 'RESERVATION ${reservation.status.toUpperCase()}',
                            style: TextStyle(
                              color: isConfirmed
                                  ? AppTheme.statusAvailable
                                  : AppTheme.statusReserved,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Player & Court Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        _detailRow(Icons.person_rounded, 'Player Name', reservation.userName),
                        const Divider(color: AppTheme.cardBorder, height: 20),
                        _detailRow(Icons.sports_tennis_rounded, 'Court', reservation.courtName),
                        const Divider(color: AppTheme.cardBorder, height: 20),
                        _detailRow(
                          Icons.calendar_month_rounded,
                          'Date & Time',
                          '${DateHelpers.toShortDate(DateTime.parse(reservation.date))} (${DateHelpers.toTimeRange(reservation.startTime, reservation.endTime)})',
                        ),
                        const Divider(color: AppTheme.cardBorder, height: 20),
                        _detailRow(
                          Icons.payment_rounded,
                          'Payment Status',
                          '₱${reservation.amount.toStringAsFixed(2)} • ${reservation.paymentMethod == 'paymongo' ? 'Paid via PayMongo (QR Ph)' : 'Paid'}',
                          valueColor: AppTheme.primary,
                        ),
                        if (reservation.paymentReference.isNotEmpty) ...[
                          const Divider(color: AppTheme.cardBorder, height: 20),
                          _detailRow(
                            Icons.receipt_rounded,
                            'Payment Ref',
                            reservation.paymentReference,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action: Check-in & Unlock Gate
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: isCheckingIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.background,
                              ),
                            )
                          : const Icon(Icons.how_to_reg_rounded, size: 20),
                      label: Text(
                        isCheckingIn ? 'Verifying Check-In...' : 'Verify & Check-In Player',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: isCheckingIn
                          ? null
                          : () async {
                              setSheetState(() => isCheckingIn = true);

                              // 1. Mark reservation as active/checked-in
                              await FirestoreService()
                                  .updateReservationStatus(reservation.id, 'active');

                              // 2. Unlock court in IoT Realtime DB
                              await CourtService().updateCourtStatus(
                                courtId: reservation.courtId,
                                isOccupied: true,
                                reservationId: reservation.id,
                                reservedByName: reservation.userName,
                                bookedUntil: reservation.endTime,
                              );

                              // 3. Log LCD check-in event so the Python bridge
                              //    can pick it up and update the Arduino LCD.
                              await LcdService.logCheckIn(
                                courtId: reservation.courtId,
                                playerName: reservation.userName,
                                endTime: reservation.endTime,
                              );

                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Player \${reservation.userName} checked in! LCD updated.',
                                    ),
                                    backgroundColor: AppTheme.statusAvailable,
                                  ),
                                );
                                _resumeCamera();
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Scan Another Button
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _resumeCamera();
                      },
                      child: const Text('Scan Another Pass'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInvalidPassModal(String scannedCode, {String? errorMsg}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF111115),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cancel_rounded, color: AppTheme.statusInUse, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Invalid QR Pass',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              errorMsg ?? 'No matching booking was found for scanned code:\n"$scannedCode"',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.background,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _resumeCamera();
                },
                child: const Text('Scan Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInputDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.keyboard_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Enter Pass ID / QR Code', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Type or paste the Reservation ID to verify:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. res_1786714213 or doc ID',
                prefixIcon: Icon(Icons.qr_code_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textCtrl.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(dialogCtx).pop();
                _handleScannedData(text);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndScanQr() async {
    setState(() => _isProcessing = true);
    try {
      final result = await QrImageDecoder.pickAndDecode();
      if (result.userCanceled) {
        setState(() => _isProcessing = false);
        return;
      }

      if (result.isSuccess) {
        await _handleScannedData(result.data!);
      } else {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.error ?? 'No valid QR code detected in image.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.statusInUse,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading QR code: $e'),
            backgroundColor: AppTheme.statusInUse,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _resumeCamera() {
    setState(() {
      _isProcessing = false;
    });
    _controller.start();
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan Player QR Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: AppTheme.primary),
            tooltip: 'Upload QR Image',
            onPressed: _isProcessing ? null : _uploadAndScanQr,
          ),
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white70),
            tooltip: 'Toggle Flashlight',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white70),
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_rounded, color: Colors.white70),
            tooltip: 'Enter Pass ID Manually',
            onPressed: _showManualInputDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera Feed ──
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ── Viewfinder Overlay ──
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primary, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Animated scan beam
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 2,
                      width: 240,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .slideY(begin: -2.0, end: 2.0, duration: 1800.ms, curve: Curves.easeInOut),
                ],
              ),
            ),
          ),

          // ── Bottom Instruction Bar ──
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111115).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Point camera at the customer\'s Check-In QR pass to verify payment and check-in',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _isProcessing ? null : _uploadAndScanQr,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: AppTheme.primary.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 16, color: AppTheme.primary),
                    label: const Text(
                      'Upload QR',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _showManualInputDialog,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Manual',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
        ],
      ),
    );
  }
}
