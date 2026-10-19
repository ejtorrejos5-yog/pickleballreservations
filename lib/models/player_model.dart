class PlayerModel {
  final String uid;
  final String name;
  final String? email;
  final int? seed;

  const PlayerModel({
    required this.uid,
    required this.name,
    this.email,
    this.seed,
  });

  factory PlayerModel.fromMap(Map<String, dynamic> data) => PlayerModel(
        uid: data['uid'] as String? ?? '',
        name: data['name'] as String? ?? '',
        email: data['email'] as String?,
        seed: data['seed'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'seed': seed,
      };

  PlayerModel copyWith({String? name, String? email, int? seed}) => PlayerModel(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        seed: seed ?? this.seed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PlayerModel && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => name;
}
