package cmd

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_webdav"

	"github.com/spf13/cobra"
)

var (
	webDavPassword             string
	webDavPasswordEnv          string
	webDavPasswordStdin        bool
	webDavPath                 string
	webDavAuth                 string
	webDavCredentialVisibility string
	webDavSessionLifetime      string
	webDavPort                 int
	webDavMount                bool
	webDavJSON                 bool
)

var webDavServeCmd = &cobra.Command{
	Use:   "serve",
	Short: "Expose a secure path through a read-only WebDAV session",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		if webDavPath == "" {
			return fmt.Errorf("path is required")
		}
		if !filepath.IsAbs(webDavPath) {
			return fmt.Errorf("path must be absolute")
		}
		options, err := parseWebDavOpenOptions(
			webDavAuth,
			webDavCredentialVisibility,
			webDavSessionLifetime,
			webDavPort,
		)
		if err != nil {
			return err
		}
		opened, cleanup, err := openRootForPath(webDavPath, passwordOptions{
			Password:      webDavPassword,
			PasswordEnv:   webDavPasswordEnv,
			PasswordStdin: webDavPasswordStdin,
		})
		if err != nil {
			return err
		}
		defer cleanup()

		manager := sec_webdav.NewManagerWithPersistentStore(
			cliWebDavPersistentStore{root: opened.Root},
		)
		defer manager.Close()
		rootKey := cliWebDavRootKey(string(opened.RootPath))
		if restoreErrors := manager.RestorePersistent(rootKey, cliWebDavProvider{root: opened.Root}); len(restoreErrors) > 0 {
			return fmt.Errorf("failed to restore persistent webdav sessions: %v", restoreErrors)
		}
		displayName := filepath.Base(string(opened.Relative))
		if displayName == "." || displayName == string(filepath.Separator) || displayName == "" {
			displayName = filepath.Base(string(opened.RootPath))
		}
		session, err := manager.OpenWithOptions(
			"cli:"+string(opened.RootPath),
			displayName,
			string(opened.Relative),
			cliWebDavProvider{root: opened.Root},
			options,
		)
		if err != nil {
			return fmt.Errorf("failed to start webdav: %w", err)
		}
		defer manager.RevokeRoot(rootKey)
		var mounted *sec_webdav.MountedSession
		if webDavMount {
			mountContext, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			mounted, err = manager.Mount(mountContext, session.ID)
			cancel()
			if err != nil {
				return err
			}
		}

		if webDavJSON {
			writeJSONLine(map[string]interface{}{
				"event":      "webdav_started",
				"url":        session.URL,
				"auth":       webDavAuthOutput(session),
				"read_only":  session.ReadOnly,
				"mounted":    mounted != nil,
				"mount_path": mountPath(mounted),
			})
		} else {
			printWebDavSession(session)
			if mounted != nil {
				fmt.Printf("Mount path: %s\n", mounted.Path())
			}
		}
		if mounted != nil && webDavJSON {
			writeJSONLine(map[string]interface{}{
				"event":      "webdav_mount_changed",
				"mounted":    true,
				"mount_path": mounted.Path(),
			})
		}

		ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer stop()
		<-ctx.Done()
		unmountErr := manager.Unmount(context.Background(), session.ID)
		if webDavJSON {
			writeJSONLine(map[string]interface{}{
				"event":         "webdav_stopped",
				"reason":        "signal",
				"unmount_error": errorText(unmountErr),
			})
		}
		return nil
	},
}

func errorText(err error) interface{} {
	if err == nil {
		return nil
	}
	return err.Error()
}

func mountPath(mounted *sec_webdav.MountedSession) string {
	if mounted == nil {
		return ""
	}
	return mounted.Path()
}

var webDavCmd = &cobra.Command{
	Use:   "webdav",
	Short: "Manage WebDAV sessions",
}

func parseWebDavOpenOptions(auth, visibility, lifetime string, port int) (sec_webdav.OpenOptions, error) {
	mode := strings.ToLower(strings.TrimSpace(auth))
	if mode == "" {
		mode = string(sec_webdav.AuthModeBearer)
	}
	if visibility == "" {
		visibility = string(sec_webdav.CredentialVisibilityOnce)
	}
	if lifetime == "" {
		lifetime = string(sec_webdav.SessionLifetimeEphemeral)
	}
	encoded, err := json.Marshal(map[string]interface{}{
		"auth_mode":             mode,
		"credential_visibility": visibility,
		"session_lifetime":      lifetime,
		"port":                  port,
	})
	if err != nil {
		return sec_webdav.OpenOptions{}, err
	}
	return sec_webdav.ParseOpenOptions(string(encoded))
}

func webDavAuthOutput(session sec_webdav.Session) map[string]interface{} {
	result := map[string]interface{}{"mode": session.AuthMode}
	result["credential_visibility"] = session.CredentialVisibility
	result["session_lifetime"] = session.SessionLifetime
	result["port"] = session.Port
	if session.AuthMode == sec_webdav.AuthModeDigest {
		result["username"] = session.Username
		result["password"] = session.Password
		result["realm"] = session.Realm
	} else {
		result["token"] = session.Token
	}
	return result
}

func printWebDavSession(session sec_webdav.Session) {
	fmt.Printf("WebDAV URL: %s\n", session.URL)
	fmt.Printf("Authentication: %s\n", session.AuthMode)
	fmt.Println("Permission: read-only")
	if session.AuthMode == sec_webdav.AuthModeDigest {
		fmt.Printf("Username: %s\n", session.Username)
		fmt.Printf("Password: %s\n", session.Password)
		fmt.Printf("Realm: %s\n", session.Realm)
	} else {
		fmt.Printf("Token: %s\n", session.Token)
	}
	fmt.Println("Press Ctrl-C to stop the session.")
}

type cliWebDavProvider struct {
	root sec_fs.ISecRoot
}

func (p cliWebDavProvider) Stat(path string) (fs.FileInfo, error) {
	return p.root.Stat(sec_fs.RelativeViewPath(path))
}

func (p cliWebDavProvider) ReadDir(path string) ([]fs.DirEntry, error) {
	return p.root.ReadDir(path)
}

func (p cliWebDavProvider) Open(path string) (io.ReadCloser, fs.FileInfo, error) {
	file, err := p.root.Open(path)
	if err != nil {
		return nil, nil, err
	}
	info, err := file.Stat()
	if err != nil {
		_ = file.Close()
		return nil, nil, err
	}
	return file, info, nil
}

func init() {
	addPasswordFlags(webDavServeCmd.Flags(), &webDavPassword, &webDavPasswordEnv, &webDavPasswordStdin)
	webDavServeCmd.Flags().StringVar(&webDavPath, "path", "", "Absolute encrypted path to expose")
	webDavServeCmd.Flags().StringVar(&webDavAuth, "auth", "bearer", "Authentication mode: bearer or digest")
	webDavServeCmd.Flags().StringVar(&webDavCredentialVisibility, "credential-visibility", "once", "Credential display: once or persistent")
	webDavServeCmd.Flags().StringVar(&webDavSessionLifetime, "session-lifetime", "ephemeral", "Session lifetime: ephemeral or persistent")
	webDavServeCmd.Flags().IntVar(&webDavPort, "port", 0, "Loopback port; persistent sessions retain the selected port")
	webDavServeCmd.Flags().BoolVar(&webDavMount, "mount", false, "Mount the WebDAV session in the operating system")
	webDavServeCmd.Flags().BoolVar(&webDavJSON, "json", false, "Output JSON Lines lifecycle events")
	webDavCmd.AddCommand(webDavServeCmd)
	rootCmd.AddCommand(webDavCmd)
}
