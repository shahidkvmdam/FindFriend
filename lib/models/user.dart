class User {
  final String id;
  final String phoneNumber;
  final String name;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final bool isOnline;

  User({
    required this.id,
    required this.phoneNumber,
    required this.name,
    required this.createdAt,
    this.lastSeen,
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'name': name,
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
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastSeen: map['lastSeen'] != null
          ? DateTime.parse(map['lastSeen'] as String)
          : null,
      isOnline: map['isOnline'] as bool? ?? false,
    );
  }
}
