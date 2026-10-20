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

  // ─── Qualifying Rounds Generation (e.g. 5 rounds before Playoffs) ─────────────
  List<List<MatchModel>> generateQualifyingTournament(
      List<PlayerModel> players, int roundCount) {
    if (players.length < 2) return [];
    final rounds = <List<MatchModel>>[];

    // If odd number of players, add a dummy BYE entry (null)
    final list = List<PlayerModel?>.from(players);
    if (list.length % 2 != 0) {
      list.add(null);
    }
    final numPlayers = list.length;
    final half = numPlayers ~/ 2;

    // Standard Berger rotation schedule: guarantees each player plays different opponents
    for (int r = 0; r < roundCount; r++) {
      final roundMatches = <MatchModel>[];
      for (int i = 0; i < half; i++) {
        final p1 = list[i];
        final p2 = list[numPlayers - 1 - i];
        final winner = (p1 == null) ? p2 : (p2 == null ? p1 : null);
        roundMatches.add(MatchModel(
          matchId: 'q_r${r + 1}_m$i',
          player1: p1,
          player2: p2,
          winner: winner,
          round: r + 1,
          matchNumber: i,
        ));
      }
      rounds.add(roundMatches);

      // Rotate: keep list[0] fixed, rotate list[1..end]
      final last = list.removeLast();
      list.insert(1, last);
    }

    return rounds;
  }

  // ─── Advance Qualified Players to Playoffs (Quarter-Finals & Knockouts) ────────
  TournamentModel advanceToPlayoffs(TournamentModel tournament) {
    if (tournament.hasPlayoffs) return tournament;
    final standings = tournament.standings;
    if (standings.length < 4) return tournament;

    final updatedRounds = tournament.rounds
        .map((r) => r.map((m) => m).toList())
        .toList();

    final qualifyingCount = tournament.qualifyingRoundsCount;

    if (standings.length >= 8) {
      // 8 Qualified Players for Quarter-Finals: Seeding 1v8, 4v5, 2v7, 3v6
      final top8 = standings.take(8).map((s) => s.player).toList();

      final qfMatches = <MatchModel>[
        MatchModel(
          matchId: 'qf_m0',
          round: qualifyingCount + 1,
          matchNumber: 0,
          player1: top8[0],
          player2: top8[7],
        ),
        MatchModel(
          matchId: 'qf_m1',
          round: qualifyingCount + 1,
          matchNumber: 1,
          player1: top8[3],
          player2: top8[4],
        ),
        MatchModel(
          matchId: 'qf_m2',
          round: qualifyingCount + 1,
          matchNumber: 2,
          player1: top8[1],
          player2: top8[6],
        ),
        MatchModel(
          matchId: 'qf_m3',
          round: qualifyingCount + 1,
          matchNumber: 3,
          player1: top8[2],
          player2: top8[5],
        ),
      ];

      // Semi-Finals (2 matches)
      final sfMatches = List.generate(
        2,
        (i) => MatchModel(
          matchId: 'sf_m$i',
          round: qualifyingCount + 2,
          matchNumber: i,
        ),
      );

      // Championship Final (1 match)
      final finalMatch = [
        MatchModel(
          matchId: 'final_m0',
          round: qualifyingCount + 3,
          matchNumber: 0,
        ),
      ];

      updatedRounds.add(qfMatches);
      updatedRounds.add(sfMatches);
      updatedRounds.add(finalMatch);
    } else {
      // 4 to 7 Players: Top 4 qualify for Semi-Finals (1v4, 2v3)
      final top4 = standings.take(4).map((s) => s.player).toList();

      final sfMatches = <MatchModel>[
        MatchModel(
          matchId: 'sf_m0',
          round: qualifyingCount + 1,
          matchNumber: 0,
          player1: top4[0],
          player2: top4[3],
        ),
        MatchModel(
          matchId: 'sf_m1',
          round: qualifyingCount + 1,
          matchNumber: 1,
          player1: top4[1],
          player2: top4[2],
        ),
      ];

      final finalMatch = [
        MatchModel(
          matchId: 'final_m0',
          round: qualifyingCount + 2,
          matchNumber: 0,
        ),
      ];

      updatedRounds.add(sfMatches);
      updatedRounds.add(finalMatch);
    }

    return tournament.copyWith(rounds: updatedRounds);
  }

  // ─── Record Result & Advance Winner ──────────────────────────────────────────
  List<List<MatchModel>> recordMatchResult({
    required List<List<MatchModel>> rounds,
    required int roundIndex,
    required int matchIndex,
    required PlayerModel winner,
    String? score,
    String format = 'single_elimination',
    int qualifyingRoundsCount = 0,
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

    // Only advance winner to next match if we are in knockout / playoff rounds
    final isPlayoff = format == 'single_elimination' || roundIndex >= qualifyingRoundsCount;
    if (isPlayoff && roundIndex + 1 < updated.length) {
      final nextMatchIndex = matchIndex ~/ 2;
      final isSlot1 = matchIndex % 2 == 0;
      if (nextMatchIndex < updated[roundIndex + 1].length) {
        final next = updated[roundIndex + 1][nextMatchIndex];
        updated[roundIndex + 1][nextMatchIndex] = next.copyWith(
          player1: isSlot1 ? winner : next.player1,
          player2: isSlot1 ? next.player2 : winner,
        );
      }
    }

    return updated;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  int _nextPowerOf2(int n) {
    if (n <= 1) return 2;
    return pow(2, (log(n) / log(2)).ceil()).toInt();
  }

  String getRoundName(int roundNumber, int totalRounds,
      {String? format, int? qualifyingRoundsCount}) {
    if (format == 'qualifying_rounds' &&
        qualifyingRoundsCount != null &&
        qualifyingRoundsCount > 0) {
      if (roundNumber <= qualifyingRoundsCount) {
        return 'Qualifying Round $roundNumber (Stage 1)';
      }
      final playoffRound = roundNumber - qualifyingRoundsCount;
      final totalPlayoffRounds = totalRounds - qualifyingRoundsCount;
      final remaining = totalPlayoffRounds - playoffRound + 1;
      switch (remaining) {
        case 1:
          return 'Championship Final';
        case 2:
          return 'Semi-Final';
        case 3:
          return 'Quarter-Final';
        default:
          return 'Playoff Round $playoffRound';
      }
    }

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
