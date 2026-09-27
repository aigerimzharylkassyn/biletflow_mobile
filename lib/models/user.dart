enum UserRole { attendee, organizer, admin }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final roles = List<String>.from(json['roles'] as List);
    return AppUser(id: json['id'] as String,
      name: json['full_name'] as String? ?? json['email'] as String,
      email: json['email'] as String,
      role: roles.contains('platform_admin') ? UserRole.admin
          : roles.contains('organizer') ? UserRole.organizer : UserRole.attendee);
  }

  /// Initials shown in the avatar circle, e.g. "Dylan Thomas" -> "DT".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
