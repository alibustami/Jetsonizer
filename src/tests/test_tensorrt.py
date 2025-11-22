#!/usr/bin/env python3
"""Smoke test confirming TensorRT Python modules can be imported."""

from __future__ import annotations

import argparse
import importlib
from dataclasses import dataclass
from typing import List


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
    main()
