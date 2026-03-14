#!/usr/bin/env python3

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import requests

from env_utils import load_env_file, update_env_file

try:
    from fyers_apiv3 import fyersModel
except ImportError as exc:
    raise SystemExit(f"fyers-apiv3 is required: {exc}")


STATUS_CONFIG_MISSING = 10
STATUS_TOKEN_MISSING = 11
STATUS_TOKEN_INVALID = 12


def _is_set(value):
    return bool(value and value.strip() and not value.startswith("YOUR_"))


def _read_config(env_file):
    load_env_file(env_file, override=True)
    return {
        "client_id": os.getenv("FYERS_CLIENT_ID", "").strip(),
        "secret_key": os.getenv("FYERS_SECRET_KEY", "").strip(),
        "redirect_uri": os.getenv("FYERS_REDIRECT_URI", "").strip(),
        "access_token": os.getenv("FYERS_ACCESS_TOKEN", "").strip(),
        "auth_code": os.getenv("FYERS_AUTH_CODE", "").strip(),
    }


def _build_session(config):
    return fyersModel.SessionModel(
        client_id=config["client_id"],
        redirect_uri=config["redirect_uri"],
        response_type="code",
        grant_type="authorization_code",
        secret_key=config["secret_key"],
    )


def _validate_token(config):
    if not _is_set(config["access_token"]):
        return False, {"message": "FYERS access token is not set"}

    try:
        response = requests.get(
            "https://api-t1.fyers.in/api/v3/profile",
            headers={
                "Authorization": f"{config['client_id']}:{config['access_token']}",
                "Content-Type": "application/json",
                "version": "3",
            },
            timeout=15,
        )
        payload = response.json()
    except Exception as exc:
        return False, {"message": str(exc)}
    return payload.get("code") == 200, payload


def _extract_auth_code(raw_input):
    value = raw_input.strip()
    if not value:
        return ""

    parsed = urlparse(value)
    candidates = []
    if parsed.query:
        candidates.append(parse_qs(parsed.query))
    if parsed.fragment:
        candidates.append(parse_qs(parsed.fragment))
    for candidate in candidates:
        for key in ("auth_code", "code"):
            values = candidate.get(key)
            if values and values[0].strip():
                return values[0].strip()

    if "auth_code=" in value or "code=" in value:
        for piece in value.replace("#", "&").split("&"):
            if piece.startswith("auth_code="):
                return piece.split("=", 1)[1].strip()
            if piece.startswith("code="):
                return piece.split("=", 1)[1].strip()
    return value


def cmd_status(args):
    config = _read_config(args.env_file)
    required = ("client_id", "secret_key", "redirect_uri")
    if not all(_is_set(config[key]) for key in required):
        print("CONFIG_MISSING")
        return STATUS_CONFIG_MISSING

    if not _is_set(config["access_token"]):
        print("TOKEN_MISSING")
        return STATUS_TOKEN_MISSING

    valid, response = _validate_token(config)
    if valid:
        profile_name = (((response.get("data") or {}).get("name")) or "").strip()
        print(f"TOKEN_VALID{':' + profile_name if profile_name else ''}")
        return 0

    print(f"TOKEN_INVALID:{(response.get('message') or 'FYERS token check failed').strip()}")
    return STATUS_TOKEN_INVALID


def cmd_auth_url(args):
    config = _read_config(args.env_file)
    required = ("client_id", "secret_key", "redirect_uri")
    if not all(_is_set(config[key]) for key in required):
        print("Missing FYERS_CLIENT_ID, FYERS_SECRET_KEY, or FYERS_REDIRECT_URI", file=sys.stderr)
        return STATUS_CONFIG_MISSING

    print(_build_session(config).generate_authcode())
    return 0


def _extract_token(response, key):
    if key in response and response.get(key):
        return response.get(key)
    data = response.get("data") or {}
    value = data.get(key)
    if value:
        return value
    return ""


def cmd_exchange_code(args):
    config = _read_config(args.env_file)
    required = ("client_id", "secret_key", "redirect_uri")
    if not all(_is_set(config[key]) for key in required):
        print("Missing FYERS_CLIENT_ID, FYERS_SECRET_KEY, or FYERS_REDIRECT_URI", file=sys.stderr)
        return STATUS_CONFIG_MISSING

    auth_code = _extract_auth_code(args.auth_input)
    if not auth_code:
        print("No FYERS auth code found in the pasted value", file=sys.stderr)
        return 1

    session = _build_session(config)
    session.set_token(auth_code)
    response = session.generate_token()
    access_token = _extract_token(response, "access_token")
    refresh_token = _extract_token(response, "refresh_token")
    if not access_token:
        print(json.dumps(response, indent=2), file=sys.stderr)
        return 1

    now_text = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    update_env_file(
        args.env_file,
        {
            "FYERS_AUTH_CODE": auth_code,
            "FYERS_AUTH_CODE_UPDATED_AT": now_text,
            "FYERS_ACCESS_TOKEN": access_token,
            "FYERS_TOKEN_UPDATED_AT": now_text,
            "FYERS_REFRESH_TOKEN": refresh_token,
        },
    )
    print("TOKEN_SAVED")
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description="Manage FYERS auth state for the India scanner.")
    parser.add_argument(
        "--env-file",
        default=str(Path(__file__).with_name(".env")),
        help="Path to the .env file to read and update.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("status", help="Validate the stored FYERS access token.")
    subparsers.add_parser("auth-url", help="Print the FYERS auth URL.")

    exchange = subparsers.add_parser("exchange-code", help="Exchange an auth code or redirected URL for an access token.")
    exchange.add_argument("--auth-input", required=True, help="Raw auth code or redirected URL copied from the browser.")
    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "status":
        return cmd_status(args)
    if args.command == "auth-url":
        return cmd_auth_url(args)
    if args.command == "exchange-code":
        return cmd_exchange_code(args)
    parser.error(f"Unsupported command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
