// Safe Disk - Build Script (Go)
// 核心构建逻辑。sh/bat wrapper 负责 bootstrap 编译此工具后调用。
// 跨平台支持：Linux / Windows / macOS
//
// Usage:
//   go run scripts/build.go run [--clean|--pub|--rebuild] [flutter_args...]
//   go run scripts/build.go build-go
//   go run scripts/build.go build-flutter
//   go run scripts/build.go build-cli [--version x.y.z]
//   go run scripts/build.go test-go
//   go run scripts/build.go test-flutter
//   go run scripts/build.go clean

package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// ── 平台检测 ──────────────────────────────────────────

func isWindows() bool { return runtime.GOOS == "windows" }
func isMac() bool     { return runtime.GOOS == "darwin" }

// ── 颜色输出 ──────────────────────────────────────────

const (
	red    = "\033[0;31m"
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	blue   = "\033[0;34m"
	cyan   = "\033[0;36m"
	reset  = "\033[0m"
)

func colorEnabled() bool {
	// Windows CMD 默认不支持 ANSI，除非启用 VT100；安全起见禁用
	if isWindows() {
		return false
	}
	return os.Getenv("TERM") != "" || os.Getenv("COLORTERM") != ""
}

func c(color, text string) string {
	if colorEnabled() {
		return color + text + reset
	}
	return text
}

// ── 平台相关常量 ──────────────────────────────────────

func flutterCmd() string {
	if isWindows() {
		if p, err := exec.LookPath("flutter.bat"); err == nil {
			return p
		}
	}
	return "flutter"
}

func goLibExt() string {
	switch runtime.GOOS {
	case "windows":
		return ".dll"
	case "darwin":
		return ".dylib"
	default:
		return ".so"
	}
}

func flutterTargetDir() string {
	switch runtime.GOOS {
	case "windows":
		return "windows"
	case "darwin":
		return "macos"
	default:
		return "linux"
	}
}

func libEnvVar() string {
	switch runtime.GOOS {
	case "windows":
		return "PATH"
	case "darwin":
		return "DYLD_LIBRARY_PATH"
	default:
		return "LD_LIBRARY_PATH"
	}
}

func libPathSep() string {
	if isWindows() {
		return ";"
	}
	return ":"
}

// ── 路径解析 ──────────────────────────────────────────

func projectRoot() string {
	// 1. 尝试从可执行文件路径推断
	if exe, err := os.Executable(); err == nil {
		exe = filepath.Clean(exe)
		dir := filepath.Dir(exe)
		if filepath.Base(dir) == "scripts" {
			return filepath.Dir(dir)
		}
	}

	// 2. 尝试从 cwd 推断
	cwd, _ := os.Getwd()
	cwd = filepath.Clean(cwd)
	if filepath.Base(cwd) == "scripts" {
		return filepath.Dir(cwd)
	}

	// 3. 默认返回 cwd
	return cwd
}

var (
	root       = projectRoot()
	nativeDir  = filepath.Join(root, "native")
	flutterDir = root
	ffiDir     = filepath.Join(nativeDir, "ffi_sec_fs")
	outName    = nativeLibraryBaseName()
	libExt     = goLibExt()
	platform   = flutterTargetDir()
)

func nativeLibraryBaseName() string {
	return nativeLibraryBaseNameFor(runtime.GOOS)
}

func nativeLibraryBaseNameFor(goos string) string {
	if goos == "windows" {
		return "ffi_sec_fs"
	}
	return "libffi_sec_fs"
}

func targetDirs() []string {
	switch runtime.GOOS {
	case "windows":
		return []string{
			filepath.Join(root, "windows"),
			filepath.Join(root, "build", "windows", "x64", "runner", "Debug"),
			filepath.Join(root, "build", "windows", "x64", "runner", "Profile"),
			filepath.Join(root, "build", "windows", "x64", "runner", "Release"),
		}
	case "darwin":
		return []string{
			filepath.Join(root, "macos"),
			filepath.Join(root, "build", "macos", "Build", "Products", "Debug"),
			filepath.Join(root, "build", "macos", "Build", "Products", "Release"),
		}
	default:
		return []string{
			filepath.Join(root, "linux"),
			filepath.Join(root, "build", "linux", "x64", "debug", "bundle"),
			filepath.Join(root, "build", "linux", "x64", "release", "bundle"),
			filepath.Join(root, "build", "native_assets", "linux"),
		}
	}
}

// ── 辅助函数 ──────────────────────────────────────────

func run(cmd []string, cwd string, env map[string]string, check bool) error {
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

	err := c.Run()
	if err != nil && check {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return fmt.Errorf("exit code %d", exitErr.ExitCode())
		}
		return err
	}
	return nil
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

func copyFile(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return err
	}
	// 复制权限
	info, err := os.Stat(src)
	if err == nil {
		os.Chmod(dst, info.Mode().Perm())
	}
	return nil
}

// ── 构建步骤 ──────────────────────────────────────────

func flutterClean() {
	fmt.Println(c(green, "[1/6] Running flutter clean..."))
	run([]string{flutterCmd(), "clean"}, flutterDir, nil, false)
}

func buildGoLibrary() string {
	fmt.Println(c(green, fmt.Sprintf("[2/6] Building Go native library (%s)...", platform)))
	libPath := filepath.Join(ffiDir, outName+libExt)

	fmt.Println(c(yellow, fmt.Sprintf("  Running: go build -buildmode=c-shared -o %s%s", outName, libExt)))
	if err := run([]string{"go", "build", "-buildmode=c-shared", "-o", outName + libExt}, ffiDir, nil, true); err != nil {
		fmt.Println(c(red, fmt.Sprintf("✗ Failed to build %s%s: %v", outName, libExt, err)))
		os.Exit(1)
	}

	if _, err := os.Stat(libPath); err != nil {
		fmt.Println(c(red, fmt.Sprintf("✗ Output file not found: %s", libPath)))
		os.Exit(1)
	}

	fmt.Println(c(green, fmt.Sprintf("✓ Built %s%s (%s)", outName, libExt, fileSize(libPath))))

	hPath := filepath.Join(ffiDir, outName+".h")
	if _, err := os.Stat(hPath); err == nil {
		fmt.Println(c(green, fmt.Sprintf("✓ Generated header: %s.h", outName)))
	}

	return libPath
}

func copyLibrary(libPath string) {
	fmt.Println(c(green, "[3/6] Copying library to Flutter directories..."))
	for _, target := range targetDirs() {
		os.MkdirAll(target, 0755)
		dest := filepath.Join(target, filepath.Base(libPath))
		if err := copyFile(libPath, dest); err != nil {
			fmt.Println(c(red, fmt.Sprintf("✗ Failed to copy to %s: %v", dest, err)))
			continue
		}
		fmt.Println(c(green, fmt.Sprintf("✓ Copied to: %s", dest)))
	}

	hPath := filepath.Join(ffiDir, outName+".h")
	if _, err := os.Stat(hPath); err == nil {
		platDir := filepath.Join(flutterDir, platform)
		os.MkdirAll(platDir, 0755)
		dest := filepath.Join(platDir, outName+".h")
		if err := copyFile(hPath, dest); err != nil {
			fmt.Println(c(red, fmt.Sprintf("✗ Failed to copy header: %v", err)))
		} else {
			fmt.Println(c(green, fmt.Sprintf("✓ Copied header to: %s/", platDir)))
		}
	}
}

func flutterPubGet() {
	fmt.Println(c(green, "[4/6] Flutter pub get..."))
	run([]string{flutterCmd(), "pub", "get"}, flutterDir, nil, false)
	fmt.Println(c(green, "✓ Flutter dependencies ready"))
}

func setLibPath() string {
	fmt.Println(c(green, "[5/6] Setting library path..."))
	paths := []string{}
	for _, d := range targetDirs() {
		if _, err := os.Stat(d); err == nil {
			paths = append(paths, d)
		}
	}

	envVar := libEnvVar()
	if existing := os.Getenv(envVar); existing != "" {
		paths = append(paths, existing)
	}

	libPath := strings.Join(paths, libPathSep())
	fmt.Println(c(green, fmt.Sprintf("✓ %s set", envVar)))
	fmt.Println(c(cyan, fmt.Sprintf("  %s=%s", envVar, libPath)))
	return libPath
}

func runFlutter(args []string) {
	fmt.Println(c(green, "[6/6] Running Flutter app..."))
	fmt.Println(c(blue, "========================================"))
	fmt.Println()

	cmd := []string{flutterCmd(), "run"}
	if len(args) == 0 {
		cmd = append(cmd, "-d", platform)
	} else {
		cmd = append(cmd, args...)
	}

	libPath := setLibPath()
	envVar := libEnvVar()
	run(cmd, flutterDir, map[string]string{envVar: libPath}, true)
}

// ── CLI 构建 ──────────────────────────────────────────

func buildCLI(version string) {
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

	fmt.Println(c(blue, fmt.Sprintf("Building Safe Disk CLI v%s...", version)))
	fmt.Println()

	for _, t := range targets {
		fmt.Printf("  Building for %s (%s)...\n", t.goos, t.goarch)
		out := filepath.Join(outputDir, t.name)
		if err := run(
			[]string{"go", "build", "-ldflags=" + ldflags, "-o", out, "./cli/"},
			nativeDir,
			map[string]string{"GOOS": t.goos, "GOARCH": t.goarch},
			true,
		); err != nil {
			fmt.Println(c(red, fmt.Sprintf("    ✗ Failed: %v", err)))
		}
	}

	devName := "safedisk-cli"
	if isWindows() {
		devName = "safedisk-cli.exe"
	}
	fmt.Println("  Building for current platform (development)...")
	if err := run(
		[]string{"go", "build", "-ldflags=" + devLdflags, "-o", filepath.Join(outputDir, devName), "./cli/"},
		nativeDir, nil, true,
	); err != nil {
		fmt.Println(c(red, fmt.Sprintf("    ✗ Failed: %v", err)))
	}

	fmt.Println()
	fmt.Println(c(green, fmt.Sprintf("✓ Build complete! Binaries in %s/", outputDir)))
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

// ── 其他命令 ──────────────────────────────────────────

func buildGoOnly() {
	libPath := buildGoLibrary()
	copyLibrary(libPath)
	fmt.Println()
	fmt.Println(c(green, "Go library built and copied."))
}

func doClean() {
	fmt.Println(c(yellow, "Cleaning build artifacts..."))

	dirs := []string{
		filepath.Join(flutterDir, "build"),
		filepath.Join(nativeDir, "bin"),
	}
	for _, d := range dirs {
		if _, err := os.Stat(d); err == nil {
			os.RemoveAll(d)
			fmt.Printf("  Removed %s\n", d)
		}
	}

	// 清理 FFI 目录生成的库文件
	for _, ext := range []string{".so", ".dll", ".dylib", ".h"} {
		path := filepath.Join(ffiDir, outName+ext)
		if _, err := os.Stat(path); err == nil {
			os.Remove(path)
			fmt.Printf("  Removed %s\n", path)
		}
	}

	// 清理复制到平台目录的文件
	platDir := filepath.Join(flutterDir, platform)
	if _, err := os.Stat(platDir); err == nil {
		for _, ext := range []string{".so", ".dll", ".dylib", ".h"} {
			path := filepath.Join(platDir, outName+ext)
			if _, err := os.Stat(path); err == nil {
				os.Remove(path)
				fmt.Printf("  Removed %s\n", path)
			}
		}
	}

	fmt.Println(c(green, "Clean complete."))
}

func testGo() {
	fmt.Println(c(blue, "Running Go tests..."))
	if err := run([]string{"go", "test", "./..."}, nativeDir, nil, true); err != nil {
		fmt.Println(c(red, fmt.Sprintf("Tests failed: %v", err)))
		os.Exit(1)
	}
}

func testFlutter() {
	fmt.Println(c(blue, "Running Flutter tests..."))
	if err := run([]string{flutterCmd(), "test"}, flutterDir, nil, true); err != nil {
		fmt.Println(c(red, fmt.Sprintf("Tests failed: %v", err)))
		os.Exit(1)
	}
}

func buildFlutter() {
	buildGoOnly()
	fmt.Println(c(green, "Building Flutter app..."))
	if err := run([]string{flutterCmd(), "build", platform}, flutterDir, nil, true); err != nil {
		fmt.Println(c(red, fmt.Sprintf("Build failed: %v", err)))
		os.Exit(1)
	}
	fmt.Println(c(green, "Flutter build complete."))
}

// ── 使用说明 ──────────────────────────────────────────

func usage() {
	fmt.Print(`Safe Disk Build Script

Usage: build <command> [options]

Commands:
  run              Build and run Flutter app
  build-go         Build Go shared library only
  build-flutter    Build Flutter app only
  build-cli        Cross-compile CLI binaries
  test-go          Run Go tests
  test-flutter     Run Flutter tests
  clean            Clean build artifacts

Run options:
  --clean          Run flutter clean first
  --pub            Run flutter pub get
  --rebuild        Shorthand for --clean --pub

Examples:
  build run                    # Build and run
  build run --rebuild          # Full rebuild
  build build-go               # Build Go library only
  build build-cli --version 1.2.0
  build clean
`)
	os.Exit(1)
}

// ── 主入口 ────────────────────────────────────────────

func main() {
	if len(os.Args) < 2 {
		usage()
	}

	command := os.Args[1]

	switch command {
	case "run":
		fs := flag.NewFlagSet("run", flag.ExitOnError)
		doClean := fs.Bool("clean", false, "Run flutter clean first")
		doPub := fs.Bool("pub", false, "Run flutter pub get")
		doRebuild := fs.Bool("rebuild", false, "Shorthand for --clean --pub")
		fs.Parse(os.Args[2:])
		flutterArgs := fs.Args()

		clean := *doClean || *doRebuild
		pub := *doPub || *doRebuild

		fmt.Println(c(blue, "========================================"))
		fmt.Println(c(blue, "  Safe Disk - Build & Run Script"))
		fmt.Println(c(blue, "========================================"))
		fmt.Println()
		fmt.Println(c(cyan, fmt.Sprintf("Project root: %s", root)))
		fmt.Println(c(cyan, fmt.Sprintf("Native dir:   %s", nativeDir)))
		fmt.Println(c(cyan, fmt.Sprintf("Platform:     %s", platform)))
		fmt.Println()

		if clean {
			flutterClean()
		} else {
			fmt.Println(c(yellow, "[1/6] Skipping flutter clean (use --clean / --rebuild)"))
		}

		libPath := buildGoLibrary()
		fmt.Println()
		copyLibrary(libPath)
		fmt.Println()

		if pub {
			flutterPubGet()
		} else {
			fmt.Println(c(yellow, "[4/6] Skipping flutter pub get (use --pub / --rebuild)"))
		}
		fmt.Println()

		runFlutter(flutterArgs)

	case "build-go":
		buildGoOnly()

	case "build-flutter":
		buildFlutter()

	case "build-cli":
		fs := flag.NewFlagSet("build-cli", flag.ExitOnError)
		version := fs.String("version", "1.0.0", "CLI version string")
		fs.Parse(os.Args[2:])
		buildCLI(*version)

	case "test-go":
		testGo()

	case "test-flutter":
		testFlutter()

	case "clean":
		doClean()

	default:
		usage()
	}
}

// needRebuild 检查 src 是否比 dst 更新（mtime），用于 wrapper 判断是否需要重新编译
func needRebuild(src, dst string) bool {
	srcInfo, err := os.Stat(src)
	if err != nil {
		return false // source 不存在，不需要重建
	}
	dstInfo, err := os.Stat(dst)
	if err != nil {
		return true // dst 不存在，需要重建
	}
	return srcInfo.ModTime().After(dstInfo.ModTime())
}
