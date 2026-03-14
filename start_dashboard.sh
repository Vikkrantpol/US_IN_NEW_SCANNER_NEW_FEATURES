#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║          US Stock Scanner — Dashboard Server                     ║
# ║          Usage:  ./start_dashboard.sh                            ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colors & Symbols ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[38;5;51m'
CYAN_SHADOW='\033[38;5;31m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
ORANGE='\033[38;5;214m'
ORANGE_SHADOW='\033[38;5;130m'
WHITE='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

CHECK="${GREEN}✔${RESET}"
CROSS="${RED}✘${RESET}"
ARROW="${CYAN}➜${RESET}"

PORT="${1:-8000}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

supports_layered_banner() {
    [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM:-}" != "dumb" ]]
}

print_3d_block() {
    local front_color="$1"
    local shadow_color="$2"
    local label_line="$3"
    local label_text="$4"
    shift 4
    local lines=("$@")
    local total="${#lines[@]}"
    local i=1

    if supports_layered_banner; then
        for line in "${lines[@]}"; do
            echo -e "    ${shadow_color}${line}${RESET}"
        done
        printf '\033[%sA' "$total"
    fi

    for line in "${lines[@]}"; do
        if [[ "$i" -eq "$label_line" ]]; then
            echo -e "  ${front_color}${BOLD}${line}${RESET}    ${DIM}${label_text}${RESET}"
        else
            echo -e "  ${front_color}${BOLD}${line}${RESET}"
        fi
        i=$((i + 1))
    done
}

banner() {
    local market_lines=(
        "███╗   ███╗ █████╗ ██████╗ ██╗  ██╗███████╗████████╗"
        "████╗ ████║██╔══██╗██╔══██╗██║ ██╔╝██╔════╝╚══██╔══╝"
        "██╔████╔██║███████║██████╔╝█████╔╝ █████╗     ██║"
        "██║╚██╔╝██║██╔══██║██╔══██╗██╔═██╗ ██╔══╝     ██║"
        "██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██╗███████╗   ██║"
        "╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝"
    )
    local dashboard_lines=(
        "██████╗  █████╗ ███████╗██╗  ██╗██████╗  ██████╗  █████╗ ██████╗ ██████╗ "
        "██╔══██╗██╔══██╗██╔════╝██║  ██║██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██╔══██╗"
        "██║  ██║███████║███████╗███████║██████╔╝██║   ██║███████║██████╔╝██║  ██║"
        "██║  ██║██╔══██║╚════██║██╔══██║██╔══██╗██║   ██║██╔══██║██╔══██╗██║  ██║"
        "██████╔╝██║  ██║███████║██║  ██║██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝"
        "╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ "
    )

    echo ""
    echo -e "  ${DIM}${CYAN}════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo ""
    print_3d_block "$CYAN" "$CYAN_SHADOW" 3 "▸ LIVE VIEW" "${market_lines[@]}"
    echo ""
    print_3d_block "$ORANGE" "$ORANGE_SHADOW" 0 "" "${dashboard_lines[@]}"
    echo ""
    echo -e "  ${DIM}${CYAN}════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "  ${DIM}${WHITE}Signal Dashboard${RESET}  ${DIM}·  by ${BOLD}Vikkrant${RESET}${DIM}  ·  Serving live view...${RESET}"
    echo -e "  ${DIM}${ORANGE}══════════════════════════════════════════════════════════════════════${RESET}"
    echo ""
}

banner

# ── Check Python ─────────────────────────────────────────────────
PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" &>/dev/null; then
        PYTHON="$candidate"
        break
    fi
done

if [[ -z "$PYTHON" ]]; then
    echo -e "  ${CROSS}  ${RED}Python not found. Please install Python 3.${RESET}"
    exit 1
fi
echo -e "  ${CHECK}  ${GREEN}Using ${PYTHON}${RESET}"

# ── Check dashboard.html exists ──────────────────────────────────
if [[ ! -f "${SCRIPT_DIR}/dashboard.html" ]]; then
    echo -e "  ${CROSS}  ${RED}dashboard.html not found in ${SCRIPT_DIR}${RESET}"
    exit 1
fi
echo -e "  ${CHECK}  ${GREEN}dashboard.html found${RESET}"

# ── Launch server ────────────────────────────────────────────────
echo ""
echo -e "  ${ARROW}  Starting HTTP server on port ${BOLD}${PORT}${RESET}"
echo -e "  ${ARROW}  Dashboard URL: ${BOLD}${CYAN}http://localhost:${PORT}/dashboard.html${RESET}"
echo ""
echo -e "  ${DIM}Press Ctrl+C to stop the server${RESET}"
echo ""

cd "$SCRIPT_DIR"

# Ensure dependencies are installed
source venv/bin/activate
if ! python -c "import fastapi" &>/dev/null; then
    echo -e "  ${DIM}Installing FastAPI requirements...${RESET}"
    pip install -q fastapi uvicorn sse-starlette httpx 
fi

export PORT=$PORT
uvicorn api:app --host 0.0.0.0 --port "$PORT" --reload --log-level warning

