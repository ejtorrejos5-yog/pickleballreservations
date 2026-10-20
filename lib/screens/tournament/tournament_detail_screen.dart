import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../models/tournament_model.dart';
import '../../models/player_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import 'bracket_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    context.read<TournamentProvider>().selectTournament(widget.tournamentId);
  }

  @override
  void dispose() {
    context.read<TournamentProvider>().clearSelected();
    super.dispose();
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
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final isCreator = currentUser != null && tournament.creatorId == currentUser.uid;
    final canManage = isAdmin || isCreator;
    final isRegistered = currentUser != null && tournament.hasPlayer(currentUser.uid);

    final statusColor = tournament.isOngoing
        ? AppTheme.statusAvailable
        : tournament.isUpcoming
            ? AppTheme.statusReserved
            : AppTheme.textMuted;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── App Bar ─────────────────────────────────────────────────
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
                title: Text(tournament.name),
                pinned: true,
                actions: [
                  if (canManage && tournament.isUpcoming)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: () => _confirmStart(context, tournament),
                        child: const Text(
                          'Start',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (canManage)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.statusInUse),
                        onPressed: () => _confirmDelete(context, tournament),
                      ),
                    ),
                ],
              ),
              // ── Body ────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header Card
                    _buildHeaderCard(tournament, statusColor, isCreator),
                    const SizedBox(height: 20),

                    // Player Participation & Registration Action Card
                    if (currentUser != null)
                      _buildPlayerActionSection(
                        context,
                        tournament: tournament,
                        currentUser: currentUser,
                        isRegistered: isRegistered,
                      ),
                    if (currentUser != null) const SizedBox(height: 20),

                    // Stage 1 Qualifying Standings & Leaderboard
                    if (tournament.isQualifyingFormat)
                      _buildStandingsSection(context, tournament, currentUser?.uid, canManage),
                    if (tournament.isQualifyingFormat)
                      const SizedBox(height: 20),

                    // Tournament Winners & Placements (if completed)
                    if (tournament.isCompleted && tournament.champion != null)
                      _buildWinnersPodium(tournament, currentUser?.uid),
                    if (tournament.isCompleted && tournament.champion != null)
                      const SizedBox(height: 20),

                    // Players List
                    _buildPlayersSection(tournament, currentUser?.uid),
                    const SizedBox(height: 20),

                    // View Bracket Button
                    _buildBracketButton(context, tournament),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(TournamentModel tournament, Color statusColor, bool isCreator) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppTheme.background, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateHelpers.toDisplayDate(tournament.date),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  tournament.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.cardBorder),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat(Icons.people_outline, '${tournament.players.length}',
                  'Players'),
              _stat(
                Icons.account_tree_outlined,
                tournament.isQualifyingFormat
                    ? '${tournament.qualifyingRoundsCount} Rds → QF'
                    : '${tournament.totalRounds} Rds',
                tournament.isQualifyingFormat ? 'Format' : 'Rounds',
              ),
              _stat(Icons.sports_tennis_rounded,
                  tournament.courtName ?? (tournament.courtId != null ? 'Assigned' : 'Open Court'),
                  'Court'),
              _stat(Icons.verified_user_outlined,
                  tournament.creatorName != null ? (isCreator ? 'You' : tournament.creatorName!) : 'Host',
                  'Organizer'),
            ],
          ),
          if (tournament.description != null &&
              tournament.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.cardBorder),
            const SizedBox(height: 8),
            Text(
              tournament.description!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _stat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerActionSection(
    BuildContext context, {
    required TournamentModel tournament,
    required dynamic currentUser,
    required bool isRegistered,
  }) {
    if (tournament.isUpcoming) {
      if (!isRegistered) {
        // Player is NOT registered yet - show JOIN button
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.08),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.how_to_reg_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Join this Event',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Registration is open! Join now to be seeded into the tournament bracket.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isProcessingAction
                      ? null
                      : () => _handleJoin(context, tournament, currentUser),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isProcessingAction
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.background,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text(
                    'Register for Tournament',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
      } else {
        // Player IS registered - show badge and option to leave
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are Registered!',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'You are placed in the event bracket.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _isProcessingAction
                    ? null
                    : () => _confirmLeave(context, tournament, currentUser.uid),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.statusInUse,
                  side: const BorderSide(color: AppTheme.statusInUse),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Leave', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms);
      }
    } else if (tournament.isOngoing && isRegistered) {
      final nextMatch = tournament.getNextMatchForPlayer(currentUser.uid);
      final isFinalWinner = tournament.champion?.uid == currentUser.uid;

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.1),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_tennis_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Your Match Status',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (nextMatch != null) ...[
              Text(
                'Round ${nextMatch.round} Matchup:',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    nextMatch.player1?.name ?? 'TBD',
                    style: TextStyle(
                      color: nextMatch.player1?.uid == currentUser.uid
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('VS',
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  Text(
                    nextMatch.player2?.name ?? 'TBD',
                    style: TextStyle(
                      color: nextMatch.player2?.uid == currentUser.uid
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ] else if (isFinalWinner) ...[
              const Text(
                '🏆 Congratulations! You have won this tournament!',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ] else ...[
              const Text(
                'Check the bracket to see match progression and tournament results.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 400.ms);
    }

    return const SizedBox.shrink();
  }

  Future<void> _handleJoin(
    BuildContext context,
    TournamentModel tournament,
    dynamic currentUser,
  ) async {
    setState(() => _isProcessingAction = true);
    final player = PlayerModel(
      uid: currentUser.uid,
      name: currentUser.name.isNotEmpty ? currentUser.name : 'Player',
      email: currentUser.email,
    );

    final messenger = ScaffoldMessenger.of(context);
    final success = await context.read<TournamentProvider>().joinTournament(
          tournament: tournament,
          player: player,
        );

    if (mounted) {
      setState(() => _isProcessingAction = false);
    }
    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Successfully registered for ${tournament.name}!'),
          backgroundColor: AppTheme.statusAvailable,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to join tournament. Please try again.'),
          backgroundColor: AppTheme.statusInUse,
        ),
      );
    }
  }

  void _confirmLeave(
    BuildContext context,
    TournamentModel tournament,
    String playerUid,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Tournament'),
        content: const Text(
          'Are you sure you want to withdraw your registration from this tournament event?',
        ),
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
              setState(() => _isProcessingAction = true);
              final messenger = ScaffoldMessenger.of(context);
              final success = await context
                  .read<TournamentProvider>()
                  .leaveTournament(
                    tournament: tournament,
                    playerUid: playerUid,
                  );
              if (mounted) {
                setState(() => _isProcessingAction = false);
              }
              if (success) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('You have left the tournament.'),
                  ),
                );
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsSection(
    BuildContext context,
    TournamentModel tournament,
    String? currentUid,
    bool canManage,
  ) {
    final standings = tournament.standings;
    final playoffSpots = tournament.players.length >= 8 ? 8 : (tournament.players.length >= 4 ? 4 : 2);
    final isPlayoffsReady = tournament.areQualifyingRoundsCompleted;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tournament.hasPlayoffs
              ? AppTheme.primary.withOpacity(0.4)
              : const Color(0xFFFFB300).withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: (tournament.hasPlayoffs ? AppTheme.primary : const Color(0xFFFFB300))
                .withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (tournament.hasPlayoffs ? AppTheme.primary : const Color(0xFFFFB300))
                      .withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.leaderboard_rounded,
                  color: tournament.hasPlayoffs ? AppTheme.primary : const Color(0xFFFFB300),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STAGE 1 STANDINGS & LEADERBOARD',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${tournament.qualifyingRoundsCount} rounds per player • Top $playoffSpots advance to ${playoffSpots == 8 ? "Quarter-Finals" : "Playoffs"}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tournament.hasPlayoffs
                      ? AppTheme.statusAvailable.withOpacity(0.15)
                      : const Color(0xFFFFB300).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tournament.hasPlayoffs ? 'PLAYOFFS SEEDED' : 'QUALIFYING ACTIVE',
                  style: TextStyle(
                    color: tournament.hasPlayoffs
                        ? AppTheme.statusAvailable
                        : const Color(0xFFFFB300),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Advance to Quarter-Finals Action Card (Organizer / Admin)
          if (canManage && tournament.isOngoing && !tournament.hasPlayoffs) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPlayoffsReady
                      ? AppTheme.primary.withOpacity(0.5)
                      : AppTheme.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isPlayoffsReady
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: isPlayoffsReady
                            ? AppTheme.statusAvailable
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isPlayoffsReady
                              ? 'All $playoffSpots qualifying spots ready! Advance top seeds to Playoffs.'
                              : 'Qualifying matches in progress. You can advance top $playoffSpots players to Quarter-Finals anytime.',
                          style: TextStyle(
                            color: isPlayoffsReady
                                ? AppTheme.statusAvailable
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: isPlayoffsReady ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmAdvanceToPlayoffs(context, tournament),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPlayoffsReady ? AppTheme.primary : AppTheme.card,
                        foregroundColor: isPlayoffsReady ? AppTheme.background : AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.flash_on_rounded, size: 16),
                      label: Text(
                        'Seed Top $playoffSpots to ${playoffSpots == 8 ? "Quarter-Finals" : "Playoffs"}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'PLAYER',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    'RDS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                    'W - L',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    'DIFF',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Standings Rows
          ...List.generate(standings.length, (index) {
            final standing = standings[index];
            final rank = index + 1;
            final isQualified = rank <= playoffSpots;
            final isCurrentUser = currentUid != null && standing.player.uid == currentUid;

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppTheme.primary.withOpacity(0.12)
                    : isQualified
                        ? AppTheme.surface.withOpacity(0.6)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrentUser
                      ? AppTheme.primary.withOpacity(0.5)
                      : isQualified
                          ? AppTheme.primary.withOpacity(0.2)
                          : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Rank Badge
                  SizedBox(
                    width: 34,
                    child: Row(
                      children: [
                        Text(
                          '$rank',
                          style: TextStyle(
                            color: isQualified ? AppTheme.primary : AppTheme.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isQualified) ...[
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: AppTheme.statusAvailable,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Player Name
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            standing.player.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrentUser
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                              fontWeight:
                                  isCurrentUser ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                color: AppTheme.background,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        if (isQualified && rank <= 8) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.statusAvailable.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppTheme.statusAvailable.withOpacity(0.4),
                              ),
                            ),
                            child: const Text(
                              'QF',
                              style: TextStyle(
                                color: AppTheme.statusAvailable,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Rounds Played
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${standing.matchesPlayed}/${tournament.qualifyingRoundsCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // W-L
                  SizedBox(
                    width: 58,
                    child: Text(
                      '${standing.wins}-${standing.losses}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: standing.wins > standing.losses
                            ? AppTheme.statusAvailable
                            : (standing.losses > standing.wins
                                ? AppTheme.statusInUse
                                : AppTheme.textPrimary),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  // Point Diff
                  SizedBox(
                    width: 42,
                    child: Text(
                      standing.pointDiff > 0
                          ? '+${standing.pointDiff}'
                          : '${standing.pointDiff}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: standing.pointDiff > 0
                            ? AppTheme.statusAvailable
                            : (standing.pointDiff < 0
                                ? AppTheme.statusInUse
                                : AppTheme.textMuted),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  void _confirmAdvanceToPlayoffs(
    BuildContext context,
    TournamentModel tournament,
  ) {
    final playoffSpots = tournament.players.length >= 8 ? 8 : (tournament.players.length >= 4 ? 4 : 2);
    final topPlayers = tournament.standings.take(playoffSpots).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Advance to ${playoffSpots == 8 ? "Quarter-Finals" : "Playoffs"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will generate the knockout bracket with the top $playoffSpots qualified seeds based on their qualifying round scores:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: topPlayers.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final s = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Seed $idx: ${s.player.name} (${s.wins}W-${s.losses}L, diff: ${s.pointDiff > 0 ? "+${s.pointDiff}" : s.pointDiff})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.background,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final messenger = ScaffoldMessenger.of(context);
              final success = await context
                  .read<TournamentProvider>()
                  .advanceToPlayoffs(tournament);

              if (success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        'Quarter-Finals bracket created with top $playoffSpots seeds!'),
                    backgroundColor: AppTheme.statusAvailable,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to generate playoffs bracket.'),
                    backgroundColor: AppTheme.statusInUse,
                  ),
                );
              }
            },
            child: Text('Generate ${playoffSpots == 8 ? "Quarter-Finals" : "Playoffs"}'),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnersPodium(TournamentModel tournament, String? currentUid) {
    final champion = tournament.champion;
    final runnerUp = tournament.runnerUp;
    final bronzeWinners = tournament.bronzeWinners;

    if (champion == null) return const SizedBox.shrink();

    final isUserChampion = currentUid != null && champion.uid == currentUid;
    final isUserRunnerUp =
        currentUid != null && runnerUp != null && runnerUp.uid == currentUid;
    final isUserBronze =
        currentUid != null && bronzeWinners.any((p) => p.uid == currentUid);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOURNAMENT PLACEMENTS',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Official Event Winners & Podium',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── 🥇 1ST PLACE (GOLD) ───
          _podiumItem(
            place: '1ST PLACE',
            medalLabel: 'CHAMPION • GOLD',
            name: champion.name,
            icon: Icons.emoji_events_rounded,
            primaryColor: const Color(0xFFFFD700),
            secondaryColor: const Color(0xFFFFA000),
            isCurrentUser: isUserChampion,
            isFirst: true,
          ),
          const SizedBox(height: 12),

          // ─── 🥈 2ND PLACE (SILVER) ───
          if (runnerUp != null) ...[
            _podiumItem(
              place: '2ND PLACE',
              medalLabel: 'RUNNER-UP • SILVER',
              name: runnerUp.name,
              icon: Icons.military_tech_rounded,
              primaryColor: const Color(0xFFE2E8F0),
              secondaryColor: const Color(0xFF94A3B8),
              isCurrentUser: isUserRunnerUp,
              isFirst: false,
            ),
            const SizedBox(height: 12),
          ],

          // ─── 🥉 3RD PLACE (BRONZE) ───
          if (bronzeWinners.isNotEmpty) ...[
            _podiumItem(
              place: '3RD PLACE',
              medalLabel: 'SEMIFINALIST • BRONZE',
              name: bronzeWinners.map((p) => p.name).join(' & '),
              icon: Icons.military_tech_outlined,
              primaryColor: const Color(0xFFCD7F32),
              secondaryColor: const Color(0xFF8C4D19),
              isCurrentUser: isUserBronze,
              isFirst: false,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 500.ms).scaleXY(
        begin: 0.96, end: 1, delay: 100.ms, duration: 500.ms);
  }

  Widget _podiumItem({
    required String place,
    required String medalLabel,
    required String name,
    required IconData icon,
    required Color primaryColor,
    required Color secondaryColor,
    required bool isCurrentUser,
    required bool isFirst,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(isFirst ? 0.22 : 0.12),
            secondaryColor.withOpacity(isFirst ? 0.12 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withOpacity(isFirst ? 0.7 : 0.4),
          width: isFirst ? 1.8 : 1.2,
        ),
        boxShadow: isFirst
            ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 12,
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 8,
                )
              ],
            ),
            child: Icon(icon, color: Colors.black87, size: isFirst ? 22 : 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      medalLabel,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: AppTheme.background,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: isFirst ? 18 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersSection(TournamentModel tournament, String? currentUid) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Participants',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tournament.players.length}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tournament.players.isEmpty)
            const Text(
              'No players registered yet. Be the first to join!',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tournament.players
                  .map<Widget>(
                    (p) {
                      final isUser = currentUid != null && p.uid == currentUid;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppTheme.primary.withOpacity(0.15)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isUser
                                ? AppTheme.primary
                                : AppTheme.cardBorder,
                            width: isUser ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 13,
                              color: isUser
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              p.name,
                              style: TextStyle(
                                color: isUser
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight:
                                    isUser ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: AppTheme.background,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  )
                  .toList(),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  Widget _buildBracketButton(BuildContext context, TournamentModel tournament) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BracketScreen(tournamentId: tournament.id),
          ),
        ),
        icon: const Icon(Icons.account_tree_rounded, size: 20),
        label: const Text('View Match Bracket'),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  void _confirmStart(BuildContext context, TournamentModel tournament) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Tournament Event'),
        content: Text(
          'Start "${tournament.name}" now? This will lock registrations and start the elimination rounds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              context
                  .read<TournamentProvider>()
                  .startTournament(tournament);
              Navigator.of(ctx).pop();
            },
            child: const Text('Start Event'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, TournamentModel tournament) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tournament'),
        content: Text('Are you sure you want to permanently delete "${tournament.name}"?'),
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
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop(); // Close dialog
              nav.pop(); // Go back to list screen
              await context
                  .read<TournamentProvider>()
                  .deleteTournament(tournament.id);
              messenger.showSnackBar(
                const SnackBar(content: Text('Tournament deleted successfully')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
