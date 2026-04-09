// Package crypto_data provides common utilities for encryption implementations.
package crypt_utils

import (
	"io"
	"sync"
)

// ChunkBufferSize defines the buffer size for gap filling operations.
// 64KB is a good balance between memory usage and I/O efficiency.
const ChunkBufferSize = 64 * 1024 // 64KB

// chunkBufferPool is a pool for reusing gap fill buffers.
// This reduces memory allocation overhead for frequent gap fill operations.
var chunkBufferPool = sync.Pool{
	New: func() interface{} {
		buf := make([]byte, ChunkBufferSize)
		return &buf
	},
}

// FillGap fills a gap using a fixed-size buffer to avoid
// allocating the entire gap size at once.
//
// Parameters:
//   - writer: the underlying storage to write to
//   - startPos: the starting position of the gap
//   - gapSize: the size of the gap to fill
//   - encryptFunc: function to encrypt data at a specific position
//     (data, pos) -> error
//
// This function uses a fixed 64KB buffer to fill the gap in chunks,
// reducing memory consumption from O(gapSize) to O(64KB).
func FillGap(
	writer io.Writer,
	startPos int64,
	gapSize int64,
	encryptFunc func(data []byte, pos int64) error,
) error {
	if gapSize <= 0 {
		return nil
	}

	// Get buffer from pool
	pooledBuf := chunkBufferPool.Get().(*[]byte)
	buf := *pooledBuf
	defer chunkBufferPool.Put(pooledBuf)

	currentPos := startPos
	remaining := gapSize

	for remaining > 0 {
		// Determine chunk size
		chunkSize := minInt64(int64(len(buf)), remaining)
		chunk := buf[:chunkSize]

		// Clear buffer to zeros
		clear(chunk)

		// Encrypt the chunk (in-place)
		if err := encryptFunc(chunk, currentPos); err != nil {
			return err
		}

		// Write the encrypted chunk
		_, err := writer.Write(chunk)
		if err != nil {
			return err
		}

		currentPos += chunkSize
		remaining -= chunkSize
	}

	return nil
}


// minInt64 returns the minimum of two int64 values.
func minInt64(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}

// ProcessDataInChunks processes data in fixed-size chunks to avoid
// allocating large buffers. This is useful for encrypting/decrypting
// large data without allocating a separate buffer.
//
// Parameters:
//   - data: the data to process (will NOT be modified)
//   - startPos: the starting position in the file
//   - processFunc: function to process each chunk
//   - tempBuf: pre-allocated temporary buffer (from pool)
//   - srcData: source data chunk (read-only)
//   - pos: current position
//     Returns: error
//
// This function processes data in 64KB chunks, reducing memory allocation.
func ProcessDataInChunks(
	data []byte,
	startPos int64,
	processFunc func(tempBuf []byte, srcData []byte, pos int64) error,
) error {
	if len(data) == 0 {
		return nil
	}

	// Get buffer from pool for temporary storage
	pooledBuf := chunkBufferPool.Get().(*[]byte)
	tempBuf := *pooledBuf
	defer chunkBufferPool.Put(pooledBuf)

	currentPos := startPos
	offset := 0

	for offset < len(data) {
		// Determine chunk size
		chunkSize := minInt64(int64(len(data)-offset), int64(len(tempBuf)))
		srcChunk := data[offset : offset+int(chunkSize)]

		// Process the chunk
		if err := processFunc(tempBuf[:chunkSize], srcChunk, currentPos); err != nil {
			return err
		}

		currentPos += chunkSize
		offset += int(chunkSize)
	}

	return nil
}

// EncryptAndWriteInChunks encrypts data in chunks and writes to storage.
// This is optimized for encryption operations that need to write encrypted data.
//
// Parameters:
//   - writer: the underlying storage to write to
//   - data: the data to encrypt and write (will NOT be modified)
//   - startPos: the starting position in the file
//   - encryptInPlaceFunc: function to encrypt data in-place at a position
//
// This function uses a fixed 64KB buffer from pool, reducing memory allocation.
func EncryptAndWriteInChunks(
	writer io.Writer,
	data []byte,
	startPos int64,
	encryptInPlaceFunc func(data []byte, pos int64),
) (int, error) {
	if len(data) == 0 {
		return 0, nil
	}

	// Get buffer from pool
	pooledBuf := chunkBufferPool.Get().(*[]byte)
	tempBuf := *pooledBuf
	defer chunkBufferPool.Put(pooledBuf)

	currentPos := startPos
	offset := 0
	totalWritten := 0

	for offset < len(data) {
		// Determine chunk size
		chunkSize := minInt64(int64(len(data)-offset), int64(len(tempBuf)))
		srcChunk := data[offset : offset+int(chunkSize)]
		dstChunk := tempBuf[:chunkSize]

		// Copy source to temp buffer
		copy(dstChunk, srcChunk)

		// Encrypt in-place on temp buffer
		encryptInPlaceFunc(dstChunk, currentPos)

		// Write the encrypted chunk
		n, err := writer.Write(dstChunk)
		if n > 0 {
			totalWritten += n
			currentPos += int64(n)
		}
		if err != nil {
			return totalWritten, err
		}

		offset += int(chunkSize)
	}

	return totalWritten, nil
}

// EncryptAndWriteAtInChunks encrypts data in chunks and writes to storage at a specific offset.
// This is optimized for encryption operations that need to write encrypted data at an offset.
//
// Parameters:
//   - writerAt: the underlying storage to write to (supports WriteAt)
//   - data: the data to encrypt and write (will NOT be modified)
//   - offset: the offset to write at
//   - encryptInPlaceFunc: function to encrypt data in-place at a position
//
// This function uses a fixed 64KB buffer from pool, reducing memory allocation.
func EncryptAndWriteAtInChunks(
	writerAt io.WriterAt,
	data []byte,
	offset int64,
	encryptInPlaceFunc func(data []byte, pos int64),
) (int, error) {
	if len(data) == 0 {
		return 0, nil
	}

	// Get buffer from pool
	pooledBuf := chunkBufferPool.Get().(*[]byte)
	tempBuf := *pooledBuf
	defer chunkBufferPool.Put(pooledBuf)

	currentPos := offset
	dataOffset := 0
	totalWritten := 0

	for dataOffset < len(data) {
		// Determine chunk size
		chunkSize := minInt64(int64(len(data)-dataOffset), int64(len(tempBuf)))
		srcChunk := data[dataOffset : dataOffset+int(chunkSize)]
		dstChunk := tempBuf[:chunkSize]

		// Copy source to temp buffer
		copy(dstChunk, srcChunk)

		// Encrypt in-place on temp buffer
		encryptInPlaceFunc(dstChunk, currentPos)

		// Write the encrypted chunk at current position
		n, err := writerAt.WriteAt(dstChunk, currentPos)
		if n > 0 {
			totalWritten += n
			currentPos += int64(n)
		}
		if err != nil {
			return totalWritten, err
		}

		dataOffset += int(chunkSize)
	}

	return totalWritten, nil
}
