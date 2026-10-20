import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/tournament_model.dart';
import '../models/player_model.dart';
import '../services/tournament_service.dart';

class TournamentProvider extends ChangeNotifier {
  final TournamentService _service = TournamentService();

  List<TournamentModel> _tournaments = [];
  TournamentModel? _selectedTournament;
  bool _isLoading = false;
  String? _error;

  List<TournamentModel> get tournaments => _tournaments;
  TournamentModel? get selectedTournament => _selectedTournament;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<List<TournamentModel>>? _listSub;
  StreamSubscription<TournamentModel?>? _detailSub;

  TournamentProvider() {
    _listSub = _service.getTournaments().listen((list) {
      _tournaments = list;
      notifyListeners();
    });
  }

  // ─── Select tournament for detail view ────────────────────────────────────
  void selectTournament(String id) {
    _detailSub?.cancel();
    _detailSub = _service.getTournamentById(id).listen((t) {
      _selectedTournament = t;
      notifyListeners();
    });
  }

  void clearSelected() {
    _detailSub?.cancel();
    _selectedTournament = null;
    notifyListeners();
  }

  // ─── Create Tournament ─────────────────────────────────────────────────────
  Future<bool> createTournament({
    required String name,
    required DateTime date,
    required List<PlayerModel> players,
    String format = 'qualifying_rounds',
    int qualifyingRoundsCount = 5,
    String? description,
    String? courtId,
    String? courtName,
    String? creatorId,
    String? creatorName,
  }) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final rounds = (format == 'qualifying_rounds')
          ? _service.generateQualifyingTournament(players, qualifyingRoundsCount)
          : _service.generateBracket(players);

      final tournament = TournamentModel(
        id: '', // Firestore will assign
        name: name.trim(),
        date: date,
        status: 'upcoming',
        format: format,
        qualifyingRoundsCount: qualifyingRoundsCount,
        players: players,
        rounds: rounds,
        description: description?.trim(),
        courtId: courtId,
        courtName: courtName,
        creatorId: creatorId,
        creatorName: creatorName,
        createdAt: DateTime.now(),
      );

      await _service.createTournament(tournament);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to create tournament: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Join Tournament ───────────────────────────────────────────────────────
  Future<bool> joinTournament({
    required TournamentModel tournament,
    required PlayerModel player,
  }) async {
    if (tournament.hasPlayer(player.uid)) return true;
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final updatedPlayers = List<PlayerModel>.from(tournament.players)..add(player);
      final updatedRounds = (tournament.format == 'qualifying_rounds')
          ? _service.generateQualifyingTournament(
              updatedPlayers, tournament.qualifyingRoundsCount)
          : _service.generateBracket(updatedPlayers);

      final updatedTournament = tournament.copyWith(
        players: updatedPlayers,
        rounds: updatedRounds,
      );
      await _service.updateTournament(updatedTournament);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to join tournament: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Leave Tournament ──────────────────────────────────────────────────────
  Future<bool> leaveTournament({
    required TournamentModel tournament,
    required String playerUid,
  }) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final updatedPlayers =
          tournament.players.where((p) => p.uid != playerUid).toList();
      final updatedRounds = (tournament.format == 'qualifying_rounds')
          ? _service.generateQualifyingTournament(
              updatedPlayers, tournament.qualifyingRoundsCount)
          : _service.generateBracket(updatedPlayers);

      final updatedTournament = tournament.copyWith(
        players: updatedPlayers,
        rounds: updatedRounds,
      );
      await _service.updateTournament(updatedTournament);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to leave tournament: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Advance to Quarter-Finals / Playoffs ───────────────────────────────────
  Future<bool> advanceToPlayoffs(TournamentModel tournament) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      final updated = _service.advanceToPlayoffs(tournament);
      await _service.updateTournament(updated);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to generate playoff bracket: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Record Match Result ───────────────────────────────────────────────────
  Future<void> recordMatchResult({
    required TournamentModel tournament,
    required int roundIndex,
    required int matchIndex,
    required PlayerModel winner,
    String? score,
  }) async {
    final updatedRounds = _service.recordMatchResult(
      rounds: tournament.rounds,
      roundIndex: roundIndex,
      matchIndex: matchIndex,
      winner: winner,
      score: score,
      format: tournament.format,
      qualifyingRoundsCount: tournament.qualifyingRoundsCount,
    );

    // Check if final match was completed
    final lastRound = updatedRounds.last;
    final finished =
        lastRound.length == 1 && lastRound.first.winner != null;

    final updated = tournament.copyWith(
      status: finished ? 'completed' : 'ongoing',
      rounds: updatedRounds,
    );
    await _service.updateTournament(updated);
  }

  // ─── Start Tournament ──────────────────────────────────────────────────────
  Future<void> startTournament(TournamentModel tournament) async {
    await _service.updateTournament(tournament.copyWith(status: 'ongoing'));
  }

  Future<void> deleteTournament(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.deleteTournament(id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete tournament: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  String getRoundName(int roundNumber, int totalRounds,
          {String? format, int? qualifyingRoundsCount}) =>
      _service.getRoundName(roundNumber, totalRounds,
          format: format, qualifyingRoundsCount: qualifyingRoundsCount);

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _listSub?.cancel();
    _detailSub?.cancel();
    super.dispose();
  }
}
