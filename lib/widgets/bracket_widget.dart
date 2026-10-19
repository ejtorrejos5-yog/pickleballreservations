import 'package:flutter/material.dart';
import '../models/tournament_model.dart';
import '../core/theme/app_theme.dart';

/// Horizontal scrollable tournament bracket widget.
class BracketWidget extends StatelessWidget {
  final List<List<MatchModel>> rounds;
  final int totalRounds;
  final bool isAdmin;
  final String? currentUserId;
  final Function(int roundIndex, int matchIndex)? onMatchTap;

  const BracketWidget({
    super.key,
    required this.rounds,
    required this.totalRounds,
    this.isAdmin = false,
    this.currentUserId,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(rounds.length, (roundIdx) {
          final round = rounds[roundIdx];
          final isLastRound = roundIdx == rounds.length - 1;
          return Row(
            children: [
              // Round column
              _RoundColumn(
                roundIndex: roundIdx,
                matches: round,
                totalRounds: totalRounds,
                isAdmin: isAdmin,
                currentUserId: currentUserId,
                onMatchTap: onMatchTap != null
                    ? (matchIdx) => onMatchTap!(roundIdx, matchIdx)
                    : null,
              ),
              // Connector lines between rounds
              if (!isLastRound)
                SizedBox(
                  width: 40,
                  child: CustomPaint(
                    painter: _ConnectorPainter(matchCount: round.length),
                    size: Size(40, _columnHeight(round.length)),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  double _columnHeight(int matchCount) => matchCount * 90.0;
}

// ─── Round Column ─────────────────────────────────────────────────────────────
class _RoundColumn extends StatelessWidget {
  final int roundIndex;
  final List<MatchModel> matches;
  final int totalRounds;
  final bool isAdmin;
  final String? currentUserId;
  final Function(int matchIndex)? onMatchTap;

  const _RoundColumn({
    required this.roundIndex,
    required this.matches,
    required this.totalRounds,
    required this.isAdmin,
    this.currentUserId,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final roundName = _roundName(roundIndex + 1, totalRounds);

    return SizedBox(
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Round label
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              roundName,
              style: const TextStyle(
                color: AppTheme.background,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Match cards
          Column(
            children: List.generate(matches.length, (i) {
              final match = matches[i];
              final isUserInMatch = currentUserId != null &&
                  ((match.player1?.uid == currentUserId) ||
                      (match.player2?.uid == currentUserId));

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MatchCard(
                  match: match,
                  canEdit: (isAdmin || isUserInMatch) && match.isReady && !match.isCompleted,
                  currentUserId: currentUserId,
                  onTap: onMatchTap != null ? () => onMatchTap!(i) : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _roundName(int round, int total) {
    final remaining = total - round + 1;
    switch (remaining) {
      case 1:
        return 'FINAL';
      case 2:
        return 'SEMI-FINAL';
      case 3:
        return 'QUARTER-FINAL';
      default:
        return 'ROUND $round';
    }
  }
}

// ─── Match Card ───────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final MatchModel match;
  final bool canEdit;
  final String? currentUserId;
  final VoidCallback? onTap;

  const _MatchCard({
    required this.match,
    required this.canEdit,
    this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUserMatch = currentUserId != null &&
        ((match.player1?.uid == currentUserId) ||
            (match.player2?.uid == currentUserId));

    return GestureDetector(
      onTap: canEdit ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUserMatch
                ? AppTheme.primary
                : match.isCompleted
                    ? AppTheme.primary.withOpacity(0.4)
                    : AppTheme.cardBorder,
            width: isUserMatch ? 1.8 : 1.0,
          ),
          boxShadow: isUserMatch
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 10,
                  )
                ]
              : canEdit
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.1),
                        blurRadius: 8,
                      )
                    ]
                  : null,
        ),
        child: Column(
          children: [
            _PlayerSlot(
              player: match.player1,
              isWinner: match.winner == match.player1,
              isCompleted: match.isCompleted,
              isCurrentUser: currentUserId != null && match.player1?.uid == currentUserId,
            ),
            Container(height: 1, color: AppTheme.cardBorder),
            _PlayerSlot(
              player: match.player2,
              isWinner: match.winner == match.player2,
              isCompleted: match.isCompleted,
              isCurrentUser: currentUserId != null && match.player2?.uid == currentUserId,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  final dynamic player;
  final bool isWinner;
  final bool isCompleted;
  final bool isCurrentUser;

  const _PlayerSlot({
    required this.player,
    required this.isWinner,
    required this.isCompleted,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = player?.name as String? ?? 'TBD';
    final isBye = player == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWinner
            ? AppTheme.primary.withOpacity(0.15)
            : isCurrentUser
                ? AppTheme.primary.withOpacity(0.08)
                : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    isBye ? 'BYE' : name,
                    style: TextStyle(
                      color: isBye
                          ? AppTheme.textMuted
                          : isWinner || isCurrentUser
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: isWinner || isCurrentUser
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontStyle: isBye ? FontStyle.italic : FontStyle.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'YOU',
                      style: TextStyle(
                        color: AppTheme.background,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isWinner)
            const Icon(Icons.emoji_events_rounded,
                size: 14, color: AppTheme.primary),
        ],
      ),
    );
  }
}

// ─── Connector painter ────────────────────────────────────────────────────────
class _ConnectorPainter extends CustomPainter {
  final int matchCount;
  _ConnectorPainter({required this.matchCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.cardBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (matchCount <= 1) return;

    final spacing = size.height / matchCount;
    final nextSpacing = size.height / (matchCount ~/ 2);

    for (int i = 0; i < matchCount; i += 2) {
      final y1 = spacing * i + spacing / 2;
      final y2 = spacing * (i + 1) + spacing / 2;
      final midY = (y1 + y2) / 2;
      final nextY = nextSpacing * (i ~/ 2) + nextSpacing / 2;

      final path = Path()
        ..moveTo(0, y1)
        ..lineTo(size.width / 2, y1)
        ..lineTo(size.width / 2, y2)
        ..moveTo(size.width / 2, midY)
        ..lineTo(size.width, nextY);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.matchCount != matchCount;
}
