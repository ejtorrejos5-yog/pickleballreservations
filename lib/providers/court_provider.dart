import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/court_model.dart';
import '../models/court_status_model.dart';
import '../services/firestore_service.dart';
import '../services/court_service.dart';
import '../core/constants/app_constants.dart';

class CourtProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final CourtService _courtService = CourtService();

  List<CourtModel> _courts = [];
  Map<String, CourtStatusModel> _courtStatuses = {};
  bool _isLoading = true;
  final Set<String> _clearingCourtIds = {};

  List<CourtModel> get courts => _courts;
  Map<String, CourtStatusModel> get courtStatuses => _courtStatuses;
  bool get isLoading => _isLoading;

  StreamSubscription<List<CourtModel>>? _courtsSub;
  StreamSubscription<Map<String, CourtStatusModel>>? _statusSub;
  Timer? _expiryCheckTimer;

  CourtProvider() {
    _init();
  }

  void _init() {
    _expiryCheckTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkAndAutoReleaseExpiredCourts(),
    );

    _courtsSub = _firestoreService.getCourts().listen((courts) {
      _courts = courts;
      _isLoading = false;
      notifyListeners();
      _subscribeToStatuses(courts.map((c) => c.id).toList());
    });
  }

  void _subscribeToStatuses(List<String> courtIds) {
    _statusSub?.cancel();
    if (courtIds.isEmpty) return;
    _statusSub =
        _courtService.getAllCourtStatuses(courtIds).listen((statuses) {
      _courtStatuses = statuses;
      _checkAndAutoReleaseExpiredCourts();
      notifyListeners();
    });
  }

  Future<void> _checkAndAutoReleaseExpiredCourts() async {
    bool stateChanged = false;

    for (final status in _courtStatuses.values) {
      if (status.isExpired && (status.isOccupiedRaw || status.reservationId != null)) {
        if (_clearingCourtIds.contains(status.courtId)) continue;
        _clearingCourtIds.add(status.courtId);
        stateChanged = true;

        try {
          await _courtService.clearCourtStatus(status.courtId);
          if (status.reservationId != null) {
            await _firestoreService.updateReservationStatus(
              status.reservationId!,
              AppConstants.statusCompleted,
            );
          }
        } catch (e) {
          debugPrint('Error auto-releasing expired court ${status.courtId}: $e');
        } finally {
          _clearingCourtIds.remove(status.courtId);
        }
      }
    }

    if (stateChanged) {
      notifyListeners();
    }
  }

  CourtStatusModel statusFor(String courtId) =>
      _courtStatuses[courtId] ?? CourtStatusModel.empty(courtId);

  @override
  void dispose() {
    _expiryCheckTimer?.cancel();
    _courtsSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}
