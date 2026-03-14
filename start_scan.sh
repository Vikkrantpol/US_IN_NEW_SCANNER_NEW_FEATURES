#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║          US Stock Scanner — Launcher Script                      ║
# ║          Usage:  ./start_scan.sh run                             ║
# ║                  ./start_scan.sh fresh                           ║
# ║                  ./start_scan.sh summary                         ║
# ║                  ./start_scan.sh diff                            ║
# ║                  ./start_scan.sh report                          ║
# ║                  ./start_scan.sh history                         ║
# ║                  ./start_scan.sh download                        ║
# ║                  ./start_scan.sh clean                           ║
# ║                  ./start_scan.sh help                            ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colors & Symbols ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
ORANGE='\033[38;5;214m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

CHECK="${GREEN}✔${RESET}"
CROSS="${RED}✘${RESET}"
ARROW="${CYAN}➜${RESET}"
SPARKLE="${MAGENTA}✦${RESET}"

# ── Paths ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
REQ_FILE="${SCRIPT_DIR}/requirements.txt"
SCANNER="${SCRIPT_DIR}/scanner.py"
DOWNLOADER="${SCRIPT_DIR}/100M_10B_Market_Cap.py"
STATE_TOOL="${SCRIPT_DIR}/scan_state.py"
STATE_DB="${SCRIPT_DIR}/scan_state.db"
ARCHIVE_DB="${SCRIPT_DIR}/scan_mega_history.db"
LEGACY_LOG="${SCRIPT_DIR}/scanner_scanned.txt"
RESULT_FILE="${SCRIPT_DIR}/scanner_results.json"
INDIA_RESULT_FILE="${SCRIPT_DIR}/india_results.json"
INDIA_SCRIPT="${SCRIPT_DIR}/India_scan.sh"
EXPORT_DIR="${SCRIPT_DIR}/exports"
PYTHON_MIN="3.8"

# ── Helper Functions ──────────────────────────────────────────────

banner() {
    echo ""
    echo -e "  ${DIM}${CYAN}══════════════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "  ${CYAN}${BOLD} ███╗   ███╗ █████╗ ██████╗ ██╗  ██╗███████╗████████╗${RESET}"
    echo -e "  ${CYAN}${BOLD} ████╗ ████║██╔══██╗██╔══██╗██║ ██╔╝██╔════╝╚══██╔══╝${RESET}"
    echo -e "  ${CYAN}${BOLD} ██╔████╔██║███████║██████╔╝█████╔╝ █████╗     ██║${RESET}   ${DIM}▸ US EQUITY${RESET}"
    echo -e "  ${CYAN}${BOLD} ██║╚██╔╝██║██╔══██║██╔══██╗██╔═██╗ ██╔══╝     ██║${RESET}"
    echo -e "  ${CYAN}${BOLD} ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██╗███████╗   ██║${RESET}"
    echo -e "  ${CYAN}${BOLD} ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝${RESET}"
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
    echo -e "  ${DIM}${CYAN}══════════════════════════════════════════════════════════════════════${RESET}"
    echo ""
}

log()   { echo -e "  ${ARROW}  $1"; }
ok()    { echo -e "  ${CHECK}  ${GREEN}$1${RESET}"; }
fail()  { echo -e "  ${CROSS}  ${RED}$1${RESET}"; }
warn()  { echo -e "  ${SPARKLE}  ${YELLOW}$1${RESET}"; }
dim()   { echo -e "  ${DIM}$1${RESET}"; }

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

separator() {
    echo -e "  ${DIM}──────────────────────────────────────────────────${RESET}"
}

check_python() {
    local py=""
    for candidate in python3 python; do
        if command -v "$candidate" &>/dev/null; then
            py="$candidate"
            break
        fi
    done

    if [[ -z "$py" ]]; then
        fail "Python not found. Please install Python ${PYTHON_MIN}+"
        exit 1
    fi

    local ver
    ver=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local major minor
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)
    local req_major req_minor
    req_major=$(echo "$PYTHON_MIN" | cut -d. -f1)
    req_minor=$(echo "$PYTHON_MIN" | cut -d. -f2)

    if (( major < req_major || (major == req_major && minor < req_minor) )); then
        fail "Python ${ver} found, but ${PYTHON_MIN}+ is required"
        exit 1
    fi

    ok "Python ${ver} detected (${py})"
    PYTHON="$py"
}

setup_venv() {
    if [[ -d "$VENV_DIR" ]]; then
        ok "Virtual environment exists"
    else
        log "Creating virtual environment..."
        "$PYTHON" -m venv "$VENV_DIR"
        ok "Virtual environment created at ${DIM}.venv/${RESET}"
    fi

    if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
        fail "Virtual environment Python not found at ${VENV_DIR}/bin/python"
        exit 1
    fi

    ok "Virtual environment ready"
}

install_deps() {
    if [[ ! -f "$REQ_FILE" ]]; then
        fail "requirements.txt not found!"
        exit 1
    fi

    local venv_python="${VENV_DIR}/bin/python"
    local missing=()

    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if ! "$venv_python" -c "import ${pkg//-/_}" &>/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done < "$REQ_FILE"

    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "All dependencies already installed"
        return
    fi

    log "Installing dependencies: ${missing[*]}"
    "$venv_python" -m pip install "${missing[@]}" --quiet 2>/dev/null
    ok "Dependencies installed"
}

show_resume_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${CYAN}Mode:${RESET} resume / incremental update"
    echo -e "  ${DIM}Uses current US rows in scan_state.db to decide what to rescan.${RESET}"
    echo -e "  ${DIM}Every scan event is archived permanently in scan_mega_history.db.${RESET}"
    echo ""
}

show_fresh_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${YELLOW}Mode:${RESET} fresh / reset US working state"
    echo -e "  ${DIM}This clears US rows from scan_state.db and deletes US JSON/log outputs.${RESET}"
    echo -e "  ${DIM}It does NOT delete scan_mega_history.db, so historical scores remain archived.${RESET}"
    echo ""
}

show_history_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${MAGENTA}Mode:${RESET} archive history"
    echo -e "  ${DIM}Reads permanent US history from scan_mega_history.db.${RESET}"
    echo ""
}

show_summary_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${CYAN}Mode:${RESET} latest scan summary"
    echo -e "  ${DIM}Reads the newest US results and prints the top 30 ranked names in a terminal table.${RESET}"
    echo ""
}

show_diff_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${ORANGE}Mode:${RESET} latest scan diff"
    echo -e "  ${DIM}Compares current US results against the newest older snapshot and archives the diff output.${RESET}"
    echo ""
}

show_report_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${CYAN}Mode:${RESET} latest scan report"
    echo -e "  ${DIM}Prints a richer US market report and saves that output payload in the permanent archive DB.${RESET}"
    echo ""
}

show_artifact_history_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${ORANGE}Mode:${RESET} artifact history"
    echo -e "  ${DIM}Shows archived generated outputs like diff, report, export, doctor, and compare views.${RESET}"
    echo ""
}

show_archive_query_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${CYAN}Mode:${RESET} archive query"
    echo -e "  ${DIM}Browses archived command-output rows directly, with optional command and text filters.${RESET}"
    echo ""
}

show_ticker_history_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${CYAN}Mode:${RESET} ticker history"
    echo -e "  ${DIM}Shows one US ticker's archived score timeline, latest profile, and recent scan events.${RESET}"
    echo ""
}

show_leaderboard_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${ORANGE}Mode:${RESET} leaderboard"
    echo -e "  ${DIM}Shows current leaders plus historical consistency, score-hit, and near-high rankings.${RESET}"
    echo ""
}

show_sector_report_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${CYAN}Mode:${RESET} sector report"
    echo -e "  ${DIM}Shows sector-level summary for the latest US scan and can drill into one sector table.${RESET}"
    echo ""
}

show_sector_history_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${ORANGE}Mode:${RESET} sector history"
    echo -e "  ${DIM}Shows archived sector-move history across scan dates and can drill into one sector timeline.${RESET}"
    echo ""
}

show_new_highs_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${ORANGE}Mode:${RESET} near 52W high"
    echo -e "  ${DIM}Shows only the latest US stocks flagged as Near 52W High, with sector breakdown.${RESET}"
    echo ""
}

show_compare_markets_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${CYAN}Mode:${RESET} compare markets"
    echo -e "  ${DIM}Compares the latest US and India market result sets side by side and archives the output.${RESET}"
    echo ""
}

show_daily_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${ORANGE}Mode:${RESET} daily workflow"
    echo -e "  ${DIM}Runs US scan, then India scan, then archives fresh reports/diffs, prints cross-market comparison, and auto-exports a workflow bundle.${RESET}"
    echo ""
}

show_daily_full_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${ORANGE}Mode:${RESET} daily full workflow"
    echo -e "  ${DIM}Runs both scans, then doctor/report/diff/sector/new-high review for both markets, India cap-class tables, compare-markets, and auto-exports a workflow bundle.${RESET}"
    echo ""
}

show_doctor_mode() {
    separator
    echo ""
    echo -e "  ${BOLD}${CYAN}Mode:${RESET} doctor"
    echo -e "  ${DIM}Checks environment, result freshness, snapshots, working DB, and archive DB health.${RESET}"
    echo ""
}

show_export_mode() {
    local export_scope="${1:-market}"
    separator
    echo ""
    echo -e "  ${BOLD}${ORANGE}Mode:${RESET} ${export_scope} export"
    echo -e "  ${DIM}Exports the latest US ${export_scope} view to CSV and/or Markdown and stores the export metadata in the archive DB.${RESET}"
    echo ""
}

reset_us_state() {
    log "Clearing US working state from scan_state.db..."
    "$PYTHON" "$STATE_TOOL" reset --db "$STATE_DB" --market US >/dev/null
    ok "US working state cleared"
}

delete_us_outputs() {
    log "Deleting US runtime outputs..."
    rm -f "$RESULT_FILE"
    rm -f "${SCRIPT_DIR}"/scanner_results_*.json
    rm -f "$LEGACY_LOG"
    ok "US JSON outputs and legacy log removed"
}

show_us_history() {
    if [[ ! -f "$ARCHIVE_DB" ]]; then
        warn "scan_mega_history.db not found yet. Run a scan first."
        exit 0
    fi
    "$PYTHON" "$STATE_TOOL" history --db "$ARCHIVE_DB" --archive-db "$ARCHIVE_DB" --market US
}

show_us_summary() {
    "$PYTHON" "$STATE_TOOL" summary --market US --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
}

show_us_diff() {
    "$PYTHON" "$STATE_TOOL" diff --market US --results-file "$RESULT_FILE" --archive-db "$ARCHIVE_DB" --limit 15
}

show_us_report() {
    "$PYTHON" "$STATE_TOOL" report --market US --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
}

show_us_artifact_history() {
    local artifact_type="${1:-}"
    local cmd=("$PYTHON" "$STATE_TOOL" artifact-history --db "$ARCHIVE_DB" --market US --limit 25)
    if [[ -n "$artifact_type" ]]; then
        cmd+=(--artifact-type "$artifact_type")
    fi
    "${cmd[@]}"
}

show_us_archive_query() {
    local command_filter="${1:-}"
    local search_filter="${2:-}"
    local cmd=("$PYTHON" "$STATE_TOOL" archive-query --db "$ARCHIVE_DB" --market US --limit 25)
    if [[ -n "$command_filter" && "$command_filter" != "all" && "$command_filter" != "*" ]]; then
        cmd+=(--command-name "$command_filter")
    fi
    if [[ -n "$search_filter" ]]; then
        cmd+=(--search "$search_filter")
    fi
    "${cmd[@]}"
}

show_us_ticker_history() {
    local ticker="${1:-}"
    if [[ -z "$ticker" ]]; then
        fail "ticker-history requires a ticker symbol, e.g. ./start_scan.sh ticker-history NVDA"
        exit 1
    fi
    "$PYTHON" "$STATE_TOOL" ticker-history --market US --db "$ARCHIVE_DB" --ticker "$ticker" --archive-db "$ARCHIVE_DB" --limit 20
}

show_us_leaderboard() {
    "$PYTHON" "$STATE_TOOL" leaderboard --market US --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 15
}

show_us_sector_report() {
    local sector_query="${1:-}"
    local cmd=("$PYTHON" "$STATE_TOOL" sector-report --market US --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30)
    if [[ -n "$sector_query" ]]; then
        cmd+=(--sector "$sector_query")
    fi
    "${cmd[@]}"
}

show_us_sector_history() {
    local sector_query="${1:-}"
    local cmd=("$PYTHON" "$STATE_TOOL" sector-history --market US --db "$ARCHIVE_DB" --archive-db "$ARCHIVE_DB" --limit 20)
    if [[ -n "$sector_query" ]]; then
        cmd+=(--sector "$sector_query")
    fi
    "${cmd[@]}"
}

show_us_new_highs() {
    "$PYTHON" "$STATE_TOOL" new-highs --market US --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
}

show_compare_markets() {
    "$PYTHON" "$STATE_TOOL" compare-markets --us-results-file "$RESULT_FILE" --india-results-file "$INDIA_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB"
}

show_us_doctor() {
    "$PYTHON" "$STATE_TOOL" doctor --market US --results-file "$RESULT_FILE" --state-db "$STATE_DB" --archive-db "$ARCHIVE_DB" --venv-dir "$VENV_DIR" --scanner-file "$SCANNER" --requirements-file "$REQ_FILE"
}

show_us_export() {
    local export_format="${1:-both}"
    local dataset="${2:-market}"
    local sector_query="${3:-}"
    local cmd=("$PYTHON" "$STATE_TOOL" export --market US --results-file "$RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --out-dir "$EXPORT_DIR" --format "$export_format" --dataset "$dataset" --limit 200)
    if [[ -n "$sector_query" ]]; then
        cmd+=(--sector "$sector_query")
    fi
    "${cmd[@]}"
}

export_workflow_bundle() {
    local workflow_name="$1"
    separator
    echo ""
    echo -e "  ${BOLD}${MAGENTA}▶  EXPORTING ${workflow_name^^} BUNDLE${RESET}"
    echo ""
    separator
    echo ""
    "$PYTHON" "$STATE_TOOL" workflow-export \
        --workflow "$workflow_name" \
        --origin-market US \
        --us-results-file "$RESULT_FILE" \
        --india-results-file "$INDIA_RESULT_FILE" \
        --db "$STATE_DB" \
        --archive-db "$ARCHIVE_DB" \
        --out-dir "$EXPORT_DIR/workflows" \
        --limit 30 \
        --us-venv-dir "$VENV_DIR" \
        --india-venv-dir "$SCRIPT_DIR/venv" \
        --us-scanner-file "$SCANNER" \
        --india-scanner-file "$SCRIPT_DIR/india_scanner.py" \
        --us-requirements-file "$REQ_FILE"
}

run_scanner() {
    separator
    echo ""
    echo -e "  ${BOLD}${MAGENTA}▶  LAUNCHING SCANNER${RESET}"
    echo ""
    separator
    echo ""

    cd "$SCRIPT_DIR"
    "${VENV_DIR}/bin/python" scanner.py
}

run_daily_flow() {
    separator
    echo ""
    echo -e "  ${BOLD}${MAGENTA}▶  RUNNING US DAILY PASS${RESET}"
    echo ""
    separator
    echo ""
    run_scanner

    if [[ -x "$INDIA_SCRIPT" || -f "$INDIA_SCRIPT" ]]; then
        separator
        echo ""
        echo -e "  ${BOLD}${MAGENTA}▶  RUNNING INDIA DAILY PASS${RESET}"
        echo ""
        separator
        echo ""
        bash "$INDIA_SCRIPT" run
    else
        warn "India launcher not found at ${INDIA_SCRIPT}; skipping India scan"
    fi

    separator
    echo ""
    echo -e "  ${BOLD}${MAGENTA}▶  ARCHIVING REPORTS, DIFFS, AND MARKET COMPARISON${RESET}"
    echo ""
    separator
    echo ""

    show_us_report
    show_us_diff
    "$PYTHON" "$STATE_TOOL" report --market IN --results-file "$INDIA_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
    "$PYTHON" "$STATE_TOOL" diff --market IN --results-file "$INDIA_RESULT_FILE" --archive-db "$ARCHIVE_DB" --limit 15
    show_compare_markets
    export_workflow_bundle "daily"
}

run_daily_full_flow() {
    separator
    echo ""
    echo -e "  ${BOLD}${MAGENTA}▶  RUNNING US DAILY FULL PASS${RESET}"
    echo ""
    separator
    echo ""
    run_scanner

    if [[ -x "$INDIA_SCRIPT" || -f "$INDIA_SCRIPT" ]]; then
        separator
        echo ""
        echo -e "  ${BOLD}${MAGENTA}▶  RUNNING INDIA DAILY FULL PASS${RESET}"
        echo ""
        separator
        echo ""
        bash "$INDIA_SCRIPT" run
    else
        warn "India launcher not found at ${INDIA_SCRIPT}; skipping India scan"
    fi

    separator
    echo ""
    echo -e "  ${BOLD}${MAGENTA}▶  RUNNING FULL MARKET REVIEW${RESET}"
    echo ""
    separator
    echo ""

    show_us_doctor
    "$PYTHON" "$STATE_TOOL" doctor --market IN --results-file "$INDIA_RESULT_FILE" --state-db "$STATE_DB" --archive-db "$ARCHIVE_DB" --venv-dir "$SCRIPT_DIR/venv" --scanner-file "$SCRIPT_DIR/india_scanner.py"

    show_us_report
    show_us_diff
    show_us_sector_report
    show_us_sector_history
    show_us_new_highs

    "$PYTHON" "$STATE_TOOL" report --market IN --results-file "$INDIA_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
    "$PYTHON" "$STATE_TOOL" diff --market IN --results-file "$INDIA_RESULT_FILE" --archive-db "$ARCHIVE_DB" --limit 15
    "$PYTHON" "$STATE_TOOL" sector-report --market IN --results-file "$INDIA_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
    "$PYTHON" "$STATE_TOOL" sector-history --market IN --db "$ARCHIVE_DB" --archive-db "$ARCHIVE_DB" --limit 20
    "$PYTHON" "$STATE_TOOL" new-highs --market IN --results-file "$INDIA_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --limit 30
    "$PYTHON" "$STATE_TOOL" summary --market IN --results-file "$INDIA_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --cap-class smallcap --limit 30
    "$PYTHON" "$STATE_TOOL" summary --market IN --results-file "$INDIA_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --cap-class midcap --limit 30
    "$PYTHON" "$STATE_TOOL" summary --market IN --results-file "$INDIA_RESULT_FILE" --db "$STATE_DB" --archive-db "$ARCHIVE_DB" --cap-class largecap --limit 30

    show_compare_markets
    export_workflow_bundle "daily-full"
}

run_downloader() {
    separator
    echo ""
    echo -e "  ${BOLD}${MAGENTA}▶  LAUNCHING MARKET CAP DOWNLOADER${RESET}"
    echo ""
    separator
    echo ""

    cd "$SCRIPT_DIR"
    python 100M_10B_Market_Cap.py
}

clean_env() {
    if [[ -d "$VENV_DIR" ]]; then
        rm -rf "$VENV_DIR"
        ok "Virtual environment removed"
    else
        warn "No virtual environment to remove"
    fi
}

show_help() {
    banner
    echo -e "  ${BOLD}Usage:${RESET}  ./start_scan.sh ${CYAN}<command>${RESET}"
    echo ""
    echo -e "  ${BOLD}Commands:${RESET}"
    echo -e "    ${CYAN}run${RESET}        Resume/update US scan using ${BOLD}scan_state.db${RESET}"
    echo -e "    ${CYAN}fresh${RESET}      Reset US working state, delete US outputs, then rescan"
    echo -e "    ${CYAN}summary${RESET}    Show the latest US top 30 summary table"
    echo -e "    ${CYAN}artifact-history${RESET} Show archived generated outputs for US and shared artifacts"
    echo -e "    ${CYAN}archive-query${RESET} Browse archived US command-output rows directly"
    echo -e "    ${CYAN}ticker-history${RESET}  Show archived score history for one ticker"
    echo -e "    ${CYAN}leaderboard${RESET} Show current and historical US leader tables"
    echo -e "    ${CYAN}sector-report${RESET} Show latest sector summary or drill into one sector"
    echo -e "    ${CYAN}sector-history${RESET} Show archived sector history snapshot or one sector timeline"
    echo -e "    ${CYAN}sector${RESET}     Friendly sector workflow alias for report/history/export"
    echo -e "    ${CYAN}new-highs${RESET}  Show only latest US Near 52W High names"
    echo -e "    ${CYAN}compare-markets${RESET} Compare latest US and India outputs side by side"
    echo -e "    ${CYAN}daily${RESET}      Run US scan, India scan, then reports/diffs/compare and auto-export bundle"
    echo -e "    ${CYAN}daily-full${RESET} Run both scans, full review analytics, then compare and auto-export bundle"
    echo -e "    ${CYAN}doctor${RESET}     Run environment and data health checks"
    echo -e "    ${CYAN}export${RESET}     Export latest US market view as csv, md, or both"
    echo -e "    ${CYAN}diff${RESET}       Compare latest US results vs previous snapshot"
    echo -e "    ${CYAN}report${RESET}     Generate a richer US report and archive it"
    echo -e "    ${CYAN}history${RESET}    Show archived US scan history from ${BOLD}scan_mega_history.db${RESET}"
    echo -e "    ${CYAN}download${RESET}   Set up venv, install deps, run ${BOLD}100M_10B_Market_Cap.py${RESET}"
    echo -e "    ${CYAN}clean${RESET}      Remove the virtual environment"
    echo -e "    ${CYAN}help${RESET}       Show this help message"
    echo ""
    echo -e "  ${BOLD}Scan State:${RESET}"
    echo -e "    ${DIM}Working state:${RESET}  scan_state.db  (reset by ${CYAN}fresh${RESET})"
    echo -e "    ${DIM}Archive:${RESET}        scan_mega_history.db  (never deleted by ${CYAN}fresh${RESET})"
    echo -e "    ${DIM}Fresh removes:${RESET}  scanner_results.json, scanner_results_YYYY-MM-DD.json, scanner_scanned.txt"
    echo ""
    echo -e "  ${BOLD}Examples:${RESET}"
    echo -e "    ${DIM}./start_scan.sh run${RESET}         # Resume / incremental update"
    echo -e "    ${DIM}./start_scan.sh fresh${RESET}       # Fresh US scan, archive preserved"
    echo -e "    ${DIM}./start_scan.sh summary${RESET}     # Top 30 from latest US scan"
    echo -e "    ${DIM}./start_scan.sh artifact-history${RESET} # Show archived outputs"
    echo -e "    ${DIM}./start_scan.sh artifact-history report${RESET} # Only report artifacts"
    echo -e "    ${DIM}./start_scan.sh archive-query${RESET} # Browse archived rows"
    echo -e "    ${DIM}./start_scan.sh archive-query summary${RESET} # Only summary rows"
    echo -e "    ${DIM}./start_scan.sh archive-query ticker-history NVDA${RESET} # Search archive rows for NVDA"
    echo -e "    ${DIM}./start_scan.sh ticker-history NVDA${RESET} # One ticker timeline"
    echo -e "    ${DIM}./start_scan.sh leaderboard${RESET} # Current + historical leaders"
    echo -e "    ${DIM}./start_scan.sh sector-report${RESET} # Sector summary for latest scan"
    echo -e "    ${DIM}./start_scan.sh sector-report Software${RESET} # Drill into one sector"
    echo -e "    ${DIM}./start_scan.sh sector-report export csv Software${RESET} # Export one sector report as CSV"
    echo -e "    ${DIM}./start_scan.sh sector-history${RESET} # Latest archived sector snapshot with deltas"
    echo -e "    ${DIM}./start_scan.sh sector-history Energy${RESET} # One sector timeline"
    echo -e "    ${DIM}./start_scan.sh sector-history export .md Energy${RESET} # Export sector history as Markdown"
    echo -e "    ${DIM}./start_scan.sh sector report Software${RESET} # Alias for sector-report Software"
    echo -e "    ${DIM}./start_scan.sh sector report export md Software${RESET} # Alias export syntax"
    echo -e "    ${DIM}./start_scan.sh sector history Energy${RESET} # Alias for sector-history Energy"
    echo -e "    ${DIM}./start_scan.sh new-highs${RESET} # Latest Near 52W High names"
    echo -e "    ${DIM}./start_scan.sh compare-markets${RESET} # Compare US and India"
    echo -e "    ${DIM}./start_scan.sh daily${RESET} # Full daily workflow"
    echo -e "    ${DIM}./start_scan.sh daily full${RESET} # Full daily workflow with all review tables"
    echo -e "    ${DIM}./start_scan.sh daily-full${RESET} # Same as daily full"
    echo -e "    ${DIM}./start_scan.sh us daily scan${RESET} # Natural alias for daily"
    echo -e "    ${DIM}./start_scan.sh us daily full${RESET} # Natural alias for daily full"
    echo -e "    ${DIM}./start_scan.sh us compare markets${RESET} # Natural alias for compare-markets"
    echo -e "    ${DIM}./start_scan.sh doctor${RESET} # Health check"
    echo -e "    ${DIM}./start_scan.sh export${RESET} # Market export in CSV + Markdown"
    echo -e "    ${DIM}./start_scan.sh export csv${RESET} # Market export in CSV only"
    echo -e "    ${DIM}./start_scan.sh diff${RESET}        # Compare latest scan vs previous snapshot"
    echo -e "    ${DIM}./start_scan.sh report${RESET}      # Full latest-scan report with stats"
    echo -e "    ${DIM}./start_scan.sh history${RESET}     # Inspect archived US scan history"
    echo -e "    ${DIM}./start_scan.sh download${RESET}    # Download market cap data first"
    echo -e "    ${DIM}./start_scan.sh clean${RESET}       # Wipe venv and start fresh"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────

CMD="${1:-help}"
ARG1="${2:-}"
ARG2="${3:-}"
ARG3="${4:-}"

case "$CMD" in
    run|resume)
        banner
        check_python
        show_resume_mode
        setup_venv
        install_deps
        run_scanner
        ;;
    fresh)
        banner
        check_python
        show_fresh_mode
        reset_us_state
        delete_us_outputs
        setup_venv
        install_deps
        run_scanner
        ;;
    history)
        banner
        check_python
        show_history_mode
        show_us_history
        ;;
    summary)
        banner
        check_python
        show_summary_mode
        show_us_summary
        ;;
    artifact-history)
        banner
        check_python
        show_artifact_history_mode
        show_us_artifact_history "$ARG1"
        ;;
    archive-query)
        banner
        check_python
        show_archive_query_mode
        show_us_archive_query "$ARG1" "${*:3}"
        ;;
    ticker-history)
        banner
        check_python
        show_ticker_history_mode
        show_us_ticker_history "$ARG1"
        ;;
    leaderboard)
        banner
        check_python
        show_leaderboard_mode
        show_us_leaderboard
        ;;
    sector-report)
        banner
        check_python
        if [[ "$ARG1" == "export" ]]; then
            show_export_mode "sector report"
            show_us_export "$(normalize_export_format "$ARG2")" "sector-report" "${*:4}"
        else
            show_sector_report_mode
            show_us_sector_report "${*:2}"
        fi
        ;;
    sector-history)
        banner
        check_python
        if [[ "$ARG1" == "export" ]]; then
            show_export_mode "sector history"
            show_us_export "$(normalize_export_format "$ARG2")" "sector-history" "${*:4}"
        else
            show_sector_history_mode
            show_us_sector_history "${*:2}"
        fi
        ;;
    sector)
        banner
        check_python
        case "$ARG1" in
            report)
                if [[ "$ARG2" == "export" ]]; then
                    show_export_mode "sector report"
                    show_us_export "$(normalize_export_format "$ARG3")" "sector-report" "${*:5}"
                else
                    show_sector_report_mode
                    show_us_sector_report "${*:3}"
                fi
                ;;
            history)
                if [[ "$ARG2" == "export" ]]; then
                    show_export_mode "sector history"
                    show_us_export "$(normalize_export_format "$ARG3")" "sector-history" "${*:5}"
                else
                    show_sector_history_mode
                    show_us_sector_history "${*:3}"
                fi
                ;;
            *)
                fail "Usage: ./start_scan.sh sector report [sector] | sector report export [csv|md|both] [sector] | sector history [sector] | sector history export [csv|md|both] [sector]"
                exit 1
                ;;
        esac
        ;;
    new-highs)
        banner
        check_python
        show_new_highs_mode
        show_us_new_highs
        ;;
    compare-markets)
        banner
        check_python
        show_compare_markets_mode
        show_compare_markets
        ;;
    us)
        banner
        check_python
        case "$ARG1 $ARG2" in
            "daily scan")
                show_daily_mode
                setup_venv
                install_deps
                run_daily_flow
                ;;
            "daily full")
                show_daily_full_mode
                setup_venv
                install_deps
                run_daily_full_flow
                ;;
            "compare markets")
                show_compare_markets_mode
                show_compare_markets
                ;;
            *)
                fail "Usage: ./start_scan.sh us daily scan | ./start_scan.sh us daily full | ./start_scan.sh us compare markets"
                exit 1
                ;;
        esac
        ;;
    daily)
        banner
        check_python
        if [[ "$ARG1" == "full" ]]; then
            show_daily_full_mode
            setup_venv
            install_deps
            run_daily_full_flow
        else
            show_daily_mode
            setup_venv
            install_deps
            run_daily_flow
        fi
        ;;
    daily-full)
        banner
        check_python
        show_daily_full_mode
        setup_venv
        install_deps
        run_daily_full_flow
        ;;
    doctor)
        banner
        check_python
        show_doctor_mode
        show_us_doctor
        ;;
    export)
        banner
        check_python
        show_export_mode "market"
        show_us_export "$(normalize_export_format "$ARG1")" "market"
        ;;
    diff)
        banner
        check_python
        show_diff_mode
        show_us_diff
        ;;
    report)
        banner
        check_python
        show_report_mode
        show_us_report
        ;;
    download)
        banner
        check_python
        setup_venv
        install_deps
        run_downloader
        ;;
    clean)
        banner
        clean_env
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        fail "Unknown command: $CMD"
        echo ""
        show_help
        exit 1
        ;;
esac
