# India_scan.sh — India Scanner Launcher

## Purpose
Shell script that automates the full setup-and-run pipeline for the India (NSE) stock scanner.

## Usage

```bash
./India_scan.sh run
./India_scan.sh fresh
./India_scan.sh summary
./India_scan.sh smallcap
./India_scan.sh midcap
./India_scan.sh largecap
./India_scan.sh diff
./India_scan.sh report
./India_scan.sh history
./India_scan.sh help
```

## Pipeline Steps

1. Prints banner
2. Checks Python >= 3.8
3. Verifies `india_scanner.py` exists
4. Creates `venv/` virtual environment if needed
5. Activates the venv
6. Installs dependencies: `yfinance pandas numpy requests fyers-apiv3`
7. Displays scan configuration and dashboard hint
8. Runs `india_scanner.py`

## Modes

- `run`: resume/update mode using India rows in `scan_state.db`
- `fresh`: clears India rows from `scan_state.db`, deletes India JSON/log outputs, then rescans
- `summary`: prints the latest top 30 India names in a terminal table
- `smallcap`: prints only `Smallcap` names from the latest India results in descending score order
- `midcap`: prints only `Midcap` names from the latest India results in descending score order
- `largecap`: prints only `Largecap` names from the latest India results in descending score order
- `diff`: compares the latest India result set to the newest older dated snapshot and archives the diff output
- `report`: prints a richer India market report and archives the report output
- `history`: reads archived India scan history from `scan_mega_history.db`
- `fresh` preserves `scan_mega_history.db`, so archived historical scores survive resets

## Scanner Behavior It Launches

When `india_scanner.py` starts, it now:

- scans each chunk with 4 worker threads
- preserves per-symbol retry handling inside each worker
- keeps scan history and resume state in `scan_state.db`
- writes a permanent archive of all scan events to `scan_mega_history.db`
- applies incremental re-scan rules instead of skipping symbols forever
- writes `india_results_YYYY-MM-DD.json` after a full scan and keeps the latest 7 snapshots

## Key Differences from `start_scan.sh`

| Feature | `start_scan.sh` | `India_scan.sh` |
|---------|-----------------|-----------------|
| Venv directory | `.venv/` | `venv/` |
| Dependencies | `requirements.txt` | Includes `fyers-apiv3` |
| Commands | `run`, `fresh`, `history`, `download`, `clean`, `help` | `run`, `fresh`, `history`, `help` |
| Interrupt handling | Shell exits | Trap notifies that progress/history is already saved |
| Pre-run info | Minimal | Displays configuration and dashboard URL |

## Graceful Interruption

- `Ctrl+C` triggers a cleanup message informing that progress is saved
- Re-running the script reuses the existing scan history and applies the incremental re-scan rules
