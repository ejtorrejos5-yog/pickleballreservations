import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/court_model.dart';
import '../../models/court_status_model.dart';
import '../../widgets/countdown_timer_widget.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../reservation/booking_screen.dart';

class CourtDetailScreen extends StatelessWidget {
  final CourtModel court;
  final CourtStatusModel status;
  final bool showReservedName;

  const CourtDetailScreen({
    super.key,
    required this.court,
    required this.status,
    this.showReservedName = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusType = status.statusType;
    final statusColor = _colorFor(statusType);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── App Bar ────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: Colors.transparent,
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: AppTheme.textPrimary, size: 20),
                  ),
                ),
                title: Text(court.name),
                pinned: true,
              ),
              // ── Body ──────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Status Card
                    _buildStatusCard(statusType, statusColor),
                    const SizedBox(height: 20),
                    // Countdown (if in use)
                    if (statusType == CourtStatusType.inUse &&
                        status.bookedUntil != null) ...[
                      _buildCountdownSection(context),
                      const SizedBox(height: 20),
                    ],
                    // Session Info (if reserved or in use)
                    if (showReservedName && status.reservedByName != null) ...[
                      _buildSessionInfo(),
                      const SizedBox(height: 20),
                    ],
                    // Court Info Card
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    // Book Button (Always visible so players can book other times/dates)
                    _buildBookButton(context),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(CourtStatusType type, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              type == CourtStatusType.available
                  ? Icons.check_circle_rounded
                  : type == CourtStatusType.reserved
                      ? Icons.schedule_rounded
                      : Icons.sports_tennis_rounded,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  type == CourtStatusType.available
                      ? 'Ready to book'
                      : type == CourtStatusType.reserved
                          ? 'Upcoming reservation'
                          : 'Session in progress',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.06, end: 0, duration: 400.ms);
  }

  Widget _buildCountdownSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard,
      child: Column(
        children: [
          const Text(
            'Session Countdown',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          CountdownTimerWidget(
            endTime: status.bookedUntil!,
            startTime: status.occupiedSince,
            size: 160,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 400.ms)
        .slideY(begin: 0.06, end: 0, delay: 100.ms, duration: 400.ms);
  }

  Widget _buildSessionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard,
      child: Column(
        children: [
          _infoRow(Icons.person_outlined, 'Reserved by', status.reservedByName!),
          if (status.bookedUntil != null) ...[
            const Divider(color: AppTheme.cardBorder, height: 20),
            _infoRow(
              Icons.access_time_rounded,
              'Session ends',
              DateHelpers.toTimeString(status.bookedUntil!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LPC Court Details',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            court.description.isNotEmpty
                ? court.description
                : 'Premium cushioned flooring pickleball court with professional tournament markings.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.location_on_outlined, 'Club Venue',
              'Lifestyle Pickleball Court (LPC)'),
          const Divider(color: AppTheme.cardBorder, height: 20),
          _infoRow(Icons.payments_outlined, 'Hourly Rate',
              '₱${court.pricePerHour.toStringAsFixed(0)} / hour slot',
              valueColor: AppTheme.primary),
          const Divider(color: AppTheme.cardBorder, height: 20),
          _infoRow(Icons.qr_code_scanner_rounded, 'Verification', 'QR Code Player Check-In'),
          const Divider(color: AppTheme.cardBorder, height: 20),
          _infoRow(Icons.schedule_rounded, 'Court Hours',
              '7:00 AM – 12:00 Midnight Daily'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBookButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookingScreen(court: court),
          ),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Book This Court'),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 400.ms);
  }

  Color _colorFor(CourtStatusType type) {
    switch (type) {
      case CourtStatusType.available:
        return AppTheme.statusAvailable;
      case CourtStatusType.reserved:
        return AppTheme.statusReserved;
      case CourtStatusType.inUse:
        return AppTheme.statusInUse;
    }
  }
}
