package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"golang.org/x/term"
)

type passwordOptions struct {
	Password      string
	PasswordEnv   string
	PasswordStdin bool
}

func readPassword(opts passwordOptions) (string, error) {
	if opts.Password != "" {
		return opts.Password, nil
	}
	if opts.PasswordEnv != "" {
		value := os.Getenv(opts.PasswordEnv)
		if value == "" {
			return "", fmt.Errorf("environment variable %s is empty or not set", opts.PasswordEnv)
		}
		return value, nil
	}
	if opts.PasswordStdin {
		reader := bufio.NewReader(os.Stdin)
		line, err := reader.ReadString('\n')
		if err != nil && len(line) == 0 {
			return "", fmt.Errorf("failed to read password from stdin: %w", err)
		}
		return strings.TrimRight(line, "\r\n"), nil
	}
	if term.IsTerminal(int(os.Stdin.Fd())) {
		fmt.Fprint(os.Stderr, "Password: ")
		data, err := term.ReadPassword(int(os.Stdin.Fd()))
		fmt.Fprintln(os.Stderr)
		if err != nil {
			return "", fmt.Errorf("failed to read password: %w", err)
		}
		if len(data) == 0 {
			return "", fmt.Errorf("password is required")
		}
		return string(data), nil
	}
	return "", fmt.Errorf("password is required; use --password, --password-env, or --password-stdin")
}
