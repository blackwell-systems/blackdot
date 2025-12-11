// Package blackdot provides a modular development framework for managing
// shell configurations, secrets, and development environments across multiple machines.
//
// # Core Systems
//
// Feature Registry: Modular control plane for enabling/disabling components.
// Configuration Layers: Hierarchical config resolution (env > project > machine > user > defaults).
// Multi-Vault Secrets: Unified API for Bitwarden, 1Password, and pass.
//
// # Features
//
//   - Claude Code integration with portable session paths
//   - Developer tool integrations (AWS, Rust, Go, Python, Docker, SSH)
//   - Extensible hook system for lifecycle automation
//   - Template system with machine-specific variables
//   - Health checks with auto-fix capabilities
//   - Cross-platform support (macOS, Linux, Windows, WSL2, Docker)
//
// # Installation
//
//	curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash
//	blackdot setup
//
// # Basic Usage
//
//	# View system status
//	blackdot status
//
//	# Manage features
//	blackdot features list
//	blackdot features enable vault
//
//	# Manage secrets
//	blackdot vault restore
//	blackdot vault push
//
//	# Health checks
//	blackdot doctor
//	blackdot doctor --fix
//
// # Architecture
//
// Blackdot combines shell integration (Zsh) with Go implementations for
// performance-critical operations. The CLI is written in Go using Cobra,
// while shell hooks provide seamless terminal integration.
//
// For complete documentation, visit: https://blackwell-systems.github.io/blackdot
package blackdot
