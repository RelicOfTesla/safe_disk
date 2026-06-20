import 'package:flutter/material.dart';

/// Welcome screen shown when no encrypted directory is opened.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Safe Disk',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Encrypted file manager'),
          const SizedBox(height: 32),
          const Text(
            '请从侧边栏打开或创建加密目录',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
