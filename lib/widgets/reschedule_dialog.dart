import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/court_model.dart';
import '../models/reservation_model.dart';
import '../providers/court_provider.dart';
import '../providers/reservation_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_helpers.dart';
import '../core/constants/app_constants.dart';

class RescheduleDialog extends StatefulWidget {
  final ReservationModel reservation;

  const RescheduleDialog({super.key, required this.reservation});

  static Future<bool?> show(BuildContext context, ReservationModel reservation) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RescheduleDialog(reservation: reservation),
    );
  }

  @override
  State<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<RescheduleDialog> {
  late DateTime _selectedDate;
  late String _selectedCourtId;
  late String _selectedCourtName;
  final Set<DateTime> _selectedSlots = {};
  List<ReservationModel> _dayReservations = [];
  StreamSubscription<List<ReservationModel>>? _resSub;
  bool _isSubmitting = false;

  int get _requiredSlotCount {
    final mins = widget.reservation.durationMinutes;
    final count = (mins / AppConstants.slotDurationMinutes).round();
    return count > 0 ? count : 1;
  }

  @override
  void initState() {
    super.initState();
    _selectedCourtId = widget.reservation.courtId;
    _selectedCourtName = widget.reservation.courtName;
    _selectedDate = DateTime.now().isAfter(widget.reservation.startTime)
        ? DateTime.now()
        : DateTime(
            widget.reservation.startTime.year,
            widget.reservation.startTime.month,
            widget.reservation.startTime.day,
          );
    _listenToReservations();
  }

  @override
  void dispose() {
    _resSub?.cancel();
    super.dispose();
  }

  void _listenToReservations() {
    _resSub?.cancel();
    final dateStr = DateHelpers.toFirestoreDate(_selectedDate);
    _resSub = context
        .read<ReservationProvider>()
        .getSlotReservations(_selectedCourtId, dateStr)
        .listen((res) {
      if (mounted) {
        setState(() {
          // Exclude the current reservation being rescheduled
          _dayReservations =
              res.where((r) => r.id != widget.reservation.id).toList();
        });
      }
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedSlots.clear();
    });
    _listenToReservations();
  }

  void _onCourtSelected(CourtModel court) {
    setState(() {
      _selectedCourtId = court.id;
      _selectedCourtName = court.name;
      _selectedSlots.clear();
    });
    _listenToReservations();
  }

  void _onSlotTap(DateTime slot) {
    final slotsNeeded = _requiredSlotCount;
    final candidateSlots = <DateTime>{};

    for (int i = 0; i < slotsNeeded; i++) {
      final s = slot.add(Duration(minutes: i * AppConstants.slotDurationMinutes));
      final isBooked = _bookedStartTimes.contains(s);
      final isPast =
          DateHelpers.slotHasPassed(s) && DateHelpers.isToday(_selectedDate);
      if (isBooked || isPast || s.hour >= AppConstants.closingHour) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cannot select this time. Need $slotsNeeded consecutive available slot(s).'),
            backgroundColor: AppTheme.statusReserved,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      candidateSlots.add(s);
    }

    setState(() {
      _selectedSlots.clear();
      _selectedSlots.addAll(candidateSlots);
    });
  }

  List<DateTime> get _bookedStartTimes =>
      _dayReservations.map((r) => r.startTime).toList();

  Future<void> _submitReschedule() async {
    if (_selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a new time slot'),
          backgroundColor: AppTheme.statusReserved,
        ),
      );
      return;
    }

    final sorted = _selectedSlots.toList()..sort();
    final newStart = sorted.first;
    final newEnd = sorted.last
        .add(const Duration(minutes: AppConstants.slotDurationMinutes));
    final newDateStr = DateHelpers.toFirestoreDate(_selectedDate);

    setState(() => _isSubmitting = true);

    final success = await context.read<ReservationProvider>().rescheduleReservation(
          reservation: widget.reservation,
          newCourtId: _selectedCourtId,
          newCourtName: _selectedCourtName,
          newDate: newDateStr,
          newStartTime: newStart,
          newEndTime: newEnd,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Booking rescheduled to ${DateHelpers.toShortDate(_selectedDate)} (${DateHelpers.toTimeRange(newStart, newEnd)})',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.card,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reschedule. Please try again.'),
            backgroundColor: AppTheme.statusInUse,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courts = context.watch<CourtProvider>().courts;
    final sortedSlots = _selectedSlots.toList()..sort();
    final hasSelection = sortedSlots.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.cardBorder, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_calendar_rounded,
                      color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reschedule Booking',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Pick a new date or time (No extra charge)',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.cardBorder, height: 1),

          // ── Scrollable Body ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Original Booking Banner ──
                  _buildOriginalBookingBanner(),
                  const SizedBox(height: 20),

                  // ── Court Selector (if multiple courts) ──
                  if (courts.length > 1) ...[
                    _buildSectionHeader(
                        Icons.sports_tennis_rounded, 'Select Court'),
                    const SizedBox(height: 10),
                    _buildCourtSelector(courts),
                    const SizedBox(height: 20),
                  ],

                  // ── Date Selector ──
                  _buildSectionHeader(
                      Icons.calendar_month_rounded, 'Select New Date'),
                  const SizedBox(height: 10),
                  _buildDateSelector(),
                  const SizedBox(height: 20),

                  // ── Time Slot Picker ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(
                          Icons.access_time_rounded, 'Select New Time Slot'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Text(
                          'Duration: ${widget.reservation.durationMinutes} mins',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTimeSlotGrid(),
                  const SizedBox(height: 16),

                  // ── Slot Legend ──
                  _buildLegend(),
                  const SizedBox(height: 20),

                  // ── New Schedule Preview Card ──
                  if (hasSelection) _buildNewPreviewCard(sortedSlots),
                ],
              ),
            ),
          ),

          // ── Bottom Action Bar ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.card,
              border: Border(
                top: BorderSide(color: AppTheme.cardBorder),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Keep Current'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_selectedSlots.isEmpty || _isSubmitting)
                          ? null
                          : _submitReschedule,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.background,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.background,
                              ),
                            )
                          : const Text(
                              'Confirm Reschedule',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildOriginalBookingBanner() {
    final originalTime = DateHelpers.toTimeRange(
      widget.reservation.startTime,
      widget.reservation.endTime,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.statusReserved.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded,
                color: AppTheme.statusReserved, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Booking',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.reservation.courtName} • ${DateHelpers.toShortDate(widget.reservation.startTime)}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  originalTime,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Text(
              '₱${widget.reservation.amount.toStringAsFixed(0)} Paid',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourtSelector(List<CourtModel> courts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: courts.map((court) {
          final isSelected = court.id == _selectedCourtId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _onCourtSelected(court),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withOpacity(0.15)
                      : AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sports_tennis_rounded,
                      size: 16,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      court.name,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final dates = List.generate(14, (i) => now.add(Duration(days: i)));

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = DateHelpers.isSameDay(date, _selectedDate);
          final isToday = DateHelpers.isToday(date);

          return GestureDetector(
            onTap: () => _onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 62,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.18)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? 'Today' : DateHelpers.toMonthDay(date).split(' ')[0],
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlotGrid() {
    final slots = DateHelpers.generateTimeSlots(
      date: _selectedDate,
      startHour: AppConstants.openingHour,
      endHour: AppConstants.closingHour,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.3,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isBooked = _bookedStartTimes.contains(slot);
        final isSelected = _selectedSlots.contains(slot);
        final isPast = DateHelpers.slotHasPassed(slot) &&
            DateHelpers.isToday(_selectedDate);

        Color bgColor;
        Color borderColor;
        Color textColor;

        if (isSelected) {
          bgColor = AppTheme.primary.withOpacity(0.2);
          borderColor = AppTheme.primary;
          textColor = AppTheme.primary;
        } else if (isBooked) {
          bgColor = AppTheme.statusInUse.withOpacity(0.08);
          borderColor = AppTheme.statusInUse.withOpacity(0.3);
          textColor = AppTheme.statusInUse.withOpacity(0.5);
        } else if (isPast) {
          bgColor = AppTheme.card.withOpacity(0.4);
          borderColor = AppTheme.cardBorder.withOpacity(0.3);
          textColor = AppTheme.textMuted.withOpacity(0.4);
        } else {
          bgColor = AppTheme.card;
          borderColor = AppTheme.cardBorder;
          textColor = AppTheme.textPrimary;
        }

        return GestureDetector(
          onTap: (isBooked || isPast) ? null : () => _onSlotTap(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
            ),
            child: Text(
              DateHelpers.toTimeString(slot),
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(AppTheme.card, AppTheme.cardBorder, 'Available'),
        const SizedBox(width: 14),
        _legendItem(AppTheme.primary.withOpacity(0.2), AppTheme.primary, 'Selected'),
        const SizedBox(width: 14),
        _legendItem(AppTheme.statusInUse.withOpacity(0.1), AppTheme.statusInUse.withOpacity(0.4), 'Booked'),
      ],
    );
  }

  Widget _legendItem(Color bg, Color border, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildNewPreviewCard(List<DateTime> sortedSlots) {
    final newStart = sortedSlots.first;
    final newEnd = sortedSlots.last
        .add(const Duration(minutes: AppConstants.slotDurationMinutes));
    final newTimeStr = DateHelpers.toTimeRange(newStart, newEnd);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_forward_rounded,
              color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Selected Schedule',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_selectedCourtName • ${DateHelpers.toShortDate(_selectedDate)}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  newTimeStr,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0);
  }
}
