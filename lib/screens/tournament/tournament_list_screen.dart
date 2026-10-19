import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../models/tournament_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import 'tournament_detail_screen.dart';
import 'create_tournament_screen.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  String _selectedFilter = 'all'; // 'all', 'my_events', 'upcoming', 'ongoing'

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final allTournaments = context.watch<TournamentProvider>().tournaments;

    final filteredTournaments = allTournaments.where((t) {
      if (_selectedFilter == 'my_events') {
        if (currentUser == null) return false;
        return t.hasPlayer(currentUser.uid) || t.creatorId == currentUser.uid;
      }
      if (_selectedFilter == 'upcoming') return t.isUpcoming;
      if (_selectedFilter == 'ongoing') return t.isOngoing;
      return true;
    }).toList();

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tournaments & Events',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Join events, compete, and track brackets',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Both players and admins can host / create tournament events
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateTournamentScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppTheme.background,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Filter Chips ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All Tournaments', Icons.grid_view_rounded),
                    const SizedBox(width: 8),
                    _filterChip('my_events', 'My Events', Icons.person_pin_rounded),
                    const SizedBox(width: 8),
                    _filterChip('upcoming', 'Upcoming', Icons.schedule_rounded),
                    const SizedBox(width: 8),
                    _filterChip('ongoing', 'Live / Ongoing', Icons.play_circle_fill_rounded),
                  ],
                ),
              ),
            ),
            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: filteredTournaments.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: filteredTournaments.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final t = filteredTournaments[i];
                        final isUserJoined = currentUser != null && t.hasPlayer(currentUser.uid);
                        final isUserCreator = currentUser != null && t.creatorId == currentUser.uid;

                        return _TournamentCard(
                          tournament: t,
                          index: i,
                          isJoined: isUserJoined,
                          isCreator: isUserCreator,
                          onTap: () {
                            context
                                .read<TournamentProvider>()
                                .selectTournament(t.id);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TournamentDetailScreen(
                                  tournamentId: t.id,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String filterKey, String label, IconData icon) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.background : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.background : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    String title = 'No tournaments found';
    String subtitle = 'Tap the + button to create a new tournament or event';

    if (_selectedFilter == 'my_events') {
      title = 'You haven\'t joined any tournaments';
      subtitle = 'Browse upcoming tournaments and tap "Join" or host your own!';
    } else if (_selectedFilter == 'upcoming') {
      title = 'No upcoming tournaments';
      subtitle = 'Check back later or organize an event with fellow players';
    } else if (_selectedFilter == 'ongoing') {
      title = 'No ongoing tournaments';
      subtitle = 'Upcoming events will appear here once started';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 60,
              color: AppTheme.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final int index;
  final bool isJoined;
  final bool isCreator;
  final VoidCallback onTap;

  const _TournamentCard({
    required this.tournament,
    required this.index,
    this.isJoined = false,
    this.isCreator = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(tournament.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isJoined
                ? AppTheme.primary.withOpacity(0.6)
                : statusColor.withOpacity(0.3),
            width: isJoined ? 1.5 : 1.0,
          ),
          boxShadow: isJoined
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.12),
                    blurRadius: 10,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            // Status bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: isJoined ? AppTheme.primary : statusColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isJoined ? AppTheme.primary : statusColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: isJoined ? AppTheme.primary : statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tournament.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateHelpers.toShortDate(tournament.date),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _chip(
                                Icons.people_outline,
                                '${tournament.players.length} players'),
                            if (tournament.courtName != null &&
                                tournament.courtName!.isNotEmpty)
                              _chip(
                                  Icons.sports_tennis_rounded,
                                  tournament.courtName!),
                            if (isJoined)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.primary.withOpacity(0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        size: 11, color: AppTheme.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Registered',
                                      style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            if (isCreator && !isJoined)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusReserved.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.statusReserved.withOpacity(0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded,
                                        size: 11, color: AppTheme.statusReserved),
                                    SizedBox(width: 4),
                                    Text(
                                      'Host',
                                      style: TextStyle(
                                          color: AppTheme.statusReserved,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status pill
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          tournament.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: index * 70), duration: 400.ms)
        .slideY(begin: 0.06, end: 0,
            delay: Duration(milliseconds: index * 70), duration: 400.ms);
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'upcoming':
        return AppTheme.statusReserved;
      case 'ongoing':
        return AppTheme.statusAvailable;
      case 'completed':
        return AppTheme.textMuted;
      default:
        return AppTheme.textMuted;
    }
  }
}
