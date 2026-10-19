import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation_model.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final allUserReservations =
        context.watch<ReservationProvider>().userReservations;
    final reservations = user != null
        ? allUserReservations.where((r) => r.userId == user.uid).toList()
        : <ReservationModel>[];
    final completedCount =
        reservations.where((r) => r.isCompleted).length;
    final upcomingCount =
        reservations.where((r) => r.isUpcoming).length;

    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Avatar ────────────────────────────────────────────
                    _buildAvatar(user.name)
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .scaleXY(begin: 0.8, end: 1, duration: 500.ms,
                            curve: Curves.elasticOut),
                    const SizedBox(height: 14),
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.isAdmin ? 'LPC ADMINISTRATOR' : 'LPC CLUB PLAYER',
                        style: const TextStyle(
                          color: AppTheme.background,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ── Stats ─────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: completedCount.toString(),
                            label: 'Completed\nSessions',
                            color: AppTheme.statusAvailable,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            value: upcomingCount.toString(),
                            label: 'Upcoming\nBookings',
                            color: AppTheme.statusReserved,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            value: reservations.length.toString(),
                            label: 'Total\nBookings',
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // ── Info Card ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LPC Player Membership',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _infoRow(Icons.sports_tennis_rounded, 'Club',
                              'Lifestyle Pickleball Court (LPC)'),
                          const Divider(color: AppTheme.cardBorder, height: 20),
                          _infoRow(Icons.email_outlined, 'Email',
                              user.email),
                          if (user.phone != null) ...[
                            const Divider(color: AppTheme.cardBorder, height: 20),
                            _infoRow(Icons.phone_outlined, 'Phone',
                                user.phone!),
                          ],
                          const Divider(color: AppTheme.cardBorder, height: 20),
                          _infoRow(
                              Icons.verified_user_outlined,
                              'Access Role',
                              user.isAdmin ? 'LPC Club Administrator' : 'Verified LPC Player'),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(
                            begin: 0.06,
                            end: 0,
                            delay: 200.ms,
                            duration: 400.ms),
                    const SizedBox(height: 24),
                    // ── Sign Out ──────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _confirmSignOut(context),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Sign Out'),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AppTheme.background,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text('$label: ',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
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
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
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
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ReservationProvider>().clear();
              context.read<AuthProvider>().signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }
}
