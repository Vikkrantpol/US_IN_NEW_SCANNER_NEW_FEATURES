# start_scan.sh — US Scanner Launcher

## Purpose
Shell script that automates the full setup-and-run pipeline for the US stock scanner.

## Usage

```bash
./start_scan.sh run
./start_scan.sh fresh
./start_scan.sh summary
./start_scan.sh diff
./start_scan.sh report
./start_scan.sh history
./start_scan.sh download
./start_scan.sh clean
./start_scan.sh help
```

## What Each Command Does

### `run`

1. Prints banner
2. Checks Python >= 3.8
3. Creates `.venv/` if needed
4. Activates the venv
5. Installs dependencies from `requirements.txt`
6. Runs `scanner.py`

`run` is resume/update mode:

- loads the current US working state from `scan_state.db`
- rescans only tickers that meet the incremental re-scan rules
- appends all scan events to `scan_mega_history.db`

### `fresh`

1. Clears US rows from `scan_state.db`
2. Deletes:
   - `scanner_results.json`
   - `scanner_results_YYYY-MM-DD.json`
   - `scanner_scanned.txt`
3. Preserves `scan_mega_history.db`
4. Runs `scanner.py` from a clean US working state

### `history`

- reads archived US scan history from `scan_mega_history.db`
- shows summary totals, recent runs, recent scan events, most-scanned tickers, and recent snapshots

### `summary`

- prints the latest top 30 US names in a terminal table

### `diff`

- compares the latest US result set to the newest older dated snapshot
- prints `new`, `upgraded`, `downgraded`, and `dropped` sections
- saves the generated diff artifact with timestamp into `scan_mega_history.db`

### `report`

- prints a richer US market report with score distribution, signal counts, sector leaders, and top ranked names
- saves the generated report artifact with timestamp into `scan_mega_history.db`

### Runtime behavior of `scanner.py`

The launched scanner currently:

- processes each chunk with 4 worker threads
- keeps scan history and resume state in `scan_state.db`
- writes a permanent archive of all scan events to `scan_mega_history.db`
- applies incremental re-scan rules instead of permanent one-time skipping
- writes `scanner_results.json` atomically after each chunk
- writes `scanner_results_YYYY-MM-DD.json` after a full scan and retains the latest 7 snapshots

### `download`

Runs the same environment setup, then launches `100M_10B_Market_Cap.py`.

### `clean`

Removes the `.venv/` directory entirely.

## Key Details

- Uses `set -euo pipefail`
- Venv path: `.venv/`
- Requirements file: `requirements.txt`
