import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A SnackBar with a copy button for error messages
class CopyableSnackBar extends SnackBar {
  CopyableSnackBar({
    super.key,
    required String message,
    bool isError = false,
    super.duration = const Duration(seconds: 4),
  }) : super(
          content: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message));
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(50, 30),
                ),
                child: const Text('复制'),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.red[700] : null,
          behavior: SnackBarBehavior.floating,
        );
}
