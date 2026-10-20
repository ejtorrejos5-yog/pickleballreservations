import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/court_model.dart';
import '../../models/court_status_model.dart';
import '../../models/reservation_model.dart';
import '../../providers/reservation_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/court_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/reschedule_dialog.dart';
import 'admin_walk_in_dialog.dart';

class AdminCourtScheduleScreen extends StatefulWidget {
  final CourtModel court;
  final CourtStatusModel status;

  const AdminCourtScheduleScreen({
    super.key,
    required this.court,
    required this.status,
  });

  @override
  State<AdminCourtScheduleScreen> createState() =>
      _AdminCourtScheduleScreenState();
}

class _AdminCourtScheduleScreenState extends State<AdminCourtScheduleScreen> {
  DateTime _selectedDay = DateTime.now();
  late CourtModel _court;
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _court = widget.court;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateHelpers.toFirestoreDate(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_court.name} Schedule'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF10B981)),
            tooltip: 'Book Walk-In for this Court',
            onPressed: () => AdminWalkInDialog.show(context, court: _court),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primary),
            tooltip: 'Edit Court Info',
            onPressed: () => _showEditCourtDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: StreamBuilder<List<ReservationModel>>(
          stream: context
              .read<ReservationProvider>()
              .getSlotReservations(_court.id, dateStr),
          builder: (context, snapshot) {
            final reservations = snapshot.data ?? [];
            final slots = DateHelpers.generateTimeSlots(
              date: _selectedDay,
              startHour: AppConstants.openingHour,
              endHour: AppConstants.closingHour,
            );

            final bookedSlotsMap = <DateTime, ReservationModel>{};
            for (final r in reservations) {
              if (r.status != 'cancelled') {
                var cur = r.startTime;
                while (cur.isBefore(r.endTime)) {
                  bookedSlotsMap[DateTime(
                      cur.year, cur.month, cur.day, cur.hour, cur.minute)] = r;
                  cur = cur.add(const Duration(minutes: 60));
                }
              }
            }

            int availableCount = 0;
            int bookedCount = 0;
            for (final slot in slots) {
              if (bookedSlotsMap.containsKey(slot)) {
                bookedCount++;
              } else if (!DateHelpers.isToday(_selectedDay) ||
                  !DateHelpers.slotHasPassed(slot)) {
                availableCount++;
              }
            }

            return CustomScrollView(
              slivers: [
                // ── Court Live Info Banner ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: _buildCourtBanner(),
                  ),
                ),

                // ── Date Selector Section ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildDateHeader(),
                  ),
                ),

                // ── Expandable Table Calendar ───────────────────────────
                if (_showCalendar)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: _buildCalendar(),
                    ),
                  ),

                // ── Quick Date Horizontal Strip ─────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 16),
                    child: _buildQuickDateStrip(),
                  ),
                ),

                // ── Slot Summary Counters ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSlotCounters(
                        slots.length, availableCount, bookedCount),
                  ),
                ),

                // ── Hourly Schedule Timeline / Grid ─────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  sliver: snapshot.connectionState == ConnectionState.waiting
                      ? const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(
                                  color: AppTheme.primary),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final slot = slots[i];
                              final reservation = bookedSlotsMap[slot];
                              final isPassed = DateHelpers.isToday(_selectedDay) &&
                                  DateHelpers.slotHasPassed(slot);

                              return _SlotTimelineTile(
                                slot: slot,
                                reservation: reservation,
                                isPassed: isPassed,
                                courtPrice: _court.pricePerHour,
                                onManageReservation: reservation != null
                                    ? () => _showReservationDetailsModal(
                                        context, reservation)
                                    : null,
                              );
                            },
                            childCount: slots.length,
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCourtBanner() {
    final statusColor = widget.status.statusType == CourtStatusType.available
        ? AppTheme.statusAvailable
        : widget.status.statusType == CourtStatusType.reserved
            ? AppTheme.statusReserved
            : AppTheme.statusInUse;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.sports_tennis_rounded,
                    color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _court.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _court.description.isNotEmpty
                          ? _court.description
                          : 'Lifestyle Pickleball Court (LPC)',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  widget.status.statusType.label.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.cardBorder, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  const Text(
                    'Hours: 7:00 AM – 12:00 Midnight',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              Text(
                '₱${_court.pricePerHour.toStringAsFixed(0)} / hr slot',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (widget.status.statusType == CourtStatusType.inUse &&
              widget.status.bookedUntil != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.statusInUse.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.statusInUse.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 16, color: AppTheme.statusInUse),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Active Session: ${widget.status.reservedByName ?? "Player"} until ${DateHelpers.toTimeString(widget.status.bookedUntil!)}',
                      style: const TextStyle(
                          color: AppTheme.statusInUse,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Court Time Slots & Date',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateHelpers.toDisplayDate(_selectedDay),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => setState(() => _showCalendar = !_showCalendar),
          icon: Icon(
            _showCalendar
                ? Icons.calendar_today_rounded
                : Icons.calendar_month_rounded,
            size: 16,
            color: AppTheme.primary,
          ),
          label: Text(
            _showCalendar ? 'Hide' : 'Pick Date',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: AppTheme.primary.withOpacity(0.12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: AppTheme.glassCard,
      padding: const EdgeInsets.all(8),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 30)),
        lastDay: DateTime.now().add(const Duration(days: 60)),
        focusedDay: _selectedDay,
        selectedDayPredicate: (d) => DateHelpers.isSameDay(d, _selectedDay),
        onDaySelected: (day, _) {
          setState(() {
            _selectedDay = day;
            _showCalendar = false;
          });
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15),
          leftChevronIcon:
              Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary),
          rightChevronIcon:
              Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
        ),
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w800),
          todayDecoration: BoxDecoration(
            color: Color(0x3000FF88),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
              color: AppTheme.primary, fontWeight: FontWeight.w700),
          defaultTextStyle: TextStyle(color: AppTheme.textPrimary),
          weekendTextStyle: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildQuickDateStrip() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 14,
        itemBuilder: (ctx, i) {
          final date = DateTime.now().add(Duration(days: i));
          final isSelected = DateHelpers.isSameDay(date, _selectedDay);

          String label;
          if (i == 0) {
            label = 'Today';
          } else if (i == 1) {
            label = 'Tomorrow';
          } else {
            label = DateHelpers.toMonthDay(date);
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = date),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.cardBorder,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.black
                        : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotCounters(int total, int available, int booked) {
    return Row(
      children: [
        _miniStat('Total Slots', total.toString(), AppTheme.textSecondary),
        const SizedBox(width: 8),
        _miniStat(
            'Available', available.toString(), AppTheme.statusAvailable),
        const SizedBox(width: 8),
        _miniStat('Booked', booked.toString(), AppTheme.statusReserved),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Text(
              value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  void _showReservationDetailsModal(
      BuildContext context, ReservationModel res) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(top: BorderSide(color: AppTheme.cardBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reservation Details',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: res.status == 'confirmed'
                        ? AppTheme.statusAvailable.withOpacity(0.15)
                        : AppTheme.statusReserved.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    res.status.toUpperCase(),
                    style: TextStyle(
                      color: res.status == 'confirmed'
                          ? AppTheme.statusAvailable
                          : AppTheme.statusReserved,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _modalRow(Icons.person_rounded, 'Player Name', res.userName),
            _modalRow(Icons.sports_tennis_rounded, 'Court', res.courtName),
            _modalRow(
              Icons.schedule_rounded,
              'Time Slot',
              DateHelpers.toTimeRange(res.startTime, res.endTime),
            ),
            _modalRow(
              Icons.calendar_today_rounded,
              'Date',
              DateHelpers.toDisplayDate(res.startTime),
            ),
            if (res.amount > 0)
              _modalRow(
                Icons.payments_rounded,
                'Amount Paid',
                '₱${res.amount.toStringAsFixed(0)} via ${res.paymentMethod.toUpperCase()}',
              ),
            if (res.paymentReference.isNotEmpty)
              _modalRow(
                Icons.tag_rounded,
                'Reference',
                res.paymentReference,
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.background,
                    ),
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: const Text('Reschedule'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      RescheduleDialog.show(context, res);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.statusInUse,
                      side: const BorderSide(color: AppTheme.statusInUse),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await FirestoreService().cancelReservation(res.id);
                      await CourtService().clearCourtStatus(res.courtId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Reservation cancelled')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCourtDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: _court.name);
    final descCtrl = TextEditingController(text: _court.description);
    final priceCtrl = TextEditingController(
        text: _court.pricePerHour.toStringAsFixed(0));
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
                'Edit ${_court.name}',
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
              final updated = _court.copyWith(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                pricePerHour: double.parse(priceCtrl.text.trim()),
              );
              await FirestoreService().updateCourt(updated);
              setState(() => _court = updated);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Court updated successfully')),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _SlotTimelineTile extends StatelessWidget {
  final DateTime slot;
  final ReservationModel? reservation;
  final bool isPassed;
  final double courtPrice;
  final VoidCallback? onManageReservation;

  const _SlotTimelineTile({
    required this.slot,
    required this.reservation,
    required this.isPassed,
    required this.courtPrice,
    this.onManageReservation,
  });

  @override
  Widget build(BuildContext context) {
    final endTime = slot.add(const Duration(minutes: 60));
    final isBooked = reservation != null;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isBooked) {
      if (reservation!.isActive) {
        statusColor = AppTheme.statusInUse;
        statusText = 'In Use';
        statusIcon = Icons.sports_tennis_rounded;
      } else {
        statusColor = AppTheme.statusReserved;
        statusText = 'Reserved';
        statusIcon = Icons.schedule_rounded;
      }
    } else if (isPassed) {
      statusColor = AppTheme.textMuted;
      statusText = 'Passed';
      statusIcon = Icons.history_rounded;
    } else {
      statusColor = AppTheme.statusAvailable;
      statusText = 'Available';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return GestureDetector(
      onTap: isBooked ? onManageReservation : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isBooked
                ? statusColor.withOpacity(0.5)
                : AppTheme.cardBorder,
            width: isBooked ? 1.5 : 1.0,
          ),
          boxShadow: isBooked
              ? [
                  BoxShadow(
                    color: statusColor.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Time Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    DateHelpers.toTimeString(slot),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    DateHelpers.toTimeString(endTime),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (isBooked) ...[
                    Text(
                      reservation!.userName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '₱${reservation!.amount > 0 ? reservation!.amount.toStringAsFixed(0) : courtPrice.toStringAsFixed(0)} • Tap for booking details',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ] else ...[
                    Text(
                      isPassed
                          ? 'Past time slot'
                          : 'Open for player reservation (₱${courtPrice.toStringAsFixed(0)}/hr)',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (isBooked)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_outline_rounded,
                    size: 16, color: statusColor),
              ),
          ],
        ),
      ),
    );
  }
}
