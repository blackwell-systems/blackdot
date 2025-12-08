// Package main provides the entry point for the dotfiles CLI.
//
// This is the Go implementation of the dotfiles management system,
// designed to run alongside the existing Zsh implementation during
// the migration period (strangler fig pattern).
//
// Build: go build -o bin/dotfiles-go ./cmd/dotfiles
// Usage: dotfiles-go <command> [flags]
package main

import (
	"os"

	"github.com/blackwell-systems/dotfiles/internal/cli"
)

// Version information set by build flags
var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	// Initialize CLI with version info
	cli.SetVersionInfo(version, commit, date)

	// Execute root command
	if err := cli.Execute(); err != nil {
		// Error already printed by CLI, just exit
		os.Exit(1)
	}
}
