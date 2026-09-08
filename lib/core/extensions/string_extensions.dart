/// String utility extensions.
extension StringExtensions on String {
  /// Capitalizes the first letter of the string.
  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Truncates the string to [maxLength] and appends "..." if needed.
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }

  /// Returns whether the string is a valid email format.
  bool get isValidEmail {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(this);
  }

  /// Returns whether the string is blank (empty or whitespace only).
  bool get isBlank => trim().isEmpty;

  /// Returns whether the string is not blank.
  bool get isNotBlank => !isBlank;
}
