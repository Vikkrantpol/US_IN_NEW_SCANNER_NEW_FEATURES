# scanner.py — US Stock Momentum + Fundamental Scanner (v3)

## Purpose
Scans the pre-downloaded US stock universe against 5 qualification gates and assigns a 0-7 momentum + fundamental score. Exact gate thresholds and scoring floors are loaded from a local secure conditions file and are intentionally omitted from tracked documentation.

## Input / Output

| Item | File | Notes |
|------|------|-------|
| Input universe | `us_stocks_100m_10b_full.csv` | Static ticker, sector, valuation, and 52-week data |
| Current output | `scanner_results.json` | Atomically refreshed after every chunk |
| Daily snapshots | `scanner_results_YYYY-MM-DD.json` | Written after a full scan completes; last 7 kept |
| Working state | `scan_state.db` | SQLite-backed latest state used for resume/update logic |
| Archive history | `scan_mega_history.db` | Permanent archive of all US scan events across fresh resets |

### Scan state schema

- `latest_scan_state` stores the newest US state per ticker
- `scan_history` stores every recorded US scan event
- `scan_runs` stores run start/end metadata
- `scan_snapshots` stores snapshot file metadata

## Execution Model

- Chunk size: 20 tickers
- Parallelism: `ThreadPoolExecutor(max_workers=4)` inside each chunk
- Shared state safety: `results` and `scanned` are guarded by `threading.Lock()`
- Per-ticker retry logic remains local to each worker thread
- Chunk pause and atomic JSON save behavior are unchanged

## Incremental Re-Scan Rules

A ticker is re-scanned if any of the following are true:

- It has never been scanned before
- Its last score was 3 or higher
- It failed exactly one primary condition last time
- Its last scan date is more than 3 days old

A ticker is skipped only when both are true:

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

## Scoring Signals (0-7)

Technical:

- T1: Configured high-proximity signal
- T2: Configured short-trend confirmation
- T3: Configured medium-trend confirmation
- T4: Configured long-trend confirmation
- T5: Configured activity-expansion signal

Fundamental:

- F1: Configured earnings-growth signal
- F2: Configured revenue-growth signal

## Data Sources

| Data | Source |
|------|--------|
| Name, sector, PE, margin, beta, 52-week range | CSV |
| 2 years of daily OHLCV | `yfinance.history()` |
| EPS growth / revenue growth | `yfinance.info` |

## Persistence and Resilience

- SQLite-backed resume state and scan history in `scan_state.db`
- Atomic save after each chunk via `.tmp` + `os.replace()`
- Daily snapshot copy after the final chunk, with 7-file retention
- Rate-limit handling: 3 retries on 429-style failures with 30s backoff
- Existing result rows are replaced in memory on re-scan so JSON stays current

## Key Functions

| Function | Description |
|----------|-------------|
| `score_ticker(ticker)` | Fetches data, applies the 5 gates, computes the score, and adds `closes_30d` |
| `process_ticker(ticker)` | Per-thread wrapper that preserves retry and error handling |
| `should_rescan(entry)` | Implements the incremental daily re-scan rules |
| `save_daily_snapshot(output_json)` | Writes dated result snapshots and prunes old ones |
| `clean_for_json(obj)` | Replaces NaN/Inf with `null`-safe values |

## Output JSON Schema

```json
{
  "generated_at": "2026-03-07 10:00:00",
  "total_scanned": 1500,
  "total_results": 120,
  "market": "US",
  "stocks": [
    {
      "ticker": "AAPL",
      "name": "Apple Inc.",
      "sector": "Technology",
      "industry": "Consumer Electronics",
      "price": 182.5,
      "closes_30d": [176.2, 177.8, 179.1],
      "market_cap_b": 2.85,
      "pe": 28.5,
      "score": 6,
      "max_score": 7,
      "primary_checks": { "P1": true, "P2": true, "P3": true, "P4": true, "P5": true },
      "signals": ["<runtime signal labels omitted from tracked docs>"],
      "details": { "RSI": 62.4, "...": "..." },
      "market": "US",
      "currency": "$",
      "scanned_at": "2026-03-07 10:00"
    }
  ]
}
```
