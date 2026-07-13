import 'dart:convert';
import 'dart:typed_data';

import 'crypto_service.dart';

class SecureNotepadDraftStore {
  SecureNotepadDraftStore({required this.cryptoService});

  static const internalNamePrefix = '.__safedisk_notepad_draft_';

  final CryptoService cryptoService;

  static bool isDraftName(String name) => name.startsWith(internalNamePrefix);

  static String draftPathFor(String sourcePath) {
    final normalized = sourcePath.replaceAll('\\', '/');
    final separator = normalized.lastIndexOf('/');
    final parent = separator < 0 ? '' : normalized.substring(0, separator);
    final hash = _fnv1a64(normalized).toRadixString(16).padLeft(16, '0');
    final name = '$internalNamePrefix$hash.bin';
    return parent.isEmpty ? name : '$parent/$name';
  }

  Future<bool> exists(String sourcePath, String tempKeyID) {
    return cryptoService.fileExistsBySession(
      draftPathFor(sourcePath),
      tempKeyID,
    );
  }

  Future<String?> read(String sourcePath, String tempKeyID) async {
    final path = draftPathFor(sourcePath);
    if (!await cryptoService.fileExistsBySession(path, tempKeyID)) return null;
    final bytes = cryptoService.decryptFileToData(path, tempKeyID);
    return utf8.decode(bytes);
  }

  Future<void> write(
    String sourcePath,
    String tempKeyID,
    String content,
  ) {
    return cryptoService.writeFileBySession(
      draftPathFor(sourcePath),
      tempKeyID,
      Uint8List.fromList(utf8.encode(content)),
    );
  }

  Future<void> delete(String sourcePath, String tempKeyID) async {
    final path = draftPathFor(sourcePath);
    if (!await cryptoService.fileExistsBySession(path, tempKeyID)) return;
    await cryptoService.deleteFileBySession(path, tempKeyID);
  }
}

int _fnv1a64(String value) {
  const offset = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  const mask = 0xffffffffffffffff;
  var hash = offset;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * prime) & mask;
  }
  return hash;
}
