# requirements.txt — Python Dependencies

## Packages

| Package | Purpose |
|---------|---------|
| `yfinance` | Yahoo Finance API — OHLCV history, stock info, fundamentals |
| `pandas` | DataFrames for CSV handling, rolling/EMA calculations |
| `numpy` | Numeric operations, NaN/Inf handling |
| `requests` | HTTP requests to NASDAQ API, NSE API |

## Additional (India Scanner)
The India scanner (`India_scan.sh`) also installs:

| Package | Purpose |
|---------|---------|
| `fyers-apiv3` | Fyers broker API — fast OHLCV, real-time quotes, circuit limits |

## Install
```bash
pip install -r requirements.txt                    # US scanner
pip install yfinance pandas numpy requests fyers-apiv3  # India scanner
```
