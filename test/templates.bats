#!/usr/bin/env bats
# Unit tests for lib/_templates.sh
# Focuses on {{#each}} loop functionality

setup() {
  # Path to the script under test
  export TEMPLATES_SH="${BATS_TEST_DIRNAME}/../lib/_templates.sh"
  export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."

  # Create temporary directory for test templates
  export TEST_TMPDIR="${BATS_TMPDIR}/templates_test_$$"
  mkdir -p "$TEST_TMPDIR"
}

teardown() {
  # Clean up temp directory
  rm -rf "$TEST_TMPDIR"
}

# Helper function to invoke zsh functions
zsh_eval() {
  zsh -c "
    export DOTFILES_DIR='$DOTFILES_DIR'
    export TEMPLATES_DIR='$DOTFILES_DIR/templates'
    source '$TEMPLATES_SH'
    $*
  "
}

# Helper function to render a template string
render_string() {
  local template="$1"
  local setup_code="${2:-}"

  # Create temp template file
  echo "$template" > "$TEST_TMPDIR/test.tmpl"

  zsh -c "
    export DOTFILES_DIR='$DOTFILES_DIR'
    export TEMPLATES_DIR='$DOTFILES_DIR/templates'
    source '$TEMPLATES_SH'
    $setup_code
    build_template_vars
    render_template '$TEST_TMPDIR/test.tmpl'
  "
}

# ============================================================
# Basic Template Rendering
# ============================================================

@test "render_template substitutes simple variables" {
  template='Hello {{ user }}'

  run render_string "$template"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Hello " ]]
  # Should have substituted {{ user }} with actual username
  [[ ! "${output}" =~ "{{ user }}" ]]
}

@test "render_template handles missing variables gracefully" {
  template='Value: {{ nonexistent_var_xyz }}'

  run render_string "$template"

  # Should warn but not fail
  [ "$status" -eq 0 ]
}

# ============================================================
# {{#each}} Loop Tests
# ============================================================

@test "process_each_loops expands ssh_hosts array" {
  template='{{#each ssh_hosts}}Host {{ name }}
{{/each}}'

  setup_code='
    SSH_HOSTS=("test-host|example.com|testuser|~/.ssh/id|")
    load_template_arrays
  '

  run render_string "$template" "$setup_code"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Host test-host" ]]
}

@test "process_each_loops handles multiple items" {
  template='{{#each ssh_hosts}}{{ name }}:{{ hostname }}
{{/each}}'

  setup_code='
    SSH_HOSTS=(
      "github|github.com|git|~/.ssh/id|"
      "gitlab|gitlab.com|git|~/.ssh/id|"
      "work|work.example.com|admin|~/.ssh/id_work|"
    )
    load_template_arrays
  '

  run render_string "$template" "$setup_code"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "github:github.com" ]]
  [[ "${output}" =~ "gitlab:gitlab.com" ]]
  [[ "${output}" =~ "work:work.example.com" ]]
}

@test "process_each_loops handles all ssh_hosts fields" {
  template='{{#each ssh_hosts}}Host {{ name }}
    HostName {{ hostname }}
    User {{ user }}
    IdentityFile {{ identity }}
{{/each}}'

  setup_code='
    SSH_HOSTS=("myhost|server.example.com|deploy|~/.ssh/deploy_key|ProxyJump bastion")
    load_template_arrays
  '

  run render_string "$template" "$setup_code"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Host myhost" ]]
  [[ "${output}" =~ "HostName server.example.com" ]]
  [[ "${output}" =~ "User deploy" ]]
  [[ "${output}" =~ "IdentityFile ~/.ssh/deploy_key" ]]
}

@test "process_each_loops handles empty array" {
  template='Before
{{#each ssh_hosts}}Host {{ name }}
{{/each}}After'

  setup_code='
    SSH_HOSTS=()
    load_template_arrays
  '

  run render_string "$template" "$setup_code"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Before" ]]
  [[ "${output}" =~ "After" ]]
  # Should not contain "Host" since array is empty
  [[ ! "${output}" =~ "Host " ]]
}

@test "process_each_loops preserves content outside loop" {
  template='# Header
{{#each ssh_hosts}}{{ name }}
{{/each}}# Footer'

  setup_code='
    SSH_HOSTS=("test|example.com|user|~/.ssh/id|")
    load_template_arrays
  '

  run render_string "$template" "$setup_code"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "# Header" ]]
  [[ "${output}" =~ "# Footer" ]]
  [[ "${output}" =~ "test" ]]
}

@test "conditionals work inside each loops" {
  template='{{#each ssh_hosts}}Host {{ name }}
{{#if extra }}    {{ extra }}
{{/if}}{{/each}}'

  setup_code='
    SSH_HOSTS=(
      "noextra|example.com|user|~/.ssh/id|"
      "withextra|example.com|user|~/.ssh/id|ProxyJump bastion"
    )
    load_template_arrays
  '

  run render_string "$template" "$setup_code"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Host noextra" ]]
  [[ "${output}" =~ "Host withextra" ]]
  [[ "${output}" =~ "ProxyJump bastion" ]]
}

# ============================================================
# Validation Tests
# ============================================================

@test "validate_template detects unmatched each blocks" {
  echo '{{#each items}}content' > "$TEST_TMPDIR/bad.tmpl"

  run zsh_eval "validate_template '$TEST_TMPDIR/bad.tmpl'"

  [ "$status" -ne 0 ]
  [[ "${output}" =~ "Unmatched" ]]
}

@test "validate_template passes for matched each blocks" {
  echo '{{#each items}}content{{/each}}' > "$TEST_TMPDIR/good.tmpl"

  run zsh_eval "validate_template '$TEST_TMPDIR/good.tmpl'"

  [ "$status" -eq 0 ]
}

# ============================================================
# Array Schema Tests
# ============================================================

@test "ssh_hosts schema defines correct fields" {
  run zsh_eval 'echo "${TMPL_ARRAY_SCHEMAS[ssh_hosts]}"'

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "name" ]]
  [[ "${output}" =~ "hostname" ]]
  [[ "${output}" =~ "user" ]]
  [[ "${output}" =~ "identity" ]]
  [[ "${output}" =~ "extra" ]]
}

@test "load_template_arrays loads SSH_HOSTS" {
  run zsh_eval '
    SSH_HOSTS=("a|b|c|d|e" "f|g|h|i|j")
    load_template_arrays
    echo "${#TMPL_ARRAYS_ssh_hosts[@]}"
  '

  [ "$status" -eq 0 ]
  [ "${output}" = "2" ]
}
