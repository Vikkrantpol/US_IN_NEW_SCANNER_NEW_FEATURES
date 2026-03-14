# Open-Source Release Notes

This repo can be published without changing the existing local workflow if you keep private runtime inputs out of version control.

## Private local files

- Copy `scan_conditions.example.json` to `.scanner_secrets/scan_conditions.json` and replace every placeholder value with your private thresholds.
- Or keep the file elsewhere and set `SCAN_CONDITIONS_FILE=/absolute/path/to/scan_conditions.json`.
- Copy `.env.example` to `.env` if you use Fyers-backed India data.

## Safe-to-publish code path

- `start_scan.sh`, `India_scan.sh`, `start_dashboard.sh`, and the dashboard continue to work with the local private files above.
- The repo-level `.gitignore` excludes private configs, generated scan outputs, history databases, exports, logs, and backup folders.

## Do not publish

- `.scanner_secrets/`
- `.env`
- `scanner_results*.json`
- `india_results*.json`
- `scan_state.db`
- `scan_mega_history.db`
- `exports/`
- `backups/`

Those files expose the strategy indirectly even if the source code is clean.
