import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/court_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/court_model.dart';
import '../../models/reservation_model.dart';
import '../../models/court_status_model.dart';
import '../../services/firestore_service.dart';
import '../../services/court_service.dart';
import 'admin_qr_scanner_screen.dart';
import 'admin_court_schedule_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_lcd_control_sheet.dart';
import '../../widgets/reschedule_dialog.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courts = context.watch<CourtProvider>().courts;
    final courtStatuses = context.watch<CourtProvider>().courtStatuses;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(context)),

            // ── Stats Row ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: _buildStats(courts, courtStatuses),
              ),
            ),

            // ── Quick Action: User Management ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminUserManagementScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.manage_accounts_rounded,
                              color: AppTheme.accent, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Players & Admins',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'View profiles, change roles, inspect bookings',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: AppTheme.textMuted, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Live Court Management ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Court Management',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          color: AppTheme.primary, size: 24),
                      onPressed: () => _showAddCourtDialog(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final court = courts[i];
                    final status =
                        context.read<CourtProvider>().statusFor(court.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AdminCourtCard(
                        court: court,
                        status: status,
                        index: i,
                      ),
                    );
                  },
                  childCount: courts.length,
                ),
              ),
            ),

            // ── Active Reservations ───────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  'Active Reservations',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder(
                stream: FirestoreService().getAllActiveReservations(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: AppTheme.primary),
                      ),
                    );
                  }
                  final reservations = snap.data!;
                  if (reservations.isEmpty) {
                    return const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        'No active reservations',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: reservations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final res = reservations[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: (res.status == 'pending'
                                      ? AppTheme.statusReserved
                                      : AppTheme.statusAvailable)
                                  .withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    res.courtName,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    res.userName,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (res.paymentMethod != 'none' && res.paymentMethod != '') ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${res.paymentMethod == 'paymongo' ? 'PayMongo (QR Ph)' : 'Manual GCash'}: ${res.paymentReference}',
                                      style: TextStyle(
                                        color: AppTheme.primary.withOpacity(0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  DateHelpers.toTimeRange(
                                      res.startTime, res.endTime),
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (res.status == 'pending'
                                            ? AppTheme.statusReserved
                                            : AppTheme.statusAvailable)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    res.status.toUpperCase(),
                                    style: TextStyle(
                                      color: res.status == 'pending'
                                          ? AppTheme.statusReserved
                                          : AppTheme.statusAvailable,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            if (res.status == 'pending') ...[
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline_rounded,
                                    color: AppTheme.statusAvailable, size: 22),
                                tooltip: 'Approve Payment',
                                onPressed: () =>
                                    _confirmApproveBooking(context, res),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined,
                                    color: AppTheme.statusInUse, size: 22),
                                tooltip: 'Decline Booking',
                                onPressed: () =>
                                    _confirmCancelBooking(context, res),
                              ),
                            ] else ...[
                              IconButton(
                                icon: const Icon(Icons.edit_calendar_rounded,
                                    color: AppTheme.primary, size: 20),
                                tooltip: 'Reschedule Booking',
                                onPressed: () =>
                                    RescheduleDialog.show(context, res),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined,
                                    color: AppTheme.statusInUse, size: 20),
                                tooltip: 'Cancel Booking',
                                onPressed: () =>
                                    _confirmCancelBooking(context, res),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/lpc_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF0D1A0D),
                  child: const Center(
                    child: Text('LPC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LPC Admin Console',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Lifestyle Pickleball Court • ${user?.name ?? 'Administrator'}',
                  style: const TextStyle(
                      color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_rounded, color: AppTheme.accent),
            tooltip: 'Manage Users',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminUserManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
            tooltip: 'Scan Player Entrance QR',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminQrScannerScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.statusInUse),
            tooltip: 'Sign Out',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStats(List<CourtModel> courts, Map<String, CourtStatusModel> statuses) {
    final available = courts
        .where((c) => statuses[c.id]?.statusType.label == 'Available')
        .length;
    final inUse = courts.length - available;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.sports_tennis_rounded,
            value: courts.length.toString(),
            label: 'Total Courts',
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            value: available.toString(),
            label: 'Available',
            color: AppTheme.statusAvailable,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.people_alt_outlined,
            value: inUse.toString(),
            label: 'In Use',
            color: AppTheme.statusInUse,
          ),
        ),
      ],
    );
  }
  void _showAddCourtDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '250');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Court'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Court Name (e.g. Court E)',
                  prefixIcon: Icon(Icons.sports_tennis),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a description'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price per Hour (₱)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  hintText: 'e.g. 250',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a price';
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              final court = CourtModel(
                id: '', // Service generates ID
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                isActive: true,
                pricePerHour: double.parse(priceCtrl.text.trim()),
              );
              await FirestoreService().addCourt(court);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Court added successfully')),
                );
              }
            },
            child: const Text('Add Court'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelBooking(BuildContext context, ReservationModel res) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text(
            'Cancel booking for ${res.userName} at ${res.courtName} (${DateHelpers.toTimeRange(res.startTime, res.endTime)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusInUse,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FirestoreService().cancelReservation(res.id);
              await CourtService().clearCourtStatus(res.courtId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking cancelled')),
              );
            },
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from the Admin account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusInUse,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              context.read<ReservationProvider>().clear();
              await context.read<AuthProvider>().signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _confirmApproveBooking(BuildContext context, ReservationModel res) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Booking'),
        content: Text(
            'Confirm payment and approve booking for ${res.userName} at ${res.courtName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusAvailable,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FirestoreService().updateReservationStatus(res.id, 'confirmed');
              await CourtService().updateCourtStatus(
                courtId: res.courtId,
                isOccupied: false,
                reservationId: res.id,
                reservedByName: res.userName,
                bookedUntil: res.endTime,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking approved successfully')),
              );
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.06, end: 0, duration: 400.ms);
  }
}

class _AdminCourtCard extends StatelessWidget {
  final CourtModel court;
  final CourtStatusModel status;
  final int index;

  const _AdminCourtCard({
    required this.court,
    required this.status,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = status.statusType.label;
    final statusColor = _colorForStatus(statusLabel);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminCourtScheduleScreen(
              court: court,
              status: status,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sports_tennis_rounded,
                  color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(court.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (status.reservedByName != null) ...[
                        Text(
                          status.reservedByName!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '₱${court.pricePerHour.toStringAsFixed(0)}/hr',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (status.bookedUntil != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Until ${DateHelpers.toTimeString(status.bookedUntil!)}',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
            IconButton(
              icon: const Icon(Icons.display_settings_rounded,
                  color: AppTheme.primary, size: 18),
              tooltip: 'LCD Display Control',
              onPressed: () => AdminLcdControlSheet.show(
                context,
                court: court,
                status: status,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppTheme.textSecondary, size: 18),
              tooltip: 'Edit Court',
              onPressed: () => _showEditCourtDialog(context),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: index * 60), duration: 400.ms)
        .slideX(
            begin: 0.05,
            end: 0,
            delay: Duration(milliseconds: index * 60),
            duration: 400.ms);
  }

  void _showEditCourtDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: court.name);
    final descCtrl = TextEditingController(text: court.description);
    final priceCtrl = TextEditingController(
        text: court.pricePerHour.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Edit ${court.name}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Court Name',
                  prefixIcon: Icon(Icons.sports_tennis),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a description'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price per Hour (₱)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  hintText: 'e.g. 250',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a price';
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              final updated = court.copyWith(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                pricePerHour: double.parse(priceCtrl.text.trim()),
              );
              await FirestoreService().updateCourt(updated);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${updated.name} updated — ₱${updated.pricePerHour.toStringAsFixed(0)}/hr'),
                  ),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'Available':
        return AppTheme.statusAvailable;
      case 'Reserved':
        return AppTheme.statusReserved;
      case 'In Use':
        return AppTheme.statusInUse;
      default:
        return AppTheme.textMuted;
    }
  }
}

