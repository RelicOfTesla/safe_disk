import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';

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
  Object? _loadError;
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
    } catch (error) {
      debugPrint('secure-image-list-load-failed:$error');
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
          _loadError = null;
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
    } catch (error) {
      loadedData?.fillRange(0, loadedData.length, 0);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _loadError = error;
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
    _applyZoomFactor(1.2);
  }

  void _zoomOut() {
    _applyZoomFactor(1.0 / 1.2);
  }

  /// Apply a zoom factor while preserving the current focal point.
  void _applyZoomFactor(double factor) {
    final matrix = _transformController.value;
    final oldScale = matrix.getMaxScaleOnAxis();
    if (oldScale <= 0) return;
    final newScale = (oldScale * factor).clamp(0.1, 10.0);
    final effectiveFactor = newScale / oldScale;
    final translation = matrix.getTranslation();
    _transformController.value = Matrix4.identity()
      ..translateByDouble(translation.x * effectiveFactor,
          translation.y * effectiveFactor, 0, 1)
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
    final strings = AppLocalizations.of(context)!;
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
                  label:
                      Text(strings.animatedImageFrames(_metadata!.frameCount)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            // Zoom in
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: _zoomIn,
              tooltip: strings.zoomInShortcut,
            ),
            // Zoom out
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _zoomOut,
              tooltip: strings.zoomOutShortcut,
            ),
            // Reset view
            IconButton(
              icon: const Icon(Icons.fit_screen),
              onPressed: _resetView,
              tooltip: strings.resetImageViewShortcut,
            ),
            // Rotate
            IconButton(
              icon: const Icon(Icons.rotate_right),
              onPressed: _rotateImage,
              tooltip: strings.rotateClockwiseShortcut,
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomBar(strings),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations strings) {
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
            tooltip: strings.previousImageShortcut,
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
            tooltip: strings.nextImageShortcut,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final strings = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Center(
        child: Semantics(
          label: strings.loadingImage,
          liveRegion: true,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null) {
      final errorMessage = _loadErrorMessage(strings, _loadError!);
      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: '${strings.imageLoadFailed}: $errorMessage',
        liveRegion: true,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadImage,
                child: Text(strings.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_imageData == null || _imageProvider == null) {
      return Center(
        child: Semantics(
          label: strings.noDisplayableImage,
          liveRegion: true,
          child: Text(strings.noDisplayableImage),
        ),
      );
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
              // Only navigate when the image is at its natural fit (no zoom/pan).
              // When zoomed or panned, dragging should pan the viewport instead.
              final matrix = _transformController.value;
              final scale = matrix.getMaxScaleOnAxis();
              final translation = matrix.getTranslation();
              const edge = 1.0;
              if ((scale - 1.0).abs() > 0.01 ||
                  translation.x.abs() > edge ||
                  translation.y.abs() > edge) {
                return;
              }

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
                semanticLabel: strings.viewingImage(_currentFileName),
                fit: BoxFit.contain,
                gaplessPlayback: false,
                errorBuilder: (context, error, stackTrace) {
                  return Semantics(
                    container: true,
                    explicitChildNodes: true,
                    label:
                        '${strings.imageDecodeFailed}: ${strings.imageDecodeFailedDescription}',
                    liveRegion: true,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(strings.imageDecodeFailed),
                          const SizedBox(height: 8),
                          Text(
                            strings.imageDecodeFailedDescription,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadImage,
                            child: Text(strings.retry),
                          ),
                        ],
                      ),
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

  String _loadErrorMessage(AppLocalizations strings, Object error) {
    if (error is! SecureImagePolicyException) {
      return strings.imageEncryptedContentInvalid;
    }
    return switch (error.violation) {
      SecureImagePolicyViolation.encodedDataTooLarge =>
        strings.imageEncodedSizeLimit(formatImageByteLimit(error.limit!)),
      SecureImagePolicyViolation.emptyContent => strings.imageContentEmpty,
      SecureImagePolicyViolation.invalidDimensions =>
        strings.imageDimensionsInvalid,
      SecureImagePolicyViolation.decodedPixelsTooLarge =>
        strings.imageDecodedPixelLimit(formatImagePixelLimit(error.limit!)),
      SecureImagePolicyViolation.invalidOrUnsupportedContent =>
        strings.imageDecodeFailedDescription,
    };
  }
}
