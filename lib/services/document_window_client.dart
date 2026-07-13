import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'content_window_host_bridge.dart';

abstract class DocumentWindowChannel {
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]);
}

class DesktopDocumentWindowChannel implements DocumentWindowChannel {
  const DesktopDocumentWindowChannel();

  static const _channel = WindowMethodChannel(
    DesktopMultiWindowPlatform.hostChannelName,
    mode: ChannelMode.unidirectional,
  );

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }
}

class DocumentWindowRequestTimeout implements Exception {
  const DocumentWindowRequestTimeout(this.operation);

  final String operation;

  @override
  String toString() => '主窗口未在限定时间内响应：$operation';
}

class RemoteDocumentSnapshot {
  const RemoteDocumentSnapshot({
    required this.content,
    required this.revision,
  });

  final Uint8List content;
  final int revision;
}

class DocumentWindowClient {
  DocumentWindowClient(
    this.token, {
    DocumentWindowChannel? channel,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _channel = channel ?? const DesktopDocumentWindowChannel();

  final String token;
  final Duration requestTimeout;
  final DocumentWindowChannel _channel;

  Future<RemoteDocumentSnapshot> read() async {
    final result = await _request(
      '读取文档',
      () => _channel.invokeMethod<Map<dynamic, dynamic>>(
        'document.read',
        {'token': token},
      ),
    );
    return _parseSnapshot(result);
  }

  Future<RemoteDocumentSnapshot> save(int revision, List<int> content) async {
    final result = await _request(
      '保存文档',
      () => _channel.invokeMethod<Map<dynamic, dynamic>>(
        'document.save',
        {
          'token': token,
          'revision': revision,
          'content': Uint8List.fromList(content),
        },
      ),
    );
    return _parseSnapshot(result);
  }

  Future<Uint8List?> readDraft() async {
    return _request(
      '读取安全草稿',
      () => _channel.invokeMethod<Uint8List>(
        'document.draftRead',
        {'token': token},
      ),
    );
  }

  Future<void> writeDraft(List<int> content) async {
    await _request(
      '写入安全草稿',
      () => _channel.invokeMethod<void>(
        'document.draftWrite',
        {'token': token, 'content': Uint8List.fromList(content)},
      ),
    );
  }

  Future<void> deleteDraft() async {
    await _request(
      '删除安全草稿',
      () => _channel.invokeMethod<void>(
        'document.draftDelete',
        {'token': token},
      ),
    );
  }

  Future<void> setDirty(bool dirty) async {
    await _request(
      '同步编辑状态',
      () => _channel.invokeMethod<void>(
        'document.setDirty',
        {'token': token, 'dirty': dirty},
      ),
    );
  }

  Future<void> close() async {
    await _request(
      '关闭文档会话',
      () => _channel.invokeMethod<void>(
        'document.closed',
        {'token': token},
      ),
    );
  }

  Future<T> _request<T>(
    String operation,
    Future<T> Function() request,
  ) async {
    try {
      return await request().timeout(requestTimeout);
    } on TimeoutException {
      throw DocumentWindowRequestTimeout(operation);
    }
  }

  RemoteDocumentSnapshot _parseSnapshot(Map<dynamic, dynamic>? value) {
    final revision = value?['revision'];
    final content = value?['content'];
    if (revision is! int || content is! Uint8List) {
      throw StateError('主窗口返回了无效的文档快照');
    }
    return RemoteDocumentSnapshot(content: content, revision: revision);
  }
}
