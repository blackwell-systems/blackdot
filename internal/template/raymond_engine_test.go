package template

import (
	"path/filepath"
	"testing"
)

// TestRaymondEngineBasicSubstitution verifies simple variable substitution
func TestRaymondEngineBasicSubstitution(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("name", "World")

	result, err := e.Render("Hello {{ name }}!")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "Hello World!"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineConditionalTrue verifies {{#if}} with truthy value
func TestRaymondEngineConditionalTrue(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("show", "yes")

	result, err := e.Render("{{#if show}}visible{{/if}}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "visible"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineConditionalFalse verifies {{#if}} with falsy value
func TestRaymondEngineConditionalFalse(t *testing.T) {
	e := NewRaymondEngine("")
	// Don't set the variable - should be falsy

	result, err := e.Render("{{#if missing}}visible{{/if}}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := ""
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineConditionalElse verifies {{#if}}...{{else}}...{{/if}}
func TestRaymondEngineConditionalElse(t *testing.T) {
	e := NewRaymondEngine("")
	// Don't set the variable

	result, err := e.Render("{{#if missing}}yes{{else}}no{{/if}}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "no"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineNestedConditionals verifies nested {{#if}} blocks
func TestRaymondEngineNestedConditionals(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("x", "1")
	e.SetVar("y", "1")

	result, err := e.Render("A{{#if x}}B{{#if y}}C{{/if}}D{{/if}}E")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "ABCDE"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineNestedConditionalsWithElse verifies nested conditionals with else
func TestRaymondEngineNestedConditionalsWithElse(t *testing.T) {
	tests := []struct {
		name     string
		outer    string
		inner    string
		expected string
	}{
		{"both true", "1", "1", "OUTER:INNER"},
		{"outer true inner false", "1", "", "OUTER:NOINNER"},
		{"outer false", "", "1", "NOOUTER"},
	}

	template := "{{#if outer}}OUTER:{{#if inner}}INNER{{else}}NOINNER{{/if}}{{else}}NOOUTER{{/if}}"

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			e := NewRaymondEngine("")
			if tt.outer != "" {
				e.SetVar("outer", tt.outer)
			}
			if tt.inner != "" {
				e.SetVar("inner", tt.inner)
			}

			result, err := e.Render(template)
			if err != nil {
				t.Fatalf("Render error: %v", err)
			}

			if result != tt.expected {
				t.Errorf("Expected %q, got %q", tt.expected, result)
			}
		})
	}
}

// TestRaymondEngineEqHelper verifies {{#if (eq var "value")}} syntax
func TestRaymondEngineEqHelper(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("machine_type", "work")

	result, err := e.Render(`{{#if (eq machine_type "work")}}WORK{{else}}PERSONAL{{/if}}`)
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "WORK"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineNeHelper verifies {{#if (ne var "value")}} syntax
func TestRaymondEngineNeHelper(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("machine_type", "personal")

	result, err := e.Render(`{{#if (ne machine_type "work")}}NOT-WORK{{else}}WORK{{/if}}`)
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "NOT-WORK"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineUnless verifies {{#unless}} blocks
func TestRaymondEngineUnless(t *testing.T) {
	e := NewRaymondEngine("")
	// Don't set variable - should show content

	result, err := e.Render("{{#unless missing}}shown{{/unless}}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "shown"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineFilterUpper verifies {{ upper var }} helper
func TestRaymondEngineFilterUpper(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("name", "hello")

	result, err := e.Render("{{ upper name }}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "HELLO"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineFilterLower verifies {{ lower var }} helper
func TestRaymondEngineFilterLower(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("name", "HELLO")

	result, err := e.Render("{{ lower name }}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "hello"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineFilterDefault verifies {{ default var "fallback" }} helper
func TestRaymondEngineFilterDefault(t *testing.T) {
	e := NewRaymondEngine("")
	// Don't set variable

	result, err := e.Render(`{{ default missing "fallback" }}`)
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "fallback"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineFilterTrim verifies {{ trim var }} helper
func TestRaymondEngineFilterTrim(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("name", "  hello  ")

	result, err := e.Render("{{ trim name }}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "hello"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineFilterBasename verifies {{ basename var }} helper
func TestRaymondEngineFilterBasename(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("path", "/home/user/.ssh/id_ed25519")

	result, err := e.Render("{{ basename path }}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "id_ed25519"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineFilterDirname verifies {{ dirname var }} helper
func TestRaymondEngineFilterDirname(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("path", "/home/user/.ssh/id_ed25519")

	result, err := e.Render("{{ dirname path }}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	// filepath.Dir returns platform-native separators
	expected := filepath.FromSlash("/home/user/.ssh")
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineFilterQuote verifies {{ quote var }} helper
func TestRaymondEngineFilterQuote(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("name", "hello")

	result, err := e.Render("{{ quote name }}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := `"hello"`
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineFilterTruncate verifies {{ truncate var N }} helper
func TestRaymondEngineFilterTruncate(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("name", "hello world")

	result, err := e.Render("{{ truncate name 5 }}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "hello"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineEachLoop verifies {{#each}} iteration
func TestRaymondEngineEachLoop(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetArray("items", []map[string]interface{}{
		{"name": "Alice"},
		{"name": "Bob"},
		{"name": "Charlie"},
	})

	result, err := e.Render("{{#each items}}{{ name }},{{/each}}")
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := "Alice,Bob,Charlie,"
	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

// TestRaymondEngineSSHHostsTemplate verifies a realistic SSH config template
func TestRaymondEngineSSHHostsTemplate(t *testing.T) {
	e := NewRaymondEngine("")
	e.SetVar("ssh_default_identity", "~/.ssh/id_ed25519")
	e.SetArray("ssh_hosts", []map[string]interface{}{
		{"name": "github.com", "hostname": "github.com", "user": "git", "identity": "~/.ssh/github"},
	})

	template := `Host {{ ssh_default_identity }}
{{#each ssh_hosts}}
Host {{ name }}
    HostName {{ hostname }}
    User {{ user }}
    IdentityFile {{ identity }}
{{/each}}`

	result, err := e.Render(template)
	if err != nil {
		t.Fatalf("Render error: %v", err)
	}

	expected := `Host ~/.ssh/id_ed25519
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github
`
	if result != expected {
		t.Errorf("Expected:\n%s\nGot:\n%s", expected, result)
	}
}
