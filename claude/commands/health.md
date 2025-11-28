Run the dotfiles health check and summarize any issues:

```bash
~/workspace/dotfiles/dotfiles-doctor.sh
```

If there are permission warnings, offer to run with `--fix`.
If there are missing items, explain how to restore them with `dotfiles vault restore`.
For drift detection, suggest running `dotfiles drift`.
