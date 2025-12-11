package cli

import (
	"os"

	"github.com/spf13/cobra"
)

func newCompletionCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "completion [bash|zsh|fish|powershell]",
		Short: "Generate shell completion script",
		Long: `Generate shell completion script for blackdot.

Bash:
  # Add to ~/.bashrc or ~/.bash_profile
  source <(blackdot completion bash)

  # Or install globally (Linux)
  blackdot completion bash > /etc/bash_completion.d/blackdot

  # Or install globally (macOS with bash-completion@2)
  blackdot completion bash > $(brew --prefix)/etc/bash_completion.d/blackdot

Zsh:
  # Add to ~/.zshrc (before compinit)
  source <(blackdot completion zsh)

  # Or install to fpath
  blackdot completion zsh > "${fpath[1]}/_blackdot"

  # If shell completion is not already enabled:
  echo "autoload -U compinit; compinit" >> ~/.zshrc

Fish:
  # Add to ~/.config/fish/completions/
  blackdot completion fish > ~/.config/fish/completions/blackdot.fish

PowerShell:
  # Add to $PROFILE
  blackdot completion powershell >> $PROFILE

  # Or load in current session
  blackdot completion powershell | Out-String | Invoke-Expression`,
		DisableFlagsInUseLine: true,
		ValidArgs:             []string{"bash", "zsh", "fish", "powershell"},
		Args:                  cobra.MatchAll(cobra.ExactArgs(1), cobra.OnlyValidArgs),
		RunE: func(cmd *cobra.Command, args []string) error {
			switch args[0] {
			case "bash":
				return cmd.Root().GenBashCompletion(os.Stdout)
			case "zsh":
				return cmd.Root().GenZshCompletion(os.Stdout)
			case "fish":
				return cmd.Root().GenFishCompletion(os.Stdout, true)
			case "powershell":
				return cmd.Root().GenPowerShellCompletionWithDesc(os.Stdout)
			}
			return nil
		},
	}

	return cmd
}
