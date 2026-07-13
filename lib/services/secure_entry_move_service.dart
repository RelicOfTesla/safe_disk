import 'crypto_service.dart';
import 'secure_clipboard_service.dart';

class SecureEntryMovePartialFailure implements Exception {
  const SecureEntryMovePartialFailure(this.cause);

  final Object cause;

  @override
  String toString() {
    return '目标文件已复制，但删除源文件失败；为避免数据丢失，源文件和目标文件均已保留。'
        '请确认后手动删除源文件。原始错误：$cause';
  }
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
    if (entry.isDirectory) {
      throw UnsupportedError(
        '跨 root 或替换已有目录的移动尚不安全：当前缺少递归删除源目录接口。'
        '可改用复制，确认内容后再手动删除源目录。',
      );
    }

    await _cryptoService.copyBySession(
      sourcePath: entry.sourcePath,
      sourceSessionID: entry.sourceSessionID,
      destinationPath: destinationPath,
      destinationSessionID: destinationSessionID,
      overwrite: overwrite,
    );
    try {
      await _cryptoService.deleteFileBySession(
        entry.sourcePath,
        entry.sourceSessionID,
      );
    } catch (error) {
      throw SecureEntryMovePartialFailure(error);
    }
  }
}
