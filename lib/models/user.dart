class User {
  final String id;
  final String phoneNumber;
  final String name;
  final int? age;
  final String? sex;
  final String? location;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final bool isOnline;

  User({
    required this.id,
    required this.phoneNumber,
    required this.name,
    this.age,
    this.sex,
    this.location,
    required this.createdAt,
    this.lastSeen,
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'name': name,
      'age': age,
      'sex': sex,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'lastSeen': lastSeen?.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      phoneNumber: map['phoneNumber'] as String,
      name: map['name'] as String,
      age: map['age'] as int?,
      sex: map['sex'] as String?,
      location: map['location'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastSeen: map['lastSeen'] != null
          ? DateTime.parse(map['lastSeen'] as String)
          : null,
      isOnline: map['isOnline'] as bool? ?? false,
    );
  }
}
