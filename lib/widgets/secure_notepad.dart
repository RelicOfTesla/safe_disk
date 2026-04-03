import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/crypto_service.dart';
import '../models/cryption_config.dart';
import '../utils/error_messages.dart';
import '../widgets/copyable_snackbar.dart';

/// Security-focused notepad for editing encrypted text files.
/// Uses Flutter's TextField for better desktop support.
class SecureNotepad extends StatefulWidget {
  final EncryptedFile file;
  final CryptoService cryptoService;
  final String tempKeyID;
  final VoidCallback? onSaved;

  const SecureNotepad({
    super.key,
    required this.file,
    required this.cryptoService,
    required this.tempKeyID,
    this.onSaved,
  });

  @override
  State<SecureNotepad> createState() => _SecureNotepadState();
}

class _SecureNotepadState extends State<SecureNotepad> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isInitializing = true; // Flag to ignore initial text changes
  String? _errorMessage;
  String _lastText = ''; // Track last text to detect real changes

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _loadFile();
  }

  @override
  void dispose() {
    // Clear sensitive data from memory
    _controller.clear();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Decrypt file content
      final contentBytes = widget.cryptoService.decryptFileToData(
        widget.file.encryptedPath,
        widget.tempKeyID,
      );
      final content = utf8.decode(contentBytes);

      if (content.isNotEmpty) {
        print('[DEBUG] Setting controller.text (length=${content.length})');
        _controller.text = content;
        _lastText = content; // Remember initial text
        print('[DEBUG] controller.text set');
      }

      setState(() {
        _isLoading = false;
        _hasChanges = false; // Reset change flag after loading
        print('[DEBUG] _hasChanges reset to false');
      });

      // Mark initialization complete after a short delay
      // This ensures initial setup doesn't trigger unsaved changes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
          print('[DEBUG] Initialization complete, _isInitializing=false');
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '文件加载失败：$e';
      });
    }
  }

  Future<void> _saveFile() async {
    if (_isSaving) return;

    try {
      setState(() => _isSaving = true);

      // Encrypt and save
      final contentBytes = utf8.encode(_controller.text);
      final encryptedBase64 =
          widget.cryptoService.encryptDataBytes(contentBytes, widget.tempKeyID);
      final encryptedBytes = base64Decode(encryptedBase64);
      await File(widget.file.encryptedPath).writeAsBytes(encryptedBytes);

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });

      widget.onSaved?.call();

      if (mounted) {
        ErrorHelper.showSuccess(context, '文件保存成功');
      }
    } catch (e) {
      setState(() => _isSaving = false);

      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.saveFileFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Do you want to save changes before closing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'no'),
            child: const Text('Don\'t Save'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'yes'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'yes') {
      await _saveFile();
      if (mounted) Navigator.of(context).pop();
      return true;
    } else if (result == 'no') {
      if (mounted) Navigator.of(context).pop();
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If didn't pop, show dialog (it will handle navigation)
        await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.file.name),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _isSaving ? null : _saveFile,
                tooltip: 'Save',
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFile,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Use TextField for better desktop support
    // (double-click, triple-click, drag selection, right-click menu)
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  if (_hasChanges)
                    const Icon(Icons.edit, size: 16, color: Colors.orange)
                  else
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    _hasChanges ? 'Unsaved changes' : 'Saved',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${_controller.text.length} characters',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // Editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: null,
                  expands: true,
                  autofocus: true,
                  showCursor: true,
                  enableInteractiveSelection: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                  ),
                  cursorColor: Theme.of(context).colorScheme.primary,
                  onChanged: (text) {
                    // Ignore text changes during initialization
                    if (_isInitializing) {
                      print(
                          '[DEBUG] onChanged called during initialization, ignoring');
                      return;
                    }

                    // Check if text actually changed
                    if (text != _lastText) {
                      print(
                          '[DEBUG] Text changed from ${_lastText.length} to ${text.length}');
                      _lastText = text;
                      if (!_hasChanges) {
                        setState(() => _hasChanges = true);
                        print('[DEBUG] _hasChanges set to true');
                      }
                    }
                  },
                  inputFormatters: [
                    // Allow all characters
                    FilteringTextInputFormatter.allow(RegExp(r'[\s\S]*')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
