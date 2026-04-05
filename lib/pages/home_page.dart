import 'package:flutter/material.dart';

/// Placeholder home page.
/// Will be implemented with new FFI interface.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Disk')),
      body: const Center(
        child: Text('UI under reconstruction'),
      ),
    );
  }
}
