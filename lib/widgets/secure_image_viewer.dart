import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/crypto_service.dart';
import '../services/file_service.dart';
import '../models/cryption_config.dart';

/// Supported image formats
const Set<String> kSupportedImageFormats = {
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
};

/// Check if a file extension is a supported image format
bool isSupportedImageFormat(String? extension) {
  if (extension == null) return false;
  return kSupportedImageFormats.contains(extension.toLowerCase());
}

/// Secure image viewer for viewing encrypted images.
/// 
/// Features:
/// - Decrypts image in memory without writing to disk
/// - Supports zoom, pan, and rotation
/// - Navigate between images in the same directory
/// - Keyboard shortcuts
/// - Secure memory cleanup on close
class SecureImageViewer extends StatefulWidget {
  final EncryptedFile file;
  final CryptoService cryptoService;
  final String tempKeyID;
  
  /// Directory path containing the image (for navigation)
  final String? directoryPath;
  
  /// File service for listing directory contents
  final FileService? fileService;

  const SecureImageViewer({
    super.key,
    required this.file,
    required this.cryptoService,
    required this.tempKeyID,
    this.directoryPath,
    this.fileService,
  });

  @override
  State<SecureImageViewer> createState() => _SecureImageViewerState();
}

class _SecureImageViewerState extends State<SecureImageViewer> {
  Uint8List? _imageData;
  bool _isLoading = true;
  String? _errorMessage;

  // Image viewing state
  final TransformationController _transformController =
      TransformationController();
  double _rotation = 0.0;
  
  // Navigation state
  List<FileSystemNode> _imageFiles = [];
  int _currentIndex = -1;

  // Focus node for keyboard shortcuts
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadImage();
    _loadImageList();
  }

  @override
  void dispose() {
    // Securely clear image data from memory
    _secureClearMemory();
    _transformController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Securely clear sensitive image data from memory
  void _secureClearMemory() {
    if (_imageData != null) {
      // Fill with zeros to securely clear the memory
      _imageData!.fillRange(0, _imageData!.length, 0);
      _imageData = null;
    }
  }

  /// Load list of image files in the directory for navigation
  Future<void> _loadImageList() async {
    if (widget.directoryPath == null || widget.fileService == null) {
      return;
    }

    try {
      final items = await widget.fileService!.listCurrentDirectory(widget.directoryPath!);
      
      // Filter only supported image files
      _imageFiles = items.where((item) {
        return !item.isDirectory && isSupportedImageFormat(item.extension);
      }).toList();
      
      // Find current file index
      _currentIndex = _imageFiles.indexWhere((f) => f.path == widget.file.encryptedPath);
      
      // Update UI to show navigation controls
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load image list: $e');
    }
  }

  /// Load and decrypt the current image
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
          _errorMessage = 'Failed to decrypt image: empty result';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load image: $e';
      });
    }
  }

  /// Navigate to previous image
  Future<void> _previousImage() async {
    if (_imageFiles.isEmpty || _currentIndex <= 0) return;
    
    _secureClearMemory();
    _currentIndex--;
    await _loadImageByIndex(_currentIndex);
  }

  /// Navigate to next image
  Future<void> _nextImage() async {
    if (_imageFiles.isEmpty || _currentIndex >= _imageFiles.length - 1) return;
    
    _secureClearMemory();
    _currentIndex++;
    await _loadImageByIndex(_currentIndex);
  }

  /// Load image by index from the image list
  Future<void> _loadImageByIndex(int index) async {
    if (index < 0 || index >= _imageFiles.length) return;
    
    final file = _imageFiles[index];
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = widget.cryptoService.decryptFileToData(
        file.path,
        widget.tempKeyID,
      );

      if (data.isNotEmpty) {
        setState(() {
          _imageData = data;
          _isLoading = false;
        });
        // Update app bar title
        setState(() {});
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

  void _zoomIn() {
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final newScale = (scale * 1.2).clamp(0.1, 10.0);
    _transformController.value = Matrix4.identity()..scale(newScale);
  }

  void _zoomOut() {
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final newScale = (scale / 1.2).clamp(0.1, 10.0);
    _transformController.value = Matrix4.identity()..scale(newScale);
  }

  /// Handle keyboard shortcuts
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Navigation
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _previousImage();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _nextImage();
    }
    // Zoom
    else if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd ||
        event.logicalKey == LogicalKeyboardKey.keyP) {
      _zoomIn();
    } else if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract ||
        event.logicalKey == LogicalKeyboardKey.keyM) {
      _zoomOut();
    }
    // Rotate
    else if (event.logicalKey == LogicalKeyboardKey.keyR) {
      _rotateImage();
    }
    // Reset
    else if (event.logicalKey == LogicalKeyboardKey.keyN) {
      _resetView();
    }
    // Close
    else if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.keyQ) {
      Navigator.of(context).pop();
    }
  }

  String get _currentFileName {
    if (_imageFiles.isNotEmpty && _currentIndex >= 0 && _currentIndex < _imageFiles.length) {
      return _imageFiles[_currentIndex].name;
    }
    return widget.file.name;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentFileName),
          actions: [
            // Navigation info
            if (_imageFiles.isNotEmpty && _currentIndex >= 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Text(
                    '${_currentIndex + 1} / ${_imageFiles.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            // Zoom in
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: _zoomIn,
              tooltip: 'Zoom in (+)',
            ),
            // Zoom out
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _zoomOut,
              tooltip: 'Zoom out (-)',
            ),
            // Reset view
            IconButton(
              icon: const Icon(Icons.fit_screen),
              onPressed: _resetView,
              tooltip: 'Reset view (N)',
            ),
            // Rotate
            IconButton(
              icon: const Icon(Icons.rotate_right),
              onPressed: _rotateImage,
              tooltip: 'Rotate (R)',
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_imageFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Previous button
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: _currentIndex > 0 ? _previousImage : null,
            tooltip: 'Previous (←)',
          ),
          // Image counter
          Text(
            '${_currentIndex + 1} / ${_imageFiles.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          // Next button
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: _currentIndex < _imageFiles.length - 1 ? _nextImage : null,
            tooltip: 'Next (→)',
          ),
        ],
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
            ),
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

    return GestureDetector(
      onDoubleTap: _resetView,
      onHorizontalDragEnd: (details) {
        // Swipe left/right to navigate
        if (details.primaryVelocity == null) return;
        
        if (details.primaryVelocity! > 300) {
          // Swipe right -> previous
          _previousImage();
        } else if (details.primaryVelocity! < -300) {
          // Swipe left -> next
          _nextImage();
        }
      },
      child: Center(
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
                      const Icon(Icons.broken_image,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Failed to display image'),
                      const SizedBox(height: 8),
                      Text(
                        'The file may be corrupted or not a valid image format.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadImage,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
