// Safe Disk CLI - Build Script (Go)
// 核心 CLI 交叉编译逻辑。sh/bat wrapper 负责 bootstrap 编译此工具后调用。

package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

var _isWin = runtime.GOOS == "windows"

func c(color, text string) string {
	if os.Getenv("TERM") == "" && os.Getenv("COLORTERM") == "" {
		return text
	}
	if _isWin {
		return text
	}
	return color + text + "\033[0m"
}

func run(cmd []string, cwd string, env map[string]string) error {
	c := exec.Command(cmd[0], cmd[1:]...)
	if cwd != "" {
		c.Dir = cwd
	}
	c.Env = os.Environ()
	for k, v := range env {
		c.Env = append(c.Env, k+"="+v)
	}
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	c.Stdin = os.Stdin
	return c.Run()
}

func fileSize(path string) string {
	info, err := os.Stat(path)
	if err != nil {
		return "?"
	}
	size := float64(info.Size())
	units := []string{"B", "KB", "MB", "GB"}
	for _, unit := range units {
		if size < 1024 {
			return fmt.Sprintf("%.1f%s", size, unit)
		}
		size /= 1024
	}
	return fmt.Sprintf("%.1fTB", size)
}

func build(version string) {
	nativeDir := filepath.Dir(os.Args[0])
	// 处理 wrapper 调用的情况：二进制在 native/ 目录
	if filepath.Base(nativeDir) != "native" {
		// 尝试从 cwd 推断
		cwd, _ := os.Getwd()
		if filepath.Base(cwd) == "native" {
			nativeDir = cwd
		} else {
			nativeDir = filepath.Join(cwd, "native")
		}
	}

	outputDir := filepath.Join(nativeDir, "bin")
	os.MkdirAll(outputDir, 0755)

	ldflags := fmt.Sprintf("-s -w -X main.Version=%s", version)
	devLdflags := fmt.Sprintf("-X main.Version=%s", version)

	type target struct{ goos, goarch, name string }
	targets := []target{
		{"linux", "amd64", "safedisk-cli-linux-amd64"},
		{"linux", "arm64", "safedisk-cli-linux-arm64"},
		{"windows", "amd64", "safedisk-cli-windows-amd64.exe"},
		{"darwin", "amd64", "safedisk-cli-darwin-amd64"},
		{"darwin", "arm64", "safedisk-cli-darwin-arm64"},
	}

	fmt.Println(c("\033[0;34m", fmt.Sprintf("Building Safe Disk CLI v%s...", version)))
	fmt.Println()

	for _, t := range targets {
		fmt.Printf("  Building for %s (%s)...\n", t.goos, t.goarch)
		out := filepath.Join(outputDir, t.name)
		if err := run(
			[]string{"go", "build", "-ldflags=" + ldflags, "-o", out, "./cli/"},
			nativeDir,
			map[string]string{"GOOS": t.goos, "GOARCH": t.goarch},
		); err != nil {
			fmt.Println(c("\033[0;31m", fmt.Sprintf("    Failed: %v", err)))
		}
	}

	devName := "safedisk-cli"
	if _isWin {
		devName = "safedisk-cli.exe"
	}
	fmt.Println("  Building for current platform (development)...")
	if err := run(
		[]string{"go", "build", "-ldflags=" + devLdflags, "-o", filepath.Join(outputDir, devName), "./cli/"},
		nativeDir, nil,
	); err != nil {
		fmt.Println(c("\033[0;31m", fmt.Sprintf("    Failed: %v", err)))
	}

	fmt.Println()
	fmt.Println(c("\033[0;32m", fmt.Sprintf("Build complete! Binaries in %s/", outputDir)))
	fmt.Println()

	entries, err := os.ReadDir(outputDir)
	if err != nil {
		return
	}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		size := float64(info.Size())
		units := []string{"B", "KB", "MB", "GB"}
		unit := "B"
		for _, u := range units {
			if size < 1024 {
				unit = u
				break
			}
			size /= 1024
		}
		fmt.Printf("  %-40s %10.1f%s\n", entry.Name(), size, unit)
	}
}

func main() {
	version := flag.String("version", "1.0.0", "Version string")
	flag.Parse()
	build(*version)
}
