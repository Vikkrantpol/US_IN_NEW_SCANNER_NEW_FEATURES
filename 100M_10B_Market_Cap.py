import yfinance as yf
import pandas as pd
import requests
import time
import os

OUTPUT_CSV      = 'us_stocks_100m_10b_full.csv'
SCANNED_LOG     = 'scanned_tickers.txt'   # tracks ALL scanned tickers (fix for resume bug)
CHUNK_SIZE      = 25
DELAY_BETWEEN   = 0.5    # seconds between tickers
CHUNK_PAUSE     = 8      # seconds between chunks
RETRY_DELAY     = 30
MAX_RETRIES     = 3
MIN_CAP         = 100_000_000
MAX_CAP         = 10_000_000_000

# ── Step 1: Get all US tickers ────────────────────────────────────────────
api_headers = {
    'User-Agent': 'Mozilla/5.0',
    'Accept': 'application/json, text/plain, */*',
    'Origin': 'https://www.nasdaq.com',
    'Referer': 'https://www.nasdaq.com/'
}

all_tickers = []
for exchange in ['nasdaq', 'nyse', 'amex']:
    try:
        url = f'https://api.nasdaq.com/api/screener/stocks?tableonly=true&limit=10000&exchange={exchange}'
        r = requests.get(url, headers=api_headers, timeout=15)
        rows = r.json()['data']['table']['rows']
        t = [row['symbol'].strip() for row in rows if row.get('symbol')]
        t = [x for x in t if all(c not in x for c in ['^', '/', '+', ' ', '~'])]
        all_tickers.extend(t)
        print(f"✅ {exchange.upper()}: {len(t)} tickers")
    except Exception as e:
        print(f"❌ {exchange.upper()} failed: {e}")

all_tickers = sorted(set(all_tickers))
print(f"\n📊 Total unique tickers: {len(all_tickers)}")

# ── Step 2: Load scanned log (tracks ALL previously scanned tickers) ──────
# This fixes the resume bug — we log every ticker we touch, not just qualifiers
if os.path.exists(SCANNED_LOG):
    with open(SCANNED_LOG, 'r') as f:
        scanned_tickers = set(f.read().splitlines())
    print(f"🔁 Resuming — {len(scanned_tickers)} already scanned, skipping them")
else:
    scanned_tickers = set()

# Load existing results if any
if os.path.exists(OUTPUT_CSV):
    done_df = pd.read_csv(OUTPUT_CSV)
    print(f"📂 Loaded {len(done_df)} existing qualifying stocks from CSV")
else:
    done_df = pd.DataFrame()

remaining = [t for t in all_tickers if t not in scanned_tickers]
chunks = [remaining[i:i+CHUNK_SIZE] for i in range(0, len(remaining), CHUNK_SIZE)]
print(f"⏳ Tickers remaining: {len(remaining)} across {len(chunks)} chunks\n")

# ── Step 3: Scan in chunks ────────────────────────────────────────────────
for chunk_num, chunk in enumerate(chunks):
    chunk_results = []
    print(f"=== Chunk {chunk_num+1}/{len(chunks)} ===")

    for ticker in chunk:
        retries = 0
        while retries <= MAX_RETRIES:
            try:
                # fast_info first — lightweight, no full API call
                fast = yf.Ticker(ticker).fast_info
                market_cap = getattr(fast, 'market_cap', None)

                if market_cap and MIN_CAP <= market_cap <= MAX_CAP:
                    # Only fetch full info for qualifying stocks
                    info = yf.Ticker(ticker).info
                    chunk_results.append({
                        'Ticker':         ticker,
                        'Company Name':   info.get('longName') or info.get('shortName') or ticker,
                        'Exchange':       info.get('exchange', 'N/A'),
                        'Sector':         info.get('sector', 'N/A'),
                        'Industry':       info.get('industry', 'N/A'),
                        'Market Cap (USD)': market_cap,
                        'Market Cap (B)': round(market_cap / 1e9, 3),
                        'Country':        info.get('country', 'N/A'),
                        'PE Ratio':       info.get('trailingPE', 'N/A'),
                        'Forward PE':     info.get('forwardPE', 'N/A'),
                        'EPS (TTM)':      info.get('trailingEps', 'N/A'),
                        'Revenue (B)':    round(info.get('totalRevenue', 0) / 1e9, 3) if info.get('totalRevenue') else 'N/A',
                        'Profit Margin':  info.get('profitMargins', 'N/A'),
                        'Dividend Yield': info.get('dividendYield', 'N/A'),
                        '52W High':       info.get('fiftyTwoWeekHigh', 'N/A'),
                        '52W Low':        info.get('fiftyTwoWeekLow', 'N/A'),
                        'Beta':           info.get('beta', 'N/A'),
                    })
                    print(f"  ✓ {ticker}: ${market_cap/1e9:.3f}B")
                else:
                    cap_str = f"${market_cap/1e9:.2f}B" if market_cap else "no data"
                    print(f"  - {ticker}: {cap_str}")

                # Mark as scanned regardless of qualifying
                scanned_tickers.add(ticker)
                with open(SCANNED_LOG, 'a') as f:
                    f.write(ticker + '\n')
                break

            except Exception as e:
                if 'Too Many Requests' in str(e) or '429' in str(e):
                    retries += 1
                    print(f"  ⚠ {ticker}: Rate limited. Waiting {RETRY_DELAY}s (retry {retries}/{MAX_RETRIES})...")
                    time.sleep(RETRY_DELAY)
                else:
                    print(f"  ✗ {ticker}: {e}")
                    scanned_tickers.add(ticker)
                    with open(SCANNED_LOG, 'a') as f:
                        f.write(ticker + '\n')
                    break

        time.sleep(DELAY_BETWEEN)

    # Append chunk results and save incrementally
    if chunk_results:
        chunk_df = pd.DataFrame(chunk_results)
        done_df = pd.concat([done_df, chunk_df], ignore_index=True)

    done_df.sort_values('Market Cap (USD)', ascending=True, inplace=True)  # ✅ ascending
    done_df.to_csv(OUTPUT_CSV, index=False)
    print(f"  >> Saved {len(done_df)} qualifying stocks so far")

    if chunk_num < len(chunks) - 1:
        print(f"  💤 Sleeping {CHUNK_PAUSE}s before next chunk...\n")
        time.sleep(CHUNK_PAUSE)

# ── Step 4: Final save with rank and download ─────────────────────────────
done_df.reset_index(drop=True, inplace=True)
done_df.insert(0, 'Rank', done_df.index + 1)
done_df.to_csv(OUTPUT_CSV, index=False)

print(f"\n🎉 DONE! {len(done_df)} stocks ($100M–$10B) saved to {OUTPUT_CSV}")
print(done_df[['Rank','Ticker','Company Name','Market Cap (B)','Sector']].head(10).to_string(index=False))