import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_helpers.dart';
import '../models/reservation_model.dart';
import '../core/constants/app_constants.dart';

class TimeSlotPicker extends StatelessWidget {
  final DateTime selectedDate;
  final List<DateTime> bookedSlots; // start times that are taken
  final Set<DateTime> selectedSlots;
  final ValueChanged<DateTime> onSlotTap;

  const TimeSlotPicker({
    super.key,
    required this.selectedDate,
    required this.bookedSlots,
    required this.selectedSlots,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final slots = DateHelpers.generateTimeSlots(
      date: selectedDate,
      startHour: AppConstants.openingHour,
      endHour: AppConstants.closingHour,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isBooked = bookedSlots.contains(slot);
        final isSelected = selectedSlots.contains(slot);
        // Real-time: gray out slots that have already passed today
        final isPast = DateHelpers.slotHasPassed(slot) &&
            DateHelpers.isToday(selectedDate);

        return _SlotChip(
          slot: slot,
          isBooked: isBooked,
          isSelected: isSelected,
          isPast: isPast,
          onTap: (isBooked || isPast) ? null : () => onSlotTap(slot),
        );
      },
    );
  }
}

class _SlotChip extends StatelessWidget {
  final DateTime slot;
  final bool isBooked;
  final bool isSelected;
  final bool isPast;
  final VoidCallback? onTap;

  const _SlotChip({
    required this.slot,
    required this.isBooked,
    required this.isSelected,
    required this.isPast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
      bgColor = AppTheme.card.withOpacity(0.5);
      borderColor = AppTheme.cardBorder.withOpacity(0.3);
      textColor = AppTheme.textMuted.withOpacity(0.4);
    } else {
      bgColor = AppTheme.card;
      borderColor = AppTheme.cardBorder;
      textColor = AppTheme.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateHelpers.toTimeString(slot),
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (isBooked)
                Text(
                  'Booked',
                  style: TextStyle(
                    color: AppTheme.statusInUse.withOpacity(0.5),
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper: extract booked start times from reservations ────────────────────
List<DateTime> bookedStartTimesFrom(List<ReservationModel> reservations) {
  return reservations.map((r) => r.startTime).toList();
}
