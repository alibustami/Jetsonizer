#!/usr/bin/env python3
"""Smoke test confirming TensorRT Python modules can be imported."""

from __future__ import annotations

import argparse
import datetime
import importlib
import os
import pwd
import sys
import traceback
from dataclasses import dataclass
from pathlib import Path
from typing import List

def _default_log_dir() -> Path:
    env_dir = os.environ.get("JETSONIZER_LOG_DIR")
    if env_dir:
        return Path(env_dir)
    user = os.environ.get("SUDO_USER") or os.environ.get("USER")
    if not user:
        try:
            user = pwd.getpwuid(os.getuid()).pw_name
        except KeyError:
            user = Path.home().name
    return Path("/home") / user / ".cache" / "Jetsonizer"


LOG_DIR = _default_log_dir()


def _write_log(exc: BaseException) -> Path | None:
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        log_path = LOG_DIR / f"{Path(__file__).stem}_{timestamp}.log"
        with log_path.open("w", encoding="utf-8") as handle:
            handle.write(f"Timestamp: {timestamp}\n")
            handle.write(f"Script: {Path(__file__).name}\n")
            handle.write("Traceback:\n")
            handle.writelines(traceback.format_exception(type(exc), exc, exc.__traceback__))
        return log_path
    except Exception:
        return None


def _report_failure(exc: BaseException) -> None:
    log_path = _write_log(exc)
    if log_path:
        print(f"Full error and logs written to {log_path}", file=sys.stderr)
    else:
        print(f"Failed to write log file under {LOG_DIR}.", file=sys.stderr)

@dataclass
class ModuleStatus:
    """Tracks the outcome of attempting to import a module."""

    name: str
    ok: bool
    version: str
    error: str | None = None


def inspect_module(module_name: str) -> ModuleStatus:
    """Attempt to import a module and capture its version (if available)."""

    def _resolve_version(module: object) -> str:
        for attr in ("__version__", "version"):
            value = getattr(module, attr, None)
            if value:
                return str(getattr(value, "__version__", value))
        return "unknown"

    try:
        module = importlib.import_module(module_name)
    except Exception as exc:  # pylint: disable=broad-except
        return ModuleStatus(
            name=module_name,
            ok=False,
            version="n/a",
            error=f"{exc.__class__.__name__}: {exc}",
        )

    return ModuleStatus(name=module_name, ok=True, version=_resolve_version(module))


def format_status(status: ModuleStatus) -> str:
    if status.ok:
        return f"{status.name}: OK (version {status.version})"
    return f"{status.name}: FAILED to import ({status.error})"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "modules",
        nargs="*",
        default=["tensorrt"],
        help="List of module names to verify (default: %(default)s).",
    )
    args = parser.parse_args()

    statuses: List[ModuleStatus] = [inspect_module(name) for name in args.modules]

    for status in statuses:
        print(format_status(status))

    failed = [status for status in statuses if not status.ok]
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    try:
        main()
    except SystemExit as exc:
        code = exc.code
        if (isinstance(code, int) and code != 0) or (not isinstance(code, int) and code is not None):
            _report_failure(exc)
        raise
    except Exception as exc:  # pylint: disable=broad-except
        _report_failure(exc)
        raise SystemExit(1) from exc
