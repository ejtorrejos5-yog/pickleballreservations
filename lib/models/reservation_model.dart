import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationModel {
  final String id;
  final String courtId;
  final String courtName;
  final String userId;
  final String userName;
  final String date; // 'yyyy-MM-dd'
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final DateTime createdAt;
  final String paymentMethod;     // 'free', 'manual_gcash', 'paymongo'
  final String paymentReference;  // GCash reference number or Paymongo ID
  final double amount;

  const ReservationModel({
    required this.id,
    required this.courtId,
    required this.courtName,
    required this.userId,
    required this.userName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    this.paymentMethod = 'none',
    this.paymentReference = '',
    this.amount = 0.0,
  });

  int get durationMinutes => endTime.difference(startTime).inMinutes;
  bool get isActive => status == 'active';
  bool get isUpcoming => status == 'confirmed' || status == 'pending';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  bool overlaps(DateTime start, DateTime end) =>
      startTime.isBefore(end) && endTime.isAfter(start);

  factory ReservationModel.fromFirestore(
      Map<String, dynamic> data, String id) {
    return ReservationModel(
      id: id,
      courtId: data['courtId'] as String? ?? '',
      courtName: data['courtName'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      date: data['date'] as String? ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      paymentMethod: data['paymentMethod'] as String? ?? 'none',
      paymentReference: data['paymentReference'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'courtId': courtId,
        'courtName': courtName,
        'userId': userId,
        'userName': userName,
        'date': date,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'amount': amount,
      };

  ReservationModel copyWith({
    String? courtId,
    String? courtName,
    String? date,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? paymentMethod,
    String? paymentReference,
    double? amount,
  }) => ReservationModel(
        id: id,
        courtId: courtId ?? this.courtId,
        courtName: courtName ?? this.courtName,
        userId: userId,
        userName: userName,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        status: status ?? this.status,
        createdAt: createdAt,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentReference: paymentReference ?? this.paymentReference,
        amount: amount ?? this.amount,
      );
}
