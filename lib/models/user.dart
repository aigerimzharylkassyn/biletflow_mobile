enum UserRole { attendee, organizer, staff, admin }

class AppUser {
  final String id;
  final List<String> roles;
  final bool supportAccess;
  final String name;
  final String email;
  final UserRole role;
  final bool emailVerified;

  const AppUser({
    required this.id,
    this.roles = const [],
    this.supportAccess = false,
    required this.name,
    required this.email,
    required this.role,
    this.emailVerified = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final roles = List<String>.from(json['roles'] as List);
    return AppUser(
        id: json['id'] as String,
        roles: roles,
        supportAccess: json['support_access'] == true,
        name: json['full_name'] as String? ?? json['email'] as String,
        email: json['email'] as String,
        emailVerified: json['email_verified'] as bool? ?? false,
        role: roles.contains('platform_admin')
            ? UserRole.admin
            : roles.contains('organizer')
                ? UserRole.organizer
                : roles.contains('event_admin')
                    ? UserRole.staff
                    : UserRole.attendee);
  }

  bool get isOrganizer =>
      role == UserRole.organizer || roles.contains('organizer');
  bool get isAdmin =>
      role == UserRole.admin || roles.contains('platform_admin');

  /// Initials shown in the avatar circle, e.g. "Dylan Thomas" -> "DT".
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
