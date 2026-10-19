import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/court_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation_model.dart';
import '../../widgets/court_status_card.dart';
import '../../widgets/countdown_timer_widget.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../courts/court_detail_screen.dart';
import '../reservation/my_reservations_screen.dart';
import '../tournament/tournament_list_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load user reservations and all reservations if admin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        context.read<ReservationProvider>().loadUserReservations(uid);
      }
      if (auth.isAdmin) {
        context.read<ReservationProvider>().loadAllReservations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const _HomeTab(),
          const _CourtsTab(),
          const MyReservationsScreen(),
          const TournamentListScreen(),
          isAdmin ? const AdminDashboardScreen() : const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        isAdmin: isAdmin,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final courtProvider = context.watch<CourtProvider>();
    final allUserReservations = context.watch<ReservationProvider>().userReservations;

    // Strictly filter by current user's uid so a new account starts with zero active sessions
    final userReservations = user != null
        ? allUserReservations.where((r) => r.userId == user.uid).toList()
        : <ReservationModel>[];

    // Active reservation for this specific user (if any)
    final activeRes = userReservations
        .where((r) => r.isActive || r.isUpcoming)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final nextRes = activeRes.isNotEmpty ? activeRes.first : null;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(context, user?.name ?? '', isAdmin)),

            // ── LPC Club Highlights Banner ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: _buildClubBanner(),
              ),
            ),

            // ── Active Session Card ────────────────────────────────────────
            if (nextRes != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: _ActiveSessionCard(reservation: nextRes),
                ),
              ),

            // ── Section Title ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Court Live Status',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Real-time IoT occupancy & bookings',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Live Sensors',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Court Grid ────────────────────────────────────────────────
            if (courtProvider.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                ),
              )
            else if (courtProvider.courts.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'No courts available',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final court = courtProvider.courts[i];
                      final status = courtProvider.statusFor(court.id);
                      return CourtStatusCard(
                        court: court,
                        status: status,
                        showReservedName: isAdmin,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CourtDetailScreen(
                              court: court,
                              status: status,
                              showReservedName: isAdmin,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: courtProvider.courts.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.88,
                  ),
                ),
              ),

            // ── LPC Club Info & Etiquette Footer ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: _buildEtiquetteCard(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, bool isAdmin) {
    final greeting = _greeting();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/lpc_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF0D1A0D),
                  child: const Center(
                    child: Text('LPC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isAdmin ? 'LPC ADMIN' : 'LPC PLAYER',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  name.isNotEmpty ? name : 'Player',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0, duration: 400.ms);
  }

  Widget _buildClubBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryDark.withOpacity(0.25),
            AppTheme.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sports_tennis_rounded, color: AppTheme.primary, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIFESTYLE PICKLEBALL COURT (LPC)',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Experience Premium Court Sessions',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Professional cushioned flooring, instant PayMongo payments, and digital QR check-in.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _amenityChip(Icons.access_time_rounded, '7 AM – 12 Midnight'),
              const SizedBox(width: 8),
              _amenityChip(Icons.qr_code_scanner_rounded, 'QR Check-In'),
              const SizedBox(width: 8),
              _amenityChip(Icons.flash_on_rounded, 'Instant QR Ph'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 450.ms).slideY(begin: 0.05, end: 0, delay: 150.ms, duration: 450.ms);
  }

  Widget _amenityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtiquetteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'LPC Player Guidelines & Etiquette',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bulletItem('Non-marking court shoes are strictly required.'),
          _bulletItem('Present your Check-In QR Code upon arrival to verify payment and check in for your session.'),
          _bulletItem('Each slot is 60 minutes. Please clear the court promptly for the next players.'),
          _bulletItem('Keep the court clean and dispose of hydration bottles in designated bins.'),
        ],
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 5, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ─── Active Session Card ──────────────────────────────────────────────────────
class _ActiveSessionCard extends StatelessWidget {
  final dynamic reservation;
  const _ActiveSessionCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Next Session',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reservation.courtName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateHelpers.toTimeRange(
                      reservation.startTime, reservation.endTime),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reservation.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Countdown
          if (reservation.isActive && reservation.endTime != null)
            CountdownTimerWidget(
              endTime: reservation.endTime,
              startTime: reservation.startTime,
              size: 90,
              showLabel: false,
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.08, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

// ─── Courts Tab (stub — points to CourtDetailScreen) ─────────────────────────
class _CourtsTab extends StatelessWidget {
  const _CourtsTab();

  @override
  Widget build(BuildContext context) {
    final courtProvider = context.watch<CourtProvider>();
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Courts',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Tap a court to book or view details',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: courtProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: courtProvider.courts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final court = courtProvider.courts[i];
                        final status =
                            courtProvider.statusFor(court.id);
                        return CourtStatusCard(
                          court: court,
                          status: status,
                          showReservedName: isAdmin,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CourtDetailScreen(
                                court: court,
                                status: status,
                                showReservedName: isAdmin,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
