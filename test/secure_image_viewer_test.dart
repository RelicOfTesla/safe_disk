import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/models/secure_image_policy.dart';
import 'package:safe_disk/services/content_window_host_bridge.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/document_window_client.dart';
import 'package:safe_disk/services/file_service.dart';
import 'package:safe_disk/services/remote_document_crypto_service.dart';
import 'package:safe_disk/widgets/secure_image_viewer.dart';
import 'package:safe_disk/windows/secure_image_window.dart';

import 'support/image_fixtures.dart';

void main() {
  test('recognizes every image format exposed by the browser', () {
    for (final extension in ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp']) {
      expect(isSupportedImageFormat(extension), isTrue);
      expect(isSupportedImageFormat(extension.toUpperCase()), isTrue);
    }
    expect(isSupportedImageFormat('svg'), isFalse);
    expect(isSupportedImageFormat(null), isFalse);
  });

  testWidgets('loads image bytes, zooms, rotates and clears memory on close',
      (tester) async {
    final bytes = _pngBytes();
    final crypto = _ImageCryptoService({'/one.png': bytes});
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      home: SecureImageViewer(
        file: _file('one.png', '/one.png'),
        cryptoService: crypto,
        tempKeyID: 'root-session',
        onClosed: () => closed = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('secure-image-content')), findsOneWidget);
    final viewer = tester.widget<InteractiveViewer>(
      find.byKey(const Key('secure-image-interactive-viewer')),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('secure-image-interactive-viewer')),
        matching: find.byType(Listener),
      ),
      findsWidgets,
      reason: '滚轮监听必须优先于 InteractiveViewer 的默认滚动处理注册',
    );
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);

    await tester.tap(find.byTooltip('放大（+）'));
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1.2);

    for (var index = 0; index < 14; index++) {
      await tester.tap(find.byTooltip('缩小（-）'));
    }
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 0.1);

    await tester.tap(find.byTooltip('重置视图（N）'));
    await tester.pump();
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    final viewerCenter = tester.getCenter(
      find.byKey(const Key('secure-image-interactive-viewer')),
    );
    mouse.hover(viewerCenter);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -20)));
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
      reason: '图片查看器必须接收滚轮缩放事件',
    );

    await tester.tap(find.byTooltip('重置视图（N）'));
    await tester.pump();
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      lessThan(1),
      reason: '滚轮缩小应使用与按钮相同的最小缩放范围',
    );

    for (var index = 0; index < 30; index++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
    }
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 0.1);

    final beforeRotation = tester
        .widget<Transform>(find.byKey(const Key('secure-image-rotation')))
        .transform
        .clone();
    await tester.tap(find.byTooltip('顺时针旋转（R）'));
    await tester.pump();
    final afterRotation = tester
        .widget<Transform>(find.byKey(const Key('secure-image-rotation')))
        .transform;
    expect(afterRotation, isNot(equals(beforeRotation)));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(closed, isTrue);
    expect(bytes.every((value) => value == 0), isTrue);
  });

  testWidgets('exposes loading, image, and failure states to assistive tools',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final inspection = Completer<SecureImageMetadata>();
    final bytes = _pngBytes();

    await tester.pumpWidget(MaterialApp(
      home: SecureImageViewer(
        file: _file('one.png', '/one.png'),
        cryptoService: _ImageCryptoService({'/one.png': bytes}),
        tempKeyID: 'root-session',
        imageInspector: (
          _, {
          int maxBytes = kMaxSecureImageEncodedBytes,
          int maxPixels = kMaxSecureImageDecodedPixels,
        }) =>
            inspection.future,
      ),
    ));
    await tester.pump();
    expect(find.bySemanticsLabel('正在加载图片'), findsOneWidget);

    inspection.complete(const SecureImageMetadata(
      width: 2,
      height: 2,
      frameCount: 1,
    ));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('正在查看：one.png'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: SecureImageViewer(
        key: const ValueKey('failed-image-viewer'),
        file: _file('empty.png', '/empty.png'),
        cryptoService: _ImageCryptoService({'/empty.png': Uint8List(0)}),
        tempKeyID: 'root-session',
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('图片加载失败：无法加载图片：图片内容为空'),
      findsOneWidget,
    );

    await tester.pumpWidget(MaterialApp(
      home: SecureImageViewer(
        key: const ValueKey('decoder-failed-image-viewer'),
        file: _file('invalid.png', '/invalid.png'),
        cryptoService: _ImageCryptoService({
          '/invalid.png': Uint8List.fromList([0]),
        }),
        tempKeyID: 'root-session',
        imageInspector: (
          _, {
          int maxBytes = kMaxSecureImageEncodedBytes,
          int maxPixels = kMaxSecureImageDecodedPixels,
        }) =>
            Future.value(const SecureImageMetadata(
          width: 1,
          height: 1,
          frameCount: 1,
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('无法显示图片：文件可能已损坏，或不是受支持的图片格式。'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('renders every format accepted by the browser codec',
      (tester) async {
    for (final extension in imageFixtureExtensions) {
      final bytes = imageFixture(extension);
      await tester.pumpWidget(MaterialApp(
        home: SecureImageViewer(
          file: _file('sample.$extension', '/sample.$extension'),
          cryptoService: _ImageCryptoService({
            '/sample.$extension': bytes,
          }),
          tempKeyID: 'root-session',
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('secure-image-content')),
        findsOneWidget,
        reason: extension,
      );
      expect(tester.takeException(), isNull, reason: extension);
      if (extension == 'gif') {
        expect(find.text('动画（2 帧）'), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(bytes.every((value) => value == 0), isTrue, reason: extension);
    }
  });

  testWidgets('known oversized image is rejected before decryption',
      (tester) async {
    final bytes = imageFixture('png');
    final crypto = _ImageCryptoService({'/large.png': bytes});
    await tester.pumpWidget(MaterialApp(
      home: SecureImageViewer(
        file: _file('large.png', '/large.png', size: bytes.length),
        cryptoService: crypto,
        tempKeyID: 'root-session',
        maxEncodedBytes: bytes.length - 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('编码数据超过'), findsOneWidget);
    expect(crypto.readPaths, isEmpty);
    expect(bytes.any((value) => value != 0), isTrue);
  });

  testWidgets('unknown oversized image is cleared after decryption',
      (tester) async {
    final bytes = imageFixture('png');
    final crypto = _ImageCryptoService({'/large.png': bytes});
    await tester.pumpWidget(MaterialApp(
      home: SecureImageViewer(
        file: _file('large.png', '/large.png'),
        cryptoService: crypto,
        tempKeyID: 'root-session',
        maxEncodedBytes: bytes.length - 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('编码数据超过'), findsOneWidget);
    expect(crypto.readPaths, ['/large.png']);
    expect(bytes.every((value) => value == 0), isTrue);
  });

  testWidgets('stale asynchronous inspection cannot replace a newer image',
      (tester) async {
    final first = imageFixture('png');
    final second = imageFixture('jpg');
    final firstInspection = Completer<SecureImageMetadata>();
    var inspectionCalls = 0;
    final crypto = _ImageCryptoService({
      '/photos/one.png': first,
      '/photos/two.jpg': second,
    });
    final fileService = _ImageFileService(crypto, [
      _node('one.png', '/photos/one.png', size: first.length),
      _node('two.jpg', '/photos/two.jpg', size: second.length),
    ]);
    Future<SecureImageMetadata> inspector(
      Uint8List data, {
      int maxBytes = kMaxSecureImageEncodedBytes,
      int maxPixels = kMaxSecureImageDecodedPixels,
    }) {
      inspectionCalls++;
      if (inspectionCalls == 1) return firstInspection.future;
      return Future.value(const SecureImageMetadata(
        width: 2,
        height: 3,
        frameCount: 1,
      ));
    }

    await tester.pumpWidget(MaterialApp(
      home: SecureImageViewer(
        file: _file('one.png', '/photos/one.png', size: first.length),
        cryptoService: crypto,
        tempKeyID: 'root-session',
        directoryPath: '/photos',
        fileService: fileService,
        imageInspector: inspector,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(inspectionCalls, 1);
    expect(find.byTooltip('下一张（→）'), findsOneWidget);

    await tester.tap(find.byTooltip('下一张（→）'));
    await tester.pumpAndSettle();
    expect(find.text('two.jpg'), findsOneWidget);
    expect(find.byKey(const Key('secure-image-content')), findsOneWidget);

    firstInspection.complete(const SecureImageMetadata(
      width: 2,
      height: 3,
      frameCount: 1,
    ));
    await tester.pumpAndSettle();
    expect(find.text('two.jpg'), findsOneWidget);
    expect(first.every((value) => value == 0), isTrue);
    expect(second.any((value) => value != 0), isTrue);
  });

  testWidgets('navigates images in one directory and clears the previous bytes',
      (tester) async {
    final first = _pngBytes();
    final second = _pngBytes();
    final crypto = _ImageCryptoService({
      '/photos/one.png': first,
      '/photos/two.png': second,
    });
    final fileService = _ImageFileService(crypto, [
      _node('one.png', '/photos/one.png'),
      _node('notes.txt', '/photos/notes.txt'),
      _node('two.png', '/photos/two.png'),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: SecureImageViewer(
        file: _file('one.png', '/photos/one.png'),
        cryptoService: crypto,
        tempKeyID: 'root-session',
        directoryPath: '/photos',
        fileService: fileService,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('two.png'), findsOneWidget);
    expect(find.text('2 / 2'), findsWidgets);
    expect(first.every((value) => value == 0), isTrue);
  });

  testWidgets('retry after a navigation failure reloads the current image',
      (tester) async {
    final crypto = _ImageCryptoService({
      '/photos/one.png': _pngBytes(),
      '/photos/two.png': Uint8List(0),
    });
    final fileService = _ImageFileService(crypto, [
      _node('one.png', '/photos/one.png'),
      _node('two.png', '/photos/two.png'),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: SecureImageViewer(
        file: _file('one.png', '/photos/one.png'),
        cryptoService: crypto,
        tempKeyID: 'root-session',
        directoryPath: '/photos',
        fileService: fileService,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下一张（→）'));
    await tester.pumpAndSettle();
    expect(find.textContaining('图片内容为空'), findsOneWidget);

    crypto.images['/photos/two.png'] = _pngBytes();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(crypto.readPaths.last, '/photos/two.png');
    expect(find.byKey(const Key('secure-image-content')), findsOneWidget);
    expect(find.text('two.png'), findsOneWidget);
  });

  testWidgets('remote image window avoids channel calls during engine dispose',
      (tester) async {
    final client = _ImageDocumentClient(_pngBytes());
    final service = RemoteDocumentCryptoService(
      client: client,
      initialSnapshot: client.snapshot,
    );
    await tester.pumpWidget(SafeDiskImageWindow(
      arguments: ContentWindowArguments(
        kind: DesktopMultiWindowPlatform.imageWindowKind,
        token: client.token,
        documentID: 'image-document',
        title: 'remote.png',
      ),
      client: client,
      cryptoService: service,
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('en'),
    );
    expect(find.text('remote.png'), findsOneWidget);
    expect(find.byKey(const Key('secure-image-content')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(client.closed, isFalse);
  });
}

Uint8List _pngBytes() => imageFixture('png');

EncryptedFile _file(String name, String path, {int? size}) => EncryptedFile(
      name: name,
      encryptedPath: path,
      originalSize: size,
      modifiedTime: DateTime(2026),
    );

FileSystemNode _node(String name, String path, {int? size}) => FileSystemNode(
      name: name,
      path: path,
      isDirectory: false,
      size: size,
    );

class _ImageCryptoService extends CryptoService {
  _ImageCryptoService(this.images);

  final Map<String, Uint8List> images;
  final List<String> readPaths = [];

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    readPaths.add(path);
    return images[path]!;
  }
}

class _ImageFileService extends FileService {
  _ImageFileService(CryptoService cryptoService, this.nodes)
      : super(cryptoService: cryptoService);

  final List<FileSystemNode> nodes;

  @override
  Future<List<FileSystemNode>> listCurrentDirectory(
    String path, {
    int offset = 0,
    int? limit,
  }) async {
    final end =
        limit == null ? nodes.length : (offset + limit).clamp(0, nodes.length);
    return nodes.sublist(offset.clamp(0, nodes.length), end);
  }
}

class _ImageDocumentClient extends DocumentWindowClient {
  _ImageDocumentClient(this.bytes) : super('image-window-token');

  final Uint8List bytes;
  bool closed = false;

  RemoteDocumentSnapshot get snapshot => RemoteDocumentSnapshot(
        content: Uint8List.fromList(bytes),
        revision: 1,
      );

  @override
  Future<void> close() async {
    closed = true;
  }
}
