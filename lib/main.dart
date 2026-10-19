import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/court_provider.dart';
import 'providers/reservation_provider.dart';
import 'providers/tournament_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'services/mock_database.dart';

// ─── Global Firebase init state ───────────────────────────────────────────────
bool _firebaseReady = false;
bool _usingPlaceholder = false;
String? _firebaseError;

/// Returns true if the firebase_options.dart still has placeholder values.
bool _isPlaceholderConfig() {
  try {
    final opts = DefaultFirebaseOptions.currentPlatform;
    return opts.projectId == 'your-firebase-project-id' ||
        opts.apiKey.startsWith('YOUR-');
  } catch (_) {
    return true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect placeholder config before trying to init
  _usingPlaceholder = _isPlaceholderConfig();

  if (!_usingPlaceholder) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseReady = true;
    } catch (e) {
      _firebaseError = e.toString();
      _firebaseReady = false;
    }
  }

  runApp(const PickleballApp());
}

class PickleballApp extends StatefulWidget {
  const PickleballApp({super.key});

  @override
  State<PickleballApp> createState() => _PickleballAppState();
}

class _PickleballAppState extends State<PickleballApp> {
  bool _useDemoMode = false;

  void _enableDemoMode() {
    setState(() {
      AppConstants.isMockMode = true;
      MockDatabase.init();
      _useDemoMode = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If using placeholder config OR Firebase failed → show setup guide
    if ((_usingPlaceholder || !_firebaseReady) && !_useDemoMode) {
      return MaterialApp(
        title: 'LPC - Lifestyle Pickleball Court',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: _FirebaseSetupScreen(
          error: _firebaseError,
          onDemoMode: _enableDemoMode,
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourtProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()),
      ],
      child: MaterialApp(
        title: 'LPC - Lifestyle Pickleball Court',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const _AppRoot(),
      ),
    );
  }
}

// ─── Auth-gated router ────────────────────────────────────────────────────────
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_tennis_rounded,
                  size: 56, color: AppTheme.primary),
              SizedBox(height: 20),
              CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 3),
            ],
          ),
        ),
      );
    }

    return auth.isAuthenticated ? const HomeScreen() : const LandingScreen();
  }
}

// ─── Firebase not configured screen ──────────────────────────────────────────
class _FirebaseSetupScreen extends StatelessWidget {
  final String? error;
  final VoidCallback onDemoMode;
  const _FirebaseSetupScreen({this.error, required this.onDemoMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Logo
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_tennis_rounded,
                    size: 44,
                    color: AppTheme.background,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scaleXY(begin: 0.7, end: 1, duration: 700.ms, curve: Curves.elasticOut),
                const SizedBox(height: 20),
                Text(
                  'Pickleball Hub',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                Text(
                  'IoT Court Reservation System',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                const SizedBox(height: 36),

                // Warning banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.statusReserved.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.statusReserved.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.statusReserved, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Firebase is not configured yet.\nFollow the steps below to connect your project.',
                          style: GoogleFonts.inter(
                            color: AppTheme.statusReserved,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: onDemoMode,
                    icon: const Icon(Icons.sports_esports_outlined, size: 20),
                    label: const Text('Run in Demo Mode (In-Memory)'),
                  ),
                ).animate().fadeIn(delay: 450.ms, duration: 500.ms),
                const SizedBox(height: 28),

                // Setup steps
                _buildStepsCard(),
                const SizedBox(height: 20),

                // Firestore seed hint
                _buildSeedCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepsCard() {
    const steps = [
      _Step(
        number: '1',
        title: 'Create Firebase Project',
        subtitle: 'console.firebase.google.com\nEnable: Auth, Firestore, Realtime DB',
        icon: Icons.cloud_outlined,
      ),
      _Step(
        number: '2',
        title: 'Add Android App',
        subtitle: 'Package: com.example.pickleballreservation\nDownload google-services.json → android/app/',
        icon: Icons.android_rounded,
      ),
      _Step(
        number: '3',
        title: 'Run FlutterFire CLI',
        subtitle: 'dart pub global activate flutterfire_cli\nflutterfire configure',
        icon: Icons.terminal_rounded,
        isCode: true,
      ),
      _Step(
        number: '4',
        title: 'Add Courts in Firestore',
        subtitle: 'Collection: courts\nFields: name, description, isActive: true',
        icon: Icons.add_circle_outline,
      ),
      _Step(
        number: '5',
        title: 'Set Admin Role',
        subtitle: 'Register → Firestore → users/{uid} → role: "admin"',
        icon: Icons.admin_panel_settings_outlined,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: AppTheme.background, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Setup Guide',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...steps.asMap().entries.map((e) => _StepTile(
                step: e.value,
                isLast: e.key == steps.length - 1,
              )),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 500.ms).slideY(begin: 0.06, end: 0, delay: 500.ms, duration: 500.ms);
  }

  Widget _buildSeedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Sample Firestore Court Document',
                style: GoogleFonts.poppins(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '{\n  "name": "Court A",\n  "description": "Professional pickleball court",\n  "isActive": true\n}',
              style: GoogleFonts.robotoMono(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add 4 documents like this in the courts collection.',
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 500.ms);
  }
}

class _Step {
  final String number;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCode;

  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isCode = false,
  });
}

class _StepTile extends StatelessWidget {
  final _Step step;
  final bool isLast;

  const _StepTile({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line + number
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step.number,
                    style: GoogleFonts.poppins(
                      color: AppTheme.background,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppTheme.cardBorder,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(step.icon, size: 15, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        step.title,
                        style: GoogleFonts.poppins(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.subtitle,
                    style: step.isCode
                        ? GoogleFonts.robotoMono(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            height: 1.6,
                            backgroundColor:
                                AppTheme.background.withOpacity(0.6),
                          )
                        : GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
