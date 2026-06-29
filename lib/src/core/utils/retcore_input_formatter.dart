import 'package:flutter/services.dart';

/// A [TextInputFormatter] that blocks invalid characters based on a [RegExp]
/// and triggers callbacks when input is rejected or accepted.
class RetCoreInputFormatter extends TextInputFormatter {
  /// The regular expression pattern that the input must match.
  final RegExp filterPattern;

  /// Callback triggered when the user types a character that does not match [filterPattern].
  final VoidCallback onRejected;

  /// Callback triggered when the user types a valid character.
  final VoidCallback? onAccepted;

  RetCoreInputFormatter({
    required this.filterPattern,
    required this.onRejected,
    this.onAccepted,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text) {
      return newValue;
    }

    if (newValue.text.isEmpty || filterPattern.hasMatch(newValue.text)) {
      onAccepted?.call();
      return newValue;
    }
    onRejected();
    return oldValue;
  }
}
