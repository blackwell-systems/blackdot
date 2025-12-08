@{
    # Module manifest for Dotfiles PowerShell module

    # Script module file associated with this manifest
    RootModule = 'Dotfiles.psm1'

    # Version number of this module
    ModuleVersion = '1.2.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'Dotfiles'

    # Company or vendor of this module
    CompanyName = 'Blackwell Systems'

    # Copyright statement for this module
    Copyright = '(c) 2025 Blackwell Systems. MIT License.'

    # Description of the functionality provided by this module
    Description = 'Cross-platform dotfiles integration for PowerShell. Provides full hooks system (24 hook points), aliases, and developer tools for Windows users. Complete parity with ZSH implementation.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        # Hook system (complete parity with ZSH)
        'Register-DotfilesHook',      # hook_register equivalent
        'Unregister-DotfilesHook',    # hook_unregister equivalent
        'Invoke-DotfilesHook',        # hook_run equivalent
        'Get-DotfilesHook',           # hook_list equivalent
        'Get-DotfilesHookPoints',     # hook_points equivalent
        'Add-DotfilesHook',           # dotfiles hook add equivalent
        'Remove-DotfilesHook',        # dotfiles hook remove equivalent
        'Test-DotfilesHook',          # dotfiles hook test equivalent
        'Enable-DotfilesHooks',
        'Disable-DotfilesHooks',

        # Utilities
        'Get-DotfilesPath',
        'Test-DotfilesCli',
        'Test-HookPoint',             # hook_valid_point equivalent
        'Initialize-Dotfiles',
        'Initialize-DotfilesHooks',   # hook_init equivalent

        # CD wrapper
        'Set-LocationWithHook',

        # SSH aliases
        'ssh-keys', 'ssh-gen', 'ssh-list', 'ssh-agent-status',
        'ssh-fp', 'ssh-tunnel', 'ssh-socks', 'ssh-status', 'ssh-copy',

        # AWS aliases
        'aws-profiles', 'aws-who', 'aws-login', 'aws-switch',
        'aws-assume', 'aws-clear', 'aws-status',

        # CDK aliases
        'cdk-init', 'cdk-env', 'cdk-env-clear',
        'cdk-outputs', 'cdk-context', 'cdk-status',

        # Go aliases
        'go-new', 'go-init', 'go-test', 'go-cover', 'go-lint',
        'go-outdated', 'go-update', 'go-build-all', 'go-bench', 'go-info',

        # Rust aliases
        'rust-new', 'rust-update', 'rust-switch', 'rust-lint',
        'rust-fix', 'rust-outdated', 'rust-expand', 'rust-info',

        # Python aliases
        'py-new', 'py-clean', 'py-venv', 'py-test', 'py-cover', 'py-info',

        # Docker aliases
        'docker-ps', 'docker-images', 'docker-ip', 'docker-env',
        'docker-ports', 'docker-stats', 'docker-vols', 'docker-nets',
        'docker-inspect', 'docker-clean', 'docker-prune', 'docker-status',

        # Claude aliases
        'claude-status', 'claude-env', 'claude-init',
        'claude-bedrock', 'claude-max', 'claude-switch',

        # Node.js (fnm) integration
        'Initialize-Fnm', 'fnm-install', 'fnm-use', 'fnm-list',

        # Zoxide integration
        'Initialize-Zoxide',

        # Core commands
        'dotfiles-status', 'dotfiles-doctor', 'dotfiles-setup',
        'dotfiles-features', 'dotfiles-vault', 'dotfiles-hook',

        # Main wrapper (handles feature auto-reload)
        'Invoke-Dotfiles'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @('cd', 'd', 'cbed', 'cmax', 'cm')

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for module discovery
            Tags = @('dotfiles', 'hooks', 'aws', 'ssh', 'development', 'cross-platform', 'windows')

            # A URL to the license for this module
            LicenseUri = 'https://github.com/blackwell-systems/dotfiles/blob/main/LICENSE'

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/blackwell-systems/dotfiles'

            # Release notes for this module
            ReleaseNotes = @'
## 1.2.0
- Claude tools integration (full parity with ZSH and Go CLI)
- claude-status: Show Claude Code configuration
- claude-bedrock: Configure AWS Bedrock backend (-Eval to set env vars)
- claude-max: Configure Anthropic Max backend (-Eval to clear vars)
- claude-switch: Interactive backend switcher
- claude-init: Initialize ~/.claude/ from templates
- claude-env: Show Claude environment variables
- Aliases: cbed (claude-bedrock), cmax/cm (claude-max)

## 1.1.0
- Complete parity with ZSH hooks implementation
- All 24 hook points supported
- File-based, function-based, and JSON-configured hooks
- Timeout support using PowerShell jobs
- Fail-fast option
- Feature gating (checks parent features)
- Full hook management: list, add, remove, test

## 1.0.0
- Initial release with basic hooks and aliases
'@
        }
    }
}
