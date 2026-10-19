import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_model.dart';

// ─── Match ────────────────────────────────────────────────────────────────────

class MatchModel {
  final String matchId;
  final PlayerModel? player1;
  final PlayerModel? player2;
  final PlayerModel? winner;
  final String? score; // e.g. "11-7, 11-5"
  final int round;
  final int matchNumber;

  const MatchModel({
    required this.matchId,
    this.player1,
    this.player2,
    this.winner,
    this.score,
    required this.round,
    required this.matchNumber,
  });

  bool get isBye => player1 == null || player2 == null;
  bool get isCompleted => winner != null;
  bool get isReady => player1 != null && player2 != null;

  factory MatchModel.fromMap(Map<String, dynamic> data) => MatchModel(
        matchId: data['matchId'] as String? ?? '',
        player1: data['player1'] != null
            ? PlayerModel.fromMap(
                Map<String, dynamic>.from(data['player1'] as Map))
            : null,
        player2: data['player2'] != null
            ? PlayerModel.fromMap(
                Map<String, dynamic>.from(data['player2'] as Map))
            : null,
        winner: data['winner'] != null
            ? PlayerModel.fromMap(
                Map<String, dynamic>.from(data['winner'] as Map))
            : null,
        score: data['score'] as String?,
        round: data['round'] as int? ?? 0,
        matchNumber: data['matchNumber'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'player1': player1?.toMap(),
        'player2': player2?.toMap(),
        'winner': winner?.toMap(),
        'score': score,
        'round': round,
        'matchNumber': matchNumber,
      };

  MatchModel copyWith({
    PlayerModel? player1,
    PlayerModel? player2,
    PlayerModel? winner,
    String? score,
  }) =>
      MatchModel(
        matchId: matchId,
        player1: player1 ?? this.player1,
        player2: player2 ?? this.player2,
        winner: winner ?? this.winner,
        score: score ?? this.score,
        round: round,
        matchNumber: matchNumber,
      );
}

// ─── Tournament ───────────────────────────────────────────────────────────────

class TournamentModel {
  final String id;
  final String name;
  final DateTime date;
  final String status; // 'upcoming' | 'ongoing' | 'completed'
  final String format;
  final List<PlayerModel> players;
  final List<List<MatchModel>> rounds; // [roundIndex][matchIndex]
  final String? description;
  final String? courtId;
  final String? courtName;
  final String? creatorId;
  final String? creatorName;
  final DateTime createdAt;

  const TournamentModel({
    required this.id,
    required this.name,
    required this.date,
    required this.status,
    required this.format,
    required this.players,
    required this.rounds,
    this.description,
    this.courtId,
    this.courtName,
    this.creatorId,
    this.creatorName,
    required this.createdAt,
  });

  bool get isUpcoming => status == 'upcoming';
  bool get isOngoing => status == 'ongoing';
  bool get isCompleted => status == 'completed';
  int get totalRounds => rounds.length;
  PlayerModel? get champion =>
      isCompleted && rounds.isNotEmpty && rounds.last.isNotEmpty
          ? rounds.last.first.winner
          : null;

  PlayerModel? get runnerUp {
    if (!isCompleted || rounds.isEmpty || rounds.last.isEmpty) return null;
    final finalMatch = rounds.last.first;
    if (finalMatch.winner == null) return null;
    if (finalMatch.player1 != null &&
        finalMatch.player1!.uid == finalMatch.winner!.uid) {
      return finalMatch.player2;
    } else {
      return finalMatch.player1;
    }
  }

  List<PlayerModel> get bronzeWinners {
    if (!isCompleted || rounds.length < 2) return [];
    final semiFinalRound = rounds[rounds.length - 2];
    final bronzeList = <PlayerModel>[];
    for (final match in semiFinalRound) {
      if (match.winner != null) {
        final loser = (match.player1 != null &&
                match.player1!.uid == match.winner!.uid)
            ? match.player2
            : match.player1;
        if (loser != null && !bronzeList.any((p) => p.uid == loser.uid)) {
          bronzeList.add(loser);
        }
      }
    }
    return bronzeList;
  }

  int get currentRoundIndex {
    for (int i = 0; i < rounds.length; i++) {
      if (rounds[i].any((m) => !m.isCompleted && m.isReady)) return i;
    }
    return rounds.length - 1;
  }

  bool hasPlayer(String uid) => players.any((p) => p.uid == uid);

  PlayerModel? getPlayer(String uid) {
    try {
      return players.firstWhere((p) => p.uid == uid);
    } catch (_) {
      return null;
    }
  }

  MatchModel? getNextMatchForPlayer(String uid) {
    if (rounds.isEmpty) return null;
    for (final round in rounds) {
      for (final match in round) {
        if (!match.isCompleted &&
            ((match.player1?.uid == uid) || (match.player2?.uid == uid))) {
          return match;
        }
      }
    }
    return null;
  }

  factory TournamentModel.fromFirestore(
      Map<String, dynamic> data, String id) {
    final players = (data['players'] as List? ?? [])
        .map((p) => PlayerModel.fromMap(Map<String, dynamic>.from(p as Map)))
        .toList();

    final rawRounds = data['rounds'];
    List<List<MatchModel>> rounds = [];
    if (rawRounds is List) {
      rounds = rawRounds.map((r) {
        if (r is Map && r.containsKey('matches')) {
          final matchesList = r['matches'] as List? ?? [];
          return matchesList
              .map((m) => MatchModel.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList();
        } else if (r is List) {
          return r
              .map((m) => MatchModel.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList();
        }
        return <MatchModel>[];
      }).toList();
    } else if (rawRounds is Map) {
      final sortedKeys = rawRounds.keys.toList()
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      rounds = sortedKeys.map((k) {
        final matches = rawRounds[k];
        if (matches is List) {
          return matches
              .map((m) => MatchModel.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList();
        }
        return <MatchModel>[];
      }).toList();
    }

    return TournamentModel(
      id: id,
      name: data['name'] as String? ?? '',
      date: (data['date'] as Timestamp).toDate(),
      status: data['status'] as String? ?? 'upcoming',
      format: data['format'] as String? ?? 'single_elimination',
      players: players,
      rounds: rounds,
      description: data['description'] as String?,
      courtId: data['courtId'] as String?,
      courtName: data['courtName'] as String?,
      creatorId: data['creatorId'] as String?,
      creatorName: data['creatorName'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'date': Timestamp.fromDate(date),
        'status': status,
        'format': format,
        'players': players.map((p) => p.toMap()).toList(),
        'rounds': rounds
            .map((round) => {
                  'matches': round.map((m) => m.toMap()).toList(),
                })
            .toList(),
        'description': description,
        'courtId': courtId,
        'courtName': courtName,
        'creatorId': creatorId,
        'creatorName': creatorName,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  TournamentModel copyWith({
    String? name,
    DateTime? date,
    String? status,
    String? format,
    List<PlayerModel>? players,
    List<List<MatchModel>>? rounds,
    String? description,
    String? courtId,
    String? courtName,
    String? creatorId,
    String? creatorName,
  }) =>
      TournamentModel(
        id: id,
        name: name ?? this.name,
        date: date ?? this.date,
        status: status ?? this.status,
        format: format ?? this.format,
        players: players ?? this.players,
        rounds: rounds ?? this.rounds,
        description: description ?? this.description,
        courtId: courtId ?? this.courtId,
        courtName: courtName ?? this.courtName,
        creatorId: creatorId ?? this.creatorId,
        creatorName: creatorName ?? this.creatorName,
        createdAt: createdAt,
      );
}
