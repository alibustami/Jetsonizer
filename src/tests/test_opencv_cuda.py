"""Validates that OpenCV is built with CUDA and can talk to the GPU."""

from __future__ import annotations

import datetime
import os
import pwd
import sys
import traceback
from pathlib import Path
from typing import Any

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


def _safe_call(device_info: Any, attr_name: str, default: Any) -> Any:
    """Return attribute value or default, calling callables defensively."""
    attr = getattr(device_info, attr_name, None)
    if attr is None:
        return default
    if callable(attr):
        try:
            return attr()
        except Exception:  # pylint: disable=broad-except
            return default
    return attr


def main() -> None:
    try:
        import cv2  # type: ignore import-not-found
    except Exception as exc:  # pylint: disable=broad-except
        raise SystemExit(f"Failed to import cv2: {exc}") from exc

    if not hasattr(cv2, "cuda"):
        raise SystemExit("This OpenCV build does not include CUDA bindings (cv2.cuda missing).")

    try:
        device_count = cv2.cuda.getCudaEnabledDeviceCount()
    except cv2.error as exc:  # type: ignore[attr-defined]
        raise SystemExit(f"Unable to query CUDA devices: {exc}") from exc

    if device_count <= 0:
        raise SystemExit("OpenCV reports zero CUDA-enabled devices.")

    try:
        cv2.cuda.setDevice(0)
        info = cv2.cuda.DeviceInfo(0)
    except cv2.error as exc:  # type: ignore[attr-defined]
        raise SystemExit(f"Unable to initialize CUDA device via OpenCV: {exc}") from exc

    device_name = _safe_call(info, "name", _safe_call(info, "deviceName", "Unknown"))
    cc_major = _safe_call(info, "majorVersion", _safe_call(info, "major", "N/A"))
    cc_minor = _safe_call(info, "minorVersion", _safe_call(info, "minor", "N/A"))
    total_mem = _safe_call(info, "totalGlobalMem", 0)
    try:
        total_mem_mib = int(total_mem) // (1024 * 1024)
    except Exception:  # pylint: disable=broad-except
        total_mem_mib = "?"

    print(f"OpenCV version: {cv2.__version__}")
    print(f"CUDA devices reported by OpenCV: {device_count}")
    print(
        "Active device: {name} | Compute Capability {cc_major}.{cc_minor} | {mem} MiB VRAM".format(
            name=device_name, cc_major=cc_major, cc_minor=cc_minor, mem=total_mem_mib
        )
    )


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
