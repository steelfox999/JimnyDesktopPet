#!/usr/bin/env python3
"""Extract frames from Jimny sprite sheets and organize into named sequence directories."""

import os
import shutil
import numpy as np
from PIL import Image

BASE_DIR = os.path.dirname(__file__)
ORIGINAL_SHEET = os.path.join(BASE_DIR, "..", "Sprite_Sheet_Jimny.png")
WATER_SHEET = os.path.join(BASE_DIR, "..", "Sprite_Sheet_Jimny_Water.png")
OUTPUT_DIR = os.path.join(BASE_DIR, "frames")

COLS = 4
COL_W = 448  # 1792 / 4

GRAY_RGB = np.array([0x8A, 0x8A, 0x8A], dtype=np.float32)
THRESHOLD = 35.0

# Original sheet: side-view rows → "drive" sequence (12 frames)
DRIVE_ROWS = [
    (905, 1126),
    (1312, 1530),
    (1680, 1906),
]

# Water sheet: rows → single "water_crossing" sequence
# Row 0: Approaching water edge (4 frames)
# Row 1: Entering water with splash (4 frames)
# Row 2: Shallow water crossing (4 frames)
# Row 3: Wheels submerged (4 frames)
# Row 4: Emerging from water (4 frames)
# Row 5: Deep splash (only col 0 usable; cols 1-3 are multi-view/alt angles)
WATER_ROWS = [
    (135, 405, 4),
    (513, 804, 4),
    (906, 1200, 4),
    (1311, 1597, 4),
    (1658, 1977, 4),
    (2073, 2325, 1),
]


def remove_gray_background(img: Image.Image) -> Image.Image:
    """Replace gray background pixels with transparency using color-distance thresholding."""
    rgba = img.convert("RGBA")
    data = np.array(rgba, dtype=np.float32)
    rgb = data[:, :, :3]
    dist = np.sqrt(np.sum((rgb - GRAY_RGB) ** 2, axis=2))
    mask = dist < THRESHOLD
    data[mask, 3] = 0
    return Image.fromarray(data.astype(np.uint8))


def trim_transparent(img: Image.Image) -> Image.Image:
    """Crop to bounding box of non-transparent pixels."""
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img


def main():
    # Clean output directory
    if os.path.exists(OUTPUT_DIR):
        shutil.rmtree(OUTPUT_DIR)
    os.makedirs(OUTPUT_DIR)

    # --- Drive frames from original sheet ---
    print("Extracting drive frames from original sheet...")
    drive_dir = os.path.join(OUTPUT_DIR, "drive")
    os.makedirs(drive_dir)
    original = Image.open(ORIGINAL_SHEET)
    print(f"  Original sheet size: {original.size}")

    frame_idx = 0
    for y_start, y_end in DRIVE_ROWS:
        for col in range(COLS):
            x = col * COL_W
            cell = original.crop((x, y_start, x + COL_W, y_end))
            cell = remove_gray_background(cell)
            cell = trim_transparent(cell)
            out_path = os.path.join(drive_dir, f"frame_{frame_idx:02d}.png")
            cell.save(out_path)
            print(f"  Saved {out_path} ({cell.size[0]}x{cell.size[1]})")
            frame_idx += 1

    print(f"  Drive: {frame_idx} frames\n")

    # --- Water crossing frames (all 6 rows → one continuous sequence) ---
    print("Extracting water crossing frames...")
    water_dir = os.path.join(OUTPUT_DIR, "water_crossing")
    os.makedirs(water_dir)
    water = Image.open(WATER_SHEET)
    print(f"  Water sheet size: {water.size}")

    frame_idx = 0
    for y_start, y_end, num_cols in WATER_ROWS:
        for col in range(num_cols):
            x = col * COL_W
            cell = water.crop((x, y_start, x + COL_W, y_end))
            cell = remove_gray_background(cell)
            cell = trim_transparent(cell)
            out_path = os.path.join(water_dir, f"frame_{frame_idx:02d}.png")
            cell.save(out_path)
            print(f"  Saved {out_path} ({cell.size[0]}x{cell.size[1]})")
            frame_idx += 1

    print(f"  Water crossing: {frame_idx} frames\n")

    # Summary
    print("--- Summary ---")
    for entry in sorted(os.listdir(OUTPUT_DIR)):
        entry_path = os.path.join(OUTPUT_DIR, entry)
        if os.path.isdir(entry_path):
            frames = [f for f in os.listdir(entry_path) if f.endswith(".png")]
            print(f"  {entry}/: {len(frames)} frames")

    print("\nDone!")


if __name__ == "__main__":
    main()
