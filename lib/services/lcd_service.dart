import 'package:firebase_database/firebase_database.dart';
import '../core/constants/app_constants.dart';

/// LcdService writes lcd_override/<courtId> and lcd_log/<courtId> nodes in
/// Firebase Realtime DB.
///
/// Primary flow (auto — via Python bridge):
///  Admin scans QR → CourtService.updateCourtStatus() writes court_status
///  → Python bridge reads court_status → sends CHECKIN serial command
///  → Arduino LCD updates automatically.
///
/// Admin override flow (manual — via LCD Control Sheet):
///  Admin opens LCD Control Sheet → taps "Set Custom Message"
///  → LcdService.setCustomMessage() writes lcd_override/{courtId}
///  → Python bridge reads lcd_override → sends CUSTOM: serial command
///  → Arduino shows the custom text.
class LcdService {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ─── Check-In Log ────────────────────────────────────────────────────────────

  /// Called after a successful check-in. Writes an LCD event log.
  static Future<void> logCheckIn({
    required String courtId,
    required String playerName,
    required DateTime endTime,
  }) async {
    if (AppConstants.isMockMode) return;

    final now = DateTime.now();
    final remainingSec = endTime.difference(now).inSeconds.clamp(0, 86400);

    try {
      await _db.ref('lcd_log/$courtId').set({
        'event': 'CHECKIN',
        'playerName': playerName,
        'checkedInAt': now.millisecondsSinceEpoch,
        'bookedUntil': endTime.millisecondsSinceEpoch,
        'remainingSeconds': remainingSec,
      });
    } catch (_) {
      // Non-critical: ignore failures so check-in still completes
    }
  }

  /// Called when a court is cleared (reservation ends or cancelled).
  static Future<void> logAvailable({required String courtId}) async {
    if (AppConstants.isMockMode) return;

    try {
      await _db.ref('lcd_log/$courtId').set({
        'event': 'AVAILABLE',
        'clearedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // ─── Custom Message Override ──────────────────────────────────────────────────

  /// Writes a 2-line custom message override to lcd_override/{courtId}.
  /// The Python bridge reads this and sends a CUSTOM: serial command to
  /// the Arduino — overriding whatever it normally shows.
  ///
  /// [line1] and [line2] are max 16 characters each (truncated on Arduino).
  static Future<void> setCustomMessage({
    required String courtId,
    required String line1,
    required String line2,
  }) async {
    if (AppConstants.isMockMode) return;

    try {
      await _db.ref('lcd_override/$courtId').set({
        'enabled': true,
        'line1': line1.substring(0, line1.length.clamp(0, 16)),
        'line2': line2.substring(0, line2.length.clamp(0, 16)),
        'setAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Disables the custom override so the LCD reverts to auto mode.
  static Future<void> clearOverride({required String courtId}) async {
    if (AppConstants.isMockMode) return;

    try {
      await _db.ref('lcd_override/$courtId').update({
        'enabled': false,
        'clearedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // ─── Next Player ─────────────────────────────────────────────────────────────

  /// Sets the nextPlayerName on court_status/{courtId} so the Python bridge
  /// includes it in the CHECKIN command (4th segment). The Arduino shows
  /// "Next: <name>" when the countdown reaches zero.
  static Future<void> setNextPlayer({
    required String courtId,
    required String? nextPlayerName,
  }) async {
    if (AppConstants.isMockMode) return;

    try {
      await _db
          .ref('court_status/$courtId')
          .update({'nextPlayerName': nextPlayerName});
    } catch (_) {}
  }

  // ─── Restart / Reload LCD ───────────────────────────────────────────────────

  /// Signals the Python bridge and Arduino to perform a restart/refresh animation
  /// and reload the current court status on the LCD.
  static Future<void> restartLcd({required String courtId}) async {
    if (AppConstants.isMockMode) return;

    try {
      await _db.ref('lcd_command/$courtId').set({
        'command': 'RESTART',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Sets the currently active court being viewed/controlled on LCD.
  static Future<void> setActiveCourt({
    required String courtId,
    required String courtName,
  }) async {
    if (AppConstants.isMockMode) return;

    try {
      await _db.ref('active_lcd_target').set({
        'courtId': courtId,
        'courtName': courtName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Streams the live connection status of the Arduino.
  static Stream<DatabaseEvent> streamArduinoStatus({required String courtId}) {
    return _db.ref('arduino_status').onValue;
  }
}
