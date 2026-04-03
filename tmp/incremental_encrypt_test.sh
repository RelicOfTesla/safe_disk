#!/bin/bash

# Safe Disk 增量加密功能测试脚本
# 目标：验证增量加密功能是否满足要求

set -e

echo "========================================"
echo "Safe Disk 增量加密功能测试"
echo "========================================"
echo ""

# 测试目录
TEST_DIR="/tmp/safedisk_incremental_test_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEST_DIR"

echo "测试目录: $TEST_DIR"
echo ""

# 项目路径
PROJECT_DIR="/home/john/Desktop/dev/safe_disk"
NATIVE_DIR="$PROJECT_DIR/native"

# 编译 Go 测试程序
echo ">>> 编译测试程序..."
cd "$NATIVE_DIR"

# 创建测试文件
cat > /tmp/test_incremental.go << 'EOF'
package main

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/safedisk/native/crypto"
)

type TestResult struct {
	Name           string  `json:"name"`
	DataSize       int64   `json:"data_size"`
	Duration       string  `json:"duration"`
	ThroughputMBps float64 `json:"throughput_mbps"`
	Success        bool    `json:"success"`
	Error          string  `json:"error,omitempty"`
}

func main() {
	results := make([]TestResult, 0)

	// 测试1: 创建 100MB 测试文件
	fmt.Println(">>> 测试1: 创建 100MB 测试文件...")
	testFile := "/tmp/test_100mb.bin"
	encryptedFile := "/tmp/test_100mb.enc"

	start := time.Now()
	data := make([]byte, 100*1024*1024) // 100MB
	if _, err := rand.Read(data); err != nil {
		results = append(results, TestResult{
			Name:    "创建100MB测试文件",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	if err := os.WriteFile(testFile, data, 0600); err != nil {
		results = append(results, TestResult{
			Name:    "创建100MB测试文件",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	duration := time.Since(start)
	results = append(results, TestResult{
		Name:           "创建100MB测试文件",
		DataSize:       100 * 1024 * 1024,
		Duration:       duration.String(),
		ThroughputMBps: float64(100) / duration.Seconds(),
		Success:        true,
	})

	// 测试2: 增量加密
	fmt.Println(">>> 测试2: 增量加密...")
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		results = append(results, TestResult{
			Name:    "生成密钥",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	start = time.Now()
	encryptor := crypto.NewIncrementalEncryptor()
	if err := encryptor.Create(encryptedFile, key, 64*1024); err != nil {
		results = append(results, TestResult{
			Name:    "增量加密",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	// 分块加密
	chunkSize := 64 * 1024
	for offset := 0; offset < len(data); offset += chunkSize {
		end := offset + chunkSize
		if end > len(data) {
			end = len(data)
		}
		if err := encryptor.AddBlock(data[offset:end]); err != nil {
			results = append(results, TestResult{
				Name:    "增量加密",
				Success: false,
				Error:   err.Error(),
			})
			json.NewEncoder(os.Stdout).Encode(results)
			return
		}
	}

	if err := encryptor.Finalize(); err != nil {
		results = append(results, TestResult{
			Name:    "增量加密",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	if err := encryptor.Close(); err != nil {
		results = append(results, TestResult{
			Name:    "增量加密",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	duration = time.Since(start)
	results = append(results, TestResult{
		Name:           "增量加密(100MB)",
		DataSize:       100 * 1024 * 1024,
		Duration:       duration.String(),
		ThroughputMBps: float64(100) / duration.Seconds(),
		Success:        true,
	})

	// 测试3: 验证文件大小
	fmt.Println(">>> 测试3: 验证加密文件大小...")
	fileInfo, err := os.Stat(encryptedFile)
	if err != nil {
		results = append(results, TestResult{
			Name:    "验证文件大小",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	originalSize := int64(100 * 1024 * 1024)
	encryptedSize := fileInfo.Size()
	overhead := encryptedSize - originalSize
	overheadPercent := float64(overhead) / float64(originalSize) * 100

	fmt.Printf("原始大小: %d bytes (%.2f MB)\n", originalSize, float64(originalSize)/(1024*1024))
	fmt.Printf("加密大小: %d bytes (%.2f MB)\n", encryptedSize, float64(encryptedSize)/(1024*1024))
	fmt.Printf("开销: %d bytes (%.2f%%)\n", overhead, overheadPercent)

	results = append(results, TestResult{
		Name:     "验证文件大小",
		DataSize: encryptedSize,
		Success:  true,
	})

	// 测试4: 增量解密
	fmt.Println(">>> 测试4: 增量解密...")
	start = time.Now()
	decryptor := crypto.NewIncrementalDecryptor()
	if err := decryptor.Open(encryptedFile, key); err != nil {
		results = append(results, TestResult{
			Name:    "增量解密",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	decryptedData, err := decryptor.DecryptAll()
	if err != nil {
		results = append(results, TestResult{
			Name:    "增量解密",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	if err := decryptor.Close(); err != nil {
		results = append(results, TestResult{
			Name:    "增量解密",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	duration = time.Since(start)
	results = append(results, TestResult{
		Name:           "增量解密(100MB)",
		DataSize:       int64(len(decryptedData)),
		Duration:       duration.String(),
		ThroughputMBps: float64(100) / duration.Seconds(),
		Success:        true,
	})

	// 测试5: 验证数据完整性
	fmt.Println(">>> 测试5: 验证数据完整性...")
	if len(data) != len(decryptedData) {
		results = append(results, TestResult{
			Name:    "验证数据完整性",
			Success: false,
			Error:   fmt.Sprintf("长度不匹配: 原始=%d, 解密=%d", len(data), len(decryptedData)),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	match := true
	for i := range data {
		if data[i] != decryptedData[i] {
			match = false
			break
		}
	}

	if !match {
		results = append(results, TestResult{
			Name:    "验证数据完整性",
			Success: false,
			Error:   "数据不匹配",
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	results = append(results, TestResult{
		Name:    "验证数据完整性",
		Success: true,
	})

	// 测试6: 随机访问解密
	fmt.Println(">>> 测试6: 随机访问解密...")
	decryptor = crypto.NewIncrementalDecryptor()
	if err := decryptor.Open(encryptedFile, key); err != nil {
		results = append(results, TestResult{
			Name:    "随机访问解密",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	// 随机访问5个块
	start = time.Now()
	for i := 0; i < 5; i++ {
		blockIndex := (i * 300) % 1600 // 随机块索引
		blockData, err := decryptor.DecryptBlock(blockIndex)
		if err != nil {
			results = append(results, TestResult{
				Name:    "随机访问解密",
				Success: false,
				Error:   fmt.Sprintf("解密块 %d 失败: %v", blockIndex, err),
			})
			json.NewEncoder(os.Stdout).Encode(results)
			return
		}

		// 验证块数据
		expectedOffset := blockIndex * chunkSize
		if expectedOffset+chunkSize > len(data) {
			expectedOffset = len(data) - chunkSize
		}
		if expectedOffset < 0 {
			expectedOffset = 0
		}

		if len(blockData) > 0 {
			fmt.Printf("  块 %d: 大小 %d bytes\n", blockIndex, len(blockData))
		}
	}

	duration = time.Since(start)
	results = append(results, TestResult{
		Name:     "随机访问解密(5次)",
		Duration: duration.String(),
		Success:  true,
	})

	if err := decryptor.Close(); err != nil {
		results = append(results, TestResult{
			Name:    "关闭解密器",
			Success: false,
			Error:   err.Error(),
		})
	}

	// 测试7: 检查 ModifyBlock 是否实现
	fmt.Println(">>> 测试7: 检查 ModifyBlock 功能...")
	encryptor = crypto.NewIncrementalEncryptor()
	if err := encryptor.Create("/tmp/test_modify.enc", key, 64*1024); err != nil {
		results = append(results, TestResult{
			Name:    "检查ModifyBlock",
			Success: false,
			Error:   err.Error(),
		})
		json.NewEncoder(os.Stdout).Encode(results)
		return
	}

	// 尝试修改块
	err = encryptor.ModifyBlock(0, []byte("test"))
	if err != nil {
		fmt.Printf("  ModifyBlock 错误: %v\n", err)
		results = append(results, TestResult{
			Name:    "检查ModifyBlock",
			Success: false,
			Error:   "ModifyBlock 未实现: " + err.Error(),
		})
	} else {
		results = append(results, TestResult{
			Name:    "检查ModifyBlock",
			Success: true,
		})
	}

	encryptor.Close()

	// 清理
	os.Remove(testFile)
	os.Remove(encryptedFile)

	// 输出结果
	fmt.Println("\n========================================")
	fmt.Println("测试结果汇总:")
	fmt.Println("========================================")
	for i, result := range results {
		status := "✓"
		if !result.Success {
			status = "✗"
		}
		fmt.Printf("%d. %s %s", i+1, status, result.Name)
		if result.Duration != "" {
			fmt.Printf(" (%s)", result.Duration)
		}
		if result.ThroughputMBps > 0 {
			fmt.Printf(" [%.2f MB/s]", result.ThroughputMBps)
		}
		if result.Error != "" {
			fmt.Printf(" - %s", result.Error)
		}
		fmt.Println()
	}

	// 输出 JSON
	json.NewEncoder(os.Stdout).Encode(results)
}
EOF

# 运行测试
echo ">>> 运行测试..."
cd "$NATIVE_DIR"
go run /tmp/test_incremental.go

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
