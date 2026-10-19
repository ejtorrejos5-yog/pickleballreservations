import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/court_model.dart';
import '../models/court_status_model.dart';
import '../core/theme/app_theme.dart';

class CourtStatusCard extends StatelessWidget {
  final CourtModel court;
  final CourtStatusModel status;
  final VoidCallback? onTap;
  final bool showReservedName;

  const CourtStatusCard({
    super.key,
    required this.court,
    required this.status,
    this.onTap,
    this.showReservedName = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusType = status.statusType;
    final color = _colorFor(statusType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _buildHeader(color, statusType),
            // ── Body ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    court.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    court.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // ── Status pill ───────────────────────────────────────────
                  _buildStatusPill(color, statusType),
                  if (showReservedName && status.reservedByName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 12,
                            color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          status.reservedByName!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildHeader(Color color, CourtStatusType type) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 0),
        ],
      ),
    );
  }

  Widget _buildStatusPill(Color color, CourtStatusType type) {
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
          _PulsingDot(color: color, animate: type == CourtStatusType.inUse),
          const SizedBox(width: 6),
          Text(
            type.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
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

// ─── Pulsing dot indicator ────────────────────────────────────────────────────
class _PulsingDot extends StatelessWidget {
  final Color color;
  final bool animate;

  const _PulsingDot({required this.color, required this.animate});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (!animate) return dot;
    return dot
        .animate(onPlay: (c) => c.repeat())
        .scaleXY(begin: 1, end: 1.5, duration: 800.ms, curve: Curves.easeInOut)
        .then()
        .scaleXY(begin: 1.5, end: 1, duration: 800.ms, curve: Curves.easeInOut);
  }
}
