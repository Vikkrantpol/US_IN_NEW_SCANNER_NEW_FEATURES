# dashboard.html — SignalScan Pro Dashboard

## Purpose
A single-page dashboard for viewing US and India scan results, comparing them to the most recent prior snapshot, and managing a browser-persistent watchlist.

## Access

```bash
./start_dashboard.sh
# Then open: http://localhost:8000/dashboard.html
```

## Data Loaded by the Dashboard

- Current market file: `scanner_results.json` or `india_results.json`
- Previous comparison file: the newest older snapshot available from:
  - `scanner_results_YYYY-MM-DD.json`, or
  - `india_results_YYYY-MM-DD.json`
- US exchange mapping source: `us_stocks_100m_10b_full.csv` is loaded client-side so TradingView hover charts can use exchange-prefixed US symbols
- Browser-local state: watchlist stored in `localStorage` under `signalscan_watchlist`

## Key Features

### Market toggle

- US mode reads `scanner_results.json` and uses the 0-7 score scale
- India mode reads `india_results.json` and uses the 0-9 score scale

### Filters and controls

| Control | Behavior |
|---------|----------|
| Search | Matches ticker or company name |
| Sector filter | Populated from the loaded results |
| Cap Size | India only: Largecap / Midcap / Smallcap |
| Min score buttons | Filters the visible table rows |
| Signal filter | Filters by signal text |
| Sort | Score, market cap, price, RSI, volume ratio |
| `★ Watchlist (N)` | Shows only watchlisted rows for the active market |

### Persistent watchlist

- Each row has a star toggle before the ticker
- Unstarred rows show `☆`, starred rows show gold `★`
- Market-specific keys are stored as `US:TICKER` or `IN:TICKER`
- Watchlist survives page refreshes, browser restarts, and market toggles

### Stock table

Columns:

- Stock
- Score, including score-delta badge when a prior snapshot exists
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
- India only: market microstructure field

### Sparkline column

- Uses `closes_30d` from the scanner output
- Renders an inline SVG sparkline at `80x24`
- Green when the last close is above the first, red when lower
- Uses a bare polyline plus a last-point dot
- Falls back to a centered `—` when `closes_30d` is missing

### TradingView hover chart

- The ticker cell opens a delayed hover popup after 350ms
- The popup contains a TradingView Advanced Chart widget loaded from `https://s3.tradingview.com/tv.js`
- Popup sizing is fixed at `520x340`
- The widget is created once the popup opens and destroyed when it closes
- India hover symbols use `NSE:TICKER`
- US hover symbols use exchange-prefixed TradingView symbols such as `NASDAQ:AAPL`, `NYSE:XYZ`, or `AMEX:ABC`
- The popup stays open when the cursor moves from the ticker cell into the popup and closes on popup leave or the `✕` button

### Score delta badges

- `NEW` when the ticker did not exist in the prior snapshot
- `↑+N` when the score increased
- `↓-N` when the score decreased
- No badge when unchanged or when no prior snapshot is available

### Table actions

- `Copy Tickers` copies the visible rows in TradingView-friendly format
- `↓ Export CSV` downloads the visible rows only
- Export filename format:
  - `signalscan_US_YYYY-MM-DD.csv`
  - `signalscan_IN_YYYY-MM-DD.csv`

### Detail panel

Clicking a row opens a slide-out panel with:

- score summary
- primary-condition pass/fail status
- technical metrics
- fundamental metrics
- market-specific details
- external links

## Auto-Refresh Behavior

- Polls the active JSON file every 15 seconds
- Handles mid-write JSON gracefully by showing the last good data and retrying in 5 seconds
- Rebuilds the previous-score lookup after each refresh

## Tech Stack

- Single-file HTML, CSS, and vanilla JS
- No external JS libraries beyond TradingView's hosted `tv.js`
- Uses `localStorage`, `fetch()`, inline SVG, TradingView widget embedding, and `Blob` downloads
