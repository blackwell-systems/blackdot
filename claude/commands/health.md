Run the blackdot health check and summarize any issues:

```bash
blackdot doctor
```

If there are permission warnings, offer to run with `--fix`.
If there are missing items, explain how to restore them with `blackdot vault restore`.
For drift detection, suggest running `blackdot drift`.
