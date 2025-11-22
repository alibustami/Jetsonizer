"""Validates that OpenCV is built with CUDA and can talk to the GPU."""

from __future__ import annotations

from typing import Any


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
    main()
