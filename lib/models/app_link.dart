enum AppLinkKind { campaign, verification, passwordReset }

/// Parses supported paths only. Tokens always go to the configured API, never
/// to the host of a pasted URL. No client-provided discount is accepted.
class AppLink {
  const AppLink(this.kind, this.token);
  final AppLinkKind kind;
  final String token;

  static AppLink? parse(String value) {
    try {
      var uri = Uri.parse(value.trim());
      if (uri.hasScheme &&
          !['http', 'https'].contains(uri.scheme) &&
          !(uri.scheme == 'biletflow' && uri.host == 'open')) {
        return null;
      }
      if (uri.fragment.startsWith('/')) uri = Uri.parse(uri.fragment);
      final parts = uri.pathSegments;
      if (parts.length == 2 &&
          parts.first == 'campaign' &&
          RegExp(r'^[A-Za-z0-9_-]{1,300}$').hasMatch(parts.last)) {
        return AppLink(AppLinkKind.campaign, parts.last);
      }
      final token = uri.queryParameters['token'];
      if (parts.length != 1 ||
          token == null ||
          !RegExp(r'^[A-Za-z0-9_.-]{1,4096}$').hasMatch(token)) {
        return null;
      }
      return switch (parts.first) {
        'verify-email' => AppLink(AppLinkKind.verification, token),
        'reset-password' => AppLink(AppLinkKind.passwordReset, token),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }
}
