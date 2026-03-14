import json
import os
import stat
from pathlib import Path
from typing import List


CONDITIONS_ENV_VAR = "SCAN_CONDITIONS_FILE"
PROJECT_DIR = Path(__file__).resolve().parent
EXAMPLE_CONDITIONS_FILE = PROJECT_DIR / "scan_conditions.example.json"
DEFAULT_CONDITIONS_FILE = PROJECT_DIR / ".scanner_secrets" / "scan_conditions.json"
LOCAL_FALLBACK_FILE = PROJECT_DIR / "scan_conditions.local.json"


def _default_candidate_paths() -> List[Path]:
    xdg_root = Path(os.getenv("XDG_CONFIG_HOME", Path.home() / ".config")).expanduser()
    return [
        DEFAULT_CONDITIONS_FILE,
        LOCAL_FALLBACK_FILE,
        xdg_root / "us_in_scanner" / "scan_conditions.json",
        Path.home() / ".us_in_scanner" / "scan_conditions.json",
    ]


def _candidate_paths() -> List[Path]:
    raw = os.getenv(CONDITIONS_ENV_VAR, "").strip()
    if raw:
        return [Path(raw).expanduser()]
    return _default_candidate_paths()


def _conditions_path() -> Path:
    paths = _candidate_paths()
    for path in paths:
        if path.exists():
            return path
    return paths[0]


def _warn_if_permissions_are_open(path: Path) -> None:
    try:
        mode = stat.S_IMODE(path.stat().st_mode)
    except OSError:
        return

    if mode & 0o077:
        print(
            f"⚠ Conditions file permissions are broad for {path}. "
            "Recommended: chmod 600 on the file and chmod 700 on its directory."
        )


def _load_file() -> dict:
    path = _conditions_path()
    if not path.exists():
        checked = "\n".join(f"  - {candidate}" for candidate in _candidate_paths())
        raise RuntimeError(
            "Secure scan conditions file not found. "
            f"Copy {EXAMPLE_CONDITIONS_FILE.name} to {DEFAULT_CONDITIONS_FILE} "
            f"or set {CONDITIONS_ENV_VAR}.\nChecked:\n{checked}"
        )

    _warn_if_permissions_are_open(path)

    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Invalid JSON in secure scan conditions file: {path}") from exc


def _require(data: dict, dotted_path: str):
    cur = data
    for part in dotted_path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            raise RuntimeError(f"Missing required secure scan condition: {dotted_path}")
        cur = cur[part]
    return cur


def load_scan_conditions(market: str) -> dict:
    normalized = market.strip().lower()
    payload = _load_file()

    market_cfg = _require(payload, normalized)
    primary = _require(market_cfg, "primary")
    scoring = _require(market_cfg, "scoring")
    ema_periods = _require(primary, "ema_periods")

    if not isinstance(ema_periods, list) or len(ema_periods) != 3:
        raise RuntimeError(
            f"Secure scan conditions for market '{market}' must define primary.ema_periods as a 3-item list."
        )

    return {
        "primary": {
            "high_lookback": _require(primary, "high_lookback"),
            "price_from_high": _require(primary, "price_from_high"),
            "turnover_window": _require(primary, "turnover_window"),
            "ema_periods": ema_periods,
            "min_turnover_m": primary.get("min_turnover_m"),
            "min_turnover_cr": primary.get("min_turnover_cr"),
        },
        "scoring": {
            "near_high_pct": _require(scoring, "near_high_pct"),
            "volume_spike_ratio": _require(scoring, "volume_spike_ratio"),
            "eps_growth_min": _require(scoring, "eps_growth_min"),
            "revenue_growth_min": _require(scoring, "revenue_growth_min"),
            "upper_circuit_pct": scoring.get("upper_circuit_pct"),
            "delivery_pct_min": scoring.get("delivery_pct_min"),
        },
    }
