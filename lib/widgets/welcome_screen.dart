import 'package:flutter/material.dart';

/// Welcome screen shown when no encrypted directory is opened.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Safe Disk',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Encrypted file manager'),
          SizedBox(height: 32),
          Text(
            '请从侧边栏打开或创建加密目录',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
