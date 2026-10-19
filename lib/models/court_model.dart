class CourtModel {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final String? imageUrl;
  final double pricePerHour; // Price per hour slot in PHP

  const CourtModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    this.imageUrl,
    this.pricePerHour = 250.0,
  });

  factory CourtModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CourtModel(
      id: id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      imageUrl: data['imageUrl'] as String?,
      pricePerHour: (data['pricePerHour'] as num?)?.toDouble() ?? 250.0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'description': description,
        'isActive': isActive,
        'imageUrl': imageUrl,
        'pricePerHour': pricePerHour,
      };

  CourtModel copyWith({
    String? name,
    String? description,
    bool? isActive,
    String? imageUrl,
    double? pricePerHour,
  }) =>
      CourtModel(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        imageUrl: imageUrl ?? this.imageUrl,
        pricePerHour: pricePerHour ?? this.pricePerHour,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CourtModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
