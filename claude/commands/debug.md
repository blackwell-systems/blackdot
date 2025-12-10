Collect debug information for troubleshooting:

```bash
echo "=== System ==="
uname -a
echo ""

echo "=== Shell ==="
echo "SHELL: $SHELL"
zsh --version
echo ""

echo "=== Blackdot ==="
cd ~/workspace/dotfiles 2>/dev/null && git log -1 --oneline || echo "Not found"
echo ""

echo "=== Health Check ==="
blackdot doctor 2>&1 | head -30
```

Summarize any issues found and suggest fixes.
