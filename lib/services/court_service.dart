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
