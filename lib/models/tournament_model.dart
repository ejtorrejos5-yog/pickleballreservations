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
  final String format; // 'single_elimination' | 'qualifying_rounds'
  final int qualifyingRoundsCount; // Number of rounds each player plays in Stage 1 (e.g. 5)
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
    this.qualifyingRoundsCount = 5,
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
  bool get isQualifyingFormat => format == 'qualifying_rounds';
  bool get hasPlayoffs => isQualifyingFormat && rounds.length > qualifyingRoundsCount;

  /// Returns true if all scheduled qualifying matches have been played.
  bool get areQualifyingRoundsCompleted {
    if (!isQualifyingFormat || rounds.isEmpty) return false;
    final limit = qualifyingRoundsCount.clamp(0, rounds.length);
    for (int r = 0; r < limit; r++) {
      if (rounds[r].any((m) => !m.isCompleted && m.isReady)) return false;
    }
    return true;
  }

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

  /// Calculates live player standings / rankings based on qualifying matches.
  List<PlayerStanding> get standings {
    final stats = <String, Map<String, dynamic>>{};
    for (final p in players) {
      stats[p.uid] = {
        'player': p,
        'played': 0,
        'wins': 0,
        'losses': 0,
        'scored': 0,
        'against': 0,
      };
    }

    // Only count qualifying rounds if this is qualifying format, else count all rounds
    final maxRoundIdx = (isQualifyingFormat && qualifyingRoundsCount > 0)
        ? qualifyingRoundsCount.clamp(0, rounds.length)
        : rounds.length;

    for (int r = 0; r < maxRoundIdx; r++) {
      for (final m in rounds[r]) {
        if (!m.isCompleted || m.winner == null) continue;
        if (m.player1 != null && stats.containsKey(m.player1!.uid)) {
          final s = stats[m.player1!.uid]!;
          s['played'] = (s['played'] as int) + 1;
          if (m.winner!.uid == m.player1!.uid) {
            s['wins'] = (s['wins'] as int) + 1;
          } else {
            s['losses'] = (s['losses'] as int) + 1;
          }
        }
        if (m.player2 != null && stats.containsKey(m.player2!.uid)) {
          final s = stats[m.player2!.uid]!;
          s['played'] = (s['played'] as int) + 1;
          if (m.winner!.uid == m.player2!.uid) {
            s['wins'] = (s['wins'] as int) + 1;
          } else {
            s['losses'] = (s['losses'] as int) + 1;
          }
        }

        // Parse score if present (e.g. "11-7" or "11-9")
        if (m.score != null && m.player1 != null && m.player2 != null) {
          final parts = m.score!.split('-');
          if (parts.length == 2) {
            final p1Pts = int.tryParse(parts[0].trim()) ?? 0;
            final p2Pts = int.tryParse(parts[1].trim()) ?? 0;
            if (stats.containsKey(m.player1!.uid)) {
              final s1 = stats[m.player1!.uid]!;
              s1['scored'] = (s1['scored'] as int) + p1Pts;
              s1['against'] = (s1['against'] as int) + p2Pts;
            }
            if (stats.containsKey(m.player2!.uid)) {
              final s2 = stats[m.player2!.uid]!;
              s2['scored'] = (s2['scored'] as int) + p2Pts;
              s2['against'] = (s2['against'] as int) + p1Pts;
            }
          }
        }
      }
    }

    final list = stats.values.toList();
    list.sort((a, b) {
      final wComp = (b['wins'] as int).compareTo(a['wins'] as int);
      if (wComp != 0) return wComp;
      final diffA = (a['scored'] as int) - (a['against'] as int);
      final diffB = (b['scored'] as int) - (b['against'] as int);
      final diffComp = diffB.compareTo(diffA);
      if (diffComp != 0) return diffComp;
      return (b['scored'] as int).compareTo(a['scored'] as int);
    });

    return List.generate(list.length, (i) {
      final item = list[i];
      return PlayerStanding(
        player: item['player'] as PlayerModel,
        rank: i + 1,
        matchesPlayed: item['played'] as int,
        wins: item['wins'] as int,
        losses: item['losses'] as int,
        pointsScored: item['scored'] as int,
        pointsAgainst: item['against'] as int,
      );
    });
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
      qualifyingRoundsCount: data['qualifyingRoundsCount'] as int? ?? 5,
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
        'qualifyingRoundsCount': qualifyingRoundsCount,
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
    int? qualifyingRoundsCount,
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
        qualifyingRoundsCount: qualifyingRoundsCount ?? this.qualifyingRoundsCount,
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

// ─── Player Standing / Leaderboard ──────────────────────────────────────────

class PlayerStanding {
  final PlayerModel player;
  final int rank;
  final int matchesPlayed;
  final int wins;
  final int losses;
  final int pointsScored;
  final int pointsAgainst;
  int get pointDiff => pointsScored - pointsAgainst;

  const PlayerStanding({
    required this.player,
    required this.rank,
    required this.matchesPlayed,
    required this.wins,
    required this.losses,
    required this.pointsScored,
    required this.pointsAgainst,
  });
}
