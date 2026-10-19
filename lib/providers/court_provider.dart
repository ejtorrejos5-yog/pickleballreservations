import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/court_model.dart';
import '../models/court_status_model.dart';
import '../services/firestore_service.dart';
import '../services/court_service.dart';

class CourtProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final CourtService _courtService = CourtService();

  List<CourtModel> _courts = [];
  Map<String, CourtStatusModel> _courtStatuses = {};
  bool _isLoading = true;

  List<CourtModel> get courts => _courts;
  Map<String, CourtStatusModel> get courtStatuses => _courtStatuses;
  bool get isLoading => _isLoading;

  StreamSubscription<List<CourtModel>>? _courtsSub;
  StreamSubscription<Map<String, CourtStatusModel>>? _statusSub;

  CourtProvider() {
    _init();
  }

  void _init() {
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
      notifyListeners();
    });
  }

  CourtStatusModel statusFor(String courtId) =>
      _courtStatuses[courtId] ?? CourtStatusModel.empty(courtId);

  @override
  void dispose() {
    _courtsSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}
