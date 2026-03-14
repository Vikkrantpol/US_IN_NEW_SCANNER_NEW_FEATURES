# Launcher Command Reference

## Purpose

This document explains the current shell commands for:

- `./start_scan.sh` for the US market
- `./India_scan.sh` for the India market

It focuses on what each command does, when to use it, and what gets written to the databases.

## Core Storage Model

Two SQLite databases are used by the launcher commands:

- `scan_state.db`
  Resettable working state used for resume logic, latest scan state, and run continuity.
- `scan_mega_history.db`
  Permanent archive used for scan history and generated artifacts like `diff`, `report`, `doctor`, `export`, and `compare-markets`.

Inside `scan_mega_history.db`, command outputs now also go into market-specific archive tables:

- `us_command_archive`
- `india_command_archive`
- `cross_market_command_archive`

Dedicated normalized history tables are also maintained for date-based tracking:

- `us_report_history`
- `india_report_history`
- `us_sector_report_history`
- `india_sector_report_history`

General rule:

- `run` updates working state
- `fresh` clears only that market's working state
- archive history is preserved in `scan_mega_history.db`

## Shared Commands

These commands are available in both launchers unless noted otherwise.

### `run`

Example:

```bash
./start_scan.sh run
./India_scan.sh run
```

What it does:

- runs the scanner in resume/incremental mode
- uses `scan_state.db` to decide what needs rescanning
- updates live result JSON files
- appends scan events to `scan_mega_history.db`

Use case:

- your normal day-to-day scan command

### `fresh`

Example:

```bash
./start_scan.sh fresh
./India_scan.sh fresh
```

What it does:

- clears only that market's rows from `scan_state.db`
- deletes that market's live JSON files and legacy text log
- starts a clean working scan
- does not delete `scan_mega_history.db`

Use case:

- after major logic changes
- when you want a full rebuild of the current market output

### `summary`

Example:

```bash
./start_scan.sh summary
./India_scan.sh summary
```

What it does:

- prints the top ranked names from the latest scan in a terminal table

Use case:

- quick review of the latest strongest names without opening the dashboard

### `history`

Example:

```bash
./start_scan.sh history
./India_scan.sh history
```

What it does:

- reads archived scan history from `scan_mega_history.db`
- shows runs, events, snapshots, and most-scanned tickers

Use case:

- understand scan activity over time

### `artifact-history [artifact_type]`

Example:

```bash
./start_scan.sh artifact-history
./start_scan.sh artifact-history report
./India_scan.sh artifact-history
./India_scan.sh artifact-history diff
```

What it does:

- reads generated artifacts from `scan_mega_history.db`
- shows grouped counts by artifact type
- shows the most recent stored artifacts in a classic table
- optional filter by artifact type

Stored artifact types can include:

- `diff`
- `report`
- `artifact-history`
- `ticker-history`
- `leaderboard`
- `sector-history`
- `sector-report`
- `new-highs`
- `compare-markets`
- `doctor`
- `export`

Use case:

- review what was generated recently
- audit reports and comparisons without rerunning commands blindly

### `archive-query [command_name] [search_text]`

Example:

```bash
./start_scan.sh archive-query
./start_scan.sh archive-query summary
./start_scan.sh archive-query ticker-history NVDA
./India_scan.sh archive-query
./India_scan.sh archive-query summary Smallcap
./India_scan.sh archive-query sector-report Industrials
```

What it does:

- queries archived command-output rows directly from the market-specific archive tables
- supports optional command filtering
- supports optional text search across note, source, entity, and payload
- shows the matching rows in a terminal table

Use case:

- search old archived outputs without opening SQLite manually
- find past `summary`, `ticker-history`, `sector-report`, or `doctor` runs quickly

### `ticker-history <symbol>`

Example:

```bash
./start_scan.sh ticker-history NVDA
./India_scan.sh ticker-history DATAPATTNS
```

What it does:

- shows one symbol's archived score history
- shows latest profile details
- shows recent scan events, score progression, failed conditions, and signals

Use case:

- review conviction over time for one name
- check whether a stock has been improving, weakening, or repeatedly qualifying

### `leaderboard`

Example:

```bash
./start_scan.sh leaderboard
./India_scan.sh leaderboard
```

What it does:

- shows current leaders from latest results
- shows most consistent historical leaders
- shows most frequent `score >= 5` names
- shows most frequent high-proximity momentum names

Use case:

- identify durable repeat performers, not just today's top table

### `sector-report [sector_name]`

Example:

```bash
./start_scan.sh sector-report
./start_scan.sh sector-report Technology
./start_scan.sh sector-report export csv Technology
./India_scan.sh sector-report
./India_scan.sh sector-report Industrials
./India_scan.sh sector-report export .md Industrials
```

What it does:

- prints a sector summary table from the latest scan
- if a sector name is provided, also prints a ranked table for that sector only
- if `export` is added, exports that sector view in `csv`, `md`, or `both`

Use case:

- review sector rotation
- isolate all names in one hot sector

### `sector-history [sector_name]`

Example:

```bash
./start_scan.sh sector-history
./start_scan.sh sector-history Energy
./start_scan.sh sector-history export csv Energy
./India_scan.sh sector-history
./India_scan.sh sector-history Industrials
./India_scan.sh sector-history export .md Industrials
```

What it does:

- reads the normalized sector history tables from `scan_mega_history.db`
- without a sector filter, shows the latest sector snapshot with deltas vs the previous scan
- with a sector filter, shows that sector's history across archived scan dates
- if `export` is added, exports that sector-history view in `csv`, `md`, or `both`

Use case:

- track sectoral moves over dates
- see whether one sector is strengthening or losing breadth

### `sector report ...` and `sector history ...`

Example:

```bash
./start_scan.sh sector report Software
./start_scan.sh sector report export md Software
./start_scan.sh sector history Energy
./India_scan.sh sector report Industrials
./India_scan.sh sector history export csv Industrials
```

What it does:

- provides a more natural alias syntax for `sector-report` and `sector-history`
- keeps the same output and archive behavior

Use case:

- comfortable command entry when working directly in terminal

### `new-highs`

Example:

```bash
./start_scan.sh new-highs
./India_scan.sh new-highs
```

What it does:

- filters latest results to only names matching the high-proximity momentum view
- prints a sector breakdown and ranked table

Use case:

- breakout review
- high-strength watchlist generation

### `compare-markets`

Example:

```bash
./start_scan.sh compare-markets
./start_scan.sh us compare markets
./India_scan.sh compare-markets
./India_scan.sh india compare markets
```

What it does:

- loads the latest US and India results together
- shows market-level comparison metrics
- shows top sectors and top ranked names for both markets
- stores the output as a shared archive artifact

Use case:

- compare breadth and strength between US and India quickly

### `daily`

Example:

```bash
./start_scan.sh daily
./start_scan.sh us daily scan
./India_scan.sh daily
./India_scan.sh india daily scan
```

What it does from the US launcher:

- runs US scan
- runs India scan
- generates and stores fresh reports and diffs for both markets
- prints cross-market comparison
- auto-exports a timestamped workflow bundle under `exports/workflows/...`

What it does from the India launcher:

- runs India scan
- runs US scan
- generates and stores fresh reports and diffs for both markets
- prints cross-market comparison
- auto-exports a timestamped workflow bundle under `exports/workflows/...`

Use case:

- one-command full workflow for the trading day

### `daily full`

Example:

```bash
./start_scan.sh daily full
./start_scan.sh daily-full
./start_scan.sh us daily full
./India_scan.sh daily full
./India_scan.sh daily-full
./India_scan.sh india daily full
```

What it does:

- runs the home market scan
- runs the other market scan in normal `run` mode
- runs `doctor` for both markets
- runs `report`, `diff`, `sector-report`, `sector-history`, and `new-highs` for both markets
- runs India `smallcap`, `midcap`, and `largecap` top tables
- runs `compare-markets`
- auto-exports a timestamped workflow bundle under `exports/workflows/...`

Use case:

- one-command full daily review when you want both scan execution and analytics in a single pass

### `doctor`

Example:

```bash
./start_scan.sh doctor
./India_scan.sh doctor
```

What it does:

- checks scanner file presence
- checks venv path
- checks result JSON freshness
- checks snapshot availability
- checks whether a diff baseline exists
- checks `scan_state.db`
- checks `scan_mega_history.db`

Use case:

- environment health check
- find out why a command is empty or why diff is not yet meaningful

### `export`

Example:

```bash
./start_scan.sh export
./start_scan.sh export csv
./India_scan.sh export
./India_scan.sh export .md
```

What it does:

- exports the latest market view to `csv`, `md`, or `both`
- stores export metadata in `scan_mega_history.db`
- works together with sector-specific export paths:
  - `sector-report export`
  - `sector-history export`

Supported examples:

```bash
./start_scan.sh export csv
./start_scan.sh sector-report export md Technology
./start_scan.sh sector history export csv Energy
./India_scan.sh export both
./India_scan.sh sector-report export csv Industrials
./India_scan.sh sector history export .md Industrials
```

What gets exported:

- `market`: full latest market result set
- `sector-report`: latest sector summary, or one sector's ranked stock table
- `sector-history`: latest sector delta snapshot, or one sector's archived date-series table

Output formats:

- `csv`
- `md`
- `both`

Output folders:

- `exports/us`
- `exports/in`

Use case:

- save a dated offline copy of the latest scan
- export sector analysis directly from terminal
- review sector history outside the dashboard
- share clean CSV/Markdown outputs

### `diff`

Example:

```bash
./start_scan.sh diff
./India_scan.sh diff
```

What it does:

- compares latest results against the newest older dated snapshot
- shows `new`, `upgrades`, `downgrades`, and `dropped`
- stores the diff output in `scan_mega_history.db`

Important note:

- if there is no older snapshot yet, the command works but shows no baseline

Use case:

- identify what changed since the previous scan day

### `report`

Example:

```bash
./start_scan.sh report
./India_scan.sh report
```

What it does:

- prints score distribution
- prints signal counts
- prints sector leaders
- prints top ranked names
- stores the report in `scan_mega_history.db`

Use case:

- generate a richer market snapshot than `summary`

### `help`

Example:

```bash
./start_scan.sh help
./India_scan.sh help
```

What it does:

- shows the launcher banner
- shows available commands
- shows short command examples

Use case:

- command discovery

## US-Only Commands

### `download`

Example:

```bash
./start_scan.sh download
```

What it does:

- prepares the US environment
- runs `100M_10B_Market_Cap.py`
- refreshes the US stock universe source file

Use case:

- refresh the US universe before scanning

### `clean`

Example:

```bash
./start_scan.sh clean
```

What it does:

- removes the US `.venv` directory

Use case:

- rebuild a broken or outdated US environment

## India-Only Commands

### `smallcap`

Example:

```bash
./India_scan.sh smallcap
```

What it does:

- shows only `Smallcap` India names from the latest scan
- sorts by descending score
- prints the colored India table view

Use case:

- isolate smallcap momentum setups

### `midcap`

Example:

```bash
./India_scan.sh midcap
```

What it does:

- shows only `Midcap` India names from the latest scan

Use case:

- isolate midcap setups

### `largecap`

Example:

```bash
./India_scan.sh largecap
```

What it does:

- shows only `Largecap` India names from the latest scan

Use case:

- isolate institutional largecap strength

## Which Command To Use

If you want a normal scan:

- use `run`

If you want a clean rebuild:

- use `fresh`

If you want latest top names:

- use `summary`

If you want one stock's full archive trail:

- use `ticker-history`

If you want the strongest historical names:

- use `leaderboard`

If you want sector-level analysis:

- use `sector-report`

If you want sector rotation over dates:

- use `sector-history`

If you want breakout-style names:

- use `new-highs`

If you want cross-market perspective:

- use `compare-markets`

If you want a full daily routine:

- use `daily`

If you want a setup/data health check:

- use `doctor`

If you want exported files:

- use `export`

## Artifact Archiving

The following command outputs are archived into `scan_mega_history.db`:

- `summary`
- `history`
- `diff`
- `report`
- `artifact-history`
- `ticker-history`
- `leaderboard`
- `sector-history`
- `sector-report`
- `new-highs`
- `compare-markets`
- `doctor`
- `export`

This means the system now stores not just raw scan results, but also the higher-level analysis outputs generated from them.

## Dedicated History Tables

### Report History Tables

- `us_report_history`
- `india_report_history`

Each archived `report` command writes one normalized row into the market-specific report history table.

Stored fields include:

- `generated_at`
- `scan_generated_at`
- `total_scanned`
- `total_results`
- `avg_score`
- `top_score`
- `score_distribution_json`
- `signal_summary_json`
- `sector_leaders_json`

Use case:

- compare full-market report strength across dates

### Sector Report History Tables

- `us_sector_report_history`
- `india_sector_report_history`

Each archived `sector-report` command writes one row per sector into the market-specific sector history table.

Stored fields include:

- `generated_at`
- `scan_generated_at`
- `requested_sector`
- `sector`
- `sector_rank`
- `sector_count`
- `avg_score`
- `best_score`
- `near_high_count`
- `avg_turnover`
- `leader`

Use case:

- track sector rotation over time
- compare how one sector's breadth and quality changed across scan dates
