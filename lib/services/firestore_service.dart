import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/court_model.dart';
import '../models/reservation_model.dart';
import '../models/tournament_model.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';
import 'mock_database.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── COURTS ──────────────────────────────────────────────────────────────────

  Stream<List<CourtModel>> getCourts() {
    if (AppConstants.isMockMode) {
      return MockDatabase.courtsController.stream;
    }

    return _db
        .collection(AppConstants.courtsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CourtModel.fromFirestore(d.data(), d.id)).toList());
  }

  Future<void> addCourt(CourtModel court) async {
    if (AppConstants.isMockMode) {
      final newCourt = CourtModel(
        id: 'court_${DateTime.now().millisecondsSinceEpoch}',
        name: court.name,
        description: court.description,
        isActive: court.isActive,
        imageUrl: court.imageUrl,
      );
      MockDatabase.courts.add(newCourt);
      MockDatabase.publishAll();
      return;
    }
    await _db.collection(AppConstants.courtsCollection).add(court.toFirestore());
  }

  Future<void> updateCourt(CourtModel court) async {
    if (AppConstants.isMockMode) {
      final index = MockDatabase.courts.indexWhere((c) => c.id == court.id);
      if (index != -1) {
        MockDatabase.courts[index] = court;
        MockDatabase.publishAll();
      }
      return;
    }
    await _db
        .collection(AppConstants.courtsCollection)
        .doc(court.id)
        .update(court.toFirestore());
  }

  // ─── RESERVATIONS ─────────────────────────────────────────────────────────────

  Stream<List<ReservationModel>> getReservationsByDate(
      String courtId, String date) {
    if (AppConstants.isMockMode) {
      return MockDatabase.reservationsController.stream.map((list) {
        return list
            .where((r) =>
                r.courtId == courtId &&
                r.date == date &&
                AppConstants.activeStatuses.contains(r.status))
            .toList();
      });
    }

    return _db
        .collection(AppConstants.reservationsCollection)
        .where('courtId', isEqualTo: courtId)
        .where('date', isEqualTo: date)
        .where('status', whereIn: AppConstants.activeStatuses)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReservationModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Stream<List<ReservationModel>> getUserReservations(String userId) {
    if (AppConstants.isMockMode) {
      return MockDatabase.reservationsController.stream.map((list) {
        final filtered = list.where((r) => r.userId == userId).toList();
        filtered.sort((a, b) => b.startTime.compareTo(a.startTime));
        return filtered;
      });
    }

    return _db
        .collection(AppConstants.reservationsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => ReservationModel.fromFirestore(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.startTime.compareTo(a.startTime));
          return list;
        });
  }

  Stream<List<ReservationModel>> getAllReservations() {
    if (AppConstants.isMockMode) {
      return MockDatabase.reservationsController.stream.map((list) {
        final sorted = List<ReservationModel>.from(list);
        sorted.sort((a, b) => b.startTime.compareTo(a.startTime));
        return sorted;
      });
    }

    return _db
        .collection(AppConstants.reservationsCollection)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReservationModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Stream<List<ReservationModel>> getAllActiveReservations() {
    if (AppConstants.isMockMode) {
      return MockDatabase.reservationsController.stream.map((list) {
        return list
            .where((r) =>
                r.status == AppConstants.statusPending ||
                r.status == AppConstants.statusConfirmed ||
                r.status == AppConstants.statusActive)
            .toList();
      });
    }

    return _db
        .collection(AppConstants.reservationsCollection)
        .where('status', whereIn: [
          AppConstants.statusPending,
          AppConstants.statusConfirmed,
          AppConstants.statusActive,
        ])
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReservationModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<String> createReservation(ReservationModel reservation) async {
    if (AppConstants.isMockMode) {
      final id = 'res_${DateTime.now().millisecondsSinceEpoch}';
      final newRes = ReservationModel(
        id: id,
        courtId: reservation.courtId,
        courtName: reservation.courtName,
        userId: reservation.userId,
        userName: reservation.userName,
        date: reservation.date,
        startTime: reservation.startTime,
        endTime: reservation.endTime,
        status: reservation.status,
        createdAt: reservation.createdAt,
        paymentMethod: reservation.paymentMethod,
        paymentReference: reservation.paymentReference,
        amount: reservation.amount,
      );
      MockDatabase.reservations.add(newRes);
      MockDatabase.publishAll();
      return id;
    }

    final doc = await _db
        .collection(AppConstants.reservationsCollection)
        .add(reservation.toFirestore());
    return doc.id;
  }

  Future<void> updateReservationStatus(String id, String status) async {
    if (AppConstants.isMockMode) {
      final index = MockDatabase.reservations.indexWhere((r) => r.id == id);
      if (index != -1) {
        MockDatabase.reservations[index] =
            MockDatabase.reservations[index].copyWith(status: status);
        MockDatabase.publishAll();
      }
      return;
    }

    await _db
        .collection(AppConstants.reservationsCollection)
        .doc(id)
        .update({'status': status});
  }

  Future<void> cancelReservation(String id) =>
      updateReservationStatus(id, AppConstants.statusCancelled);

  Future<void> rescheduleReservation({
    required String reservationId,
    required String newCourtId,
    required String newCourtName,
    required String newDate,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    if (AppConstants.isMockMode) {
      final index =
          MockDatabase.reservations.indexWhere((r) => r.id == reservationId);
      if (index != -1) {
        MockDatabase.reservations[index] =
            MockDatabase.reservations[index].copyWith(
          courtId: newCourtId,
          courtName: newCourtName,
          date: newDate,
          startTime: newStartTime,
          endTime: newEndTime,
          status: AppConstants.statusConfirmed,
        );
        MockDatabase.publishAll();
      }
      return;
    }

    await _db
        .collection(AppConstants.reservationsCollection)
        .doc(reservationId)
        .update({
      'courtId': newCourtId,
      'courtName': newCourtName,
      'date': newDate,
      'startTime': Timestamp.fromDate(newStartTime),
      'endTime': Timestamp.fromDate(newEndTime),
      'status': AppConstants.statusConfirmed,
    });
  }

  Future<void> updateReservationPayment({
    required String docId,
    required String paymentMethod,
    required String paymentReference,
    required double amount,
  }) async {
    if (AppConstants.isMockMode) {
      final index = MockDatabase.reservations.indexWhere((r) => r.id == docId);
      if (index != -1) {
        MockDatabase.reservations[index] =
            MockDatabase.reservations[index].copyWith(
          paymentMethod: paymentMethod,
          paymentReference: paymentReference,
          amount: amount,
        );
        MockDatabase.publishAll();
      }
      return;
    }

    await _db
        .collection(AppConstants.reservationsCollection)
        .doc(docId)
        .update({
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      'amount': amount,
    });
  }

  /// Returns false if an overlapping confirmed/active reservation exists.
  Future<bool> isSlotAvailable(
      String courtId, String date, DateTime start, DateTime end) async {
    if (AppConstants.isMockMode) {
      final matches = MockDatabase.reservations
          .where((r) =>
              r.courtId == courtId &&
              r.date == date &&
              AppConstants.activeStatuses.contains(r.status))
          .toList();

      for (final res in matches) {
        if (res.overlaps(start, end)) return false;
      }
      return true;
    }

    final snap = await _db
        .collection(AppConstants.reservationsCollection)
        .where('courtId', isEqualTo: courtId)
        .where('date', isEqualTo: date)
        .where('status', whereIn: AppConstants.activeStatuses)
        .get();

    for (final doc in snap.docs) {
      final res = ReservationModel.fromFirestore(doc.data(), doc.id);
      if (res.overlaps(start, end)) return false;
    }
    return true;
  }

  // ─── TOURNAMENTS ──────────────────────────────────────────────────────────────

  Stream<List<TournamentModel>> getTournaments() {
    if (AppConstants.isMockMode) {
      return MockDatabase.tournamentsController.stream.map((list) {
        final sorted = List<TournamentModel>.from(list);
        sorted.sort((a, b) => b.date.compareTo(a.date));
        return sorted;
      });
    }

    return _db
        .collection(AppConstants.tournamentsCollection)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TournamentModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Stream<TournamentModel?> getTournamentById(String id) {
    if (AppConstants.isMockMode) {
      return MockDatabase.tournamentsController.stream.map((list) {
        for (final t in list) {
          if (t.id == id) return t;
        }
        return null;
      });
    }

    return _db
        .collection(AppConstants.tournamentsCollection)
        .doc(id)
        .snapshots()
        .map((snap) =>
            snap.exists ? TournamentModel.fromFirestore(snap.data()!, snap.id) : null);
  }

  Future<String> createTournament(TournamentModel tournament) async {
    if (AppConstants.isMockMode) {
      final id = 'tour_${DateTime.now().millisecondsSinceEpoch}';
      final newTour = TournamentModel(
        id: id,
        name: tournament.name,
        date: tournament.date,
        status: tournament.status,
        format: tournament.format,
        players: tournament.players,
        rounds: tournament.rounds,
        description: tournament.description,
        courtId: tournament.courtId,
        createdAt: tournament.createdAt,
      );
      MockDatabase.tournaments.add(newTour);
      MockDatabase.publishAll();
      return id;
    }

    final doc = await _db
        .collection(AppConstants.tournamentsCollection)
        .add(tournament.toFirestore());
    return doc.id;
  }

  Future<void> updateTournament(TournamentModel tournament) async {
    if (AppConstants.isMockMode) {
      final index = MockDatabase.tournaments.indexWhere((t) => t.id == tournament.id);
      if (index != -1) {
        MockDatabase.tournaments[index] = tournament;
        MockDatabase.publishAll();
      }
      return;
    }

    await _db
        .collection(AppConstants.tournamentsCollection)
        .doc(tournament.id)
        .update(tournament.toFirestore());
  }

  Future<void> deleteTournament(String id) async {
    if (AppConstants.isMockMode) {
      MockDatabase.tournaments.removeWhere((t) => t.id == id);
      MockDatabase.publishAll();
      return;
    }
    await _db.collection(AppConstants.tournamentsCollection).doc(id).delete();
  }

  // ─── USER MANAGEMENT ──────────────────────────────────────────────────────────

  Stream<List<UserModel>> getAllUsers() {
    if (AppConstants.isMockMode) {
      return MockDatabase.usersController.stream;
    }

    return _db
        .collection(AppConstants.usersCollection)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    if (AppConstants.isMockMode) {
      final index = MockDatabase.users.indexWhere((u) => u.uid == uid);
      if (index != -1) {
        MockDatabase.users[index] =
            MockDatabase.users[index].copyWith(role: newRole);
        if (MockDatabase.currentUser?.uid == uid) {
          MockDatabase.currentUser = MockDatabase.users[index];
        }
        MockDatabase.publishAll();
      }
      return;
    }

    await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'role': newRole});
  }

  Future<void> updateUser(UserModel user) async {
    if (AppConstants.isMockMode) {
      final index = MockDatabase.users.indexWhere((u) => u.uid == user.uid);
      if (index != -1) {
        MockDatabase.users[index] = user;
        if (MockDatabase.currentUser?.uid == user.uid) {
          MockDatabase.currentUser = user;
        }
        MockDatabase.publishAll();
      }
      return;
    }

    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update(user.toFirestore());
  }

  Future<void> createUser(UserModel user) async {
    if (AppConstants.isMockMode) {
      MockDatabase.users.add(user);
      MockDatabase.publishAll();
      return;
    }

    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(user.toFirestore());
  }

  Future<void> deleteUser(String uid) async {
    if (AppConstants.isMockMode) {
      MockDatabase.users.removeWhere((u) => u.uid == uid);
      MockDatabase.publishAll();
      return;
    }

    await _db.collection(AppConstants.usersCollection).doc(uid).delete();
  }
}
