import 'dart:math';
import '../models/tournament_model.dart';
import '../models/player_model.dart';
import 'firestore_service.dart';

class TournamentService {
  final FirestoreService _firestoreService = FirestoreService();

  // ─── Bracket Generation (Single Elimination) ──────────────────────────────────
  List<List<MatchModel>> generateBracket(List<PlayerModel> players) {
    if (players.length < 2) return [];
    final bracketSize = _nextPowerOf2(players.length);
    final rounds = <List<MatchModel>>[];

    // Shuffle for random seeding
    final seeded = List<PlayerModel?>.from(players)..shuffle(Random());

    // Pad with BYE (null) entries
    while (seeded.length < bracketSize) {
      seeded.add(null);
    }

    // ── Round 1 ──────────────────────────────────────────────────────────────
    final round1 = <MatchModel>[];
    for (int i = 0; i < seeded.length; i += 2) {
      final p1 = seeded[i];
      final p2 = seeded[i + 1];
      // Auto-advance BYE matches
      final winner = (p1 == null) ? p2 : (p2 == null ? p1 : null);
      round1.add(MatchModel(
        matchId: 'r1m${i ~/ 2}',
        player1: p1,
        player2: p2,
        winner: winner,
        round: 1,
        matchNumber: i ~/ 2,
      ));
    }
    rounds.add(round1);

    // ── Subsequent Rounds ─────────────────────────────────────────────────────
    int prevMatches = round1.length;
    int roundNum = 2;
    while (prevMatches > 1) {
      final numMatches = prevMatches ~/ 2;
      final round = List.generate(
        numMatches,
        (i) => MatchModel(
          matchId: 'r${roundNum}m$i',
          round: roundNum,
          matchNumber: i,
        ),
      );

      // Pre-fill winners from BYE matches in previous round
      final prevRound = rounds.last;
      for (int i = 0; i < prevRound.length; i++) {
        final prev = prevRound[i];
        if (prev.winner != null) {
          final nextIdx = i ~/ 2;
          final isSlot1 = i % 2 == 0;
          final next = round[nextIdx];
          round[nextIdx] = next.copyWith(
            player1: isSlot1 ? prev.winner : next.player1,
            player2: isSlot1 ? next.player2 : prev.winner,
          );
        }
      }

      rounds.add(round);
      prevMatches = numMatches;
      roundNum++;
    }

    return rounds;
  }

  // ─── Record Result & Advance Winner ──────────────────────────────────────────
  List<List<MatchModel>> recordMatchResult({
    required List<List<MatchModel>> rounds,
    required int roundIndex,
    required int matchIndex,
    required PlayerModel winner,
    String? score,
  }) {
    // Deep copy
    final updated = rounds
        .map((r) => r.map((m) => m).toList())
        .toList();

    // Update current match
    updated[roundIndex][matchIndex] = updated[roundIndex][matchIndex].copyWith(
      winner: winner,
      score: score,
    );

    // Advance winner to next round
    if (roundIndex + 1 < updated.length) {
      final nextMatchIndex = matchIndex ~/ 2;
      final isSlot1 = matchIndex % 2 == 0;
      final next = updated[roundIndex + 1][nextMatchIndex];
      updated[roundIndex + 1][nextMatchIndex] = next.copyWith(
        player1: isSlot1 ? winner : next.player1,
        player2: isSlot1 ? next.player2 : winner,
      );
    }

    return updated;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  int _nextPowerOf2(int n) {
    if (n <= 1) return 2;
    return pow(2, (log(n) / log(2)).ceil()).toInt();
  }

  String getRoundName(int roundNumber, int totalRounds) {
    final remaining = totalRounds - roundNumber + 1;
    switch (remaining) {
      case 1:
        return 'Final';
      case 2:
        return 'Semi-Final';
      case 3:
        return 'Quarter-Final';
      default:
        return 'Round $roundNumber';
    }
  }

  // ─── Firestore Delegation ─────────────────────────────────────────────────────
  Stream<List<TournamentModel>> getTournaments() =>
      _firestoreService.getTournaments();

  Stream<TournamentModel?> getTournamentById(String id) =>
      _firestoreService.getTournamentById(id);

  Future<String> createTournament(TournamentModel t) =>
      _firestoreService.createTournament(t);

  Future<void> updateTournament(TournamentModel t) =>
      _firestoreService.updateTournament(t);

  Future<void> deleteTournament(String id) =>
      _firestoreService.deleteTournament(id);
}
