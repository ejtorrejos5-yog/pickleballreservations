import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/reservation_model.dart';
import '../models/court_model.dart';
import '../services/firestore_service.dart';
import '../services/court_service.dart';
import '../core/utils/date_helpers.dart';

class ReservationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final CourtService _courtService = CourtService();

  List<ReservationModel> _userReservations = [];
  List<ReservationModel> _allReservations = [];
  bool _isLoading = false;
  String? _error;

  List<ReservationModel> get userReservations => _userReservations;
  List<ReservationModel> get allReservations => _allReservations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<List<ReservationModel>>? _sub;
  StreamSubscription<List<ReservationModel>>? _allSub;

  // ─── Load user reservations ────────────────────────────────────────────────
  void loadUserReservations(String userId) {
    _sub?.cancel();
    _userReservations = []; // Clear immediately to avoid showing old user data
    notifyListeners();
    _sub = _firestoreService.getUserReservations(userId).listen((list) {
      _userReservations = list;
      notifyListeners();
    });
  }

  // ─── Load all reservations (Admin) ─────────────────────────────────────────
  void loadAllReservations() {
    _allSub?.cancel();
    _allReservations = [];
    notifyListeners();
    _allSub = _firestoreService.getAllReservations().listen((list) {
      _allReservations = list;
      notifyListeners();
    });
  }

  // ─── Clear on Logout / Switch User ─────────────────────────────────────────
  void clear() {
    _sub?.cancel();
    _allSub?.cancel();
    _userReservations = [];
    _allReservations = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // ─── Create Reservation ────────────────────────────────────────────────────
  Future<ReservationModel?> createReservation({
    required CourtModel court,
    required String userId,
    required String userName,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    String status = 'confirmed',
    String paymentMethod = 'none',
    String paymentReference = '',
    double amount = 0.0,
  }) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final dateStr = DateHelpers.toFirestoreDate(date);

      // 1. Check availability
      final available = await _firestoreService.isSlotAvailable(
          court.id, dateStr, startTime, endTime);
      if (!available) {
        _error = 'This time slot is already taken. Please choose another.';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // 2. Create Firestore doc
      final reservation = ReservationModel(
        id: '',
        courtId: court.id,
        courtName: court.name,
        userId: userId,
        userName: userName,
        date: dateStr,
        startTime: startTime,
        endTime: endTime,
        status: status,
        createdAt: DateTime.now(),
        paymentMethod: paymentMethod,
        paymentReference: paymentReference,
        amount: amount,
      );
      final docId = await _firestoreService.createReservation(reservation);

      // 3. Update Realtime DB (reserved — not yet occupied)
      try {
        await _courtService.updateCourtStatus(
          courtId: court.id,
          isOccupied: false,
          reservationId: docId,
          reservedByName: userName,
          bookedUntil: endTime,
        );
      } catch (e) {
        debugPrint('Warning: Realtime DB update failed: $e');
      }

      final createdRes = reservation.copyWith(
        status: status,
        paymentMethod: paymentMethod,
        paymentReference: paymentReference,
        amount: amount,
      );
      final finalRes = ReservationModel(
        id: docId,
        courtId: createdRes.courtId,
        courtName: createdRes.courtName,
        userId: createdRes.userId,
        userName: createdRes.userName,
        date: createdRes.date,
        startTime: createdRes.startTime,
        endTime: createdRes.endTime,
        status: createdRes.status,
        createdAt: createdRes.createdAt,
        paymentMethod: createdRes.paymentMethod,
        paymentReference: createdRes.paymentReference,
        amount: createdRes.amount,
      );

      _isLoading = false;
      notifyListeners();
      return finalRes;
    } catch (e) {
      _error = 'Failed to book. Please try again: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ─── Cancel Reservation ────────────────────────────────────────────────────
  Future<void> cancelReservation(ReservationModel reservation) async {
    await _firestoreService.cancelReservation(reservation.id);
    try {
      await _courtService.clearCourtStatus(reservation.courtId);
    } catch (e) {
      debugPrint('Warning: Realtime DB clear failed: $e');
    }
  }

  // ─── Reschedule Reservation ────────────────────────────────────────────────
  Future<bool> rescheduleReservation({
    required ReservationModel reservation,
    required String newCourtId,
    required String newCourtName,
    required String newDate,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.rescheduleReservation(
        reservationId: reservation.id,
        newCourtId: newCourtId,
        newCourtName: newCourtName,
        newDate: newDate,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
      );
      if (reservation.courtId != newCourtId) {
        await _courtService.clearCourtStatus(reservation.courtId);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to reschedule: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Slot availability stream ──────────────────────────────────────────────
  Stream<List<ReservationModel>> getSlotReservations(
          String courtId, String date) =>
      _firestoreService.getReservationsByDate(courtId, date);

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _allSub?.cancel();
    super.dispose();
  }
}
