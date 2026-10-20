import 'package:firebase_database/firebase_database.dart';
import '../models/court_status_model.dart';
import '../core/constants/app_constants.dart';
import 'mock_database.dart';
import 'lcd_service.dart';

class CourtService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ─── Single Court Status ──────────────────────────────────────────────────────
  Stream<CourtStatusModel> getCourtStatus(String courtId) {
    if (AppConstants.isMockMode) {
      return MockDatabase.statusesController.stream.map((map) {
        return map[courtId] ?? CourtStatusModel.empty(courtId);
      });
    }

    return _db
        .ref('${AppConstants.courtStatusPath}/$courtId')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) {
        return CourtStatusModel.empty(courtId);
      }
      return CourtStatusModel.fromRealtimeDB(
        Map<dynamic, dynamic>.from(event.snapshot.value as Map),
        courtId,
      );
    });
  }

  // ─── All Courts Status ────────────────────────────────────────────────────────
  Stream<Map<String, CourtStatusModel>> getAllCourtStatuses(
      List<String> courtIds) {
    if (AppConstants.isMockMode) {
      return MockDatabase.statusesController.stream.map((map) {
        final res = <String, CourtStatusModel>{};
        for (final id in courtIds) {
          res[id] = map[id] ?? CourtStatusModel.empty(id);
        }
        return res;
      });
    }

    return _db
        .ref(AppConstants.courtStatusPath)
        .onValue
        .map((event) {
      final result = <String, CourtStatusModel>{};
      if (event.snapshot.value == null) {
        for (final id in courtIds) {
          result[id] = CourtStatusModel.empty(id);
        }
        return result;
      }

      final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      for (final id in courtIds) {
        if (raw.containsKey(id)) {
          result[id] = CourtStatusModel.fromRealtimeDB(
            Map<dynamic, dynamic>.from(raw[id] as Map),
            id,
          );
        } else {
          result[id] = CourtStatusModel.empty(id);
        }
      }
      return result;
    });
  }

  // ─── Update Status (called on reservation confirm & IoT events) ───────────────
  Future<void> updateCourtStatus({
    required String courtId,
    required bool isOccupied,
    String? reservationId,
    String? reservedByName,
    DateTime? bookedUntil,
    DateTime? occupiedSince,
    bool forceOverride = false,
  }) async {
    if (AppConstants.isMockMode) {
      MockDatabase.courtStatuses[courtId] = CourtStatusModel(
        courtId: courtId,
        isOccupied: isOccupied,
        reservationId: reservationId,
        reservedByName: reservedByName,
        bookedUntil: bookedUntil,
        occupiedSince: occupiedSince,
      );
      MockDatabase.publishAll();
      return;
    }

    // ── Protection for Ongoing Session ─────────────────────────────────────────
    // If court is currently occupied and current player's time has NOT expired,
    // do NOT overwrite the active player! Queue this new booking as nextPlayerName.
    if (!forceOverride) {
      try {
        final snap =
            await _db.ref('${AppConstants.courtStatusPath}/$courtId').get();
        if (snap.exists && snap.value != null) {
          final current = Map<dynamic, dynamic>.from(snap.value as Map);
          final currentOccupied = current['isOccupied'] as bool? ?? false;
          final currentBookedUntil = current['bookedUntil'] as int?;
          final currentName = (current['reservedByName'] ?? '').toString();
          final nowMs = DateTime.now().millisecondsSinceEpoch;

          final bool isCurrentSessionActive = currentOccupied &&
              currentBookedUntil != null &&
              currentBookedUntil > nowMs;

          if (isCurrentSessionActive) {
            // If the incoming booking is for a different player (or next time slot)
            if (reservedByName != null &&
                reservedByName.isNotEmpty &&
                reservedByName != currentName) {
              await _db.ref('${AppConstants.courtStatusPath}/$courtId').update({
                'nextPlayerName': reservedByName,
                'nextReservationId': reservationId,
                'nextBookedUntil': bookedUntil?.millisecondsSinceEpoch,
              });
            }
            // Do not overwrite active player's screen/countdown!
            return;
          }
        }
      } catch (_) {}
    }

    await _db
        .ref('${AppConstants.courtStatusPath}/$courtId')
        .update({
      'isOccupied': isOccupied,
      'reservationId': reservationId,
      'reservedByName': reservedByName,
      'bookedUntil': bookedUntil?.millisecondsSinceEpoch,
      'occupiedSince':
          isOccupied ? (occupiedSince ?? DateTime.now()).millisecondsSinceEpoch : null,
    });

    try {
      await _db.ref('lcd_override/$courtId').update({'enabled': false});
    } catch (_) {}
  }

  /// Promotes the queued next player to active session once the previous player's time is up.
  Future<bool> promoteNextPlayer(String courtId) async {
    if (AppConstants.isMockMode) return false;
    try {
      final snap =
          await _db.ref('${AppConstants.courtStatusPath}/$courtId').get();
      if (!snap.exists || snap.value == null) return false;

      final current = Map<dynamic, dynamic>.from(snap.value as Map);
      final nextPlayer = current['nextPlayerName']?.toString();
      if (nextPlayer == null || nextPlayer.isEmpty) {
        await clearCourtStatus(courtId);
        return false;
      }

      final nextBookedUntil = current['nextBookedUntil'] as int?;
      final nextResId = current['nextReservationId']?.toString();
      final now = DateTime.now();
      final endTime = nextBookedUntil != null &&
              nextBookedUntil > now.millisecondsSinceEpoch
          ? DateTime.fromMillisecondsSinceEpoch(nextBookedUntil)
          : now.add(const Duration(hours: 1));

      await _db.ref('${AppConstants.courtStatusPath}/$courtId').set({
        'isOccupied': true,
        'reservationId': nextResId,
        'reservedByName': nextPlayer,
        'bookedUntil': endTime.millisecondsSinceEpoch,
        'occupiedSince': now.millisecondsSinceEpoch,
        'nextPlayerName': null,
        'nextReservationId': null,
        'nextBookedUntil': null,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Clear Status (on cancel / timeout) ──────────────────────────────────────
  Future<void> clearCourtStatus(String courtId) async {
    if (AppConstants.isMockMode) {
      MockDatabase.courtStatuses[courtId] = CourtStatusModel.empty(courtId);
      MockDatabase.publishAll();
      return;
    }

    await _db.ref('${AppConstants.courtStatusPath}/$courtId').set({
      'isOccupied': false,
      'reservationId': null,
      'reservedByName': null,
      'bookedUntil': null,
      'occupiedSince': null,
      'nextPlayerName': null,
    });

    try {
      await _db.ref('lcd_override/$courtId').update({'enabled': false});
    } catch (_) {}

    try {
      await LcdService.logAvailable(courtId: courtId);
    } catch (_) {}
  }

  // ─── Set Next Player (LCD display helper) ─────────────────────────────────────
  Future<void> setNextPlayer(String courtId, String? nextPlayerName) async {
    if (AppConstants.isMockMode) {
      final existing = MockDatabase.courtStatuses[courtId] ??
          CourtStatusModel.empty(courtId);
      MockDatabase.courtStatuses[courtId] = CourtStatusModel(
        courtId: existing.courtId,
        isOccupied: existing.isOccupied,
        occupiedSince: existing.occupiedSince,
        bookedUntil: existing.bookedUntil,
        reservationId: existing.reservationId,
        reservedByName: existing.reservedByName,
        nextPlayerName: nextPlayerName,
      );
      MockDatabase.publishAll();
      return;
    }

    await _db
        .ref('${AppConstants.courtStatusPath}/$courtId')
        .update({'nextPlayerName': nextPlayerName});
  }
}
