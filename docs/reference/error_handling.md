# Safe Disk Go Core Library - Error Handling

> Go 错误处理参考文档。本文主体仍待中文化，当前实现状态请结合 [CODE_AUDIT_STATUS.md](../CODE_AUDIT_STATUS.md) 判断。

This document describes the unified error handling mechanism for the Safe Disk native Go library.

## Overview

The error handling system provides:
- **Unified error types** with machine-readable error codes
- **Rich context** including operation name and file path
- **FFI-friendly** JSON serialization for Flutter integration
- **Backward compatibility** with existing code

## Error Codes

Error codes are organized by category:

| Range    | Category      | Description                    |
|----------|---------------|--------------------------------|
| 0        | Success       | No error                       |
| 1-99     | General       | General operation errors       |
| 100-199  | Key           | Key-related errors             |
| 200-299  | Crypto        | Encryption/Decryption errors   |
| 300-399  | Stream        | Streaming operation errors     |
| 400-499  | File          | File operation errors          |
| 500-599  | Config        | Configuration errors           |
| 600-699  | Encoding      | Encoding/Decoding errors       |

### Common Error Codes

```
ErrSuccess                 = 0    // Operation completed successfully
ErrUnknown                = 1    // An unknown error occurred
ErrInvalidParameter       = 2    // Invalid parameter provided
ErrOperationFailed        = 3    // Operation failed

// Key errors (100-199)
ErrInvalidKeySize         = 100  // Invalid key size: expected 32 bytes for AES-256
ErrInvalidKey             = 101  // Invalid or corrupted key
ErrKeyNotFound            = 102  // Temporary key not found
ErrKeyExpired             = 103  // Temporary key has expired
ErrKeyDerivation          = 104  // Failed to derive encryption key
ErrRandomGeneration       = 105  // Failed to generate random data
ErrPasswordIncorrect      = 106  // Password is incorrect
ErrChallengeMismatch      = 107  // Challenge verification failed

// Crypto errors (200-299)
ErrEncryptionFailed       = 200  // Encryption operation failed
ErrDecryptionFailed       = 201  // Decryption operation failed
ErrInvalidCiphertext      = 202  // Invalid ciphertext format or length
ErrInvalidIV              = 203  // Invalid initialization vector
ErrAuthTagMismatch        = 204  // Authentication tag verification failed
ErrDataCorrupted          = 205  // Data is corrupted or tampered

// Stream errors (300-399)
ErrInvalidStreamFormat    = 300  // Invalid stream format
ErrInvalidChunkFormat     = 301  // Invalid chunk format
ErrStreamDecryptFailed    = 302  // Stream decryption failed
ErrStreamEncryptFailed    = 303  // Stream encryption failed
ErrInvalidChunkSize       = 304  // Invalid chunk size

// File errors (400-499)
ErrFileNotFound           = 400  // File not found
ErrFileRead               = 401  // Failed to read file
ErrFileWrite              = 402  // Failed to write file
ErrFileOpen               = 403  // Failed to open file
ErrFileStat               = 404  // Failed to get file information
ErrPathInvalid            = 405  // Invalid file path

// Config errors (500-599)
ErrConfigNotFound         = 500  // Encryption config file not found
ErrConfigParse            = 501  // Failed to parse config file
ErrConfigSave             = 502  // Failed to save config file
ErrConfigInvalid          = 503  // Invalid config file content

// Encoding errors (600-699)
ErrBase64Decode           = 600  // Failed to decode base64 data
ErrBase64Encode           = 601  // Failed to encode to base64
ErrJSONDecode             = 602  // Failed to decode JSON data
ErrJSONEncode             = 603  // Failed to encode to JSON
```

## Error Structure

Each error contains:

```go
type Error struct {
    Code      ErrorCode  // Machine-readable error code
    Message   string     // Human-readable error message
    Operation string     // Operation that caused the error (e.g., "encrypt", "decrypt")
    FilePath  string     // File path if applicable
    Cause     string     // Underlying error message
}
```

## FFI Integration

Errors are returned to Flutter via JSON:

```json
{
  "success": false,
  "error": "[encrypt_file] Failed to read file (file: /path/to/file.txt): open /path/to/file.txt: no such file or directory",
  "code": 401,
  "operation": "encrypt_file",
  "filePath": "/path/to/file.txt"
}
```

Flutter can use the `code` field to:
- Display localized error messages
- Implement specific error handling logic
- Log errors with structured data

## Usage Examples

### Creating Errors

```go
// Simple error
err := errors.New(errors.ErrInvalidKeySize)

// Error with custom message
err := errors.NewWithMessage(errors.ErrFileNotFound, "config file not found in vault directory")

// Wrapping an existing error
err := errors.Wrap(errors.ErrFileRead, underlyingErr)

// Wrapping with custom message
err := errors.WrapWithMessage(errors.ErrDecryptionFailed, "failed to decrypt chunk 5", underlyingErr)
```

### Adding Context

```go
// Add operation context
err := errors.WithOperation(err, "encrypt_file")

// Add file path context
err := errors.WithFile(err, "/path/to/file.txt")

// Add both
err := errors.WithContext(err, "decrypt_file", "/path/to/file.txt")
```

### Checking Errors

```go
// Check if error has specific code
if errors.Is(err, errors.ErrKeyExpired) {
    // Handle expired key
}

// Get error code
code := errors.GetCode(err)
switch code {
case errors.ErrFileNotFound:
    // Handle missing file
case errors.ErrPasswordIncorrect:
    // Handle wrong password
}
```

## Best Practices

1. **Always use error codes** instead of string comparison
2. **Add context** when propagating errors up the call stack
3. **Use WithFile** when dealing with file operations
4. **Use WithOperation** to clarify the failing operation
5. **Log both the error code and message** for debugging

## Migration from Old Error Handling

### Before
```go
if err != nil {
    return fmt.Errorf("failed to read file: %v", err)
}
```

### After
```go
if err != nil {
    return errors.WithFile(errors.Wrap(errors.ErrFileRead, err), filePath)
}
```

This provides:
- Machine-readable error code (401)
- File path context
- Clear error message
- Preserved error chain
