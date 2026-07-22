/// Upper bound for a fully materialized secure-notepad document.
///
/// The editor, undo history and encrypted draft all retain document bytes, so
/// large files need a streaming editor rather than a higher in-memory limit.
const kMaxSecureNotepadContentBytes = 16 * 1024 * 1024;

const kSecureNotepadContentLimitLabel = '16 MiB';
