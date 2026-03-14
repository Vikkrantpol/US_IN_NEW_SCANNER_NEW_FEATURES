# india_scanner.py — India Pro Stock Scanner (NSE)

## Purpose
Scans NSE-listed Indian equities against 5 qualification gates and assigns a 0-9 momentum + fundamental score. Exact gate thresholds and scoring floors are loaded from a local secure conditions file and are intentionally omitted from tracked documentation. It prefers Fyers for market data when configured and falls back to yfinance when needed.

## Input / Output

| Item | File / Source | Notes |
|------|---------------|-------|
| Input universe | NSE equity list | Fetched live from `nsearchives.nseindia.com` |
| Fallback universe | Nifty 500 list | Used if the main NSE list fetch fails |
| Current output | `india_results.json` | Atomically refreshed after every chunk |
| Daily snapshots | `india_results_YYYY-MM-DD.json` | Written after a full scan completes; last 7 kept |
| Working state | `scan_state.db` | SQLite-backed latest state used for resume/update logic |
| Archive history | `scan_mega_history.db` | Permanent archive of all India scan events across fresh resets |

### Scan state schema

- `latest_scan_state` stores the newest India state per symbol
- `scan_history` stores every recorded India scan event
- `scan_runs` stores run start/end metadata
- `scan_snapshots` stores snapshot file metadata

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `FYERS_CLIENT_ID` | `YOUR_CLIENT_ID-100` | Fyers client ID |
| `FYERS_ACCESS_TOKEN` | `YOUR_ACCESS_TOKEN` | Fyers access token |
| `SCAN_CONDITIONS_FILE` | unset | Optional override path for the local secure conditions file |
| `CHUNK_SIZE` | 15 | Symbols per chunk |
| `MAX_WORKERS` | 4 | Threads per chunk |

## Execution Model

- Chunk size: 15 symbols
- Parallelism: `ThreadPoolExecutor(max_workers=4)` inside each chunk
- Shared `results` and `scanned` collections are lock-protected
- Per-symbol retry logic and completion-time printing remain per worker
- Atomic per-chunk JSON save and chunk sleep behavior are unchanged

## Incremental Re-Scan Rules

A symbol is re-scanned if any of the following are true:

- It has never been scanned before
- Its previous score was 3 or higher
- It failed exactly one primary condition last time
- Its last scan date is more than 3 days old

A symbol is skipped only when both are true:

- It failed 2 or more primary conditions last time
- It was scanned within the last 3 days

## Qualification Gates (all 5 must pass)

| # | Condition | Threshold |
|---|-----------|-----------|
| P1 | Price-strength gate | Runtime threshold loaded from the local secure conditions file |
| P2 | Short-trend gate | Runtime threshold loaded from the local secure conditions file |
| P3 | Medium-trend gate | Runtime threshold loaded from the local secure conditions file |
| P4 | Long-trend gate | Runtime threshold loaded from the local secure conditions file |
| P5 | Liquidity gate | Runtime threshold loaded from the local secure conditions file |

## Scoring Signals (0-9)

Technical:

- T1: Configured high-proximity signal
- T2: Configured short-trend confirmation
- T3: Configured medium-trend confirmation
- T4: Configured long-trend confirmation
- T5: Configured activity-expansion signal
- T6: Configured live-limit proximity signal (Fyers only)
- T7: Configured delivery-strength signal (NSE API)

Fundamental:

- F1: Configured earnings-growth signal
- F2: Configured revenue-growth signal

## Data Source Hierarchy

| Data | Primary Source | Fallback |
|------|---------------|----------|
| Daily OHLCV | Fyers history API | yfinance (`.NS`) |
| Circuit limits | Fyers quotes API | Not available |
| Delivery % | NSE quote-equity API | Not available |
| Fundamentals | yfinance `.info` | None |
| Symbol list | NSE equity CSV | Nifty 500 CSV |

## Persistence and Resilience

- SQLite-backed resume state and scan history in `scan_state.db`
- Atomic save after each chunk via `.tmp` + `os.replace()`
- Daily snapshot copy after the final chunk, with 7-file retention
- Up to 3 retries on rate-limit style failures
- Existing result rows are replaced in memory on re-scan

## Key Functions

| Function | Description |
|----------|-------------|
| `score_ticker(symbol)` | Core scoring logic; adds `closes_30d` to qualifying results |
| `process_ticker(symbol)` | Per-thread wrapper around retry, printing, and scan-history updates |
| `should_rescan(entry)` | Implements the incremental daily re-scan rules |
| `save_daily_snapshot(output_json)` | Writes dated result snapshots and prunes older files |
| `fetch_delivery_nse(symbol)` | Pulls delivery % from NSE trade info |

## India-Specific Output Fields

```json
{
  "ticker": "RELIANCE",
  "closes_30d": [2894.1, 2908.7, 2921.0],
  "market_cap_cr": 5200.5,
  "cap_category": "Midcap",
  "avg_turnover_cr": 85.3,
  "details": {
    "Upper Circuit": 1250.0,
    "% To Circuit": 2.1,
    "Delivery %": "62.3%"
  },
  "market": "IN",
  "currency": "₹"
}
```

Cap categories:

- Smallcap: below ₹5,000Cr
- Midcap: ₹5,000Cr to below ₹20,000Cr
- Largecap: ₹20,000Cr and above
