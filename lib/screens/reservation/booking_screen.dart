import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/court_model.dart';
import '../../models/reservation_model.dart';
import '../../providers/reservation_provider.dart';
import '../../widgets/time_slot_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/constants/app_constants.dart';
import 'payment_screen.dart';

class BookingScreen extends StatefulWidget {
  final CourtModel court;

  const BookingScreen({super.key, required this.court});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDay = DateTime.now();
  final Set<DateTime> _selectedSlots = {};
  List<ReservationModel> _dayReservations = [];
  final bool _isConfirming = false;

  StreamSubscription<List<ReservationModel>>? _reservationSub;
  Timer? _clockTimer; // Ticks every minute to refresh past-slot states

  @override
  void initState() {
    super.initState();
    _loadReservations();
    // Refresh every minute so past slots become unselectable in real-time
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reservationSub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _loadReservations() {
    _reservationSub?.cancel(); // Cancel previous subscription
    final dateStr = DateHelpers.toFirestoreDate(_selectedDay);
    _reservationSub = context
        .read<ReservationProvider>()
        .getSlotReservations(widget.court.id, dateStr)
        .listen((res) {
      if (mounted) setState(() => _dayReservations = res);
    });
  }

  void _onDaySelected(DateTime day, DateTime _) {
    setState(() {
      _selectedDay = day;
      _selectedSlots.clear();
    });
    _loadReservations();
  }

  void _onSlotTap(DateTime slot) {
    setState(() {
      if (_selectedSlots.contains(slot)) {
        _selectedSlots.remove(slot);
      } else {
        _selectedSlots.add(slot);
      }
    });
  }

  void _confirm() {
    if (_selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one time slot'),
          backgroundColor: AppTheme.statusReserved,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          court: widget.court,
          date: _selectedDay,
          slots: _selectedSlots,
        ),
      ),
    );
  }

  List<DateTime> get _bookedStartTimes {
    return _dayReservations.map((r) => r.startTime).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book ${widget.court.name}'),
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
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Calendar ──────────────────────────────────────────
                    _buildCalendar(),
                    const SizedBox(height: 24),
                    // ── Slot picker ───────────────────────────────────────
                    const Text(
                      'Select Time Slots',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select one or more time slots',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TimeSlotPicker(
                      selectedDate: _selectedDay,
                      bookedSlots: _bookedStartTimes,
                      selectedSlots: _selectedSlots,
                      onSlotTap: _onSlotTap,
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            // ── Confirm Bar ───────────────────────────────────────────────
            _buildConfirmBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      decoration: AppTheme.glassCard,
      child: TableCalendar(
        firstDay: today,
        lastDay: today.add(const Duration(days: 60)),
        focusedDay: _selectedDay,
        selectedDayPredicate: (d) =>
            DateHelpers.isSameDay(d, _selectedDay),
        onDaySelected: _onDaySelected,
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
          todayDecoration: BoxDecoration(
            color: Color(0x3000FF88),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
          ),
          defaultTextStyle: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          weekendTextStyle: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          outsideTextStyle: TextStyle(color: AppTheme.textMuted),
          disabledTextStyle: TextStyle(color: AppTheme.textMuted),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          leftChevronIcon:
              Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary),
          rightChevronIcon:
              Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle:
              TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          weekendStyle:
              TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildConfirmBar() {
    final hasSelection = _selectedSlots.isNotEmpty;
    final sorted = _selectedSlots.toList()..sort();
    final hours = _selectedSlots.length;
    final pricePerHour = widget.court.pricePerHour;
    final total = hours * pricePerHour;

    final summary = hasSelection
        ? _selectedSlots.length == 1
            ? DateHelpers.toTimeString(sorted.first)
            : '${DateHelpers.toTimeString(sorted.first)} – ${DateHelpers.toTimeString(sorted.last.add(const Duration(minutes: AppConstants.slotDurationMinutes)))}'
        : 'No slots selected';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasSelection ? summary : 'No slots selected',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasSelection) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$hours hr${hours > 1 ? 's' : ''} × ₱${pricePerHour.toStringAsFixed(0)}/hr = ₱${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: hasSelection && !_isConfirming ? _confirm : null,
              child: _isConfirming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.background,
                      ),
                    )
                  : Text(hasSelection ? 'Pay ₱${total.toStringAsFixed(0)}' : 'Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}
