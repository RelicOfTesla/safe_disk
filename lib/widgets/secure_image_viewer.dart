import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/crypto_service.dart';
import '../models/cryption_config.dart';

/// Secure image viewer for viewing encrypted images.
/// Decrypts image in memory without writing to disk.
class SecureImageViewer extends StatefulWidget {
  final EncryptedFile file;
  final CryptoService cryptoService;
  final String tempKeyID;

  const SecureImageViewer({
    super.key,
    required this.file,
    required this.cryptoService,
    required this.tempKeyID,
  });

  @override
  State<SecureImageViewer> createState() => _SecureImageViewerState();
}

class _SecureImageViewerState extends State<SecureImageViewer> {
  Uint8List? _imageData;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Image viewing state
  final TransformationController _transformController = TransformationController();
  double _scale = 1.0;
  double _rotation = 0.0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    // Clear sensitive data from memory
    _imageData = null;
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Decrypt image file
      final data = widget.cryptoService.decryptFileToData(
        widget.file.encryptedPath,
        widget.tempKeyID,
      );

      if (data.isNotEmpty) {
        setState(() {
          _imageData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to decrypt image';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load image: $e';
      });
    }
  }

  void _resetView() {
    setState(() {
      _scale = 1.0;
      _rotation = 0.0;
    });
    _transformController.value = Matrix4.identity();
  }

  void _rotateImage() {
    setState(() {
      _rotation += 90;
      if (_rotation >= 360) _rotation = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetView,
            tooltip: 'Reset view',
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right),
            onPressed: _rotateImage,
            tooltip: 'Rotate',
          ),
        ],
      ),
      body: _buildBody(),
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
              onPressed: _loadImage,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_imageData == null) {
      return const Center(child: Text('No image data'));
    }

    return Center(
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.1,
        maxScale: 10.0,
        child: Transform.rotate(
          angle: _rotation * 3.14159265359 / 180,
          child: Image.memory(
            _imageData!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Failed to display image'),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
