# start_dashboard.sh — Dashboard HTTP Server

## Purpose
Launches a Python HTTP server so `dashboard.html` can load the current JSON result files, dated snapshot JSON files, and the US universe CSV used for TradingView symbol mapping.

## Usage

```bash
./start_dashboard.sh
./start_dashboard.sh 3000
```

## What It Does

1. Detects Python (`python3` or `python`)
2. Verifies `dashboard.html` exists in the script directory
3. Starts a local `SimpleHTTPRequestHandler`-based HTTP server from the project directory
4. Sends `no-store` / `no-cache` headers so the browser reloads the latest dashboard JS and JSON
5. Prints the dashboard URL

## Why It's Needed

Browsers block `fetch()` calls to local files. The HTTP server allows the dashboard to load:

- `scanner_results.json`
- `india_results.json`
- dated snapshots such as `scanner_results_YYYY-MM-DD.json`
- dated snapshots such as `india_results_YYYY-MM-DD.json`
- `us_stocks_100m_10b_full.csv`

Those files are used for:

- score-delta badges in the dashboard
- US TradingView hover popup symbol mapping

Note:

- The hover popup also loads TradingView's hosted `tv.js`, so that preview needs normal browser internet access in addition to the local HTTP server.
