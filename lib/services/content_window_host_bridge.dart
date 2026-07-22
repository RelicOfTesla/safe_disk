import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import 'document_session_broker.dart';

typedef ContentWindowCallHandler = Future<Object?> Function(MethodCall call);

abstract class ContentWindowPlatform {
  Future<void> setHostHandler(ContentWindowCallHandler? handler);

  Future<bool> openNotepad({
    required String token,
    required String documentID,
    required String title,
    required String localePreference,
  });

  Future<bool> openImage({
    required String token,
    required String documentID,
    required String title,
    required String localePreference,
  });

  Future<void> closeTokens(Set<String> tokens);

  Stream<Set<String>> get aliveTokens;
}

class DesktopMultiWindowPlatform implements ContentWindowPlatform {
  DesktopMultiWindowPlatform();

  static const hostChannelName = 'safe_disk/document_host/v1';
  static const argumentVersion = 2;
  static const legacyArgumentVersion = 1;
  static const notepadWindowKind = 'secure_notepad';
  static const imageWindowKind = 'secure_image';

  final WindowMethodChannel _hostChannel = const WindowMethodChannel(
    hostChannelName,
    mode: ChannelMode.unidirectional,
  );
  final Map<String, WindowController> _controllers = {};

  @override
  Future<void> setHostHandler(ContentWindowCallHandler? handler) {
    return _hostChannel.setMethodCallHandler(handler);
  }

  @override
  Future<bool> openNotepad({
    required String token,
    required String documentID,
    required String title,
    required String localePreference,
  }) {
    return _openContentWindow(
      kind: notepadWindowKind,
      token: token,
      documentID: documentID,
      title: title,
      localePreference: localePreference,
    );
  }

  @override
  Future<bool> openImage({
    required String token,
    required String documentID,
    required String title,
    required String localePreference,
  }) {
    return _openContentWindow(
      kind: imageWindowKind,
      token: token,
      documentID: documentID,
      title: title,
      localePreference: localePreference,
    );
  }

  Future<bool> _openContentWindow({
    required String kind,
    required String token,
    required String documentID,
    required String title,
    required String localePreference,
  }) async {
    final controller = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        title: title,
        width: 960,
        height: 720,
        arguments: jsonEncode({
          'version': argumentVersion,
          'kind': kind,
          'token': token,
          'documentID': documentID,
          'title': title,
          'localePreference': localePreference,
        }),
      ),
    );
    _controllers[token] = controller;
    return true;
  }

  @override
  Future<void> closeTokens(Set<String> tokens) async {
    for (final token in tokens) {
      final controller = _controllers[token];
      if (controller == null) continue;
      await controller.close();
      _controllers.remove(token);
    }
  }

  @override
  Stream<Set<String>> get aliveTokens async* {
    await for (final _ in onWindowsChanged) {
      final controllers = await WindowController.getAll();
      final tokens = controllers
          .map((controller) => tryParseArguments(controller.arguments))
          .whereType<ContentWindowArguments>()
          .map((arguments) => arguments.token)
          .toSet();
      _controllers.removeWhere((token, _) => !tokens.contains(token));
      yield tokens;
    }
  }

  static ContentWindowArguments? tryParseArguments(String value) {
    if (value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic> ||
          (json['version'] != argumentVersion &&
              json['version'] != legacyArgumentVersion)) {
        return null;
      }
      final kind = json['kind'];
      if (kind != notepadWindowKind && kind != imageWindowKind) return null;
      final token = json['token'];
      final documentID = json['documentID'];
      final title = json['title'];
      final localePreference = json['localePreference'];
      if (token is! String ||
          token.isEmpty ||
          documentID is! String ||
          documentID.isEmpty ||
          title is! String ||
          title.isEmpty) {
        return null;
      }
      if (localePreference != null &&
          (localePreference is! String || localePreference.isEmpty)) {
        return null;
      }
      return ContentWindowArguments(
        kind: kind as String,
        token: token,
        documentID: documentID,
        title: title,
        localePreference: localePreference as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class ContentWindowArguments {
  const ContentWindowArguments({
    required this.kind,
    required this.token,
    required this.documentID,
    required this.title,
    this.localePreference,
  });

  final String kind;
  final String token;
  final String documentID;
  final String title;
  final String? localePreference;
}

class ContentWindowHostBridge {
  ContentWindowHostBridge({
    required DocumentSessionBroker broker,
    ContentWindowPlatform? platform,
  })  : _broker = broker,
        _platform = platform ?? DesktopMultiWindowPlatform();

  final DocumentSessionBroker _broker;
  final ContentWindowPlatform _platform;
  final Set<String> _nativeTokens = {};
  StreamSubscription<Set<String>>? _windowSubscription;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await _platform.setHostHandler(_handleWindowCall);
      _windowSubscription = _platform.aliveTokens.listen(_reconcileWindows);
    } catch (_) {
      _started = false;
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (!_started) return;
    _started = false;
    await _windowSubscription?.cancel();
    _windowSubscription = null;
    try {
      await _platform.setHostHandler(null);
    } catch (_) {
      // A platform can disappear while the app is shutting down.
    }
  }

  Future<bool> openNotepad(
    DocumentLease lease, {
    required String localePreference,
  }) async {
    return _open(lease, localePreference, _platform.openNotepad);
  }

  Future<bool> openImage(
    DocumentLease lease, {
    required String localePreference,
  }) async {
    return _open(lease, localePreference, _platform.openImage);
  }

  Future<bool> _open(
    DocumentLease lease,
    String localePreference,
    Future<bool> Function({
      required String token,
      required String documentID,
      required String title,
      required String localePreference,
    }) openWindow,
  ) async {
    try {
      await start();
      final opened = await openWindow(
        token: lease.token,
        documentID: lease.documentID,
        title: lease.displayName,
        localePreference: localePreference,
      );
      if (opened) _nativeTokens.add(lease.token);
      return opened;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on WindowChannelException {
      return false;
    }
  }

  Future<void> closeRootWindows(String rootSessionID) async {
    final tokens = _broker.tokensForRoot(rootSessionID).intersection(
          _nativeTokens,
        );
    // A native close is asynchronous. Revoke before awaiting it so a window
    // that is still tearing down cannot use its token after the root changes.
    // Existing writes finish while the native root is still available.
    await _broker.revokeRootSessions(rootSessionID);
    await _platform.closeTokens(tokens);
    for (final token in tokens) {
      _nativeTokens.remove(token);
    }
  }

  void _reconcileWindows(Set<String> aliveTokens) {
    final closedTokens = _nativeTokens.difference(aliveTokens);
    for (final token in closedTokens) {
      _broker.close(token);
      _nativeTokens.remove(token);
    }
  }

  Future<Object?> _handleWindowCall(MethodCall call) async {
    try {
      final arguments = _arguments(call);
      final token = _requiredString(arguments, 'token');
      switch (call.method) {
        case 'document.read':
          return _snapshotMap(_broker.read(token));
        case 'document.save':
          final revision = arguments['revision'];
          final content = arguments['content'];
          if (revision is! int || content is! Uint8List) {
            throw const FormatException('revision 或 content 格式无效');
          }
          return _snapshotMap(await _broker.save(
            token: token,
            baseRevision: revision,
            content: content,
          ));
        case 'document.draftRead':
          return _broker.readDraft(token);
        case 'document.draftWrite':
          final content = arguments['content'];
          if (content is! Uint8List) {
            throw const FormatException('content 格式无效');
          }
          await _broker.writeDraft(token, content);
          return null;
        case 'document.draftDelete':
          await _broker.deleteDraft(token);
          return null;
        case 'document.setDirty':
          final dirty = arguments['dirty'];
          if (dirty is! bool) throw const FormatException('dirty 格式无效');
          _broker.setDirty(token, dirty);
          return null;
        case 'document.closed':
          _nativeTokens.remove(token);
          _broker.close(token);
          return null;
        default:
          throw PlatformException(
            code: 'unsupported_method',
            message: '不支持的内容窗口调用：${call.method}',
          );
      }
    } on DocumentSessionConflict catch (error) {
      throw PlatformException(code: 'write_conflict', message: error.message);
    } on DocumentSessionNotFound catch (error) {
      throw PlatformException(code: 'session_not_found', message: '$error');
    } on DocumentSessionReadOnly catch (error) {
      throw PlatformException(code: 'read_only', message: '$error');
    } on DocumentContentLimitExceeded catch (error) {
      throw PlatformException(code: 'content_too_large', message: '$error');
    } on FormatException catch (error) {
      throw PlatformException(code: 'invalid_request', message: error.message);
    }
  }

  Map<Object?, Object?> _arguments(MethodCall call) {
    final arguments = call.arguments;
    if (arguments is! Map) throw const FormatException('请求参数必须是 map');
    return arguments.cast<Object?, Object?>();
  }

  String _requiredString(Map<Object?, Object?> arguments, String key) {
    final value = arguments[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key 格式无效');
    }
    return value;
  }

  Map<String, Object> _snapshotMap(DocumentSnapshot snapshot) => {
        'revision': snapshot.revision,
        'content': snapshot.content,
      };
}
