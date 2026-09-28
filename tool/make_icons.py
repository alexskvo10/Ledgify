"""Generates the Ledgify app icon for Windows (.ico) and Android (mipmaps).

The drawing matches the in-app logo (`AppMark` in lib/screens/home_shell.dart):
a green gradient tile with a white ledger "L" and a coin dot.

Usage (needs Pillow):  python tool/make_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
S = 1024  # master size


def master(full_bleed: bool = False) -> Image.Image:
    """full_bleed=True fills the square (Android launchers mask it themselves)."""
    grad = Image.new("RGBA", (S, S))
    top, bottom = (0x3D, 0xDC, 0x6A), (0x1E, 0x9E, 0x44)
    px = grad.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * (S - 1))  # diagonal, top-left → bottom-right
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,)

    mask = Image.new("L", (S, S), 0)
    inset = 0 if full_bleed else round(S * 0.04)
    radius = round(S * (0.22 if full_bleed else 0.26))
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset, inset, S - inset, S - inset), radius=radius, fill=255)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(img)
    w = round(S * 0.13)
    x0, y0, y1, x1 = S * 0.34, S * 0.26, S * 0.72, S * 0.70
    d.line([(x0, y0), (x0, y1), (x1, y1)], fill="white", width=w, joint="curve")
    for cx, cy in [(x0, y0), (x0, y1), (x1, y1)]:  # round caps
        d.ellipse((cx - w / 2, cy - w / 2, cx + w / 2, cy + w / 2), fill="white")
    r = S * 0.09
    cx, cy = S * 0.68, S * 0.36
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill="white")
    return img


def main() -> None:
    icon = master()
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    icon.save(ico, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print("wrote", ico.relative_to(ROOT))

    android = master(full_bleed=True)
    for folder, size in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        out = ROOT / f"android/app/src/main/res/{folder}/ic_launcher.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        android.resize((size, size), Image.LANCZOS).save(out)
        print("wrote", out.relative_to(ROOT))

    preview = ROOT / "docs/assets/icon.png"
    preview.parent.mkdir(parents=True, exist_ok=True)
    icon.resize((256, 256), Image.LANCZOS).save(preview)
    print("wrote", preview.relative_to(ROOT))


if __name__ == "__main__":
    main()
