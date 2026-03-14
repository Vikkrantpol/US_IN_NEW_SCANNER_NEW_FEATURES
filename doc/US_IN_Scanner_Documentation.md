# US & India Stock Scanner — Complete Documentation

SignalScan Pro is a dual-market stock scanning system with threaded scanners, incremental daily re-scanning, dated snapshots, and a browser dashboard for review and export.

---

## 1. Project Overview

The project scans two universes:

| Market | Universe | Score Range | Extras |
|--------|----------|-------------|--------|
| US | US stocks filtered to roughly $100M-$10B market cap | 0-7 | CSV-backed static data |
| India | NSE-listed equities | 0-9 | Market microstructure signals, circuit detection, cap category |

Runtime flow:

1. Build or fetch the market universe
2. Scan in threaded chunks
3. Save current results and daily snapshots
4. View, filter, compare, watchlist, copy, or export in the dashboard

---

## 2. File Structure

```text
US_IN_New_Scanner/
├── 100M_10B_Market_Cap.py
├── scanner.py
├── india_scanner.py
├── dashboard.html
├── start_scan.sh
├── India_scan.sh
├── start_dashboard.sh
├── requirements.txt
├── us_stocks_100m_10b_full.csv
├── scanner_results.json
├── scanner_results_YYYY-MM-DD.json
├── scan_state.db
├── scan_mega_history.db
├── india_results.json
├── india_results_YYYY-MM-DD.json
├── scanner_scanned.txt
├── india_scanned.txt
├── scanned_tickers.txt
└── doc/
```

Notes:

- `scanner_results.json` and `india_results.json` are the live result files
- dated snapshot JSONs are created after each full scan and retained for the latest 7 scan dates
- `scan_state.db` stores resettable working state, run metadata, and snapshot metadata for resume/update logic
- `scan_mega_history.db` stores a permanent archive of all scan events across fresh resets
- `scanner_scanned.txt` and `india_scanned.txt` are legacy logs imported into SQLite on first run

---

## 3. Data Sources

| Source | Used By | Purpose |
|--------|---------|---------|
| NASDAQ screener API | `100M_10B_Market_Cap.py` | US ticker universe download |
| `yfinance` | downloader + both scanners | OHLCV, fundamentals, market cap |
| NSE equity CSV | `india_scanner.py` | India symbol universe |
| NSE quote API | `india_scanner.py` | Delivery % |
| Fyers API | `india_scanner.py` | India OHLCV and circuit limits when configured |

---

## 4. US Scanner Pipeline

`100M_10B_Market_Cap.py`:

- downloads US tickers from NASDAQ
- checks market cap with `yfinance`
- stores qualifying names, sector, valuation, and 52-week fields in `us_stocks_100m_10b_full.csv`

`scanner.py`:

1. Loads the US CSV
2. Loads US state from `scan_state.db`
3. Decides what to rescan using the incremental rules
4. Splits work into chunks of 20
5. Runs each chunk with `ThreadPoolExecutor(max_workers=4)`
6. For each ticker:
   - reads static fields from CSV
   - fetches 2 years of OHLCV from `yfinance`
   - applies the 5 primary gates
   - computes the 0-7 score
   - stores `closes_30d` for dashboard sparklines
7. Writes `scanner_results.json` atomically after each chunk
8. Writes `scanner_results_YYYY-MM-DD.json` after the full run and prunes snapshots older than the latest 7 dates

---

## 5. India Scanner Pipeline

`india_scanner.py`:

1. Loads the NSE symbol list, with Nifty 500 fallback
2. Initializes Fyers when credentials are available
3. Loads India state from `scan_state.db`
4. Decides what to rescan using the same incremental rules
5. Splits work into chunks of 15
6. Runs each chunk with `ThreadPoolExecutor(max_workers=4)`
7. For each symbol:
   - fetches OHLCV from Fyers or yfinance fallback
   - applies the 5 primary gates
   - computes the 0-9 score
   - stores `closes_30d` for dashboard sparklines
8. Writes `india_results.json` atomically after each chunk
9. Writes `india_results_YYYY-MM-DD.json` after the full run and keeps the latest 7 dates

India-specific scoring extras:

- near upper circuit
- delivery %
- cap category

---

## 6. Primary Conditions and Scoring

Exact runtime thresholds are sourced from a local secure conditions file and are intentionally omitted from tracked documentation.

### Primary gates

| Gate | US | India |
|------|----|-------|
| P1 | Price-strength gate | Same category, market-specific threshold |
| P2 | Short-trend gate | Same category, market-specific threshold |
| P3 | Medium-trend gate | Same category, market-specific threshold |
| P4 | Long-trend gate | Same category, market-specific threshold |
| P5 | Liquidity gate | Same category, market-specific threshold |

### Scoring signals

| Signal | US | India |
|--------|----|-------|
| High-proximity momentum signal | Yes | Yes |
| Short-trend confirmation | Yes | Yes |
| Medium-trend confirmation | Yes | Yes |
| Long-trend confirmation | Yes | Yes |
| Activity-expansion signal | Yes | Yes |
| Live-limit proximity signal | No | Yes |
| Delivery-strength signal | No | Yes |
| Earnings-growth signal | Yes | Yes |
| Revenue-growth signal | Yes | Yes |

---

## 7. Incremental Re-Scan and Persistence

State is now persisted in SQLite:

- `latest_scan_state` keeps the newest state per market+ticker
- `scan_history` keeps every scan event
- `scan_runs` tracks run start/end metadata
- `scan_snapshots` records dated snapshot files

A ticker or symbol is re-scanned if any of the following are true:

- it has never been scanned
- its previous score was 3 or higher
- it failed exactly one primary condition
- its last scan date is more than 3 days old

It is skipped only when both are true:

- it failed 2 or more primary conditions
- it was scanned within the last 3 days

Other persistence rules:

- per-chunk JSON writes remain atomic
- each completed full scan creates a dated snapshot copy
- only the latest 7 dated snapshots are retained
- existing result rows are replaced on re-scan so the live JSON stays current

---

## 8. Dashboard

`dashboard.html` reads the current market JSON, then looks for the newest older snapshot available to calculate score deltas.

### Main capabilities

- market toggle between US and India
- auto-refresh every 15 seconds
- watchlist stored in `localStorage` as `signalscan_watchlist`
- market-scoped watchlist keys such as `US:AAPL` and `IN:RELIANCE`
- watchlist-only filter button with live count
- sparkline column rendered from `closes_30d`
- TradingView hover popup on the ticker cell
- score delta badges: `NEW`, `↑+N`, `↓-N`
- `Copy Tickers` for visible rows
- `↓ Export CSV` for visible rows only

### Table columns

US:

- Stock
- Score + delta
- Chart
- Signals
- Price
- Market Cap
- PE
- Margin
- Vol Ratio
- RSI
- Avg Turnover
- Sector

India adds:

- market microstructure fields

### Hover chart behavior

- The ticker cell opens a floating TradingView preview after a short hover delay
- India preview symbols use `NSE:TICKER`
- US preview symbols use exchange-prefixed symbols such as `NASDAQ:AAPL`, sourced from `us_stocks_100m_10b_full.csv`
- The popup is a single reusable widget container that is destroyed and recreated per hovered stock
- The popup remains open when moving from the ticker cell into the popup and closes on popup leave or the close button

### CSV export

Downloaded filename:

- `signalscan_US_YYYY-MM-DD.csv`
- `signalscan_IN_YYYY-MM-DD.csv`

Columns exported:

- Ticker
- Name
- Score
- Signals
- Price
- MarketCap
- PE
- Margin
- VolRatio
- RSI
- AvgTurnover
- Sector
- India only: `Delivery%`, `CapCategory`

---

## 9. Shell Launchers

### `start_scan.sh`

```bash
./start_scan.sh run
./start_scan.sh fresh
./start_scan.sh history
./start_scan.sh download
./start_scan.sh clean
./start_scan.sh help
```

### `India_scan.sh`

```bash
./India_scan.sh run
./India_scan.sh fresh
./India_scan.sh history
./India_scan.sh help
```

### `start_dashboard.sh`

```bash
./start_dashboard.sh
./start_dashboard.sh 3000
```

The dashboard must be served over HTTP because the browser fetches both live JSON files and dated snapshot JSON files.

---

## 10. Resilience Summary

- threaded chunk processing with 4 workers
- lock-protected shared result and scan-history state
- per-ticker retry handling preserved in worker threads
- atomic chunk saves
- snapshot retention
- dashboard recovery when JSON is temporarily mid-write

---

## 11. Quick Start

```bash
# 1. Build or refresh the US universe
./start_scan.sh download

# 2. Run the US scanner
./start_scan.sh run

# 3. Run the India scanner
./India_scan.sh run

# 4. Start the dashboard server
./start_dashboard.sh
```

Then open `http://localhost:8000/dashboard.html`.

The dashboard will use the live JSON for the active market, previous snapshots for score deltas, and browser local storage for the watchlist.

---

Generated on 2026-03-07 for the current project state.
