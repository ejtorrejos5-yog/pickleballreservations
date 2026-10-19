import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/court_provider.dart';
import '../../models/court_model.dart';
import '../../models/court_status_model.dart';
import '../../services/court_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../home/home_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _courtsKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _downloadKey = GlobalKey();
  final GlobalKey _tournamentsKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  int? _expandedFaqIndex;

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _onBookPressed() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _navigateToRegister();
    }
  }

  Future<void> _downloadApk() async {
    const apkUrl = 'lpc-pickleball.apk';
    try {
      await launchUrlString(apkUrl, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (mounted) {
      _showDownloadGuideDialog(context);
    }
  }

  void _showDownloadGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(26),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.android_rounded,
                  color: AppTheme.primaryDark, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Download LPC Android App',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'v1.0.0 • Android 8.0+ • ~45 MB',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primaryDark, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your download is starting. You can sign in and register directly inside the mobile app!',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'How to install the APK on your phone:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildDialogStep(
                '1', 'Check your notifications bar or Downloads folder for "lpc-pickleball.apk".'),
            _buildDialogStep('2',
                'Tap the file. If asked to allow installation from unknown sources, tap "Settings" and turn it ON.'),
            _buildDialogStep(
                '3', 'Tap "Install" and wait a few seconds.'),
            _buildDialogStep(
                '4', 'Open LPC, sign in or register, and enjoy seamless court reservations!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await launchUrlString('lpc-pickleball.apk',
                    mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download APK Again'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDialogStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isTablet = MediaQuery.of(context).size.width >= 600 && !isDesktop;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background ambient gradient blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 600,
            left: -150,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main scrollable content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Sticky Navigation Bar
              SliverAppBar(
                pinned: true,
                floating: true,
                elevation: 0,
                backgroundColor: Colors.white.withOpacity(0.92),
                toolbarHeight: 76,
                titleSpacing: 0,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    border: const Border(
                      bottom: BorderSide(color: AppTheme.cardBorder, width: 1),
                    ),
                  ),
                ),
                title: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 48.0 : (isTablet ? 24.0 : 16.0),
                  ),
                  child: Row(
                    children: [
                      // Brand Logo & Name
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: AppTheme.primaryGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/images/lpc_logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.sports_tennis_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppConstants.brandShort,
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    AppConstants.brandTagline,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Desktop Navigation Links
                      if (isDesktop) ...[
                        _buildNavLink('Courts', () => _scrollToKey(_courtsKey)),
                        _buildNavLink('Smart Tech', () => _scrollToKey(_featuresKey)),
                        _buildNavLink('How It Works', () => _scrollToKey(_howItWorksKey)),
                        _buildNavLink('Download App', () => _scrollToKey(_downloadKey)),
                        _buildNavLink('Tournaments', () => _scrollToKey(_tournamentsKey)),
                        _buildNavLink('Rates', () => _scrollToKey(_pricingKey)),
                        _buildNavLink('FAQ', () => _scrollToKey(_faqKey)),
                        const SizedBox(width: 16),
                      ],

                      // Top App Bar Action Buttons
                      // Download APK button
                      OutlinedButton.icon(
                        onPressed: _downloadApk,
                        icon: const Icon(Icons.android_rounded, size: 17, color: AppTheme.primaryDark),
                        label: Text(isDesktop ? 'Download APK' : 'APK',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppTheme.primaryLight,
                          side: const BorderSide(color: AppTheme.primary, width: 1.2),
                          padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 16 : 10, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Auth action buttons
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          if (auth.isAuthenticated) {
                            return ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) => const HomeScreen()),
                                );
                              },
                              icon: const Icon(Icons.dashboard_rounded, size: 18),
                              label: const Text('Dashboard'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                            );
                          }

                          return Row(
                            children: [
                              OutlinedButton(
                                onPressed: _navigateToLogin,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  side: const BorderSide(
                                      color: AppTheme.primary, width: 1.5),
                                ),
                                child: const Text('Sign In'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _navigateToRegister,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  elevation: 4,
                                  shadowColor: AppTheme.primary.withOpacity(0.4),
                                ),
                                child: const Text('Book Court'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Page Content
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeroSection(isDesktop),
                    _buildStatsBanner(isDesktop),
                    _buildCourtsSection(isDesktop),
                    _buildFeaturesSection(isDesktop),
                    _buildHowItWorksSection(isDesktop),
                    _buildDownloadSection(isDesktop),
                    _buildTournamentShowcase(isDesktop),
                    _buildPricingSection(isDesktop),
                    _buildFaqSection(isDesktop),
                    _buildFinalCtaSection(isDesktop),
                    _buildFooter(isDesktop),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Nav Link Helper
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildNavLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppTheme.primaryLight.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. HERO SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 580),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: isDesktop ? 60.0 : 36.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildHeroTextContent(),
                    ),
                    const SizedBox(width: 48),
                    Expanded(
                      flex: 5,
                      child: _buildHeroInteractiveMockup(),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildHeroTextContent(),
                    const SizedBox(height: 36),
                    _buildHeroInteractiveMockup(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: AppTheme.primaryDark, size: 16),
              const SizedBox(width: 6),
              Text(
                'IoT Smart Court & Live Arduino LCD Powered',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 20),

        // Main Headline
        RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(
              color: AppTheme.textPrimary,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
            children: const [
              TextSpan(text: 'Experience the Next Generation of '),
              TextSpan(
                text: 'Pickleball Courts',
                style: TextStyle(
                  color: AppTheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.primaryLight,
                  decorationThickness: 4,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 150.ms, duration: 500.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 18),

        // Subtitle
        Text(
          'Lifestyle Pickleball Court brings tournament-grade cushioned flooring, instant PayMongo reservations, automated QR check-in, and court-side Arduino countdown displays for an elite sporting experience.',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 16,
            height: 1.6,
          ),
        ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
        const SizedBox(height: 32),

        // Action CTAs (Book + Download APK + Live Courts)
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            ElevatedButton.icon(
              onPressed: _onBookPressed,
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: const Text('Book a Court Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: AppTheme.primary.withOpacity(0.4),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _downloadApk,
              icon: const Icon(Icons.android_rounded, size: 20, color: Colors.white),
              label: const Text('Download APK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _scrollToKey(_courtsKey),
              icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
              label: const Text('Live Courts'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
        const SizedBox(height: 28),

        // Trust indicators
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _buildTrustIcon(Icons.check_circle_rounded, 'Instant Confirmation'),
            _buildTrustIcon(Icons.speed_rounded, 'Real-Time LCD Timer'),
            _buildTrustIcon(Icons.security_rounded, 'PayMongo Protected'),
            _buildTrustIcon(Icons.android_rounded, 'Android APK Available'),
          ],
        ).animate().fadeIn(delay: 450.ms, duration: 500.ms),
      ],
    );
  }

  Widget _buildTrustIcon(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primary, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Interactive Live Court Simulation Mockup
  Widget _buildHeroInteractiveMockup() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with live indicator
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.statusAvailable,
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
               .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 800.ms),
              const SizedBox(width: 8),
              Text(
                'LIVE IOT SYSTEM ACTIVE',
                style: GoogleFonts.poppins(
                  color: AppTheme.statusAvailable,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '4 Courts Online',
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Court LCD Display Simulation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF061406),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E381E), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF39FF14).withOpacity(0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.developer_board_rounded,
                        color: Color(0xFF39FF14), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'ARDUINO 16x2 LCD • COURT 1',
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF39FF14).withOpacity(0.7),
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'C1:Gabriel',
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF39FF14),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Color(0xFF39FF14), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '59:48 left',
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF39FF14),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Active Match Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automated QR Check-In',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Scan code at court gate to activate lighting & timer',
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _onBookPressed,
              icon: const Icon(Icons.sports_tennis_rounded, size: 18),
              label: const Text('Reserve Next Available Slot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. STATS BANNER
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStatsBanner(bool isDesktop) {
    final stats = [
      {'val': '4 Courts', 'label': 'Cushioned Tournament Grade'},
      {'val': '7 AM - 12 MN', 'label': 'Open Daily for Booking'},
      {'val': '100% Digital', 'label': 'Contactless QR Check-In'},
      {'val': 'Android APK', 'label': 'Direct Mobile App Download'},
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 36.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 32,
            runSpacing: 24,
            children: stats.map((s) {
              return Column(
                children: [
                  Text(
                    s['val']!,
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s['label']!,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. COURTS LIVE STATUS SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCourtsSection(bool isDesktop) {
    return Container(
      key: _courtsKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 70.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader(
                badge: 'LIVE COURT STATUS',
                title: 'Available Courts & Real-Time Sync',
                subtitle:
                    'Check current court occupancy, features, and reserve your preferred court in seconds.',
              ),
              const SizedBox(height: 48),

              // Consumer of CourtProvider to show real live courts
              Consumer<CourtProvider>(
                builder: (context, courtProvider, _) {
                  final courts = courtProvider.courts;

                  // Fallback sample courts if database empty or loading
                  final displayCourts = courts.isNotEmpty
                      ? courts
                      : [
                          const CourtModel(
                            id: 'nTiDjaUFXFlKcqWa8Y8M',
                            name: 'Court 1 (Championship A)',
                            description:
                                'Tournament court with pro cushioning and LCD display',
                            isActive: true,
                          ),
                          const CourtModel(
                            id: 'F9etMsllvoRpT7a7xN3O',
                            name: 'Court 2 (Court B)',
                            description:
                                'Standard court with high-visibility LED floodlights',
                            isActive: true,
                          ),
                          const CourtModel(
                            id: 'dNydjbXGbKHu6f8kFEoM',
                            name: 'Court 3 (Court C)',
                            description:
                                'Covered outdoor court with spectator seating',
                            isActive: true,
                          ),
                          const CourtModel(
                            id: '3i6TMY5z2tqrGdDhqGQ1',
                            name: 'Court 4 (Court D)',
                            description:
                                'Clubhouse court near equipment rental station',
                            isActive: true,
                          ),
                        ];

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 1000
                          ? 4
                          : (constraints.maxWidth >= 600 ? 2 : 1);

                      return Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: displayCourts.map((court) {
                          final width = (constraints.maxWidth -
                                  (crossAxisCount - 1) * 24) /
                              crossAxisCount;
                          return SizedBox(
                            width: width,
                            child: _buildCourtCard(court),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourtCard(CourtModel court) {
    return StreamBuilder<CourtStatusModel>(
      stream: CourtService().getCourtStatus(court.id),
      builder: (context, snapshot) {
        final status = snapshot.data ?? CourtStatusModel.empty(court.id);
        final isOccupied = status.isOccupied;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isOccupied
                  ? AppTheme.statusReserved.withOpacity(0.4)
                  : AppTheme.cardBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top Image / Court Graphic
              Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: isOccupied
                      ? LinearGradient(
                          colors: [
                            const Color(0xFFD97706).withOpacity(0.85),
                            const Color(0xFFB45309),
                          ],
                        )
                      : AppTheme.primaryGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(21),
                    topRight: Radius.circular(21),
                  ),
                ),
                child: Stack(
                  children: [
                    // Court lines pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.15,
                        child: CustomPaint(
                          painter: _CourtLinesPainter(),
                        ),
                      ),
                    ),
                    // Status Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOccupied
                                    ? AppTheme.statusReserved
                                    : AppTheme.statusAvailable,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOccupied ? 'OCCUPIED' : 'AVAILABLE',
                              style: GoogleFonts.poppins(
                                color: isOccupied
                                    ? AppTheme.statusReserved
                                    : AppTheme.statusAvailable,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Court Icon
                    Positioned(
                      bottom: 12,
                      left: 14,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.sports_tennis_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            court.name.split('(').first.trim(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Card Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: GoogleFonts.poppins(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      court.description,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // IoT Hardware Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.memory_rounded,
                              color: AppTheme.primaryDark, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Arduino LCD Equipped',
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _onBookPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isOccupied ? Colors.white : AppTheme.primary,
                          foregroundColor: isOccupied
                              ? AppTheme.primary
                              : Colors.white,
                          side: isOccupied
                              ? const BorderSide(color: AppTheme.primary)
                              : null,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          isOccupied ? 'View Next Slots' : 'Reserve Court',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. SMART IOT FEATURES SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFeaturesSection(bool isDesktop) {
    final features = [
      {
        'icon': Icons.screenshot_monitor_rounded,
        'title': 'Dedicated 16x2 LCD',
        'desc':
            'Each individual court features an Arduino Uno controller & LCD display that ticks your remaining session time second-by-second.',
        'tag': '1 LCD = 1 Court',
      },
      {
        'icon': Icons.qr_code_scanner_rounded,
        'title': 'Contactless QR Check-In',
        'desc':
            'Receive an instant digital QR pass upon booking. Scan it at the court gate to automatically start your session and illuminate the court.',
        'tag': 'Zero Delay Check-In',
      },
      {
        'icon': Icons.payments_rounded,
        'title': 'PayMongo Integration',
        'desc':
            'Frictionless Philippine payment gateway supporting GCash, Maya, GrabPay, and major credit cards with immediate automated receipting.',
        'tag': 'GCash • Maya • Cards',
      },
      {
        'icon': Icons.emoji_events_rounded,
        'title': 'Tournament Engine',
        'desc':
            'Dynamic single-elimination tournament generator with real-time bracket tracking, live seeds, and court assignment management.',
        'tag': 'Bracket Automation',
      },
    ];

    return Container(
      key: _featuresKey,
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 70.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader(
                badge: 'SMART COURT TECHNOLOGY',
                title: 'Engineered for Performance & Convenience',
                subtitle:
                    'We built LPC with custom IoT hardware and modern cloud technology so players never worry about court timing or queue conflicts.',
              ),
              const SizedBox(height: 48),

              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: features.map((f) {
                      final width = (constraints.maxWidth - (crossAxisCount - 1) * 24) / crossAxisCount;
                      return SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  f['icon'] as IconData,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  f['tag'] as String,
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.primaryDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                f['title'] as String,
                                style: GoogleFonts.poppins(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                f['desc'] as String,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. HOW IT WORKS SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildHowItWorksSection(bool isDesktop) {
    final steps = [
      {
        'step': '01',
        'title': 'Choose Court & Slot',
        'desc': 'Select your court and 1-hour booking duration between 7 AM and 12 MN.',
        'icon': Icons.event_available_rounded,
      },
      {
        'step': '02',
        'title': 'Fast Secure Checkout',
        'desc': 'Pay in seconds via PayMongo with GCash, Maya, cards, or e-wallets.',
        'icon': Icons.lock_clock_rounded,
      },
      {
        'step': '03',
        'title': 'Scan QR at Court',
        'desc': 'Arrive at LPC, show your digital QR code to check in instantly.',
        'icon': Icons.qr_code_rounded,
      },
      {
        'step': '04',
        'title': 'Play with LCD Timer',
        'desc': 'Your dedicated court LCD activates and counts down your playtime.',
        'icon': Icons.sports_tennis_rounded,
      },
    ];

    return Container(
      key: _howItWorksKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 70.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader(
                badge: 'SEAMLESS FLOW',
                title: 'How It Works in 4 Easy Steps',
                subtitle:
                    'From reservation to court-side play in under two minutes without waiting in line.',
              ),
              const SizedBox(height: 48),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 850;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: steps.map((s) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: _buildStepCard(s),
                              ),
                            );
                          }).toList(),
                        )
                      : Column(
                          children: steps.map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _buildStepCard(s),
                            );
                          }).toList(),
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(step['icon'] as IconData,
                    color: AppTheme.primaryDark, size: 22),
              ),
              Text(
                step['step'] as String,
                style: GoogleFonts.poppins(
                  color: AppTheme.primary.withOpacity(0.4),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            step['title'] as String,
            style: GoogleFonts.poppins(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step['desc'] as String,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. DOWNLOAD MOBILE APP SECTION (APK)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDownloadSection(bool isDesktop) {
    return Container(
      key: _downloadKey,
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 80.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(flex: 6, child: _buildDownloadTextContent(isDesktop)),
                    const SizedBox(width: 48),
                    Expanded(flex: 5, child: _buildDownloadPhoneVisual()),
                  ],
                )
              : Column(
                  children: [
                    _buildDownloadTextContent(isDesktop),
                    const SizedBox(height: 40),
                    _buildDownloadPhoneVisual(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDownloadTextContent(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.android_rounded, color: AppTheme.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'OFFICIAL ANDROID APP (APK)',
                style: GoogleFonts.poppins(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Download LPC for Android\nSign In & Book Anywhere',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isDesktop ? 34 : 26,
            fontWeight: FontWeight.w800,
            height: 1.22,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Install the official LPC mobile application directly on your Android phone. Register your player account, reserve slots, scan QR passes at the court gate, and receive live LCD countdown updates on your phone.',
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),

        // Key Mobile Perks
        _buildAppPerk(
          Icons.camera_alt_rounded,
          'Built-In Camera QR Scanner',
          'Scan your court gate QR code in under a second.',
        ),
        const SizedBox(height: 14),
        _buildAppPerk(
          Icons.notifications_active_rounded,
          'Instant Match & Timer Alerts',
          'Receive notifications 10 minutes before your booked slot ends.',
        ),
        const SizedBox(height: 14),
        _buildAppPerk(
          Icons.account_balance_wallet_rounded,
          'Seamless PayMongo Integration',
          'Direct app-switch payments with GCash, Maya, and cards.',
        ),
        const SizedBox(height: 32),

        // Download Action Button
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _downloadApk,
              icon: const Icon(Icons.download_rounded, size: 22),
              label: const Text('Download Android APK (v1.0.0)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: AppTheme.primary.withOpacity(0.5),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showDownloadGuideDialog(context),
              icon: const Icon(Icons.help_outline_rounded, size: 18, color: Colors.white),
              label: const Text('Install Guide', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF334155)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Compatible with Android 8.0 and above • Direct safe APK download',
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAppPerk(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                desc,
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadPhoneVisual() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.18),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Simulated App Screen Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sports_tennis_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LPC Mobile App',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('Sign In & Register Ready',
                            style: GoogleFonts.inter(
                                color: AppTheme.primaryDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('FREE',
                          style: TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF061406),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_rounded,
                          color: Color(0xFF39FF14), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Live Court LCD: 59:48 left',
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFF39FF14),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Buttons inside preview
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Sign In',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.primary),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Register',
                            style: GoogleFonts.poppins(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_download_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tap "Download Android APK" above to get started',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. TOURNAMENTS SHOWCASE
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTournamentShowcase(bool isDesktop) {
    return Container(
      key: _tournamentsKey,
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 70.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader(
                badge: 'COMPETITIVE PLAY',
                title: 'Tournaments & Single Elimination Brackets',
                subtitle:
                    'Join weekly club championships, track match progress live, and climb the LPC rankings.',
              ),
              const SizedBox(height: 48),

              Container(
                padding: EdgeInsets.all(isDesktop ? 40 : 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(flex: 5, child: _buildTournamentDetails()),
                          const SizedBox(width: 40),
                          Expanded(flex: 5, child: _buildBracketMockup()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildTournamentDetails(),
                          const SizedBox(height: 28),
                          _buildBracketMockup(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTournamentDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
          ),
          child: Text(
            'LPC Monthly Smash Series',
            style: GoogleFonts.poppins(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Single Elimination Championship',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Compete across 4, 8, or 16 player single-elimination brackets. Real-time court dispatching guarantees smooth match transitions on Court A and B.',
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _onBookPressed,
          icon: const Icon(Icons.emoji_events_rounded, size: 18),
          label: const Text('Join Next Tournament'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildBracketMockup() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'LIVE BRACKET PREVIEW',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMatchTile('Semi-Final 1', 'Carlo M.', 'Juan D.', 'Winner: Carlo M.'),
          const SizedBox(height: 10),
          _buildMatchTile('Semi-Final 2', 'Gabriel T.', 'Ana S.', 'Winner: Gabriel T.'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Finals: Carlo M. vs Gabriel T.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTile(String label, String p1, String p2, String outcome) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8), fontSize: 10)),
              Text('$p1 vs $p2',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Text(
            outcome,
            style: GoogleFonts.poppins(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. RATES & AMENITIES SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPricingSection(bool isDesktop) {
    return Container(
      key: _pricingKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 70.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader(
                badge: 'RATES & SCHEDULE',
                title: 'Simple, Transparent Pricing',
                subtitle:
                    'No membership required. Pay as you play with flexible online reservations.',
              ),
              const SizedBox(height: 48),

              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildPricingCard(
                    title: 'Regular Hours',
                    time: '7:00 AM - 5:00 PM',
                    price: '₱350',
                    per: '/ court hour',
                    features: [
                      'Full court access (up to 4 players)',
                      'Dedicated Arduino LCD countdown timer',
                      'High-grip cushioned acrylic flooring',
                      'Contactless QR code gate check-in',
                    ],
                    isFeatured: false,
                  ),
                  _buildPricingCard(
                    title: 'Peak Hours (Night)',
                    time: '5:00 PM - 12:00 Midnight',
                    price: '₱450',
                    per: '/ court hour',
                    features: [
                      'Full court access (up to 4 players)',
                      'High-lumen LED tournament floodlights',
                      'Dedicated Arduino LCD countdown timer',
                      'Chilled complimentary drinking water',
                      'Priority re-booking window',
                    ],
                    isFeatured: true,
                  ),
                  _buildPricingCard(
                    title: 'Equipment Rental',
                    time: 'Available On-Site',
                    price: '₱50',
                    per: '/ paddle set',
                    features: [
                      'Pro carbon fiber pickleball paddles',
                      'USAPA-approved outdoor tournament balls',
                      'Eye protection & grip overhauls',
                      'Ball pickup hoppers available',
                    ],
                    isFeatured: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String time,
    required String price,
    required String per,
    required List<String> features,
    required bool isFeatured,
  }) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isFeatured ? Colors.white : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isFeatured ? AppTheme.primary : AppTheme.cardBorder,
          width: isFeatured ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isFeatured
                ? AppTheme.primary.withOpacity(0.14)
                : const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFeatured)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'MOST POPULAR',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            time,
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryDark,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                per,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          ...features.map((feat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feat,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onBookPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isFeatured ? AppTheme.primary : AppTheme.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Reserve Slot'),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 9. FAQ ACCORDION SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFaqSection(bool isDesktop) {
    final faqs = [
      {
        'q': 'How do I download and install the Android app (APK)?',
        'a':
            'Click the "Download Android APK" button anywhere on this page. When the download finishes, tap the file in your notification bar or Downloads folder. If prompted to allow installation from unknown sources, toggle it on in Settings, then tap Install.'
      },
      {
        'q': 'Can I sign in or create a new account in the mobile app?',
        'a':
            'Yes! The Android app allows you to register a new account or sign in with your existing email and password. All your reservations, QR passes, and player profile sync automatically between web and mobile.'
      },
      {
        'q': 'How does the Arduino LCD display work at the court?',
        'a':
            'Each court has its own dedicated 16x2 LCD module. When you check in, the display shows your player name and ticks down your remaining session in real-time. When time expires, it flashes "TIME UP" and displays the next queued player.'
      },
      {
        'q': 'How do I pay using GCash or Maya?',
        'a':
            'During the reservation checkout, select PayMongo as your payment provider. You will be provided with an immediate QR or redirection link to authorize your GCash or Maya payment, and your reservation will confirm instantly.'
      },
      {
        'q': 'What happens if I arrive late for my booked slot?',
        'a':
            'Your slot timer begins automatically at your scheduled start time. You can scan your QR code anytime during your slot, but the timer will reflect the remaining time left until your booked end time.'
      },
      {
        'q': 'Can I cancel or reschedule my court booking?',
        'a':
            'Yes! You can manage and cancel your active reservations directly from the "My Reservations" tab up to 2 hours before your scheduled game time.'
      },
      {
        'q': 'Are paddles and balls available for beginners?',
        'a':
            'Absolutely! We have tournament-grade carbon fiber paddles and balls available for rental at our clubhouse station for a minimal fee of ₱50.'
      },
    ];

    return Container(
      key: _faqKey,
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 70.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              _buildSectionHeader(
                badge: 'FREQUENTLY ASKED QUESTIONS',
                title: 'Got Questions? We Have Answers',
                subtitle:
                    'Everything you need to know about downloading the app, reserving, paying, and playing at LPC.',
              ),
              const SizedBox(height: 40),

              ...faqs.asMap().entries.map((entry) {
                final idx = entry.key;
                final faq = entry.value;
                final isExpanded = _expandedFaqIndex == idx;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isExpanded ? AppTheme.background : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isExpanded
                          ? AppTheme.primary.withOpacity(0.5)
                          : AppTheme.cardBorder,
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: Key('faq_$idx'),
                      initiallyExpanded: isExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _expandedFaqIndex = expanded ? idx : null;
                        });
                      },
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
                      title: Text(
                        faq['q']!,
                        style: GoogleFonts.poppins(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                          child: Text(
                            faq['a']!,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 10. FINAL CTA SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFinalCtaSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 80.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 48.0 : 24.0,
              vertical: 48.0,
            ),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sports_tennis_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ready to Step on the Court?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isDesktop ? 34 : 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Join hundreds of pickleball enthusiasts enjoying real-time IoT courts, instant bookings, and weekly tournaments.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _onBookPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 34, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'Book Your Court Now',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _downloadApk,
                      icon: const Icon(Icons.android_rounded, size: 20),
                      label: const Text('Download Android APK'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 11. FOOTER
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDesktop) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64.0 : 20.0,
        vertical: 40.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + desc
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: AppTheme.primaryGradient,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/lpc_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.sports_tennis_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppConstants.appName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Lifestyle Pickleball Court is a state-of-the-art sports facility featuring IoT countdown displays, contactless QR passes, and automated tournament brackets.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop) ...[
                    const Spacer(),
                    // Hours
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OPERATING HOURS',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Monday – Sunday',
                            style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8), fontSize: 12)),
                        Text('7:00 AM – 12:00 MN',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(width: 48),
                    // Quick links
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUICK LINKS',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildFooterLink('Download Android APK', _downloadApk),
                        _buildFooterLink('Sign In', _navigateToLogin),
                        _buildFooterLink('Register', _navigateToRegister),
                        _buildFooterLink('Rates & Hours', () => _scrollToKey(_pricingKey)),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 30),
              const Divider(color: Color(0xFF1E293B)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© 2026 Lifestyle Pickleball Court (LPC). All rights reserved.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Powered by Flutter & Arduino IoT',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String badge,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: GoogleFonts.poppins(
              color: AppTheme.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter for subtle court lines in card graphics
// ─────────────────────────────────────────────────────────────────────────────
class _CourtLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Court outline
    canvas.drawRect(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16), paint);
    // Center net line
    canvas.drawLine(
      Offset(size.width / 2, 8),
      Offset(size.width / 2, size.height - 8),
      paint..strokeWidth = 3,
    );
    // Kitchen lines (non-volley zones)
    canvas.drawLine(
      Offset(size.width * 0.35, 8),
      Offset(size.width * 0.35, size.height - 8),
      paint..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(size.width * 0.65, 8),
      Offset(size.width * 0.65, size.height - 8),
      paint..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
