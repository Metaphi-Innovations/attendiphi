import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A styled text input field with consistent theming.
///
/// Wraps [TextFormField] with the design system's input decoration,
/// semantic labels for accessibility, and common configuration.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.showFloatingLabel = false,
    this.controller,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
    this.autofillHints,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
  });

  final String? label;
  final String? hint;
  final bool showFloatingLabel;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final int? maxLength;
  final int maxLines;
  final Widget? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label ?? hint ?? '',
      textField: true,
      child: TextFormField(
        controller: controller,
        validator: validator,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        enabled: enabled,
        maxLength: maxLength,
        maxLines: maxLines,
        focusNode: focusNode,
        autofocus: autofocus,
        autocorrect: autocorrect,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
        decoration: InputDecoration(
          labelText: showFloatingLabel ? label : null,
          hintText: hint,
          prefixIcon: prefixIcon,
          prefixText: prefixText,
          suffixIcon: suffixIcon,
          counterText: '',
        ),
      ),
    );
  }
}
