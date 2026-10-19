class AppConstants {
  AppConstants._();

  // ─── App Info ────────────────────────────────────────────────────────────────
  static const String appName = 'LPC Lifestyle Pickleball Court';
  static const String brandShort = 'LPC';
  static const String brandTagline = 'Lifestyle Pickleball Court';
  static const String brandSubtitle = 'IoT Smart Court & Reservation Hub';
  static const String appVersion = '1.0.0';

  // ─── Court Config ────────────────────────────────────────────────────────────
  static const int openingHour = 7;   // 7:00 AM
  static const int closingHour = 24;  // 12:00 Midnight (last slot starts 11 PM)
  static const int slotDurationMinutes = 60; // 1-hour slots
  static const int maxReservationSlots = 24; // No limit — select as many as needed

  // ─── Firebase Collections ────────────────────────────────────────────────────
  static const String courtsCollection = 'courts';
  static const String reservationsCollection = 'reservations';
  static const String usersCollection = 'users';
  static const String tournamentsCollection = 'tournaments';

  // ─── Firebase Realtime DB Paths ──────────────────────────────────────────────
  static const String courtStatusPath = 'court_status';

  // ─── Reservation Statuses ────────────────────────────────────────────────────
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static const List<String> activeStatuses = [
    statusPending,
    statusConfirmed,
    statusActive,
  ];

  // ─── User Roles ──────────────────────────────────────────────────────────────
  static const String rolePlayer = 'player';
  static const String roleAdmin = 'admin';

  // ─── Tournament ──────────────────────────────────────────────────────────────
  static const String formatSingleElimination = 'single_elimination';
  static const String tournamentUpcoming = 'upcoming';
  static const String tournamentOngoing = 'ongoing';
  static const String tournamentCompleted = 'completed';

  static const List<int> validBracketSizes = [4, 8, 16];

  // ─── Mock Mode Toggle ────────────────────────────────────────────────────────
  static bool isMockMode = false;
}
