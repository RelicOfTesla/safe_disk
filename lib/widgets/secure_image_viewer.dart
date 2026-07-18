import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/secure_image_policy.dart';
import '../services/crypto_service.dart';
import '../services/file_service.dart';
import '../models/cryption_config.dart';

export '../models/secure_image_policy.dart'
    show kSupportedImageFormats, isSupportedImageFormat;

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
  final VoidCallback? onClosed;
  final int maxEncodedBytes;
  final int maxDecodedPixels;
  final SecureImageInspector imageInspector;

  const SecureImageViewer({
    super.key,
    required this.file,
    required this.cryptoService,
    required this.tempKeyID,
    this.directoryPath,
    this.fileService,
    this.onClosed,
    this.maxEncodedBytes = kMaxSecureImageEncodedBytes,
    this.maxDecodedPixels = kMaxSecureImageDecodedPixels,
    this.imageInspector = inspectSecureImage,
  });

  @override
  State<SecureImageViewer> createState() => _SecureImageViewerState();
}

class _SecureImageViewerState extends State<SecureImageViewer> {
  Uint8List? _imageData;
  MemoryImage? _imageProvider;
  SecureImageMetadata? _metadata;
  bool _isLoading = true;
  String? _errorMessage;
  int _loadGeneration = 0;

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
    _loadGeneration++;
    // Securely clear image data from memory
    _secureClearMemory();
    _transformController.dispose();
    _focusNode.dispose();
    widget.onClosed?.call();
    super.dispose();
  }

  /// Securely clear sensitive image data from memory
  void _secureClearMemory() {
    final provider = _imageProvider;
    _imageProvider = null;
    if (provider != null) {
      PaintingBinding.instance.imageCache.evict(provider, includeLive: true);
    }
    if (_imageData != null) {
      // Fill with zeros to securely clear the memory
      _imageData!.fillRange(0, _imageData!.length, 0);
      _imageData = null;
    }
    _metadata = null;
  }

  /// Load list of image files in the directory for navigation
  Future<void> _loadImageList() async {
    if (widget.directoryPath == null || widget.fileService == null) {
      return;
    }

    try {
      final items =
          await widget.fileService!.listCurrentDirectory(widget.directoryPath!);
      final imageFiles = items.where((item) {
        return !item.isDirectory && isSupportedImageFormat(item.extension);
      }).toList();
      final currentIndex = imageFiles.indexWhere(
        (file) => file.path == widget.file.encryptedPath,
      );
      if (!mounted) return;
      setState(() {
        _imageFiles = imageFiles;
        _currentIndex = currentIndex;
      });
    } catch (e) {
      debugPrint('Failed to load image list: $e');
    }
  }

  /// Load and decrypt the current image
  Future<void> _loadImage() async {
    final generation = ++_loadGeneration;
    Uint8List? loadedData;
    try {
      _secureClearMemory();
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _rotation = 0;
        });
      }
      _transformController.value = Matrix4.identity();

      validateSecureImageEncodedSize(
        _currentOriginalSize,
        maxBytes: widget.maxEncodedBytes,
      );
      await Future<void>.delayed(Duration.zero);
      if (!mounted || generation != _loadGeneration) return;

      loadedData = widget.cryptoService.decryptFileToData(
        _currentEncryptedPath,
        widget.tempKeyID,
      );
      final metadata = await widget.imageInspector(
        loadedData,
        maxBytes: widget.maxEncodedBytes,
        maxPixels: widget.maxDecodedPixels,
      );
      if (!mounted || generation != _loadGeneration) {
        loadedData.fillRange(0, loadedData.length, 0);
        return;
      }
      final provider = MemoryImage(loadedData);
      setState(() {
        _imageData = loadedData;
        _imageProvider = provider;
        _metadata = metadata;
        _isLoading = false;
      });
      loadedData = null;
    } catch (e) {
      loadedData?.fillRange(0, loadedData.length, 0);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e is SecureImagePolicyException
            ? '无法加载图片：${e.message}'
            : '无法加载图片：图片解密失败或内容无效';
      });
    }
  }

  /// Navigate to previous image
  Future<void> _previousImage() async {
    if (_imageFiles.isEmpty || _currentIndex <= 0) return;

    _currentIndex--;
    await _loadImageByIndex(_currentIndex);
  }

  /// Navigate to next image
  Future<void> _nextImage() async {
    if (_imageFiles.isEmpty || _currentIndex >= _imageFiles.length - 1) return;

    _currentIndex++;
    await _loadImageByIndex(_currentIndex);
  }

  /// Load image by index from the image list
  Future<void> _loadImageByIndex(int index) async {
    if (index < 0 || index >= _imageFiles.length) return;

    await _loadImage();
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
    _transformController.value = Matrix4.identity()
      ..scaleByDouble(newScale, newScale, newScale, 1);
  }

  void _zoomOut() {
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final newScale = (scale / 1.2).clamp(0.1, 10.0);
    _transformController.value = Matrix4.identity()
      ..scaleByDouble(newScale, newScale, newScale, 1);
  }

  void _handleMouseWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse ||
        event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      if (!mounted) return;
      if (scroll.scrollDelta.dy < 0) {
        _zoomIn();
      } else {
        _zoomOut();
      }
    });
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
    if (_imageFiles.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _imageFiles.length) {
      return _imageFiles[_currentIndex].name;
    }
    return widget.file.name;
  }

  String get _currentEncryptedPath {
    if (_imageFiles.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _imageFiles.length) {
      return _imageFiles[_currentIndex].path;
    }
    return widget.file.encryptedPath;
  }

  int? get _currentOriginalSize {
    if (_imageFiles.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _imageFiles.length) {
      return _imageFiles[_currentIndex].size;
    }
    return widget.file.originalSize;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
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
            if (_metadata?.isAnimated ?? false)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  avatar: const Icon(Icons.animation, size: 16),
                  label: Text('动画（${_metadata!.frameCount} 帧）'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            // Zoom in
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: _zoomIn,
              tooltip: '放大（+）',
            ),
            // Zoom out
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _zoomOut,
              tooltip: '缩小（-）',
            ),
            // Reset view
            IconButton(
              icon: const Icon(Icons.fit_screen),
              onPressed: _resetView,
              tooltip: '重置视图（N）',
            ),
            // Rotate
            IconButton(
              icon: const Icon(Icons.rotate_right),
              onPressed: _rotateImage,
              tooltip: '顺时针旋转（R）',
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
            tooltip: '上一张（←）',
          ),
          // Image counter
          Text(
            '${_currentIndex + 1} / ${_imageFiles.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          // Next button
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed:
                _currentIndex < _imageFiles.length - 1 ? _nextImage : null,
            tooltip: '下一张（→）',
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
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_imageData == null || _imageProvider == null) {
      return const Center(child: Text('没有可显示的图片数据'));
    }

    return SizedBox.expand(
      child: InteractiveViewer(
        key: const Key('secure-image-interactive-viewer'),
        transformationController: _transformController,
        // Keep a sufficiently large canvas so pointer gestures can reach the
        // same 10%-1000% range as the toolbar controls.
        boundaryMargin: const EdgeInsets.all(10000),
        minScale: 0.1,
        maxScale: 10.0,
        // As a child, this listener registers before InteractiveViewer's own
        // pointer-signal handler, so mouse wheels use the toolbar zoom path.
        child: Listener(
          onPointerSignal: _handleMouseWheel,
          child: GestureDetector(
            onDoubleTap: _resetView,
            onHorizontalDragEnd: (details) {
              // Swipe left/right to navigate.
              if (details.primaryVelocity == null) return;

              if (details.primaryVelocity! > 300) {
                _previousImage();
              } else if (details.primaryVelocity! < -300) {
                _nextImage();
              }
            },
            child: Transform.rotate(
              key: const Key('secure-image-rotation'),
              angle: _rotation * 3.14159265359 / 180,
              child: Image(
                key: const Key('secure-image-content'),
                image: _imageProvider!,
                fit: BoxFit.contain,
                gaplessPlayback: false,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('无法显示图片'),
                        const SizedBox(height: 8),
                        Text(
                          '文件可能已损坏，或不是受支持的图片格式。',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadImage,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
