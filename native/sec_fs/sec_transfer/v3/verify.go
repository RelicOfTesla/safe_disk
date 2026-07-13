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
	"safe_disk/native/sec_fs/sec_transfer"
)

const verificationPathSampleLimit = 16

type treeVerificationError struct {
	report sec_transfer.VerificationReport
}

func (e *treeVerificationError) Error() string {
	first := firstVerificationDifference(e.report)
	return fmt.Sprintf("%s (missing_dirs=%d unexpected_dirs=%d missing_files=%d unexpected_files=%d digest_mismatches=%d truncated=%t)",
		first,
		e.report.MissingDirectoryCount,
		e.report.UnexpectedDirectoryCount,
		e.report.MissingFileCount,
		e.report.UnexpectedFileCount,
		e.report.DigestMismatchCount,
		e.report.Truncated,
	)
}

func (e *treeVerificationError) Report() sec_transfer.VerificationReport {
	return e.report
}

func verifyPlainAndRoot(ctx context.Context, plainPath string, root sec_fs.ISecRoot) error {
	report := sec_transfer.VerificationReport{}
	err := walkPlainEntries(ctx, plainPath, false, func(path, relativePath string, isDir bool) error {
		viewPath := sec_fs.RelativeViewPath(manifestPath(relativePath))
		if isDir {
			report.ExpectedDirectories++
			info, err := root.Stat(viewPath)
			if os.IsNotExist(err) || (err == nil && !info.IsDir()) {
				addVerificationDifference(&report.MissingDirectories, &report.MissingDirectoryCount, string(viewPath))
				return nil
			}
			return err
		}

		report.ExpectedFiles++
		info, err := root.Stat(viewPath)
		if os.IsNotExist(err) || (err == nil && info.IsDir()) {
			addVerificationDifference(&report.MissingFiles, &report.MissingFileCount, string(viewPath))
			return nil
		}
		if err != nil {
			return err
		}
		plainDigest, err := hashPlainFile(ctx, path)
		if err != nil {
			return err
		}
		rootDigest, err := hashRootFile(ctx, root, viewPath)
		if err != nil {
			return err
		}
		if plainDigest != rootDigest {
			addVerificationDifference(&report.DigestMismatches, &report.DigestMismatchCount, string(viewPath))
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("verify plain source entries: %w", err)
	}
	err = walkRootEntries(ctx, root, "", false, func(viewPath sec_fs.RelativeViewPath, isDir bool) error {
		path := filepath.Join(plainPath, filepath.FromSlash(string(viewPath)))
		if isDir {
			report.ActualDirectories++
			info, err := os.Stat(path)
			if os.IsNotExist(err) || (err == nil && !info.IsDir()) {
				addVerificationDifference(&report.UnexpectedDirectories, &report.UnexpectedDirectoryCount, manifestPath(string(viewPath)))
				return nil
			}
			return err
		}

		report.ActualFiles++
		info, err := os.Stat(path)
		if os.IsNotExist(err) || (err == nil && info.IsDir()) {
			addVerificationDifference(&report.UnexpectedFiles, &report.UnexpectedFileCount, manifestPath(string(viewPath)))
			return nil
		}
		return err
	})
	if err != nil {
		return fmt.Errorf("verify encrypted work entries: %w", err)
	}
	return verificationReportError(report)
}

func verifyRootAndPlain(ctx context.Context, root sec_fs.ISecRoot, plainPath string) error {
	report := sec_transfer.VerificationReport{}
	err := walkRootEntries(ctx, root, "", false, func(viewPath sec_fs.RelativeViewPath, isDir bool) error {
		relativePath := manifestPath(string(viewPath))
		path := filepath.Join(plainPath, filepath.FromSlash(relativePath))
		if isDir {
			report.ExpectedDirectories++
			info, err := os.Stat(path)
			if os.IsNotExist(err) || (err == nil && !info.IsDir()) {
				addVerificationDifference(&report.MissingDirectories, &report.MissingDirectoryCount, relativePath)
				return nil
			}
			return err
		}

		report.ExpectedFiles++
		info, err := os.Stat(path)
		if os.IsNotExist(err) || (err == nil && info.IsDir()) {
			addVerificationDifference(&report.MissingFiles, &report.MissingFileCount, relativePath)
			return nil
		}
		if err != nil {
			return err
		}
		rootDigest, err := hashRootFile(ctx, root, viewPath)
		if err != nil {
			return err
		}
		plainDigest, err := hashPlainFile(ctx, path)
		if err != nil {
			return err
		}
		if rootDigest != plainDigest {
			addVerificationDifference(&report.DigestMismatches, &report.DigestMismatchCount, relativePath)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("verify encrypted source entries: %w", err)
	}
	err = walkPlainEntries(ctx, plainPath, false, func(_ string, relativePath string, isDir bool) error {
		viewPath := sec_fs.RelativeViewPath(manifestPath(relativePath))
		if isDir {
			report.ActualDirectories++
			info, err := root.Stat(viewPath)
			if os.IsNotExist(err) || (err == nil && !info.IsDir()) {
				addVerificationDifference(&report.UnexpectedDirectories, &report.UnexpectedDirectoryCount, string(viewPath))
				return nil
			}
			return err
		}

		report.ActualFiles++
		info, err := root.Stat(viewPath)
		if os.IsNotExist(err) || (err == nil && info.IsDir()) {
			addVerificationDifference(&report.UnexpectedFiles, &report.UnexpectedFileCount, string(viewPath))
			return nil
		}
		return err
	})
	if err != nil {
		return fmt.Errorf("verify plain work entries: %w", err)
	}
	return verificationReportError(report)
}

func hashPlainFile(ctx context.Context, path string) ([sha256.Size]byte, error) {
	file, err := os.Open(path)
	if err != nil {
		return [sha256.Size]byte{}, err
	}
	digest, hashErr := hashReader(ctx, file)
	closeErr := file.Close()
	if hashErr != nil {
		return [sha256.Size]byte{}, hashErr
	}
	return digest, closeErr
}

func hashRootFile(ctx context.Context, root sec_fs.ISecRoot, path sec_fs.RelativeViewPath) ([sha256.Size]byte, error) {
	file, err := root.OpenFile(path, os.O_RDONLY)
	if err != nil {
		return [sha256.Size]byte{}, err
	}
	digest, hashErr := hashReader(ctx, file)
	closeErr := file.Close()
	if hashErr != nil {
		return [sha256.Size]byte{}, hashErr
	}
	return digest, closeErr
}

func addVerificationDifference(samples *[]string, count *int, path string) {
	*count++
	path = manifestPath(path)
	if len(*samples) < verificationPathSampleLimit {
		*samples = append(*samples, path)
		sort.Strings(*samples)
		return
	}
	if path >= (*samples)[len(*samples)-1] {
		return
	}
	(*samples)[len(*samples)-1] = path
	sort.Strings(*samples)
}

func verificationReportError(report sec_transfer.VerificationReport) error {
	report.Truncated = report.MissingDirectoryCount > len(report.MissingDirectories) ||
		report.UnexpectedDirectoryCount > len(report.UnexpectedDirectories) ||
		report.MissingFileCount > len(report.MissingFiles) ||
		report.UnexpectedFileCount > len(report.UnexpectedFiles) ||
		report.DigestMismatchCount > len(report.DigestMismatches)
	if report.MissingDirectoryCount == 0 && report.UnexpectedDirectoryCount == 0 &&
		report.MissingFileCount == 0 && report.UnexpectedFileCount == 0 && report.DigestMismatchCount == 0 {
		return nil
	}
	return &treeVerificationError{report: report}
}

func firstVerificationDifference(report sec_transfer.VerificationReport) string {
	for _, difference := range []struct {
		paths  []string
		prefix string
	}{
		{report.MissingDirectories, "missing directory in work tree"},
		{report.UnexpectedDirectories, "unexpected directory in work tree"},
		{report.MissingFiles, "missing file in work tree"},
		{report.UnexpectedFiles, "unexpected file in work tree"},
		{report.DigestMismatches, "file digest mismatch"},
	} {
		if len(difference.paths) > 0 {
			return difference.prefix + ": " + difference.paths[0]
		}
	}
	return "tree verification failed"
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

func manifestPath(path string) string {
	return filepath.ToSlash(filepath.Clean(path))
}
