import 'crypto_service.dart';
import 'secure_clipboard_service.dart';

class SecureEntryMovePartialFailure implements Exception {
  const SecureEntryMovePartialFailure(this.cause);

  final Object cause;

  @override
  String toString() => 'secure-entry-move-source-delete-failed';
}

class SecureEntryMoveService {
  const SecureEntryMoveService(this._cryptoService);

  final CryptoService _cryptoService;

  Future<void> move({
    required SecureClipboardEntry entry,
    required String destinationPath,
    required String destinationSessionID,
    required bool overwrite,
  }) async {
    final sameRoot = entry.sourceSessionID == destinationSessionID;
    if (sameRoot && !overwrite) {
      await _cryptoService.renameBySession(
        entry.sourcePath,
        destinationPath,
        entry.sourceSessionID,
      );
      return;
    }
    await _cryptoService.copyBySession(
      sourcePath: entry.sourcePath,
      sourceSessionID: entry.sourceSessionID,
      destinationPath: destinationPath,
      destinationSessionID: destinationSessionID,
      overwrite: overwrite,
    );
    try {
      if (entry.isDirectory) {
        await _cryptoService.deleteDirectoryBySession(
          entry.sourcePath,
          entry.sourceSessionID,
        );
      } else {
        await _cryptoService.deleteFileBySession(
          entry.sourcePath,
          entry.sourceSessionID,
        );
      }
    } catch (error) {
      throw SecureEntryMovePartialFailure(error);
    }
  }
}
