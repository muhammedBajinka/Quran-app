enum MediaReportReason {
  inappropriate('inappropriate', 'Inappropriate content'),
  misleading('misleading', 'Misleading content'),
  harassment('harassment', 'Harassment'),
  spam('spam', 'Spam'),
  copyright('copyright', 'Copyright concern'),
  other('other', 'Other');

  final String code;
  final String label;
  const MediaReportReason(this.code, this.label);

  static MediaReportReason parse(String value) {
    final normalized = value.trim().toLowerCase();
    return values.firstWhere(
      (reason) => reason.code == normalized || reason.label.toLowerCase() == normalized,
      orElse: () => throw ArgumentError.value(value, 'reason', 'Unknown report reason'),
    );
  }
}
