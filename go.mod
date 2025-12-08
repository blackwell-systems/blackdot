module github.com/blackwell-systems/dotfiles

go 1.24.0

toolchain go1.24.7

require (
	github.com/BurntSushi/toml v1.5.0
	github.com/aymerick/raymond v2.0.2+incompatible
	github.com/blackwell-systems/vaultmux v0.3.1
	github.com/fatih/color v1.18.0
	github.com/spf13/cobra v1.8.1
	github.com/spf13/pflag v1.0.5
	golang.org/x/crypto v0.45.0
)

require (
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/mattn/go-colorable v0.1.13 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	golang.org/x/sys v0.38.0 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
)

// vaultmux will be added as external dependency when published:
// require github.com/blackwell-systems/vaultmux v0.1.0
