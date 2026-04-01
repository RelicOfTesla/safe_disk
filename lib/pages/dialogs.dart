import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

/// Dialog for creating encrypted directory
class CreateEncryptedDirectoryDialog extends StatefulWidget {
  @override
  State<CreateEncryptedDirectoryDialog> createState() => _CreateEncryptedDirectoryDialogState();
}

class _CreateEncryptedDirectoryDialogState extends State<CreateEncryptedDirectoryDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _mutable = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  
  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Encrypted Directory'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Mutable Password Mode'),
            subtitle: const Text('Allows changing password without re-encrypting files'),
            value: _mutable,
            onChanged: (value) => setState(() => _mutable = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final password = _passwordController.text;
            final confirm = _confirmController.text;
            
            if (password.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a password')),
              );
              return;
            }
            
            if (password != confirm) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Passwords do not match')),
              );
              return;
            }
            
            Navigator.pop(context, {
              'password': password,
              'mutable': _mutable,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Dialog for selecting directory path with manual input support
class PathSelectionDialog extends StatefulWidget {
  final String? initialPath;
  
  const PathSelectionDialog({this.initialPath});
  
  @override
  State<PathSelectionDialog> createState() => _PathSelectionDialogState();
}

class _PathSelectionDialogState extends State<PathSelectionDialog> {
  final _pathController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _pathController.text = widget.initialPath ?? '';
  }
  
  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }
  
  Future<void> _browseDirectory() async {
    final String? selectedPath = await getDirectoryPath();
    if (selectedPath != null && selectedPath.isNotEmpty) {
      setState(() {
        _pathController.text = selectedPath;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Directory'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pathController,
            decoration: InputDecoration(
              labelText: 'Directory Path',
              hintText: 'Enter or browse for directory',
              suffixIcon: IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _browseDirectory,
                tooltip: 'Browse',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final path = _pathController.text.trim();
            if (path.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a directory path')),
              );
              return;
            }
            
            final dir = Directory(path);
            if (!dir.existsSync()) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Directory does not exist')),
              );
              return;
            }
            
            Navigator.pop(context, path);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
