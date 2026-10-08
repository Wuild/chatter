#!/usr/bin/env python3
"""Raise notification assets from original sources; requires ffmpeg.

Use separate input/output directories to avoid repeated lossy re-encoding.
The loudest 100 ms RMS window is used because these alerts are too short for
integrated LUFS metering. Quiet tails must not drive excessive amplification.
"""

import argparse
from array import array
import math
from pathlib import Path
import subprocess
import sys


def measure(path):
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ar", "192000", "-ac", "2", "-f", "f32le", "-"],
        check=True, capture_output=True,
    )
    samples = array("f", result.stdout)
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples:
        raise ValueError(f"Empty sound: {path}")
    peak = max(abs(value) for value in samples)
    # Stereo 192 kHz: ten 10 ms blocks form a 100 ms loudness window.
    blocks = [sum(value * value for value in samples[i:i + 3840])
              for i in range(0, len(samples), 3840)]
    energy = max(sum(blocks[i:i + 10]) for i in range(max(1, len(blocks) - 9)))
    rms = math.sqrt(energy / min(len(samples), 38400))
    if rms == 0:
        raise ValueError(f"Silent sound: {path}")
    return 20 * math.log10(rms), 20 * math.log10(peak), len(samples)


def normalize(source, destination):
    before, _, sample_count = measure(source)
    gain = -12 - before
    # Re-render from the source, never the previous lossy output. Brief peaks
    # can reduce the first pass's average level, so allow bounded gain corrections.
    for _ in range(6):
        filters = (
            f"volume={gain:.4f}dB,"
            "alimiter=limit=0.707946:attack=2:release=10:level=false:latency=true"
        )
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(source), "-af", filters,
             "-c:a", "libvorbis", "-q:a", "6", str(destination)], check=True,
        )
        after, peak, count = measure(destination)
        if after >= -12.5:
            break
        gain = min(35, gain + -12 - after)
    # Vorbis decoders may discard a short codec startup block on re-encoding.
    if abs(after + 12) > 1 or peak > -0.5 or abs(count - sample_count) > 4096:
        raise ValueError(f"Audio validation failed: {destination} (peak {peak:.2f} dB)")
    print(f"{source.name}: 100 ms RMS {before:.1f} -> {after:.1f} dB; oversampled peak {peak:.1f} dB")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.source.resolve() == args.output.resolve():
        parser.error("Use separate source and output directories.")
    sources = sorted(args.source.glob("*.ogg"))
    if not sources:
        parser.error("No .ogg source files found.")
    args.output.mkdir(parents=True, exist_ok=True)
    for source in sources:
        normalize(source, args.output / source.name)


if __name__ == "__main__":
    main()
