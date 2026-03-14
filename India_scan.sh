#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║              INDIA STOCK SCANNER — LAUNCHER                     ║
# ║              NSE Momentum + Fundamental Scanner                  ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# Self-permission — make this script executable if it isn't already
chmod +x "${BASH_SOURCE[0]}" 2>/dev/null || true

# ── Colors & Styles ───────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[38;5;84m"
BLUE="\033[38;5;39m"
ORANGE="\033[38;5;214m"
RED="\033[38;5;196m"
GOLD="\033[38;5;220m"
CYAN="\033[38;5;51m"
MUTED="\033[38;5;244m"

# ── Config ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
SCANNER="$SCRIPT_DIR/india_scanner.py"
STATE_TOOL="$SCRIPT_DIR/scan_state.py"
STATE_DB="$SCRIPT_DIR/scan_state.db"
ARCHIVE_DB="$SCRIPT_DIR/scan_mega_history.db"
LEGACY_LOG="$SCRIPT_DIR/india_scanned.txt"
RESULT_FILE="$SCRIPT_DIR/india_results.json"
US_RESULT_FILE="$SCRIPT_DIR/scanner_results.json"
US_SCRIPT="$SCRIPT_DIR/start_scan.sh"
EXPORT_DIR="$SCRIPT_DIR/exports"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE_FILE="$SCRIPT_DIR/.env.example"
FYERS_AUTH_HELPER="$SCRIPT_DIR/fyers_auth.py"
REQUIREMENTS="yfinance pandas numpy requests fyers-apiv3"
PYTHON_MIN="3.8"

# ── Helpers ───────────────────────────────────────────────────────
print_banner() {
  echo ""
  echo -e "  ${DIM}${CYAN}══════════════════════════════════════════════════════════════════════${RESET}"
  echo ""
  echo -e "  ${CYAN}${BOLD} ██╗███╗  ██╗██████╗ ██╗ █████╗ ${RESET}"
  echo -e "  ${CYAN}${BOLD} ██║████╗ ██║██╔══██╗██║██╔══██╗${RESET}"
  echo -e "  ${CYAN}${BOLD} ██║██╔██╗██║██║  ██║██║███████║${RESET}   ${DIM}▸ NSE EQUITY${RESET}"
  echo -e "  ${CYAN}${BOLD} ██║██║╚████║██║  ██║██║██╔══██║${RESET}"
  echo -e "  ${CYAN}${BOLD} ██║██║ ╚███║██████╔╝██║██║  ██║${RESET}"
  echo -e "  ${CYAN}${BOLD} ╚═╝╚═╝  ╚══╝╚═════╝ ╚═╝╚═╝  ╚═╝${RESET}"
  echo ""
  echo -e "  ${ORANGE}${BOLD} ███████╗ ██████╗ █████╗ ███╗  ██╗███╗  ██╗███████╗██████╗${RESET}"
  echo -e "  ${ORANGE}${BOLD} ██╔════╝██╔════╝██╔══██╗████╗ ██║████╗ ██║██╔════╝██╔══██╗${RESET}"
  echo -e "  ${ORANGE}${BOLD} ███████╗██║     ███████║██╔██╗██║██╔██╗██║█████╗  ██████╔╝${RESET}"
  echo -e "  ${ORANGE}${BOLD} ╚════██║██║     ██╔══██║██║╚████║██║╚████║██╔══╝  ██╔══██╗${RESET}"
  echo -e "  ${ORANGE}${BOLD} ███████║╚██████╗██║  ██║██║ ╚███║██║ ╚███║███████╗██║  ██║${RESET}"
  echo -e "  ${ORANGE}${BOLD} ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚══╝╚═╝  ╚══╝╚══════╝╚═╝  ╚═╝${RESET}"
  echo ""
  echo -e "  ${DIM}${CYAN}══════════════════════════════════════════════════════════════════════${RESET}"
  echo -e "  ${DIM}Momentum Scanner  ·  by ${BOLD}Vikkrant${RESET}${DIM}  ·  Initializing...${RESET}"
  echo -e "  ${DIM}${ORANGE}══════════════════════════════════════════════════════════════════════${RESET}"
  echo ""
}

print_step() {
  echo -e "${BLUE}${BOLD}▶${RESET}  ${BOLD}$1${RESET}"
}

print_ok() {
  echo -e "${GREEN}  ✓${RESET}  $1"
}

print_warn() {
  echo -e "${ORANGE}  ⚠${RESET}  $1"
}

print_err() {
  echo -e "${RED}  ✗${RESET}  $1"
}

print_info() {
  echo -e "${MUTED}  ·${RESET}  $1"
}

normalize_export_format() {
  local raw="${1:-both}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  raw="${raw#.}"
  case "$raw" in
    md|markdown) echo "md" ;;
    csv) echo "csv" ;;
    both|"") echo "both" ;;
    *) echo "both" ;;
  esac
}

divider() {
  echo -e "${MUTED}  ────────────────────────────────────────────${RESET}"
}

print_resume_mode() {
  divider
  echo -e "  ${CYAN}${BOLD}Mode:${RESET} resume / incremental update"
  echo -e "  ${MUTED}Uses India rows in scan_state.db to decide what to rescan.${RESET}"
  echo -e "  ${MUTED}Every scan event is archived permanently in scan_mega_history.db.${RESET}"
  divider
}

print_fresh_mode() {
  divider
  echo -e "  ${ORANGE}${BOLD}Mode:${RESET} fresh / reset India working state"
  echo -e "  ${MUTED}Clears India rows from scan_state.db, deletes the active India JSON/log outputs, and preserves dated snapshots.${RESET}"
  echo -e "  ${MUTED}scan_mega_history.db is preserved, so historical scores remain archived.${RESET}"
  divider
}

print_history_mode() {
  divider
  echo -e "  ${GOLD}${BOLD}Mode:${RESET} archive history"
  echo -e "  ${MUTED}Reads permanent India history from scan_mega_history.db.${RESET}"
  divider
}

print_summary_mode() {
  divider
  echo -e "  ${CYAN}${BOLD}Mode:${RESET} latest scan summary"
  echo -e "  ${MUTED}Reads the newest India results and prints the top 30 ranked names in a terminal table.${RESET}"
  divider
}

print_diff_mode() {
  divider
  echo -e "  ${ORANGE}${BOLD}Mode:${RESET} latest scan diff"
  echo -e "  ${MUTED}Compares current India results against the newest older snapshot and archives the diff output.${RESET}"
  divider
}

print_report_mode() {
  divider
  echo -e "  ${CYAN}${BOLD}Mode:${RESET} latest scan report"
  echo -e "  ${MUTED}Prints a richer India market report and saves that output payload in the permanent archive DB.${RESET}"
  divider
}

print_artifact_history_mode() {
  divider
  echo -e "  ${ORANGE}${BOLD}Mode:${RESET} artifact history"
  echo -e "  ${MUTED}Shows archived generated outputs like diff, report, export, doctor, and compare views.${RESET}"
  divider
}

print_archive_query_mode() {
  divider
  echo -e "  ${CYAN}${BOLD}Mode:${RESET} archive query"
  echo -e "  ${MUTED}Browses archived command-output rows directly, with optional command and text filters.${RESET}"
  divider
}

print_ticker_history_mode() {
  divider
  echo -e "  ${CYAN}${BOLD}Mode:${RESET} ticker history"
  echo -e "  ${MUTED}Shows one India symbol's archived score timeline, latest profile, and recent scan events.${RESET}"
  divider
}

print_leaderboard_mode() {
  divider
  echo -e "  ${ORANGE}${BOLD}Mode:${RESET} leaderboard"
  echo -e "  ${MUTED}Shows current leaders plus historical consistency, score-hit, and near-high rankings.${RESET}"
  divider
}

print_sector_report_mode() {
  divider
  echo -e "  ${CYAN}${BOLD}Mode:${RESET} sector report"
  echo -e "  ${MUTED}Shows sector-level summary for the latest India scan and can drill into one sector table.${RESET}"
  divider
}

print_sector_history_mode() {
  divider
  echo -e "  ${ORANGE}${BOLD}Mode:${RESET} sector history"
  echo -e "  ${MUTED}Shows archived sector moves across dates and can drill into one sector timeline.${RESET}"
  divider
}

print_new_highs_mode() {
  divider
  echo -e "  ${ORANGE}${BOLD}Mode:${RESET} near 52W high"
  echo -e "  ${MUTED}Shows only the latest India stocks flagged as Near 52W High, with sector breakdown.${RESET}"
  divider
}

print_compare_markets_mode() {
  divider
  echo -e "  ${CYAN}${BOLD}Mode:${RESET} compare markets"
  echo -e "  ${MUTED}Compares the latest India and US market result sets side by side and archives the output.${RESET}"
  divider
}

print_daily_mode() {
  divider
  echo -e "  ${ORANGE}${BOLD}Mode:${RESET} daily workflow"
  echo -e "  ${MUTED}Runs India scan, then US scan, then archives fresh reports/diffs, prints cross-market comparison, and auto-exports a workflow bundle.${RESET}"
  divider
}

print_daily_full_mode() {
  divider
  echo -e "  ${ORANGE}${BOLD}Mode:${RESET} daily full workflow"
  echo -e "  ${MUTED}Runs both scans, then doctor/report/diff/sector/new-high review for both markets, India cap-class tables, compare-markets, and auto-exports a workflow bundle.${RESET}"
  divider
}

print_doctor_mode() {
  divider
  echo -e "  ${CYAN}${BOLD}Mode:${RESET} doctor"
  echo -e "  ${MUTED}Checks environment, result freshness, snapshots, working DB, and archive DB health.${RESET}"
  divider
}

print_export_mode() {
  local export_scope="${1:-market}"
  divider
  echo -e "  ${ORANGE}${BOLD}Mode:${RESET} ${export_scope} export"
  echo -e "  ${MUTED}Exports the latest India ${export_scope} view to CSV and/or Markdown and stores the export metadata in the archive DB.${RESET}"
  divider
}

print_cap_class_mode() {
  local cap_label="$1"
  case "$1" in
    smallcap) cap_label="Smallcap" ;;
    midcap)   cap_label="Midcap" ;;
    largecap) cap_label="Largecap" ;;
  esac
  divider
  echo -e "  ${CYAN}${BOLD}Mode:${RESET} ${cap_label} table"
  echo -e "  ${MUTED}Shows only ${cap_label} India results from the latest scan, sorted by descending score.${RESET}"
  divider
}

ensure_env_file() {
  if [[ -f "$ENV_FILE" ]]; then
    return
  fi

  if [[ -f "$ENV_EXAMPLE_FILE" ]]; then
    cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
    print_ok "Created $(basename "$ENV_FILE") from template"
  else
    : > "$ENV_FILE"
    print_ok "Created empty $(basename "$ENV_FILE")"
  fi
}

load_env_file() {
  ensure_env_file
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
}

fyers_configured() {
  [[ -n "${FYERS_CLIENT_ID:-}" && -n "${FYERS_SECRET_KEY:-}" && -n "${FYERS_REDIRECT_URI:-}" ]]
}

open_url_in_browser() {
  local url="$1"
  if [[ "${FYERS_OPEN_BROWSER:-1}" == "0" ]]; then
    return 0
  fi
  if command -v open &>/dev/null; then
    open "$url" >/dev/null 2>&1 || return 1
    return 0
  fi
  if command -v xdg-open &>/dev/null; then
    xdg-open "$url" >/dev/null 2>&1 || return 1
    return 0
  fi
  return 1
}

ensure_fyers_session() {
  load_env_file

  if ! fyers_configured; then
    print_info "FYERS credentials are not set in $(basename "$ENV_FILE") — yfinance fallback stays active"
    return 0
  fi

  local status_output=""
  local status_code=0
  set +e
  status_output="$("$VENV_PYTHON" "$FYERS_AUTH_HELPER" --env-file "$ENV_FILE" status 2>/dev/null)"
  status_code=$?
  set -e

  if [[ "$status_code" -eq 0 ]]; then
    if [[ "$status_output" == TOKEN_VALID:* ]]; then
      print_ok "FYERS access token is valid (${status_output#TOKEN_VALID:})"
    else
      print_ok "FYERS access token is valid"
    fi
    return 0
  fi

  case "$status_code" in
    10)
      print_info "FYERS credentials are incomplete in $(basename "$ENV_FILE") — yfinance fallback stays active"
      return 0
      ;;
    11|12)
      if [[ "$status_output" == TOKEN_INVALID:* ]]; then
        print_warn "FYERS token check failed: ${status_output#TOKEN_INVALID:}"
      elif [[ "$status_output" == TOKEN_MISSING* ]]; then
        print_info "FYERS access token is not saved yet"
      fi

      if [[ ! -t 0 ]]; then
        print_warn "No interactive terminal available — continuing with yfinance fallback"
        return 0
      fi

      printf "  Continue with FYERS login now? [Y/n]: "
      local continue_with_fyers=""
      local continue_choice=""
      IFS= read -r continue_with_fyers
      continue_choice="$(printf '%s' "$continue_with_fyers" | tr '[:upper:]' '[:lower:]')"
      case "$continue_choice" in
        n|no)
          print_warn "Continuing with yfinance fallback"
          return 0
          ;;
      esac

      divider
      echo -e "  ${CYAN}${BOLD}FYERS Login${RESET}"
      echo -e "  ${MUTED}Opening the FYERS login page so you can copy the redirected URL or auth code.${RESET}"

      local auth_url=""
      if ! auth_url="$("$VENV_PYTHON" "$FYERS_AUTH_HELPER" --env-file "$ENV_FILE" auth-url 2>/dev/null)"; then
        print_warn "Could not generate FYERS auth URL — continuing with yfinance fallback"
        return 0
      fi

      if open_url_in_browser "$auth_url"; then
        print_ok "FYERS login page opened in your browser"
      else
        print_warn "Could not open the browser automatically"
      fi

      echo -e "  ${MUTED}If needed, open this URL manually:${RESET}"
      echo -e "  ${GOLD}${auth_url}${RESET}"
      echo ""
      printf "  Paste the FYERS redirect URL or auth code (leave blank to skip): "
      local auth_input=""
      IFS= read -r auth_input

      if [[ -z "$auth_input" ]]; then
        print_warn "FYERS login skipped — continuing with yfinance fallback"
        return 0
      fi

      if "$VENV_PYTHON" "$FYERS_AUTH_HELPER" --env-file "$ENV_FILE" exchange-code --auth-input "$auth_input" >/dev/null; then
        load_env_file
        print_ok "FYERS access token saved to $(basename "$ENV_FILE")"
      else
        print_warn "FYERS auth exchange failed — continuing with yfinance fallback"
      fi
      return 0
      ;;
    *)
      print_warn "FYERS token check failed — continuing with yfinance fallback"
      return 0
      ;;
  esac
}

# ── Check Python ──────────────────────────────────────────────────
check_python() {
  print_step "Checking Python..."

  if command -v python3 &>/dev/null; then
    PYTHON_BIN="python3"
  elif command -v python &>/dev/null; then
    PYTHON_BIN="python"
  else
    print_err "Python not found. Install from https://www.python.org"
    exit 1
  fi

  PY_VERSION=$($PYTHON_BIN -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
  PY_MAJOR=$($PYTHON_BIN -c "import sys; print(sys.version_info.major)")
  PY_MINOR=$($PYTHON_BIN -c "import sys; print(sys.version_info.minor)")

  if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 8 ]]; then
    print_err "Python $PY_VERSION found. Need >= $PYTHON_MIN"
    exit 1
  fi

  print_ok "Python $PY_VERSION  ($PYTHON_BIN)"
}

# ── Check scanner file ────────────────────────────────────────────
check_scanner() {
  print_step "Checking scanner file..."

  if [[ ! -f "$SCANNER" ]]; then
    print_err "india_scanner.py not found in $SCRIPT_DIR"
    print_info "Make sure india_scanner.py is in the same folder as this script."
    exit 1
  fi

  print_ok "india_scanner.py found"
}

# ── Setup venv ────────────────────────────────────────────────────
setup_venv() {
  print_step "Setting up virtual environment..."

  if [[ -d "$VENV_DIR" ]]; then
    print_ok "venv already exists — skipping creation"
  else
    print_info "Creating venv at $VENV_DIR ..."
    $PYTHON_BIN -m venv "$VENV_DIR"
    print_ok "venv created"
  fi

  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    print_err "venv Python not found at $VENV_DIR/bin/python"
    exit 1
  fi

  print_ok "venv ready"
}

# ── Install / verify dependencies ────────────────────────────────
install_deps() {
  print_step "Checking dependencies..."

  VENV_PYTHON="$VENV_DIR/bin/python"

  MISSING=()
  for pkg in $REQUIREMENTS; do
    pkg_name="${pkg%%[>=<!]*}"   # strip version specifiers if any
    if ! "$VENV_PYTHON" -c "import ${pkg_name//-/_}" &>/dev/null 2>&1; then
      # Try the actual import name for packages with dashes
      case "$pkg_name" in
        fyers-apiv3) import_name="fyers_apiv3" ;;
        *)           import_name="${pkg_name//-/_}" ;;
      esac
      if ! "$VENV_PYTHON" -c "import $import_name" &>/dev/null 2>&1; then
        MISSING+=("$pkg")
      fi
    fi
  done

  if [[ ${#MISSING[@]} -eq 0 ]]; then
    print_ok "All dependencies already installed"
  else
    echo ""
    print_info "Installing: ${MISSING[*]}"
    echo ""
    "$VENV_PYTHON" -m pip install "${MISSING[@]}" --quiet --progress-bar on
    echo ""
    print_ok "Dependencies installed"
  fi

  # Print versions
  divider
  print_info "Package versions:"
  "$VENV_PYTHON" -c "
import yfinance, pandas, numpy
print(f'    yfinance  {yfinance.__version__}')
print(f'    pandas    {pandas.__version__}')
print(f'    numpy     {numpy.__version__}')
try:
    import fyers_apiv3
    print(f'    fyers     installed')
except:
    print(f'    fyers     not installed (yfinance fallback active)')
"
  divider
}

reset_india_state() {
  print_step "Clearing India working state..."
  "$PYTHON_BIN" "$STATE_TOOL" reset --db "$STATE_DB" --market IN >/dev/null
  print_ok "India working state cleared"
}

delete_india_outputs() {
  print_step "Deleting India runtime outputs..."
  rm -f "$RESULT_FILE"
  rm -f "$LEGACY_LOG"
  print_ok "Active India JSON output and legacy log removed; dated snapshots preserved"
}

show_india_history() {
  if [[ ! -f "$ARCHIVE_DB" ]]; then
    print_warn "scan_mega_history.db not found yet. Run a scan first."
    exit 0
  fi
  "$PYTHON_BIN" "$STATE_TOOL" history --db "$ARCHIVE_DB" --archive-db "$ARCHIVE_DB" --market IN
}

show_india_summary() {
  "$PYTHON_BIN" "$STATE_TOOL" summary --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
}

show_india_diff() {
  "$PYTHON_BIN" "$STATE_TOOL" diff --market IN --results-file "$RESULT_FILE" --archive-db "$ARCHIVE_DB" --limit 15
}

show_india_report() {
  "$PYTHON_BIN" "$STATE_TOOL" report --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
}

show_india_cap_table() {
  local cap_class="$1"
  "$PYTHON_BIN" "$STATE_TOOL" summary --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --cap-class "$cap_class" --limit 500
}

show_india_artifact_history() {
  local artifact_type="${1:-}"
  local cmd=("$PYTHON_BIN" "$STATE_TOOL" artifact-history --db "$ARCHIVE_DB" --market IN --limit 25)
  if [[ -n "$artifact_type" ]]; then
    cmd+=(--artifact-type "$artifact_type")
  fi
  "${cmd[@]}"
}

show_india_archive_query() {
  local command_filter="${1:-}"
  local search_filter="${2:-}"
  local cmd=("$PYTHON_BIN" "$STATE_TOOL" archive-query --db "$ARCHIVE_DB" --market IN --limit 25)
  if [[ -n "$command_filter" && "$command_filter" != "all" && "$command_filter" != "*" ]]; then
    cmd+=(--command-name "$command_filter")
  fi
  if [[ -n "$search_filter" ]]; then
    cmd+=(--search "$search_filter")
  fi
  "${cmd[@]}"
}

show_india_ticker_history() {
  local ticker="${1:-}"
  if [[ -z "$ticker" ]]; then
    print_err "ticker-history requires a symbol, e.g. ./India_scan.sh ticker-history RELIANCE"
    exit 1
  fi
  "$PYTHON_BIN" "$STATE_TOOL" ticker-history --market IN --db "$ARCHIVE_DB" --ticker "$ticker" --archive-db "$ARCHIVE_DB" --limit 20
}

show_india_leaderboard() {
  "$PYTHON_BIN" "$STATE_TOOL" leaderboard --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 15
}

show_india_sector_report() {
  local sector_query="${1:-}"
  local cmd=("$PYTHON_BIN" "$STATE_TOOL" sector-report --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30)
  if [[ -n "$sector_query" ]]; then
    cmd+=(--sector "$sector_query")
  fi
  "${cmd[@]}"
}

show_india_sector_history() {
  local sector_query="${1:-}"
  local cmd=("$PYTHON_BIN" "$STATE_TOOL" sector-history --market IN --db "$ARCHIVE_DB" --archive-db "$ARCHIVE_DB" --limit 20)
  if [[ -n "$sector_query" ]]; then
    cmd+=(--sector "$sector_query")
  fi
  "${cmd[@]}"
}

show_india_new_highs() {
  "$PYTHON_BIN" "$STATE_TOOL" new-highs --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
}

show_compare_markets() {
  "$PYTHON_BIN" "$STATE_TOOL" compare-markets --us-results-file "$US_RESULT_FILE" --india-results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB"
}

show_india_doctor() {
  "$PYTHON_BIN" "$STATE_TOOL" doctor --market IN --results-file "$RESULT_FILE" --state-db "$STATE_DB" --archive-db "$ARCHIVE_DB" --venv-dir "$VENV_DIR" --scanner-file "$SCANNER"
}

show_india_export() {
  local export_format="${1:-both}"
  local dataset="${2:-market}"
  local sector_query="${3:-}"
  local cmd=("$PYTHON_BIN" "$STATE_TOOL" export --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --out-dir "$EXPORT_DIR" --format "$export_format" --dataset "$dataset" --limit 200)
  if [[ -n "$sector_query" ]]; then
    cmd+=(--sector "$sector_query")
  fi
  "${cmd[@]}"
}

export_workflow_bundle() {
  local workflow_name="$1"
  divider
  echo ""
  echo -e "${BLUE}${BOLD}▶${RESET}  ${BOLD}Exporting ${workflow_name} bundle${RESET}"
  echo ""
  divider
  echo ""
  "$PYTHON_BIN" "$STATE_TOOL" workflow-export \
    --workflow "$workflow_name" \
    --origin-market IN \
    --us-results-file "$US_RESULT_FILE" \
    --india-results-file "$RESULT_FILE" \
    --db "$STATE_DB" \
    --archive-db "$ARCHIVE_DB" \
    --out-dir "$EXPORT_DIR/workflows" \
    --limit 30 \
    --us-venv-dir "$SCRIPT_DIR/.venv" \
    --india-venv-dir "$VENV_DIR" \
    --us-scanner-file "$SCRIPT_DIR/scanner.py" \
    --india-scanner-file "$SCANNER" \
    --us-requirements-file "$SCRIPT_DIR/requirements.txt"
}

# ── Pre-run info ──────────────────────────────────────────────────
print_run_info() {
  local market_data_mode="yfinance fallback only"
  if fyers_configured && [[ -n "${FYERS_ACCESS_TOKEN:-}" ]]; then
    market_data_mode="FYERS market data + yfinance fundamentals"
  fi

  echo ""
  echo -e "${GOLD}${BOLD}  Scan Configuration${RESET}"
  echo -e "${MUTED}  ─────────────────────────────────────────────${RESET}"
  echo -e "  ${MUTED}Exchange   :${RESET}  NSE India"
  echo -e "  ${MUTED}Data Mode  :${RESET}  $market_data_mode"
  echo -e "  ${MUTED}Conditions :${RESET}  P1 Close ≥ 250H × 0.75  │  P2 Close ≥ EMA21"
  echo -e "  ${MUTED}           :${RESET}  P3 Close ≥ EMA50         │  P4 Close ≥ EMA200"
  echo -e "  ${MUTED}           :${RESET}  P5 Avg Turnover ≥ ₹50Cr/day"
  echo -e "  ${MUTED}Signals    :${RESET}  Near 52W High · EMA21/50/200 · Volume Spike"
  echo -e "  ${MUTED}           :${RESET}  Upper Circuit · Delivery % · EPS · Rev Growth"
  echo -e "  ${MUTED}Output     :${RESET}  india_results.json"
  echo -e "  ${MUTED}Secrets    :${RESET}  $(basename "$ENV_FILE")"
  echo -e "  ${MUTED}Dashboard  :${RESET}  http://localhost:8000/dashboard.html"
  echo -e "${MUTED}  ─────────────────────────────────────────────${RESET}"
  echo ""
  echo -e "${MUTED}  Press Ctrl+C at any time to stop. Progress is saved automatically.${RESET}"
  echo -e "${MUTED}  Re-run this script to resume from where it stopped.${RESET}"
  echo ""
}

# ── Dashboard reminder ────────────────────────────────────────────
print_dashboard_tip() {
  echo ""
  divider
  echo -e "  ${CYAN}${BOLD}Dashboard${RESET}"
  echo -e "  ${MUTED}Open a new terminal and run:${RESET}"
  echo ""
  echo -e "  ${GOLD}  cd $(basename $SCRIPT_DIR) && python -m http.server 8000${RESET}"
  echo ""
  echo -e "  ${MUTED}Then open Safari/Chrome:${RESET}  ${CYAN}http://localhost:8000/dashboard.html${RESET}"
  echo -e "  ${MUTED}Toggle to${RESET} 🇮🇳 ${BOLD}INDIA NSE/BSE${RESET} ${MUTED}to see live results${RESET}"
  divider
  echo ""
}

show_help() {
  print_banner
  echo -e "${BOLD}Usage:${RESET}  ./India_scan.sh ${CYAN}[command]${RESET}"
  echo ""
  echo -e "${BOLD}Commands:${RESET}"
  echo -e "  ${CYAN}run${RESET}      Resume/update India scan using ${BOLD}scan_state.db${RESET}"
  echo -e "  ${CYAN}fresh${RESET}    Reset India working state, clear active India outputs, then rescan"
  echo -e "  ${CYAN}summary${RESET}  Show the latest India top 30 summary table"
  echo -e "  ${CYAN}artifact-history${RESET} Show archived generated outputs for India and shared artifacts"
  echo -e "  ${CYAN}archive-query${RESET} Browse archived India command-output rows directly"
  echo -e "  ${CYAN}ticker-history${RESET}  Show archived score history for one symbol"
  echo -e "  ${CYAN}leaderboard${RESET} Show current and historical India leader tables"
  echo -e "  ${CYAN}sector-report${RESET} Show latest sector summary or drill into one sector"
  echo -e "  ${CYAN}sector-history${RESET} Show archived sector history snapshot or one sector timeline"
  echo -e "  ${CYAN}sector${RESET}   Friendly sector workflow alias for report/history/export"
  echo -e "  ${CYAN}new-highs${RESET}  Show only latest India Near 52W High names"
  echo -e "  ${CYAN}compare-markets${RESET} Compare latest India and US outputs side by side"
  echo -e "  ${CYAN}daily${RESET}    Run India scan, US scan, then reports/diffs/compare and auto-export bundle"
  echo -e "  ${CYAN}daily-full${RESET} Run both scans, full review analytics, then compare and auto-export bundle"
  echo -e "  ${CYAN}doctor${RESET}   Run environment and data health checks"
  echo -e "  ${CYAN}export${RESET}   Export latest India market view as csv, md, or both"
  echo -e "  ${CYAN}smallcap${RESET} Show only Smallcap India stocks from latest scan"
  echo -e "  ${CYAN}midcap${RESET}   Show only Midcap India stocks from latest scan"
  echo -e "  ${CYAN}largecap${RESET} Show only Largecap India stocks from latest scan"
  echo -e "  ${CYAN}diff${RESET}     Compare latest India results vs previous snapshot"
  echo -e "  ${CYAN}report${RESET}   Generate a richer India report and archive it"
  echo -e "  ${CYAN}history${RESET}  Show archived India scan history from ${BOLD}scan_mega_history.db${RESET}"
  echo -e "  ${CYAN}help${RESET}     Show this help message"
  echo ""
  echo -e "${BOLD}Scan State:${RESET}"
  echo -e "  ${MUTED}Working state:${RESET}  scan_state.db  (India rows cleared by ${CYAN}fresh${RESET})"
  echo -e "  ${MUTED}Archive:${RESET}        scan_mega_history.db  (never deleted by ${CYAN}fresh${RESET})"
  echo -e "  ${MUTED}Fresh removes:${RESET}  india_results.json, india_scanned.txt"
  echo -e "  ${MUTED}Fresh keeps:${RESET}    india_results_YYYY-MM-DD.json snapshots for diff/history reuse"
  echo -e "  ${MUTED}FYERS config:${RESET}   .env  (optional; blank values keep yfinance-only mode)"
  echo ""
  echo -e "${BOLD}Examples:${RESET}"
  echo -e "  ${MUTED}./India_scan.sh${RESET}          # Default run + FYERS auth check"
  echo -e "  ${MUTED}./India_scan.sh run${RESET}      # Resume / incremental update"
  echo -e "  ${MUTED}./India_scan.sh fresh${RESET}    # Fresh India scan, archive preserved"
  echo -e "  ${MUTED}./India_scan.sh summary${RESET}  # Top 30 from latest India scan"
  echo -e "  ${MUTED}./India_scan.sh artifact-history${RESET} # Show archived outputs"
  echo -e "  ${MUTED}./India_scan.sh artifact-history report${RESET} # Only report artifacts"
  echo -e "  ${MUTED}./India_scan.sh archive-query${RESET} # Browse archived rows"
  echo -e "  ${MUTED}./India_scan.sh archive-query summary${RESET} # Only summary rows"
  echo -e "  ${MUTED}./India_scan.sh archive-query summary Smallcap${RESET} # Search summary rows for Smallcap"
  echo -e "  ${MUTED}./India_scan.sh ticker-history RELIANCE${RESET} # One symbol timeline"
  echo -e "  ${MUTED}./India_scan.sh leaderboard${RESET} # Current + historical leaders"
  echo -e "  ${MUTED}./India_scan.sh sector-report${RESET} # Sector summary for latest scan"
  echo -e "  ${MUTED}./India_scan.sh sector-report Finance${RESET} # Drill into one sector"
  echo -e "  ${MUTED}./India_scan.sh sector-report export csv Industrials${RESET} # Export one sector report as CSV"
  echo -e "  ${MUTED}./India_scan.sh sector-history${RESET} # Latest archived sector snapshot with deltas"
  echo -e "  ${MUTED}./India_scan.sh sector-history Industrials${RESET} # One sector timeline"
  echo -e "  ${MUTED}./India_scan.sh sector-history export .md Industrials${RESET} # Export sector history as Markdown"
  echo -e "  ${MUTED}./India_scan.sh sector report Industrials${RESET} # Alias for sector-report Industrials"
  echo -e "  ${MUTED}./India_scan.sh sector report export md Industrials${RESET} # Alias export syntax"
  echo -e "  ${MUTED}./India_scan.sh sector history Industrials${RESET} # Alias for sector-history Industrials"
  echo -e "  ${MUTED}./India_scan.sh new-highs${RESET} # Latest Near 52W High names"
  echo -e "  ${MUTED}./India_scan.sh compare-markets${RESET} # Compare India and US"
  echo -e "  ${MUTED}./India_scan.sh daily${RESET} # Full daily workflow"
  echo -e "  ${MUTED}./India_scan.sh daily full${RESET} # Full daily workflow with all review tables"
  echo -e "  ${MUTED}./India_scan.sh daily-full${RESET} # Same as daily full"
  echo -e "  ${MUTED}./India_scan.sh india daily scan${RESET} # Natural alias for daily"
  echo -e "  ${MUTED}./India_scan.sh india daily full${RESET} # Natural alias for daily full"
  echo -e "  ${MUTED}./India_scan.sh india compare markets${RESET} # Natural alias for compare-markets"
  echo -e "  ${MUTED}./India_scan.sh doctor${RESET} # Health check"
  echo -e "  ${MUTED}./India_scan.sh export${RESET} # Market export in CSV + Markdown"
  echo -e "  ${MUTED}./India_scan.sh export csv${RESET} # Market export in CSV only"
  echo -e "  ${MUTED}./India_scan.sh smallcap${RESET} # Filter latest India table to Smallcap"
  echo -e "  ${MUTED}./India_scan.sh midcap${RESET}   # Filter latest India table to Midcap"
  echo -e "  ${MUTED}./India_scan.sh largecap${RESET} # Filter latest India table to Largecap"
  echo -e "  ${MUTED}./India_scan.sh diff${RESET}     # Compare latest scan vs previous snapshot"
  echo -e "  ${MUTED}./India_scan.sh report${RESET}   # Full latest-scan report with stats"
  echo -e "  ${MUTED}./India_scan.sh history${RESET}  # Inspect archived India scan history"
  echo ""
}

# ── Cleanup on exit ───────────────────────────────────────────────
cleanup() {
  echo ""
  echo -e "${ORANGE}${BOLD}  Scan interrupted.${RESET}"
  echo -e "${MUTED}  Progress saved to scan_state.db — re-run to resume.${RESET}"
  echo ""
}
trap cleanup INT TERM

# ══════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════
CMD="${1:-run}"
ARG1="${2:-}"
ARG2="${3:-}"
ARG3="${4:-}"

run_scan_flow() {
  check_scanner
  setup_venv
  install_deps
  ensure_fyers_session
  print_run_info
  print_dashboard_tip

  sleep 1

  echo -e "${GREEN}${BOLD}  Starting scan...${RESET}"
  echo ""

  "$VENV_DIR/bin/python" "$SCANNER"

  echo ""
  echo -e "${GREEN}${BOLD}  ✓ Scan complete!${RESET}"
  echo -e "${MUTED}  Results saved to india_results.json${RESET}"
  echo -e "${MUTED}  Open dashboard.html to explore results.${RESET}"
  echo ""
}

run_daily_flow() {
  divider
  echo ""
  echo -e "${BLUE}${BOLD}▶${RESET}  ${BOLD}Running India daily pass${RESET}"
  echo ""
  divider
  echo ""
  run_scan_flow

  if [[ -x "$US_SCRIPT" || -f "$US_SCRIPT" ]]; then
    divider
    echo ""
    echo -e "${BLUE}${BOLD}▶${RESET}  ${BOLD}Running US daily pass${RESET}"
    echo ""
    divider
    echo ""
    bash "$US_SCRIPT" run
  else
    print_warn "US launcher not found at $US_SCRIPT — skipping US scan"
  fi

  divider
  echo ""
  echo -e "${BLUE}${BOLD}▶${RESET}  ${BOLD}Archiving reports, diffs, and market comparison${RESET}"
  echo ""
  divider
  echo ""

  show_india_report
  show_india_diff
  "$PYTHON_BIN" "$STATE_TOOL" report --market US --results-file "$US_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
  "$PYTHON_BIN" "$STATE_TOOL" diff --market US --results-file "$US_RESULT_FILE" --archive-db "$ARCHIVE_DB" --limit 15
  show_compare_markets
  export_workflow_bundle "daily"
}

run_daily_full_flow() {
  divider
  echo ""
  echo -e "${BLUE}${BOLD}▶${RESET}  ${BOLD}Running India daily full pass${RESET}"
  echo ""
  divider
  echo ""
  run_scan_flow

  if [[ -x "$US_SCRIPT" || -f "$US_SCRIPT" ]]; then
    divider
    echo ""
    echo -e "${BLUE}${BOLD}▶${RESET}  ${BOLD}Running US daily full pass${RESET}"
    echo ""
    divider
    echo ""
    bash "$US_SCRIPT" run
  else
    print_warn "US launcher not found at $US_SCRIPT — skipping US scan"
  fi

  divider
  echo ""
  echo -e "${BLUE}${BOLD}▶${RESET}  ${BOLD}Running full market review${RESET}"
  echo ""
  divider
  echo ""

  show_india_doctor
  "$PYTHON_BIN" "$STATE_TOOL" doctor --market US --results-file "$US_RESULT_FILE" --state-db "$STATE_DB" --archive-db "$ARCHIVE_DB" --venv-dir "$SCRIPT_DIR/.venv" --scanner-file "$SCRIPT_DIR/scanner.py" --requirements-file "$SCRIPT_DIR/requirements.txt"

  show_india_report
  show_india_diff
  show_india_sector_report
  show_india_sector_history
  show_india_new_highs
  "$PYTHON_BIN" "$STATE_TOOL" summary --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --cap-class smallcap --limit 30
  "$PYTHON_BIN" "$STATE_TOOL" summary --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --cap-class midcap --limit 30
  "$PYTHON_BIN" "$STATE_TOOL" summary --market IN --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --cap-class largecap --limit 30

  "$PYTHON_BIN" "$STATE_TOOL" report --market US --results-file "$US_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
  "$PYTHON_BIN" "$STATE_TOOL" diff --market US --results-file "$US_RESULT_FILE" --archive-db "$ARCHIVE_DB" --limit 15
  "$PYTHON_BIN" "$STATE_TOOL" sector-report --market US --results-file "$US_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
  "$PYTHON_BIN" "$STATE_TOOL" sector-history --market US --db "$ARCHIVE_DB" --archive-db "$ARCHIVE_DB" --limit 20
  "$PYTHON_BIN" "$STATE_TOOL" new-highs --market US --results-file "$US_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30

  show_compare_markets
  export_workflow_bundle "daily-full"
}

case "$CMD" in
  run|resume)
    print_banner
    check_python
    print_resume_mode
    run_scan_flow
    ;;
  fresh)
    print_banner
    check_python
    print_fresh_mode
    reset_india_state
    delete_india_outputs
    run_scan_flow
    ;;
  history)
    print_banner
    check_python
    print_history_mode
    show_india_history
    ;;
  summary)
    print_banner
    check_python
    print_summary_mode
    show_india_summary
    ;;
  artifact-history)
    print_banner
    check_python
    print_artifact_history_mode
    show_india_artifact_history "$ARG1"
    ;;
  archive-query)
    print_banner
    check_python
    print_archive_query_mode
    show_india_archive_query "$ARG1" "${*:3}"
    ;;
  ticker-history)
    print_banner
    check_python
    print_ticker_history_mode
    show_india_ticker_history "$ARG1"
    ;;
  leaderboard)
    print_banner
    check_python
    print_leaderboard_mode
    show_india_leaderboard
    ;;
  sector-report)
    print_banner
    check_python
    if [[ "$ARG1" == "export" ]]; then
      print_export_mode "sector report"
      show_india_export "$(normalize_export_format "$ARG2")" "sector-report" "${*:4}"
    else
      print_sector_report_mode
      show_india_sector_report "${*:2}"
    fi
    ;;
  sector-history)
    print_banner
    check_python
    if [[ "$ARG1" == "export" ]]; then
      print_export_mode "sector history"
      show_india_export "$(normalize_export_format "$ARG2")" "sector-history" "${*:4}"
    else
      print_sector_history_mode
      show_india_sector_history "${*:2}"
    fi
    ;;
  sector)
    print_banner
    check_python
    case "$ARG1" in
      report)
        if [[ "$ARG2" == "export" ]]; then
          print_export_mode "sector report"
          show_india_export "$(normalize_export_format "$ARG3")" "sector-report" "${*:5}"
        else
          print_sector_report_mode
          show_india_sector_report "${*:3}"
        fi
        ;;
      history)
        if [[ "$ARG2" == "export" ]]; then
          print_export_mode "sector history"
          show_india_export "$(normalize_export_format "$ARG3")" "sector-history" "${*:5}"
        else
          print_sector_history_mode
          show_india_sector_history "${*:3}"
        fi
        ;;
      *)
        print_err "Usage: ./India_scan.sh sector report [sector] | sector report export [csv|md|both] [sector] | sector history [sector] | sector history export [csv|md|both] [sector]"
        exit 1
        ;;
    esac
    ;;
  new-highs)
    print_banner
    check_python
    print_new_highs_mode
    show_india_new_highs
    ;;
  compare-markets)
    print_banner
    check_python
    print_compare_markets_mode
    show_compare_markets
    ;;
  india)
    print_banner
    check_python
    case "$ARG1 $ARG2" in
      "daily scan")
        print_daily_mode
        run_daily_flow
        ;;
      "daily full")
        print_daily_full_mode
        run_daily_full_flow
        ;;
      "compare markets")
        print_compare_markets_mode
        show_compare_markets
        ;;
      *)
        print_err "Usage: ./India_scan.sh india daily scan | ./India_scan.sh india daily full | ./India_scan.sh india compare markets"
        exit 1
        ;;
    esac
    ;;
  daily)
    print_banner
    check_python
    if [[ "$ARG1" == "full" ]]; then
      print_daily_full_mode
      run_daily_full_flow
    else
      print_daily_mode
      run_daily_flow
    fi
    ;;
  daily-full)
    print_banner
    check_python
    print_daily_full_mode
    run_daily_full_flow
    ;;
  doctor)
    print_banner
    check_python
    print_doctor_mode
    show_india_doctor
    ;;
  export)
    print_banner
    check_python
    print_export_mode "market"
    show_india_export "$(normalize_export_format "$ARG1")" "market"
    ;;
  smallcap|midcap|largecap)
    print_banner
    check_python
    print_cap_class_mode "$CMD"
    show_india_cap_table "$CMD"
    ;;
  diff)
    print_banner
    check_python
    print_diff_mode
    show_india_diff
    ;;
  report)
    print_banner
    check_python
    print_report_mode
    show_india_report
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    print_banner
    print_err "Unknown command: $CMD"
    echo ""
    show_help
    exit 1
    ;;
esac
