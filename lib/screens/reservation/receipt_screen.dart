import 'package:flutter/material.dart';
import '../../models/court_model.dart';
import '../../models/reservation_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/qr_downloader.dart';

class ReceiptScreen extends StatefulWidget {
  final CourtModel court;
  final ReservationModel reservation;

  const ReceiptScreen({
    super.key,
    required this.court,
    required this.reservation,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _isDownloading = false;

  Future<void> _downloadQr(String qrUrl) async {
    setState(() => _isDownloading = true);
    final fileName = 'court_entrance_qr_${widget.reservation.id}.png';

    final success = await QrDownloader.downloadQrImage(
      qrUrl: qrUrl,
      fileName: fileName,
    );

    if (mounted) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'QR Code downloaded successfully!'
                : 'Failed to download QR code. Please try again.',
          ),
          backgroundColor:
              success ? AppTheme.statusAvailable : AppTheme.statusInUse,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData = 'pickleball_reservation:${widget.reservation.id}';
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=400x400&color=ff9900&bgcolor=1a1a1a&data=$qrData';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/lpc_logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 8),
            const Text('LPC Booking Receipt'),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Success Header ───────────────────────────────────────────
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primary,
                  size: 64,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your reservation is locked and confirmed.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ── Entrance QR Code Card ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.glassCard,
                  child: Column(
                    children: [
                      const Text(
                        'PLAYER CHECK-IN QR PASS',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            qrUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Download QR Code Button ──────────────────────────────
                      SizedBox(
                        width: 220,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppTheme.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : const Icon(Icons.download_rounded,
                                  size: 20, color: AppTheme.primary),
                          label: Text(
                            _isDownloading ? 'Downloading...' : 'Download QR Code',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          onPressed:
                              _isDownloading ? null : () => _downloadQr(qrUrl),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Scan this QR code at the IoT entrance scanner to open the gate and enter the court.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Receipt Details Card ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.glassCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt Summary',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const Divider(color: AppTheme.cardBorder, height: 24),
                      _receiptRow('Venue', 'Lifestyle Pickleball Court (LPC)'),
                      _receiptRow('Court', widget.court.name),
                      _receiptRow('Date',
                          DateHelpers.toShortDate(DateTime.parse(widget.reservation.date))),
                      _receiptRow(
                          'Time',
                          DateHelpers.toTimeRange(
                              widget.reservation.startTime, widget.reservation.endTime)),
                      _receiptRow('Amount Paid',
                          '₱${widget.reservation.amount.toStringAsFixed(2)}'),
                      _receiptRow('Payment Method', 'PayMongo (QR Ph)'),
                      _receiptRow('Reference ID', widget.reservation.paymentReference),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Done Button ──────────────────────────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
