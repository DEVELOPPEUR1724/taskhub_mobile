class Profile {
  final int id;
  final String name;
  final String email;
  final String role;

  Profile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
    );
  }
}
