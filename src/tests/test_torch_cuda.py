"""Smoke test that validates PyTorch can talk to CUDA."""

from __future__ import annotations

import argparse
import datetime
import os
import pwd
import sys
import traceback
from pathlib import Path
from typing import Any, Callable, Dict

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

def _safe_call(func: Callable[[], Any], default: Any) -> Any:
    """Call a zero-arg function and return a default if it raises."""
    try:
        return func()
    except Exception:  # pylint: disable=broad-except
        return default


def gather_torch_cuda_info() -> Dict[str, Any]:
    """Collect PyTorch/CUDA metadata without failing on missing pieces."""
    try:
        import torch  # type: ignore import-not-found
    except Exception as exc:  # pylint: disable=broad-except
        raise RuntimeError(f"Failed to import torch: {exc}") from exc

    cuda_module = getattr(torch, "cuda", None)
    cuda_runtime = getattr(getattr(torch, "version", None), "cuda", None) or "n/a"
    cuda_available = bool(getattr(cuda_module, "is_available", lambda: False)())

    device_count = 0
    device_name = "n/a"
    device_capability = "n/a"
    device_memory_mib: Any = "n/a"

    if cuda_available and cuda_module is not None:
        device_count = int(_safe_call(cuda_module.device_count, 0))
        if device_count > 0:
            device_name = _safe_call(lambda: cuda_module.get_device_name(0), "n/a")
            capability = _safe_call(lambda: cuda_module.get_device_capability(0), None)
            if isinstance(capability, (tuple, list)) and len(capability) == 2:
                device_capability = f"{capability[0]}.{capability[1]}"

            properties = _safe_call(lambda: cuda_module.get_device_properties(0), None)
            total_mem = getattr(properties, "total_memory", None)
            if isinstance(total_mem, (int, float)):
                device_memory_mib = int(total_mem) // (1024 * 1024)

    return {
        "version": getattr(torch, "__version__", "unknown"),
        "cuda_runtime": cuda_runtime,
        "cuda_available": cuda_available,
        "device_count": device_count,
        "device_name": device_name,
        "device_capability": device_capability,
        "device_memory_mib": device_memory_mib,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--machine-readable",
        action="store_true",
        help="Emit compact pipe-delimited summary for shell scripts.",
    )
    args = parser.parse_args()

    try:
        info = gather_torch_cuda_info()
    except RuntimeError as exc:
        raise SystemExit(str(exc)) from exc

    cuda_flag = "yes" if info["cuda_available"] else "no"
    if args.machine_readable:
        print(f"{info['version']}|{info['cuda_runtime']}|{cuda_flag}")
        return

    print(f"PyTorch version: {info['version']}")
    print(f"CUDA runtime reported by torch: {info['cuda_runtime']}")
    print(f"CUDA available: {cuda_flag}")
    if info["cuda_available"]:
        print(f"CUDA device count: {info['device_count']}")
        if info["device_count"] > 0:
            print(
                "Active device: {name} | SM {sm} | {mem} MiB VRAM".format(
                    name=info["device_name"],
                    sm=info["device_capability"],
                    mem=info["device_memory_mib"],
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
