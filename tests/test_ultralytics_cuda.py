"""Stream YOLO11m detections over video.mp4 and show annotated frames live."""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path
from typing import Tuple

try:
    import cv2  # type: ignore import-not-found
except Exception as exc:  # pylint: disable=broad-except
    raise SystemExit("OpenCV (cv2) is required to display video output.") from exc


def _default_video_path() -> Path:
    """Return the repo-root video path used by default."""
    return Path(__file__).resolve().parents[1] / "video.mp4"


def should_draw_overlay(mode: str, video_path: Path) -> bool:
    """Decide whether to draw new annotations based on the CLI mode and input video."""
    resolved = video_path.resolve()
    default_video = _default_video_path().resolve()
    if mode == "always":
        return True
    if mode == "never":
        return False
    # Auto mode: skip plotting when the bundled demo already has boxes burned in.
    return resolved != default_video


def overlay_fps_text(frame, fps: float) -> None:
    """Put an FPS counter on the frame."""
    label = f"FPS: {fps:.1f}" if fps > 0 else "FPS: --"
    cv2.putText(
        frame,
        label,
        (10, 30),
        cv2.FONT_HERSHEY_SIMPLEX,
        1.0,
        (0, 255, 0),
        2,
        cv2.LINE_AA,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run Ultralytics YOLO11m on a video file and display annotated frames. "
            "Press 'q' or ESC to quit."
        )
    )
    parser.add_argument(
        "--video",
        type=Path,
        default=_default_video_path(),
        help="Video file to read (default: %(default)s).",
    )
    parser.add_argument(
        "--model",
        default="yolo11x.pt",
        help="YOLOv11 weights to use (default: %(default)s).",
    )
    parser.add_argument(
        "--device",
        default="auto",
        help="Torch device identifier (e.g. cuda:0, cpu, auto).",
    )
    parser.add_argument(
        "--confidence",
        type=float,
        default=0.5,
        help="Confidence threshold for detections (default: %(default)s).",
    )
    parser.add_argument(
        "--max-frames",
        type=int,
        default=0,
        help="Optional limit on processed frames (0 = entire video).",
    )
    parser.add_argument(
        "--window-title",
        default="Ultralytics YOLO11m",
        help="Window title for the annotated video display.",
    )
    parser.add_argument(
        "--overlay-mode",
        choices=("auto", "always", "never"),
        default="auto",
        help=(
            "Whether to draw new detections on top of the video. "
            "'auto' skips drawing when the bundled, pre-annotated sample video is used."
        ),
    )
    return parser.parse_args()


def resolve_device(requested: str) -> Tuple[str, bool]:
    """Resolve device string, preferring CUDA when available."""
    try:
        import torch  # type: ignore import-not-found
    except Exception as exc:  # pylint: disable=broad-except
        raise SystemExit("PyTorch is required for YOLO inference.") from exc

    def _has_cuda() -> bool:
        cuda_mod = getattr(torch, "cuda", None)
        is_available = getattr(cuda_mod, "is_available", lambda: False)
        return bool(is_available())

    normalized = requested.strip().lower()
    if normalized in {"auto", ""}:
        if _has_cuda():
            return "cuda:0", True
        return "cpu", False

    if normalized.startswith("cuda") and not _has_cuda():
        print("CUDA requested but unavailable; falling back to CPU.", file=sys.stderr)
        return "cpu", False

    return requested, normalized.startswith("cuda")


def load_model(weights: str, device: str) -> "YOLO":  # type: ignore[name-defined]
    """Load YOLO weights and move them to the selected device."""
    try:
        from ultralytics import YOLO  # type: ignore import-not-found
    except Exception as exc:  # pylint: disable=broad-except
        raise SystemExit("Ultralytics package is required (pip install ultralytics).") from exc

    model = YOLO(weights)
    # YOLO.to is a no-op on CPU but keeps the API consistent.
    model.to(device)
    return model


def ensure_window(title: str) -> None:
    """Create the OpenCV window once so we can report display issues early."""
    try:
        cv2.namedWindow(title, cv2.WINDOW_NORMAL)
    except cv2.error as exc:
        raise SystemExit(
            "Failed to open a GUI window. Ensure you have a display (e.g. set DISPLAY)."
        ) from exc


def stream_video(
    video_path: Path,
    model: "YOLO",  # type: ignore[name-defined]
    model_label: str,
    device: str,
    confidence: float,
    max_frames: int,
    window_title: str,
    draw_annotations: bool,
) -> None:
    """Read frames, run YOLO, and display annotated video."""
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise SystemExit(f"Failed to open video file: {video_path}")

    print(f"Streaming {video_path} with {model_label} on {device}. Press 'q' or ESC to stop.")

    ensure_window(window_title)

    frame_count = 0
    prev_time = time.perf_counter()
    fps_value = 0.0
    try:
        while True:
            ok, frame = cap.read()
            if not ok or frame is None:
                break

            frame_count += 1
            results = model.predict(
                frame,
                device=device,
                conf=confidence,
                verbose=False,
            )

            if not results:
                annotated = frame
            elif draw_annotations:
                # Annotate in-place to avoid stacking on top of pre-annotated footage.
                annotated = results[0].plot()  # Ultralytics already copies the frame.
            else:
                annotated = frame

            now = time.perf_counter()
            elapsed = now - prev_time
            prev_time = now
            if elapsed > 0:
                instant_fps = 1.0 / elapsed
                fps_value = instant_fps if fps_value == 0.0 else (0.85 * fps_value + 0.15 * instant_fps)
            overlay_fps_text(annotated, fps_value)

            cv2.imshow(window_title, annotated)
            key = cv2.waitKey(1) & 0xFF
            if key in (ord("q"), 27):  # ESC or q
                break

            if max_frames and frame_count >= max_frames:
                break
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
    finally:
        cap.release()
        cv2.destroyAllWindows()


def main() -> None:
    args = parse_args()
    video_path = args.video.expanduser().resolve()
    if not video_path.exists():
        raise SystemExit(f"Video file not found: {video_path}")

    if not 0.0 < args.confidence <= 1.0:
        raise SystemExit("Confidence must be within (0, 1].")

    device, using_cuda = resolve_device(args.device)
    model = load_model(args.model, device)
    draw_annotations = should_draw_overlay(args.overlay_mode, video_path)

    if using_cuda:
        print("Using CUDA for inference.")
    else:
        print("Running on CPU. Set --device cuda:0 if a GPU becomes available.")

    if args.overlay_mode == "auto" and not draw_annotations:
        print(
            "Sample video already includes bounding boxes; skipping additional overlays. "
            "Use --overlay-mode always to draw them anyway."
        )

    stream_video(
        video_path=video_path,
        model=model,
        model_label=args.model,
        device=device,
        confidence=args.confidence,
        max_frames=args.max_frames,
        window_title=args.window_title,
        draw_annotations=draw_annotations,
    )


if __name__ == "__main__":
    main()
