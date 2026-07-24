# Safe Disk

> **AI Coding Notice**: This project is co-developed with AI assistance. All code, tests, and documentation are generated or reviewed by AI models. Verify critical security and cryptographic paths independently before production use.

Cross-platform encrypted directory management tool. Supports Windows, Linux, and macOS.

[中文版](README_zh.md)

## Project Status

Core backend is stable, Flutter UI is under active iteration.

- Flutter UI: vault unlock, file browsing, import/export, secure notepad, image viewer, WebDAV sharing.
- Go crypto backend: AES-CTR/XTS, ChaCha20 data encryption; AES-GCM filename encryption; PBKDF2/Argon2/scrypt key derivation.
- Native interop layer: vault management, file operations, copy, import/export, convert.
- CLI tool: vault management, import/export, WebDAV service.
- See [docs](docs/README.md) and [Code Audit Status](docs/CODE_AUDIT_STATUS.md) for detailed progress.

## Core Features

- Multi-vault encrypted directory management
- Native-like file browser (grid / list / tree views)
- Secure notepad (Flutter-rendered, anti-keylogger)
- Encrypted image viewer (zoom, pan, multi-image navigation)
- Secure import/export (in-place encryption/decryption, atomic migration)
- WebDAV read-only sharing (Basic Auth, Digest, TLS)
- Cross-platform clipboard support
- Pluggable encryption (AES-CTR / XTS / ChaCha20, PBKDF2 / Argon2 / scrypt)
- Filename and directory name encryption
- Auto-lock with in-memory key cleanup
- Multi-window secure notepad and image viewer
- Dark/light themes, i18n (Chinese / English)

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter (Dart) |
| Backend | Go (crypto, file ops, WebDAV) |
| IPC | C shared library (native interop) |
| Build | Go cross-compile + Flutter build |

## Project Structure

```
safe_disk/
├── lib/                      # Flutter code
│   ├── native/              # Native interop bindings
│   ├── models/              # Data models
│   ├── services/            # Services (crypto, settings, WebDAV, multi-window)
│   ├── pages/               # UI pages
│   ├── widgets/             # Widgets (notepad, image viewer, file browser)
│   └── utils/               # Utilities
├── native/                   # Go code
│   ├── cli/                 # CLI tool
│   ├── config/              # Config management
│   ├── ffi_sec_fs/          # Native bridge export layer
│   └── sec_fs/              # Core encrypted filesystem
│       ├── crypto_data/     # Data encryption
│       ├── crypto_hkdf/     # Key derivation
│       ├── crypto_name/     # Filename encryption
│       ├── sec_transfer/    # Secure transfer (atomic import/export)
│       └── sec_utils/       # Path utilities
├── docs/                     # Documentation
└── scripts/                  # Build scripts
```

## Quick Start

### Prerequisites

- Flutter SDK (^3.5.4)
- Go 1.25+
- Linux: GTK development libraries
- Windows: Visual Studio Build Tools

### Build & Run

```bash
# Recommended: use the build script
./scripts/build_and_run.sh

# Manual build
cd native
go build -buildmode=c-shared -o libsafedisk_native.so && cp libsafedisk_native.so ../linux/
flutter pub get
flutter run -d linux
```

### Build CLI

```bash
cd native
go build -o safe-disk ./cli/
```

### Run Tests

```bash
cd native && go test ./...
flutter test
```

## Encryption

| Component | Default | Pluggable |
|---|---|---|
| Data | AES-256-CTR | AES-XTS, ChaCha20, RC4 |
| Filename | AES-256-GCM | — |
| Key derivation | PBKDF2 | Argon2, scrypt |
| Key exchange | HKDF-SHA256 | — |

Vault configuration is stored per directory (checksums, iterations, algorithm selection).

## Threat Model

- **Anti-keylogger**: Notepad uses Flutter rendering (no native text widgets).
- **Anti-filesystem scan**: All decryption is in-memory; no plaintext ever touches disk.
- **Anti-screenshot** (optional): Window content protection.
- **Anti-memory scan** (optional): Zero-fill buffers after use.

## Documentation

- [Docs Index](docs/README.md)
- [Code Audit Status](docs/CODE_AUDIT_STATUS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Native Interop Design](docs/FFI_DESIGN.md)
- [CLI Design](docs/CLI_DESIGN.md)
- [Encryption](docs/ENCRYPTION.md)
- [Transfer Design](docs/TRANSFER_DESIGN.md)
- [Development Standards](docs/DEVELOPMENT_STANDARDS.md)
- [Active Tasks](docs/TODO.md)
- [Platform Acceptance](docs/PLATFORM_ACCEPTANCE.md)

## License

TBD
