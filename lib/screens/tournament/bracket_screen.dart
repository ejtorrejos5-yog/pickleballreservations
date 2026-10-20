import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../models/tournament_model.dart';
import '../../models/player_model.dart';
import '../../widgets/bracket_widget.dart';
import '../../core/theme/app_theme.dart';

class BracketScreen extends StatefulWidget {
  final String tournamentId;

  const BracketScreen({super.key, required this.tournamentId});

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TournamentProvider>().selectTournament(widget.tournamentId);
  }

  @override
  Widget build(BuildContext context) {
    final tournament =
        context.watch<TournamentProvider>().selectedTournament;
    final currentUser = context.watch<AuthProvider>().currentUser;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    if (tournament == null) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final isCreator = currentUser != null && tournament.creatorId == currentUser.uid;
    final canManageMatch = (isAdmin || isCreator) && tournament.isOngoing;

    return Scaffold(
      appBar: AppBar(
        title: Text('${tournament.name} Bracket'),
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
            // Round & Court info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _infoBadge(Icons.people_outline,
                        '${tournament.players.length} players'),
                    const SizedBox(width: 8),
                    _infoBadge(Icons.account_tree_outlined,
                        '${tournament.totalRounds} rounds'),
                    const SizedBox(width: 8),
                    if (tournament.courtName != null && tournament.courtName!.isNotEmpty) ...[
                      _infoBadge(Icons.sports_tennis_rounded, tournament.courtName!),
                      const SizedBox(width: 8),
                    ],
                    if (tournament.isOngoing)
                      _infoBadge(
                          Icons.flag_rounded,
                          'Round ${tournament.currentRoundIndex + 1}'),
                    if (tournament.isCompleted)
                      _infoBadge(
                          Icons.emoji_events_rounded,
                          'Completed'),
                  ],
                ),
              ),
            ),
            if (tournament.isCompleted && tournament.champion != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withOpacity(0.18),
                      AppTheme.card,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.4)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFFFD700), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '🥇 Gold: ${tournament.champion!.name}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (tournament.runnerUp != null) ...[
                        const SizedBox(width: 14),
                        Text(
                          '🥈 Silver: ${tournament.runnerUp!.name}',
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (tournament.bronzeWinners.isNotEmpty) ...[
                        const SizedBox(width: 14),
                        Text(
                          '🥉 Bronze: ${tournament.bronzeWinners.map((p) => p.name).join(" & ")}',
                          style: const TextStyle(
                            color: Color(0xFFCD7F32),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (tournament.isQualifyingFormat && !tournament.hasPlayoffs)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.military_tech_rounded,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stage 1: Qualifying Rounds Active',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Top 8 players will advance to Quarter-Finals.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canManageMatch)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.background,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () =>
                            _confirmAdvancePlayoffs(context, tournament),
                        child: const Text('Advance to QF'),
                      ),
                  ],
                ),
              ),
            // Bracket
            Expanded(
              child: tournament.rounds.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_tree_outlined,
                                size: 50,
                                color: AppTheme.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'No bracket generated yet',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'At least 2 players are needed to generate the tournament bracket.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : BracketWidget(
                      rounds: tournament.rounds,
                      totalRounds: tournament.totalRounds,
                      isAdmin: canManageMatch,
                      currentUserId: currentUser?.uid,
                      format: tournament.format,
                      qualifyingRoundsCount: tournament.qualifyingRoundsCount,
                      onMatchTap: tournament.isOngoing
                          ? (roundIdx, matchIdx) {
                              final match = tournament.rounds[roundIdx][matchIdx];
                              final isUserInMatch = currentUser != null &&
                                  (match.player1?.uid == currentUser.uid ||
                                      match.player2?.uid == currentUser.uid);

                              if (canManageMatch || isUserInMatch) {
                                _showRecordDialog(
                                  context,
                                  tournament,
                                  roundIdx,
                                  matchIdx,
                                );
                              }
                            }
                          : null,
                    ),
            ),
            // Legend
            _buildLegend(currentUser != null),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildLegend(bool hasLoggedInUser) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 6,
        children: [
          if (hasLoggedInUser) _legendItem(AppTheme.primary, 'Your Match'),
          _legendItem(AppTheme.primary.withOpacity(0.6), 'Winner'),
          _legendItem(AppTheme.cardBorder, 'Pending'),
          _legendItem(AppTheme.textMuted, 'TBD / Bye'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  void _showRecordDialog(
    BuildContext context,
    TournamentModel tournament,
    int roundIndex,
    int matchIndex,
  ) {
    final match = tournament.rounds[roundIndex][matchIndex];
    if (!match.isReady || match.isCompleted) return;

    final scoreCtrl = TextEditingController();
    PlayerModel? selectedWinner;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Record Match Result'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Round ${roundIndex + 1}, Match ${matchIndex + 1}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text('Select Winner:',
                  style: TextStyle(color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              // Player 1
              _winnerOption(
                ctx,
                player: match.player1!,
                isSelected: selectedWinner == match.player1,
                onTap: () =>
                    setDialogState(() => selectedWinner = match.player1),
              ),
              const SizedBox(height: 8),
              // VS divider
              const Row(
                children: [
                  Expanded(child: Divider(color: AppTheme.cardBorder)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('VS',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                  ),
                  Expanded(child: Divider(color: AppTheme.cardBorder)),
                ],
              ),
              const SizedBox(height: 8),
              // Player 2
              _winnerOption(
                ctx,
                player: match.player2!,
                isSelected: selectedWinner == match.player2,
                onTap: () =>
                    setDialogState(() => selectedWinner = match.player2),
              ),
              const SizedBox(height: 16),
              // Score input
              TextField(
                controller: scoreCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Score (optional, e.g. 11-7, 11-5)',
                  prefixIcon: Icon(Icons.score_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selectedWinner == null
                  ? null
                  : () {
                      context.read<TournamentProvider>().recordMatchResult(
                            tournament: tournament,
                            roundIndex: roundIndex,
                            matchIndex: matchIndex,
                            winner: selectedWinner!,
                            score: scoreCtrl.text.isEmpty
                                ? null
                                : scoreCtrl.text,
                          );
                      Navigator.of(ctx).pop();
                    },
              child: const Text('Save Result'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _winnerOption(
    BuildContext context, {
    required PlayerModel player,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.12)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.person_rounded,
                size: 18,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 10),
            Text(
              player.name,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppTheme.primary),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmAdvancePlayoffs(BuildContext context, TournamentModel tournament) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Advance to Quarter-Finals'),
        content: const Text(
          'Populate the Quarter-Finals elimination bracket using the current Leaderboard standings?\n\nThe Top 8 players with the best win records will be seeded into the playoff bracket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context
                  .read<TournamentProvider>()
                  .advanceToPlayoffs(tournament);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quarter-Finals bracket created! 🏆'),
                    backgroundColor: AppTheme.statusAvailable,
                  ),
                );
              }
            },
            child: const Text('Advance Now'),
          ),
        ],
      ),
    );
  }
}
