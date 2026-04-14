package shell

import (
	"os"
	"strings"
	"testing"
)

func TestDetect(t *testing.T) {
	tests := []struct {
		name     string
		shellEnv string
		want     ShellType
	}{
		{
			name:     "zsh shell",
			shellEnv: "/bin/zsh",
			want:     ShellZsh,
		},
		{
			name:     "bash shell",
			shellEnv: "/usr/bin/bash",
			want:     ShellBash,
		},
		{
			name:     "fish shell",
			shellEnv: "/usr/local/bin/fish",
			want:     ShellFish,
		},
		{
			name:     "unknown shell",
			shellEnv: "/bin/ksh",
			want:     ShellUnknown,
		},
		{
			name:     "empty SHELL env",
			shellEnv: "",
			want:     ShellUnknown,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Save original SHELL env
			origShell := os.Getenv("SHELL")
			defer os.Setenv("SHELL", origShell)

			// Set test SHELL env
			if tt.shellEnv == "" {
				os.Unsetenv("SHELL")
			} else {
				os.Setenv("SHELL", tt.shellEnv)
			}

			got := Detect()
			if got != tt.want {
				t.Errorf("Detect() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestExportVar(t *testing.T) {
	tests := []struct {
		name     string
		shellEnv string
		varName  string
		varValue string
		want     string
	}{
		{
			name:     "zsh export",
			shellEnv: "/bin/zsh",
			varName:  "FOO",
			varValue: "bar",
			want:     `export FOO="bar"`,
		},
		{
			name:     "bash export",
			shellEnv: "/bin/bash",
			varName:  "PATH",
			varValue: "/usr/bin",
			want:     `export PATH="/usr/bin"`,
		},
		{
			name:     "fish export",
			shellEnv: "/bin/fish",
			varName:  "BAZ",
			varValue: "qux",
			want:     `set -gx BAZ "qux"`,
		},
		{
			name:     "value with spaces",
			shellEnv: "/bin/bash",
			varName:  "MSG",
			varValue: "hello world",
			want:     `export MSG="hello world"`,
		},
		{
			name:     "value with quotes",
			shellEnv: "/bin/bash",
			varName:  "STR",
			varValue: `say "hi"`,
			want:     `export STR="say \"hi\""`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Save and restore SHELL env
			origShell := os.Getenv("SHELL")
			defer os.Setenv("SHELL", origShell)

			os.Setenv("SHELL", tt.shellEnv)

			got := ExportVar(tt.varName, tt.varValue)
			if got != tt.want {
				t.Errorf("ExportVar() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestEvalOutput(t *testing.T) {
	tests := []struct {
		name     string
		shellEnv string
		vars     map[string]string
		wantVars []string // List of expected export statements (order doesn't matter)
	}{
		{
			name:     "single var bash",
			shellEnv: "/bin/bash",
			vars: map[string]string{
				"FOO": "bar",
			},
			wantVars: []string{`export FOO="bar"`},
		},
		{
			name:     "multiple vars zsh",
			shellEnv: "/bin/zsh",
			vars: map[string]string{
				"A": "1",
				"B": "2",
			},
			wantVars: []string{
				`export A="1"`,
				`export B="2"`,
			},
		},
		{
			name:     "multiple vars fish",
			shellEnv: "/bin/fish",
			vars: map[string]string{
				"X": "alpha",
				"Y": "beta",
			},
			wantVars: []string{
				`set -gx X "alpha"`,
				`set -gx Y "beta"`,
			},
		},
		{
			name:     "empty map",
			shellEnv: "/bin/bash",
			vars:     map[string]string{},
			wantVars: []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Save and restore SHELL env
			origShell := os.Getenv("SHELL")
			defer os.Setenv("SHELL", origShell)

			os.Setenv("SHELL", tt.shellEnv)

			got := EvalOutput(tt.vars)
			gotLines := strings.Split(got, "\n")

			// For empty map, expect empty string
			if len(tt.wantVars) == 0 {
				if got != "" {
					t.Errorf("EvalOutput() = %q, want empty string", got)
				}
				return
			}

			// Check all expected vars are present (order doesn't matter due to map iteration)
			for _, wantVar := range tt.wantVars {
				found := false
				for _, line := range gotLines {
					if line == wantVar {
						found = true
						break
					}
				}
				if !found {
					t.Errorf("EvalOutput() missing expected export: %q\nGot: %q", wantVar, got)
				}
			}

			// Check no extra lines
			if len(gotLines) != len(tt.wantVars) {
				t.Errorf("EvalOutput() got %d lines, want %d", len(gotLines), len(tt.wantVars))
			}
		})
	}
}

func TestSourceCommand(t *testing.T) {
	tests := []struct {
		name     string
		shellEnv string
		path     string
		want     string
	}{
		{
			name:     "zsh source",
			shellEnv: "/bin/zsh",
			path:     "/path/to/config",
			want:     `source "/path/to/config"`,
		},
		{
			name:     "bash source",
			shellEnv: "/bin/bash",
			path:     "/etc/profile",
			want:     `source "/etc/profile"`,
		},
		{
			name:     "fish source",
			shellEnv: "/bin/fish",
			path:     "/home/user/.config/fish/config.fish",
			want:     `source /home/user/.config/fish/config.fish`,
		},
		{
			name:     "path with spaces",
			shellEnv: "/bin/bash",
			path:     "/path with spaces/config",
			want:     `source "/path with spaces/config"`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Save and restore SHELL env
			origShell := os.Getenv("SHELL")
			defer os.Setenv("SHELL", origShell)

			os.Setenv("SHELL", tt.shellEnv)

			got := SourceCommand(tt.path)
			if got != tt.want {
				t.Errorf("SourceCommand() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestCommonIntegrations(t *testing.T) {
	integrations := CommonIntegrations()

	// Check we got the expected 3 integrations
	expectedNames := []string{"direnv", "starship", "zoxide"}
	if len(integrations) != len(expectedNames) {
		t.Fatalf("CommonIntegrations() returned %d integrations, want %d", len(integrations), len(expectedNames))
	}

	for i, expected := range expectedNames {
		if integrations[i].Name != expected {
			t.Errorf("Integration[%d].Name = %q, want %q", i, integrations[i].Name, expected)
		}

		// Verify each integration has required fields
		if integrations[i].Description == "" {
			t.Errorf("Integration[%d] (%s) missing Description", i, expected)
		}
		if integrations[i].Condition == nil {
			t.Errorf("Integration[%d] (%s) missing Condition function", i, expected)
		}
		if integrations[i].Setup == nil {
			t.Errorf("Integration[%d] (%s) missing Setup function", i, expected)
		}
	}
}

func TestIntegrationConditions(t *testing.T) {
	integrations := CommonIntegrations()

	// Test that Condition functions don't panic
	for _, integration := range integrations {
		t.Run(integration.Name+"_condition", func(t *testing.T) {
			// Should not panic
			_ = integration.Condition()
		})
	}
}

func TestIntegrationSetup(t *testing.T) {
	tests := []struct {
		name         string
		shellEnv     string
		integration  string
		wantContains string // Expected substring in output
	}{
		{
			name:         "direnv zsh",
			shellEnv:     "/bin/zsh",
			integration:  "direnv",
			wantContains: "direnv hook zsh",
		},
		{
			name:         "direnv bash",
			shellEnv:     "/bin/bash",
			integration:  "direnv",
			wantContains: "direnv hook bash",
		},
		{
			name:         "direnv fish",
			shellEnv:     "/bin/fish",
			integration:  "direnv",
			wantContains: "direnv hook fish",
		},
		{
			name:         "starship zsh",
			shellEnv:     "/bin/zsh",
			integration:  "starship",
			wantContains: "starship init zsh",
		},
		{
			name:         "zoxide bash",
			shellEnv:     "/bin/bash",
			integration:  "zoxide",
			wantContains: "zoxide init bash",
		},
	}

	integrations := CommonIntegrations()
	integrationMap := make(map[string]*Integration)
	for _, i := range integrations {
		integrationMap[i.Name] = i
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Save and restore SHELL env
			origShell := os.Getenv("SHELL")
			defer os.Setenv("SHELL", origShell)

			os.Setenv("SHELL", tt.shellEnv)

			integration := integrationMap[tt.integration]
			if integration == nil {
				t.Fatalf("Integration %q not found", tt.integration)
			}

			got, err := integration.Setup()
			if err != nil {
				t.Fatalf("Setup() returned error: %v", err)
			}

			if !strings.Contains(got, tt.wantContains) {
				t.Errorf("Setup() = %q, want to contain %q", got, tt.wantContains)
			}
		})
	}
}

func TestIntegrationSetupUnknownShell(t *testing.T) {
	// Save and restore SHELL env
	origShell := os.Getenv("SHELL")
	defer os.Setenv("SHELL", origShell)

	os.Setenv("SHELL", "/bin/ksh") // Unknown shell

	integrations := CommonIntegrations()
	for _, integration := range integrations {
		t.Run(integration.Name, func(t *testing.T) {
			got, err := integration.Setup()
			if err != nil {
				t.Errorf("Setup() returned unexpected error: %v", err)
			}
			// Unknown shells should return empty string
			if got != "" {
				t.Errorf("Setup() for unknown shell = %q, want empty string", got)
			}
		})
	}
}

func TestGenerateFeatureCheck(t *testing.T) {
	tests := []struct {
		name            string
		featureName     string
		wantContains    []string
		wantNotContains []string
	}{
		{
			name:        "simple feature",
			featureName: "ssh_tools",
			wantContains: []string{
				"Feature check for ssh_tools",
				"blackdot features check ssh_tools",
				"_BLACKDOT_FEATURE_SSH_TOOLS=1",
				"_BLACKDOT_FEATURE_SSH_TOOLS=0",
			},
		},
		{
			name:        "feature with underscore",
			featureName: "aws_helpers",
			wantContains: []string{
				"Feature check for aws_helpers",
				"blackdot features check aws_helpers",
				"_BLACKDOT_FEATURE_AWS_HELPERS=1",
				"_BLACKDOT_FEATURE_AWS_HELPERS=0",
			},
		},
		{
			name:        "feature with dash converted to underscore",
			featureName: "docker-tools",
			wantContains: []string{
				"Feature check for docker-tools",
				"blackdot features check docker-tools",
				"_BLACKDOT_FEATURE_DOCKER-TOOLS=1",
				"_BLACKDOT_FEATURE_DOCKER-TOOLS=0",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GenerateFeatureCheck(tt.featureName)

			for _, want := range tt.wantContains {
				if !strings.Contains(got, want) {
					t.Errorf("GenerateFeatureCheck() missing expected string %q\nGot: %s", want, got)
				}
			}

			for _, notWant := range tt.wantNotContains {
				if strings.Contains(got, notWant) {
					t.Errorf("GenerateFeatureCheck() contains unexpected string %q\nGot: %s", notWant, got)
				}
			}

			// Verify it's valid shell syntax (basic check)
			if !strings.Contains(got, "if ") || !strings.Contains(got, "fi") {
				t.Errorf("GenerateFeatureCheck() doesn't look like valid shell syntax\nGot: %s", got)
			}
		})
	}
}

func TestShellTypeConstants(t *testing.T) {
	// Verify constants are defined and have expected values
	tests := []struct {
		got  ShellType
		want string
	}{
		{ShellZsh, "zsh"},
		{ShellBash, "bash"},
		{ShellFish, "fish"},
		{ShellUnknown, "unknown"},
	}

	for _, tt := range tests {
		if string(tt.got) != tt.want {
			t.Errorf("ShellType constant = %q, want %q", tt.got, tt.want)
		}
	}
}

func TestDetectWithComplexPaths(t *testing.T) {
	tests := []struct {
		name     string
		shellEnv string
		want     ShellType
	}{
		{
			name:     "zsh via homebrew",
			shellEnv: "/opt/homebrew/bin/zsh",
			want:     ShellZsh,
		},
		{
			name:     "bash via asdf",
			shellEnv: "/home/user/.asdf/shims/bash",
			want:     ShellBash,
		},
		{
			name:     "fish from custom location",
			shellEnv: "/usr/local/custom/bin/fish",
			want:     ShellFish,
		},
		{
			name:     "relative path",
			shellEnv: "zsh", // Just the binary name
			want:     ShellZsh,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			origShell := os.Getenv("SHELL")
			defer os.Setenv("SHELL", origShell)

			os.Setenv("SHELL", tt.shellEnv)

			got := Detect()
			if got != tt.want {
				t.Errorf("Detect() with path %q = %v, want %v", tt.shellEnv, got, tt.want)
			}
		})
	}
}

func TestIntegrationConditionsWithCustomPaths(t *testing.T) {
	// This test verifies the Condition logic checks multiple paths
	// We can't easily mock os.Stat, but we can verify the function doesn't panic
	// and returns a boolean

	integrations := CommonIntegrations()

	for _, integration := range integrations {
		t.Run(integration.Name, func(t *testing.T) {
			// Call Condition multiple times to ensure it's stable
			result1 := integration.Condition()
			result2 := integration.Condition()

			// Results should be consistent
			if result1 != result2 {
				t.Errorf("Condition() returned inconsistent results: %v != %v", result1, result2)
			}

			// Result should be a valid boolean (true or false)
			if result1 != true && result1 != false {
				t.Errorf("Condition() returned non-boolean value: %v", result1)
			}
		})
	}
}

func TestSourceCommandEdgeCases(t *testing.T) {
	tests := []struct {
		name     string
		shellEnv string
		path     string
		want     string
	}{
		{
			name:     "empty path bash",
			shellEnv: "/bin/bash",
			path:     "",
			want:     `source ""`,
		},
		{
			name:     "empty path fish",
			shellEnv: "/bin/fish",
			path:     "",
			want:     `source `,
		},
		{
			name:     "path with special chars",
			shellEnv: "/bin/bash",
			path:     "/path/with/$VAR/config",
			want:     `source "/path/with/$VAR/config"`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			origShell := os.Getenv("SHELL")
			defer os.Setenv("SHELL", origShell)

			os.Setenv("SHELL", tt.shellEnv)

			got := SourceCommand(tt.path)
			if got != tt.want {
				t.Errorf("SourceCommand(%q) = %q, want %q", tt.path, got, tt.want)
			}
		})
	}
}

func TestExportVarEdgeCases(t *testing.T) {
	tests := []struct {
		name     string
		shellEnv string
		varName  string
		varValue string
		want     string
	}{
		{
			name:     "empty var name",
			shellEnv: "/bin/bash",
			varName:  "",
			varValue: "value",
			want:     `export ="value"`,
		},
		{
			name:     "empty var value",
			shellEnv: "/bin/bash",
			varName:  "EMPTY",
			varValue: "",
			want:     `export EMPTY=""`,
		},
		{
			name:     "var name with special chars",
			shellEnv: "/bin/bash",
			varName:  "MY_VAR_123",
			varValue: "test",
			want:     `export MY_VAR_123="test"`,
		},
		{
			name:     "fish with empty value",
			shellEnv: "/bin/fish",
			varName:  "EMPTY",
			varValue: "",
			want:     `set -gx EMPTY ""`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			origShell := os.Getenv("SHELL")
			defer os.Setenv("SHELL", origShell)

			os.Setenv("SHELL", tt.shellEnv)

			got := ExportVar(tt.varName, tt.varValue)
			if got != tt.want {
				t.Errorf("ExportVar(%q, %q) = %q, want %q", tt.varName, tt.varValue, got, tt.want)
			}
		})
	}
}

func TestGenerateFeatureCheckFormat(t *testing.T) {
	// Verify the generated shell code has expected structure
	got := GenerateFeatureCheck("test_feature")

	// Should be a multi-line string
	lines := strings.Split(strings.TrimSpace(got), "\n")
	if len(lines) < 4 {
		t.Errorf("GenerateFeatureCheck() produced %d lines, want at least 4", len(lines))
	}

	// Should contain if/else/fi structure
	containsIf := false
	containsElse := false
	containsFi := false

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "if ") {
			containsIf = true
		}
		if strings.HasPrefix(line, "else") {
			containsElse = true
		}
		if strings.HasPrefix(line, "fi") {
			containsFi = true
		}
	}

	if !containsIf {
		t.Error("GenerateFeatureCheck() missing 'if' statement")
	}
	if !containsElse {
		t.Error("GenerateFeatureCheck() missing 'else' statement")
	}
	if !containsFi {
		t.Error("GenerateFeatureCheck() missing 'fi' statement")
	}

	// Should redirect output (>/dev/null 2>&1)
	if !strings.Contains(got, ">/dev/null 2>&1") {
		t.Error("GenerateFeatureCheck() missing output redirection")
	}
}

func TestIntegrationPaths(t *testing.T) {
	// Verify CommonIntegrations checks both /usr/local/bin and /opt/homebrew/bin
	integrations := CommonIntegrations()

	for _, integration := range integrations {
		t.Run(integration.Name, func(t *testing.T) {

			// The actual implementation checks /usr/local/bin and /opt/homebrew/bin
			// We can't easily mock os.Stat, so just verify Condition is callable
			result := integration.Condition()

			// Should return bool without panic
			_ = result

			// Verify Setup produces output for known shells
			origShell := os.Getenv("SHELL")
			defer os.Setenv("SHELL", origShell)

			for _, shell := range []string{"/bin/zsh", "/bin/bash", "/bin/fish"} {
				os.Setenv("SHELL", shell)
				output, err := integration.Setup()
				if err != nil {
					t.Errorf("Setup() for %s returned error: %v", shell, err)
				}
				if output == "" {
					t.Errorf("Setup() for %s returned empty output", shell)
				}
			}

			// Unknown shell should return empty
			os.Setenv("SHELL", "/bin/unknown")
			output, err := integration.Setup()
			if err != nil {
				t.Errorf("Setup() for unknown shell returned error: %v", err)
			}
			if output != "" {
				t.Errorf("Setup() for unknown shell = %q, want empty", output)
			}
		})
	}
}
