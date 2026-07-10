package sec_transfer_v3

import (
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"

	"safe_disk/native/sec_fs"
)

type treeManifest struct {
	dirs  map[string]struct{}
	files map[string][sha256.Size]byte
}

func verifyPlainAndRoot(ctx context.Context, plainPath string, root sec_fs.ISecRoot) error {
	plainManifest, err := buildPlainManifest(ctx, plainPath)
	if err != nil {
		return fmt.Errorf("read plain source manifest: %w", err)
	}
	rootManifest, err := buildRootManifest(ctx, root)
	if err != nil {
		return fmt.Errorf("read encrypted work manifest: %w", err)
	}
	return compareTreeManifests(plainManifest, rootManifest)
}

func verifyRootAndPlain(ctx context.Context, root sec_fs.ISecRoot, plainPath string) error {
	rootManifest, err := buildRootManifest(ctx, root)
	if err != nil {
		return fmt.Errorf("read encrypted source manifest: %w", err)
	}
	plainManifest, err := buildPlainManifest(ctx, plainPath)
	if err != nil {
		return fmt.Errorf("read plain work manifest: %w", err)
	}
	return compareTreeManifests(rootManifest, plainManifest)
}

func buildPlainManifest(ctx context.Context, rootPath string) (treeManifest, error) {
	files, dirs, err := collectPlainEntries(ctx, rootPath, false)
	if err != nil {
		return treeManifest{}, err
	}
	manifest := newTreeManifest()
	for _, dir := range dirs {
		rel, err := filepath.Rel(rootPath, dir)
		if err != nil {
			return treeManifest{}, err
		}
		manifest.dirs[manifestPath(rel)] = struct{}{}
	}
	for _, path := range files {
		if err := ctx.Err(); err != nil {
			return treeManifest{}, err
		}
		rel, err := filepath.Rel(rootPath, path)
		if err != nil {
			return treeManifest{}, err
		}
		file, err := os.Open(path)
		if err != nil {
			return treeManifest{}, err
		}
		digest, hashErr := hashReader(ctx, file)
		closeErr := file.Close()
		if hashErr != nil {
			return treeManifest{}, hashErr
		}
		if closeErr != nil {
			return treeManifest{}, closeErr
		}
		manifest.files[manifestPath(rel)] = digest
	}
	return manifest, nil
}

func buildRootManifest(ctx context.Context, root sec_fs.ISecRoot) (treeManifest, error) {
	files, dirs, err := collectRootEntries(ctx, root, "", false)
	if err != nil {
		return treeManifest{}, err
	}
	manifest := newTreeManifest()
	for _, dir := range dirs {
		manifest.dirs[manifestPath(string(dir))] = struct{}{}
	}
	for _, path := range files {
		if err := ctx.Err(); err != nil {
			return treeManifest{}, err
		}
		file, err := root.OpenFile(path, os.O_RDONLY)
		if err != nil {
			return treeManifest{}, err
		}
		digest, hashErr := hashReader(ctx, file)
		closeErr := file.Close()
		if hashErr != nil {
			return treeManifest{}, hashErr
		}
		if closeErr != nil {
			return treeManifest{}, closeErr
		}
		manifest.files[manifestPath(string(path))] = digest
	}
	return manifest, nil
}

func compareTreeManifests(expected treeManifest, actual treeManifest) error {
	if err := comparePathSets("directory", expected.dirs, actual.dirs); err != nil {
		return err
	}
	expectedFiles := make(map[string]struct{}, len(expected.files))
	actualFiles := make(map[string]struct{}, len(actual.files))
	for path := range expected.files {
		expectedFiles[path] = struct{}{}
	}
	for path := range actual.files {
		actualFiles[path] = struct{}{}
	}
	if err := comparePathSets("file", expectedFiles, actualFiles); err != nil {
		return err
	}
	paths := make([]string, 0, len(expected.files))
	for path := range expected.files {
		paths = append(paths, path)
	}
	sort.Strings(paths)
	for _, path := range paths {
		if expected.files[path] != actual.files[path] {
			return fmt.Errorf("file digest mismatch: %s", path)
		}
	}
	return nil
}

func comparePathSets(kind string, expected map[string]struct{}, actual map[string]struct{}) error {
	missing := setDifference(expected, actual)
	if len(missing) > 0 {
		return fmt.Errorf("missing %s in work tree: %s", kind, missing[0])
	}
	extra := setDifference(actual, expected)
	if len(extra) > 0 {
		return fmt.Errorf("unexpected %s in work tree: %s", kind, extra[0])
	}
	return nil
}

func setDifference(left map[string]struct{}, right map[string]struct{}) []string {
	result := make([]string, 0)
	for path := range left {
		if _, ok := right[path]; !ok {
			result = append(result, path)
		}
	}
	sort.Strings(result)
	return result
}

func hashReader(ctx context.Context, reader io.Reader) ([sha256.Size]byte, error) {
	hash := sha256.New()
	if _, err := io.Copy(hash, contextReader{ctx: ctx, reader: reader}); err != nil {
		return [sha256.Size]byte{}, err
	}
	var digest [sha256.Size]byte
	copy(digest[:], hash.Sum(nil))
	return digest, nil
}

func newTreeManifest() treeManifest {
	return treeManifest{
		dirs:  make(map[string]struct{}),
		files: make(map[string][sha256.Size]byte),
	}
}

func manifestPath(path string) string {
	return filepath.ToSlash(filepath.Clean(path))
}
