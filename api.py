import asyncio
import json
import os
import re
import shlex
import time
from typing import Any, AsyncGenerator

from fastapi import FastAPI
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from sse_starlette.sse import EventSourceResponse

app = FastAPI(title="SignalScan Pro Backend")

# Serve the current directory as static so the dashboard can fetch result files directly.
app.mount("/static", StaticFiles(directory="."), name="static")

ANSI_REGEX = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
BANNER_CHARS = "█╔╗╚╝"


def strip_ansi(text: str) -> str:
    return ANSI_REGEX.sub("", text).replace("\r", "")


def sse_event(event: str, data: dict[str, Any]) -> dict[str, str]:
    return {"event": event, "data": json.dumps(data, ensure_ascii=False)}


def is_separator_line(line: str) -> bool:
    stripped = line.strip()
    return bool(stripped) and all(char in "═─-_" for char in stripped)


def is_box_border(line: str) -> bool:
    stripped = line.strip()
    return stripped.startswith(("┌", "├", "└"))


def is_box_row(line: str) -> bool:
    return line.strip().startswith("│")


def contains_banner_art(line: str) -> bool:
    return any(char in line for char in BANNER_CHARS)


def looks_like_report_title(line: str) -> bool:
    stripped = line.strip()
    if not stripped or len(stripped) > 96:
        return False
    if contains_banner_art(stripped) or is_separator_line(stripped):
        return False
    if any(token in stripped for token in ("Mode:", "Momentum Scanner", "Initializing", "Checking Python")):
        return False
    if stripped.startswith(("Reads ", "Shows ", "Uses ", "Every ", "Runs ", "Checks ")):
        return False

    letters = re.sub(r"[^A-Za-z]", "", stripped)
    return len(letters) >= 6 and stripped == stripped.upper()


def looks_like_heading(line: str) -> bool:
    stripped = line.strip()
    if not stripped or len(stripped) > 80:
        return False
    if is_separator_line(stripped) or is_box_border(stripped) or is_box_row(stripped):
        return False
    if ":" in stripped or "|" in stripped or stripped.endswith("."):
        return False
    if any(token in stripped for token in ("Mode", "Python", "Initializing", "Momentum Scanner")):
        return False
    return True


def parse_metric_line(line: str) -> tuple[list[dict[str, str]], list[str]]:
    metrics: list[dict[str, str]] = []
    pills: list[str] = []

    for part in [item.strip() for item in line.split("|") if item.strip()]:
        if ":" in part:
            label, value = part.split(":", 1)
            metrics.append({"label": label.strip(), "value": value.strip()})
        else:
            pills.append(part)

    return metrics, pills


def parse_box_table(table_lines: list[str]) -> dict[str, Any] | None:
    rows = [line for line in table_lines if is_box_row(line)]
    if len(rows) < 2:
        return None

    header = [cell.strip() for cell in rows[0].strip()[1:-1].split("│")]
    body = [
        [cell.strip() for cell in row.strip()[1:-1].split("│")]
        for row in rows[1:]
    ]

    return {"columns": header, "rows": body}


def parse_command_output(text: str, market: str, action: str, arg: str | None) -> dict[str, Any]:
    cleaned_text = strip_ansi(text)
    lines = [line.rstrip() for line in cleaned_text.splitlines()]
    title = ""
    title_index = -1

    for index, line in enumerate(lines):
        if looks_like_report_title(line):
            title = line.strip()
            title_index = index
            break

    if not title:
        market_label = "India" if market == "IN" else "US"
        title = f"{market_label} {action}".strip()

    overview: list[dict[str, str]] = []
    pills: list[str] = []
    sections: list[dict[str, Any]] = []

    start_index = max(title_index + 1, 0)
    while start_index < len(lines) and not lines[start_index].strip():
        start_index += 1

    cursor = start_index
    while cursor < len(lines):
        line = lines[cursor].strip()
        if not line:
            cursor += 1
            continue
        if is_separator_line(line):
            cursor += 1
            continue
        if is_box_border(line) or looks_like_heading(line):
            break
        if contains_banner_art(line):
            cursor += 1
            continue
        metrics, line_pills = parse_metric_line(line)
        overview.extend(metrics)
        pills.extend(line_pills)
        cursor += 1

    pending_heading: str | None = None
    note_buffer: list[str] = []

    def flush_notes() -> None:
        nonlocal note_buffer
        if not note_buffer:
            return
        title_for_notes = pending_heading
        sections.append(
            {
                "type": "notes",
                "title": title_for_notes,
                "items": note_buffer[:],
            }
        )
        note_buffer = []

    while cursor < len(lines):
        raw_line = lines[cursor]
        line = raw_line.strip()

        if not line or is_separator_line(line):
            flush_notes()
            pending_heading = None
            cursor += 1
            continue

        if contains_banner_art(line):
            cursor += 1
            continue

        if is_box_border(line):
            table_lines = [raw_line]
            cursor += 1
            while cursor < len(lines):
                table_lines.append(lines[cursor])
                if lines[cursor].strip().startswith("└"):
                    break
                cursor += 1
            table = parse_box_table(table_lines)
            if table:
                flush_notes()
                sections.append(
                    {
                        "type": "table",
                        "title": pending_heading,
                        "columns": table["columns"],
                        "rows": table["rows"],
                    }
                )
                pending_heading = None
            cursor += 1
            continue

        if looks_like_heading(line):
            flush_notes()
            pending_heading = line
            cursor += 1
            continue

        if any(token in line for token in ("Mode:", "Momentum Scanner", "Checking Python")):
            cursor += 1
            continue

        metrics, line_pills = parse_metric_line(line)
        if metrics and not note_buffer and not pending_heading:
            overview.extend(metrics)
            pills.extend(line_pills)
        elif metrics or line_pills:
            note_buffer.append(line)
        else:
            note_buffer.append(line)
        cursor += 1

    flush_notes()

    return {
        "title": title,
        "market": market,
        "action": action,
        "argument": arg,
        "overview": overview,
        "pills": pills,
        "sections": sections,
    }


def classify_log_line(line: str) -> str:
    stripped = line.strip()
    upper = stripped.upper()
    if not stripped:
        return "muted"
    if any(token in upper for token in ("TRACEBACK", "ERROR", "FAILED", "FAIL", "✗", "EXITED WITH CODE")):
        return "error"
    if any(token in upper for token in ("WARN", "WARNING", "⚠")):
        return "warn"
    if any(token in upper for token in ("PASS", "SUCCESS", "COMPLETED", "✓", "✔")):
        return "success"
    if stripped.startswith(("▶", "➜")) or upper.endswith(":") or looks_like_report_title(stripped):
        return "info"
    return "neutral"


async def run_cmd_and_yield(
    cmd: list[str],
    market: str,
    action: str,
    arg: str | None = None,
) -> AsyncGenerator[dict[str, str], None]:
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    started_at = time.time()
    command_display = shlex.join(cmd)

    yield sse_event(
        "meta",
        {
            "market": market,
            "action": action,
            "argument": arg,
            "command": command_display,
            "started_at": started_at,
        },
    )

    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        env=env,
    )

    raw_lines: list[str] = []

    try:
        while True:
            line = await process.stdout.readline()
            if not line:
                break

            decoded_line = line.decode("utf-8", errors="replace")
            clean_line = strip_ansi(decoded_line).rstrip("\n")
            raw_lines.append(clean_line)

            yield sse_event(
                "log",
                {
                    "line": clean_line,
                    "level": classify_log_line(clean_line),
                    "timestamp": time.time(),
                },
            )

        await process.wait()

        cleaned_output = "\n".join(raw_lines)
        report = parse_command_output(cleaned_output, market=market, action=action, arg=arg)
        yield sse_event("report", report)
        yield sse_event(
            "complete",
            {
                "status": "success" if process.returncode == 0 else "error",
                "returncode": process.returncode,
                "duration_seconds": round(time.time() - started_at, 2),
                "command": command_display,
            },
        )
    except asyncio.CancelledError:
        process.terminate()
        await process.wait()
        cleaned_output = "\n".join(raw_lines)
        report = parse_command_output(cleaned_output, market=market, action=action, arg=arg)
        yield sse_event("report", report)
        yield sse_event(
            "complete",
            {
                "status": "cancelled",
                "returncode": None,
                "duration_seconds": round(time.time() - started_at, 2),
                "command": command_display,
            },
        )


@app.get("/", response_class=HTMLResponse)
async def serve_dashboard():
    with open("dashboard.html", "r") as file:
        return file.read()


@app.get("/{filename}")
async def serve_file(filename: str):
    if os.path.exists(filename):
        return FileResponse(filename)
    return {"error": "File not found"}


@app.get("/api/scan/us")
async def scan_us(action: str, arg: str | None = None):
    cmd = ["./start_scan.sh"]
    if action:
        cmd += action.split(" ")
    if arg:
        cmd.append(arg)
    return EventSourceResponse(run_cmd_and_yield(cmd, market="US", action=action, arg=arg))


@app.get("/api/scan/in")
async def scan_in(action: str, arg: str | None = None):
    cmd = ["./India_scan.sh"]
    if action:
        cmd += action.split(" ")
    if arg:
        cmd.append(arg)
    return EventSourceResponse(run_cmd_and_yield(cmd, market="IN", action=action, arg=arg))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=True)
