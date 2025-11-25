#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-${BW_SESSION:-}}"

if [[ -z "$SESSION" ]]; then
  echo "❌ restore-aws.sh: BW_SESSION or session arg is required."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ 'jq' is required."
  exit 1
fi

AWS_DIR="$HOME/.aws"
mkdir -p "$AWS_DIR"
chmod 700 "$AWS_DIR"

restore_aws_note() {
  local ITEM_NAME="$1"
  local TARGET_PATH="$2"

  echo "🟦 Restoring AWS file from Bitwarden item: $ITEM_NAME"

  local JSON NOTES
  if ! JSON="$(bw get item "$ITEM_NAME" --session "$SESSION" 2>/dev/null)"; then
    echo "⚠️  Item '$ITEM_NAME' not found. Skipping."
    return 0
  fi

  NOTES="$(printf '%s\n' "$JSON" | jq -r '.notes // ""')"
  if [[ -z "$NOTES" || "$NOTES" == "null" ]]; then
    echo "⚠️  Item '$ITEM_NAME' has empty notes. Skipping."
    return 0
  fi

  printf '%s\n' "$NOTES" > "$TARGET_PATH"
  chmod 600 "$TARGET_PATH"

  echo "✅ Wrote $TARGET_PATH"
}

# ~/.aws/config
restore_aws_note "AWS-Config" "$AWS_DIR/config"

# ~/.aws/credentials
restore_aws_note "AWS-Credentials" "$AWS_DIR/credentials"

echo "🟦 AWS restore complete."

