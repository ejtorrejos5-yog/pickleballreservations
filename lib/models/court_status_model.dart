enum CourtStatusType { available, reserved, inUse }

extension CourtStatusTypeExt on CourtStatusType {
  String get label {
    switch (this) {
      case CourtStatusType.available:
        return 'Available';
      case CourtStatusType.reserved:
        return 'Reserved';
      case CourtStatusType.inUse:
        return 'In Use';
    }
  }
}

class CourtStatusModel {
  final String courtId;
  final bool isOccupied;
  final DateTime? occupiedSince;
  final DateTime? bookedUntil;
  final String? reservationId;
  final String? reservedByName;
  /// Name of the next player queued for this court (shown on LCD after timer ends).
  final String? nextPlayerName;

  const CourtStatusModel({
    required this.courtId,
    required this.isOccupied,
    this.occupiedSince,
    this.bookedUntil,
    this.reservationId,
    this.reservedByName,
    this.nextPlayerName,
  });

  CourtStatusType get statusType {
    if (isOccupied) return CourtStatusType.inUse;
    if (reservationId != null && bookedUntil != null &&
        bookedUntil!.isAfter(DateTime.now())) {
      return CourtStatusType.reserved;
    }
    return CourtStatusType.available;
  }

  int get secondsRemaining {
    if (bookedUntil == null) return 0;
    final diff = bookedUntil!.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  double get progressFraction {
    if (occupiedSince == null || bookedUntil == null) return 0.0;
    final total = bookedUntil!.difference(occupiedSince!).inSeconds;
    if (total <= 0) return 0.0;
    final elapsed = DateTime.now().difference(occupiedSince!).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  factory CourtStatusModel.fromRealtimeDB(
      Map<dynamic, dynamic> data, String courtId) {
    DateTime? occupiedSince;
    DateTime? bookedUntil;

    if (data['occupiedSince'] != null) {
      occupiedSince =
          DateTime.fromMillisecondsSinceEpoch(data['occupiedSince'] as int);
    }
    if (data['bookedUntil'] != null) {
      bookedUntil =
          DateTime.fromMillisecondsSinceEpoch(data['bookedUntil'] as int);
    }

    return CourtStatusModel(
      courtId: courtId,
      isOccupied: data['isOccupied'] as bool? ?? false,
      occupiedSince: occupiedSince,
      bookedUntil: bookedUntil,
      reservationId: data['reservationId']?.toString(),
      reservedByName: data['reservedByName']?.toString(),
      nextPlayerName: data['nextPlayerName']?.toString(),
    );
  }

  static CourtStatusModel empty(String courtId) =>
      CourtStatusModel(courtId: courtId, isOccupied: false);
}
