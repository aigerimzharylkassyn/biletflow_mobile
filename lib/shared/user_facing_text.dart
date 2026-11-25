final _internalId = RegExp(
  r'(?<![a-z0-9])#?(?:[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}|[a-f0-9]{32})(?![a-z0-9])',
  caseSensitive: false,
);

/// Hides database identifiers embedded in server-provided display text.
/// The original values remain available for requests, links, and QR codes.
String withoutInternalIds(String text, {String fallback = ''}) {
  if (!_internalId.hasMatch(text)) {
    return text.trim().isEmpty ? fallback : text;
  }
  final visible = text
      .replaceAll(_internalId, '')
      .replaceAll(RegExp(r'\([ \t]*\)|\[[ \t]*\]|\{[ \t]*\}'), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAllMapped(RegExp(r'[ \t]+([,.;:!?])'), (match) => match[1]!)
      .trim();
  return visible.isEmpty ? fallback : visible;
}
