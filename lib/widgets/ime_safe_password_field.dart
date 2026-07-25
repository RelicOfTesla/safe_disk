import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ime/flutter_ime.dart';

/// A password text field that disables IME on focus to prevent CJK
/// composition window freezes (Windows/Linux), and re-enables on blur.
///
/// Wraps a [TextField] with:
/// - [disableIME]/[enableIME] from `flutter_ime` (Windows: detaches IME context)
/// - [FilteringTextInputFormatter] restricting input to ASCII printable
/// - [enableIMEPersonalizedLearning] set to false
///
/// This is the single reusable component for all password input in the app.
class ImeSafePasswordField extends StatefulWidget {
  const ImeSafePasswordField({
    super.key,
    required this.controller,
    this.focusNode,
    this.textFieldKey,
    this.decoration,
    this.labelText,
    this.autofocus = false,
    this.enabled = true,
    this.obscureText = true,
    this.showObscureToggle = false,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final Key? textFieldKey;
  final InputDecoration? decoration;
  final String? labelText;
  final bool autofocus;
  final bool enabled;
  final bool obscureText;
  final bool showObscureToggle;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<ImeSafePasswordField> createState() => _ImeSafePasswordFieldState();
}

class _ImeSafePasswordFieldState extends State<ImeSafePasswordField> {
  late final FocusNode _focusNode;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _obscure = widget.obscureText;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      disableIME();
    } else {
      enableIME();
    }
  }

  @override
  void dispose() {
    enableIME();
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ??
        InputDecoration(labelText: widget.labelText);
    return TextField(
      key: widget.textFieldKey,
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      decoration: widget.showObscureToggle
          ? decoration.copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            )
          : decoration,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[ -~]')),
      ],
      onSubmitted: widget.onSubmitted,
    );
  }
}
