import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_helpers.dart';

class CountdownTimerWidget extends StatefulWidget {
  final DateTime endTime;
  final DateTime? startTime;
  final double size;
  final bool showLabel;

  const CountdownTimerWidget({
    super.key,
    required this.endTime,
    this.startTime,
    this.size = 140,
    this.showLabel = true,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _secondsRemaining = 0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _updateSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateSeconds());
  }

  void _updateSeconds() {
    final secs = DateHelpers.secondsUntilEnd(widget.endTime);
    if (mounted) setState(() => _secondsRemaining = secs);
  }

  @override
  void dispose() {
    _timer.cancel();
    _animController.dispose();
    super.dispose();
  }

  double get _progress {
    if (widget.startTime == null) return 0.0;
    final total = widget.endTime.difference(widget.startTime!).inSeconds;
    if (total <= 0) return 0.0;
    return (_secondsRemaining / total).clamp(0.0, 1.0);
  }

  Color get _color {
    if (_progress > 0.5) return AppTheme.statusAvailable;
    if (_progress > 0.25) return AppTheme.statusReserved;
    return AppTheme.statusInUse;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background ring
              CircularProgressIndicator(
                value: 1,
                strokeWidth: 8,
                valueColor:
                    AlwaysStoppedAnimation(AppTheme.cardBorder.withOpacity(0.5)),
              ),
              // Progress ring
              CircularProgressIndicator(
                value: widget.startTime != null ? _progress : null,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation(_color),
                backgroundColor: Colors.transparent,
              ),
              // Center content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateHelpers.formatCountdown(_secondsRemaining),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: widget.size * 0.18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (widget.showLabel)
                      Text(
                        _secondsRemaining > 0 ? 'remaining' : 'expired',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: widget.size * 0.09,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Compact Inline Timer ─────────────────────────────────────────────────────
class InlineCountdown extends StatefulWidget {
  final DateTime endTime;
  const InlineCountdown({super.key, required this.endTime});

  @override
  State<InlineCountdown> createState() => _InlineCountdownState();
}

class _InlineCountdownState extends State<InlineCountdown> {
  late Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _seconds = DateHelpers.secondsUntilEnd(widget.endTime);
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _seconds = DateHelpers.secondsUntilEnd(widget.endTime));
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _seconds > 1800
        ? AppTheme.statusAvailable
        : _seconds > 600
            ? AppTheme.statusReserved
            : AppTheme.statusInUse;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            DateHelpers.formatCountdown(_seconds),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
