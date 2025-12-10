// Package main provides the entry point for the blackdot CLI.
//
// This is the Go implementation of the blackdot configuration management system.
//
// Build: go build -o bin/blackdot ./cmd/blackdot
// Usage: blackdot <command> [flags]
package main

import (
	"os"

	"github.com/blackwell-systems/blackdot/internal/cli"
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
