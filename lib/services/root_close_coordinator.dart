import 'document_session_broker.dart';

enum RootCloseDisposition {
  closeImmediately,
  confirmClosingWindows,
  blockedByUnsavedDocuments,
  blockedByActiveWrites,
}

class RootCloseDecision {
  const RootCloseDecision({
    required this.disposition,
    required this.windowCount,
    required this.dirtyDocumentNames,
    required this.activeWriteCount,
  });

  final RootCloseDisposition disposition;
  final int windowCount;
  final List<String> dirtyDocumentNames;
  final int activeWriteCount;
}

class RootCloseCoordinator {
  const RootCloseCoordinator(this._broker);

  final DocumentSessionBroker _broker;

  RootCloseDecision inspect(String rootSessionID) {
    final summary = _broker.summarizeRoot(rootSessionID);
    final disposition = summary.hasActiveWrites
        ? RootCloseDisposition.blockedByActiveWrites
        : summary.hasDirtyWindows
            ? RootCloseDisposition.blockedByUnsavedDocuments
            : summary.hasWindows
                ? RootCloseDisposition.confirmClosingWindows
                : RootCloseDisposition.closeImmediately;
    return RootCloseDecision(
      disposition: disposition,
      windowCount: summary.windowCount,
      dirtyDocumentNames: summary.dirtyDocumentNames,
      activeWriteCount: summary.activeWriteCount,
    );
  }

  void releaseRoot(String rootSessionID) {
    _broker.closeRootSessions(rootSessionID);
  }
}
