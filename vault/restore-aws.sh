#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-}"

if [[ -z "${SESSION}" ]]; then
  echo "Usage: restore-aws.sh <BW_SESSION>" >&2
  exit 1
fi

AWS_DIR="$HOME/.aws"
mkdir -p "$AWS_DIR"
chmod 700 "$AWS_DIR"

echo "🟦 Restoring AWS config from Bitwarden item 'AWS-Config'..."

if bw get item "AWS-Config" --session "$SESSION" >/dev/null 2>&1; then
  CONFIG_JSON=$(bw get item "AWS-Config" --session "$SESSION")
  echo "$CONFIG_JSON" | jq -r '.notes' > "$AWS_DIR/config"
  chmod 600 "$AWS_DIR/config"
  echo "✅ ~/.aws/config restored."
else
  echo "⚠️ No Bitwarden item named 'AWS-Config' found. Skipping ~/.aws/config."
fi

echo "🟦 Restoring AWS credentials from Bitwarden item 'AWS-Credentials' (if present)..."

if bw get item "AWS-Credentials" --session "$SESSION" >/dev/null 2>&1; then
  CREDS_JSON=$(bw get item "AWS-Credentials" --session "$SESSION")
  echo "$CREDS_JSON" | jq -r '.notes' > "$AWS_DIR/credentials"
  chmod 600 "$AWS_DIR/credentials"
  echo "✅ ~/.aws/credentials restored."
else
  echo "⚠️ No Bitwarden item named 'AWS-Credentials' found. Leaving ~/.aws/credentials as-is."
fi

