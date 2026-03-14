import ast
import os
import re
import shlex
from pathlib import Path


ENV_KEY_RE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=")


def _decode_value(raw_value: str) -> str:
    value = raw_value.strip()
    if not value:
        return ""
    if value[0] == value[-1] and value[0] in {"'", '"'}:
        try:
            parsed = ast.literal_eval(value)
            return "" if parsed is None else str(parsed)
        except Exception:
            return value[1:-1]
    return value


def load_env_file(path, override: bool = False):
    env_path = Path(path)
    loaded = {}
    if not env_path.exists():
        return loaded

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("export "):
            stripped = stripped[7:].lstrip()
        if "=" not in stripped:
            continue
        key, raw_value = stripped.split("=", 1)
        key = key.strip()
        if not key:
            continue
        value = _decode_value(raw_value)
        loaded[key] = value
        if override or key not in os.environ:
            os.environ[key] = value
    return loaded


def update_env_file(path, updates):
    env_path = Path(path)
    env_path.parent.mkdir(parents=True, exist_ok=True)
    existing_lines = []
    if env_path.exists():
        existing_lines = env_path.read_text(encoding="utf-8").splitlines()

    seen = set()
    new_lines = []
    for line in existing_lines:
        match = ENV_KEY_RE.match(line)
        if not match:
            new_lines.append(line)
            continue
        key = match.group(1)
        if key not in updates:
            new_lines.append(line)
            continue
        seen.add(key)
        new_lines.append(f"{key}={shlex.quote('' if updates[key] is None else str(updates[key]))}")

    missing = [key for key in updates if key not in seen]
    if missing and new_lines and new_lines[-1].strip():
        new_lines.append("")
    for key in missing:
        new_lines.append(f"{key}={shlex.quote('' if updates[key] is None else str(updates[key]))}")

    env_path.write_text("\n".join(new_lines).rstrip() + "\n", encoding="utf-8")

