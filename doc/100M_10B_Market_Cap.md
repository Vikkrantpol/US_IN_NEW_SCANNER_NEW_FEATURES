# 100M_10B_Market_Cap.py — US Market Cap Downloader

## Purpose
Downloads a comprehensive list of **US stocks with market caps between $100M and $10B** from NASDAQ, NYSE, and AMEX exchanges. This CSV is used as the input universe for `scanner.py`.

## Input / Output

| Item | Source / File | Format |
|------|---------------|--------|
| **Input** | NASDAQ Screener API (all 3 exchanges) | JSON via HTTP |
| **Output** | `us_stocks_100m_10b_full.csv` | CSV with rank, fundamentals |
| **Resume log** | `scanned_tickers.txt` | Tracks all scanned tickers |

## How It Works

### Step 1 — Fetch All US Tickers
- Hits `api.nasdaq.com/api/screener/stocks` for NASDAQ, NYSE, and AMEX
- Filters out special symbols (containing `^`, `/`, `+`, ` `, `~`)
- De-duplicates and sorts alphabetically

### Step 2 — Resume Support
- Reads `scanned_tickers.txt` to skip previously scanned tickers
- Loads existing `us_stocks_100m_10b_full.csv` to append new results

### Step 3 — Scan Market Caps
For each ticker:
1. Uses `yf.Ticker(t).fast_info` (lightweight) to check market cap
2. If cap is within $100M–$10B range → fetches full `.info` for details
3. Stores: ticker, name, exchange, sector, industry, market cap, PE, EPS, revenue, margin, beta, 52W high/low

### Step 4 — Final Save
- Sorts by market cap ascending
- Adds a `Rank` column
- Saves to CSV

## Rate-Limit Handling

| Parameter | Value |
|-----------|-------|
| Chunk size | 25 tickers |
| Delay between tickers | 0.5s |
| Chunk pause | 8s |
| Retry on 429 | up to 3 retries, 30s backoff |

## Output CSV Columns

```
Rank, Ticker, Company Name, Exchange, Sector, Industry,
Market Cap (USD), Market Cap (B), Country, PE Ratio,
Forward PE, EPS (TTM), Revenue (B), Profit Margin,
Dividend Yield, 52W High, 52W Low, Beta
```
