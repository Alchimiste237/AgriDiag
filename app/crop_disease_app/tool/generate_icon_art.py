#!/usr/bin/env python3
"""
generate_icon_art.py — AgroDiag crop-leaf launcher icon generator
=================================================================

Draws the app icon artwork (a fresh green crop leaf on a green gradient)
with Pillow + numpy — no TensorFlow needed — and writes every platform's
launcher icon file:

    icon.png                                 1024px master (for tool/generate_icons.dart)
    android/app/src/main/res/mipmap-*/       ic_launcher.png (48/72/96/144/192)
    ios/Runner/.../AppIcon.appiconset/       all Icon-App-*.png sizes (incl. 1024)
    macos/Runner/.../AppIcon.appiconset/     app_icon_16..1024.png
    windows/runner/resources/app_icon.ico    multi-size ICO (16..256)
    linux/runner/resources/app_icon.png      512px
    web/icons/                               Icon-192/512 + maskable variants
    web/favicon.png                          32px

Run from app/crop_disease_app/:   python tool/generate_icon_art.py

The artwork is drawn once at 1024px and downscaled with LANCZOS. The
"maskable" web icons are rendered with the artwork at 72% so it survives
launcher cropping (safe zone).

NOTES:
- This script is the canonical generator for ALL icon sizes (including the
  web maskable icons). Running `tool/generate_icons.dart` afterwards would
  overwrite the Android/iOS/web regular icons (same art) but the maskables
  with a white background — so prefer this script for regenerations.
- The Linux PNG is written to the conventional `linux/runner/resources/`
  location for future packaging; the current GTK runner does not set a
  window icon yet.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]  # app/crop_disease_app
CANVAS = 1024

# --- Palette (matches the app's Material green seed 0xFF2E7D32) ---
BG_TOP = (76, 175, 80)        # #4CAF50  light green
BG_BOTTOM = (27, 94, 32)      # #1B5E20  deep green
LEAF_FILL = (200, 230, 201)   # #C8E6C9  fresh leaf
LEAF_EDGE = (27, 94, 32)      # deep green outline + veins
SMALL_FILL = (129, 199, 132)  # #81C784  secondary leaf


def _cubic(p0, p1, p2, p3, n=48):
    """Sample a cubic Bézier into a list of points."""
    pts = []
    for i in range(n + 1):
        t = i / n
        mt = 1.0 - t
        x = mt**3 * p0[0] + 3 * mt * mt * t * p1[0] + 3 * mt * t * t * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt * mt * t * p1[1] + 3 * mt * t * t * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def _gradient(size, c_top_left, c_bottom_right):
    """Diagonal green gradient (top-left -> bottom-right)."""
    y, x = np.mgrid[0:size, 0:size]
    t = np.clip((x + y) / (2.0 * (size - 1)), 0, 1)[..., None]
    c1 = np.array(c_top_left, dtype=float)
    c2 = np.array(c_bottom_right, dtype=float)
    arr = c1[None, None, :] * (1 - t) + c2[None, None, :] * t
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def _radial_glow(size, center=(0.35, 0.30), radius=0.75, strength=70):
    """Soft light from the upper-left corner."""
    y, x = np.mgrid[0:size, 0:size]
    cx, cy = center[0] * size, center[1] * size
    dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (radius * size)
    alpha = np.clip(1 - dist, 0, 1) * strength
    rgba = np.dstack([np.full((size, size), 255, np.uint8),
                      np.full((size, size), 255, np.uint8),
                      np.full((size, size), 255, np.uint8),
                      alpha.astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA").filter(ImageFilter.GaussianBlur(size * 0.03))


def _draw_leaf(length, width, fill, edge, scale=1.0):
    """
    Draw a vertical leaf (tip up, base down) with midrib + side veins on a
    transparent layer. Dimensions are in master (1024) units.
    """
    length *= scale
    width *= scale
    pad = max(90, int(width * 0.18))
    w, h = int(width + 2 * pad), int(length + 2 * pad)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = w / 2.0
    y0 = pad

    def P(x, y):
        return (cx + x, y0 + y)

    tip, base = P(0, 0), P(0, length)
    edge_w = max(4, int(14 * scale))

    # Leaf outline: right edge then mirrored left edge.
    right = _cubic(tip, P(width * 0.50, length * 0.22),
                   P(width * 0.58, length * 0.78), base, 48)
    left = _cubic(base, P(-width * 0.58, length * 0.78),
                  P(-width * 0.50, length * 0.22), tip, 48)[1:]
    outline = right + left
    d.polygon(outline, fill=fill + (255,))
    d.line(outline + [outline[0]], fill=edge + (255,), width=edge_w, joint="curve")

    # Midrib: gentle S-curve from base to tip.
    mid = _cubic(P(0, length), P(-width * 0.10, length * 0.55),
                 P(width * 0.06, length * 0.16), tip, 24)
    d.line(mid, fill=edge + (255,), width=max(4, int(length * 0.022)), joint="curve")

    # Side veins sweeping outward from the midrib.
    vein_w = max(2, int(length * 0.011))
    for f in (0.28, 0.42, 0.56, 0.70, 0.84):
        yy = length * f
        for side in (-1, 1):
            d.line([P(0, yy), P(side * width * 0.44, yy - length * 0.10)],
                   fill=edge + (200,), width=vein_w)
    return layer


def _droplet(size, alpha=130):
    """Soft white highlight blob."""
    drop = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(drop)
    d.ellipse([int(size * 0.25), int(size * 0.12),
               int(size * 0.82), int(size * 0.92)], fill=(255, 255, 255, alpha))
    return drop.filter(ImageFilter.GaussianBlur(size * 0.05))


def _paste_centered(canvas, layer, px, py):
    """Composite `layer` so its center lands at (px, py) on the canvas."""
    canvas.alpha_composite(layer, (int(px - layer.width / 2), int(py - layer.height / 2)))


def render_icon(size, content_scale=1.0):
    """Render the full icon at `size` with the artwork scaled by content_scale."""
    s = content_scale
    img = _gradient(size, BG_TOP, BG_BOTTOM).convert("RGBA")
    img = Image.alpha_composite(img, _radial_glow(size))

    # Main leaf: tilted -42 deg so the tip points up-right.
    leaf = _draw_leaf(length=640, width=600, fill=LEAF_FILL, edge=LEAF_EDGE, scale=s)
    main = leaf.rotate(-42, resample=Image.BICUBIC, expand=True)
    _paste_centered(img, main, size * 0.52, size * 0.40)

    # Small accent leaf at the bottom-left.
    small = _draw_leaf(length=280, width=240, fill=SMALL_FILL, edge=LEAF_EDGE, scale=s)
    small = small.rotate(28, resample=Image.BICUBIC, expand=True)
    _paste_centered(img, small, size * 0.17, size * 0.78)

    # Highlight droplet on the main leaf.
    _paste_centered(img, _droplet(int(size * 0.15 * s)), size * 0.46, size * 0.33)

    return img.convert("RGB")


def _write_png(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG")


def _downscale(master, size):
    return master.resize((size, size), Image.LANCZOS)


def main():
    print("Rendering AgroDiag crop-leaf icon...")
    master = render_icon(CANVAS)
    maskable_master = render_icon(CANVAS, content_scale=0.72)

    master_path = ROOT / "icon.png"
    _write_png(master, master_path)
    print(f"  [OK] {master_path.relative_to(ROOT)} ({master.width}x{master.height})")

    # --- Android mipmaps ---
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in [("mipmap-mdpi", 48), ("mipmap-hdpi", 72), ("mipmap-xhdpi", 96),
                         ("mipmap-xxhdpi", 144), ("mipmap-xxxhdpi", 192)]:
        out = android_res / folder / "ic_launcher.png"
        _write_png(_downscale(master, size), out)
        print(f"  [OK] {out.relative_to(ROOT)} ({size}x{size})")

    # --- iOS AppIcon.appiconset ---
    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167, "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, size in ios_sizes.items():
        _write_png(_downscale(master, size), ios_dir / name)
    print(f"  [OK] iOS AppIcon.appiconset ({len(ios_sizes)} sizes)")

    # --- macOS AppIcon.appiconset ---
    mac_dir = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        _write_png(_downscale(master, size), mac_dir / f"app_icon_{size}.png")
    print("  [OK] macOS AppIcon.appiconset (7 sizes)")

    # --- Windows multi-size ICO ---
    win_ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    _downscale(master, 256).save(
        win_ico, format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print(f"  [OK] {win_ico.relative_to(ROOT)} (16..256 multi-size ICO)")

    # --- Linux ---
    linux_png = ROOT / "linux" / "runner" / "resources" / "app_icon.png"
    _write_png(_downscale(master, 512), linux_png)
    print(f"  [OK] {linux_png.relative_to(ROOT)} (512x512)")

    # --- Web ---
    web = ROOT / "web"
    _write_png(_downscale(master, 192), web / "icons" / "Icon-192.png")
    _write_png(_downscale(master, 512), web / "icons" / "Icon-512.png")
    _write_png(_downscale(maskable_master, 192), web / "icons" / "Icon-maskable-192.png")
    _write_png(_downscale(maskable_master, 512), web / "icons" / "Icon-maskable-512.png")
    _write_png(_downscale(master, 32), web / "favicon.png")
    print("  [OK] web icons + favicon")

    print("Done. Regenerate anytime with:  python tool/generate_icon_art.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
