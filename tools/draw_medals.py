"""Draws the difficulty medals (bronze / silver / gold) used by the difficulty
picker and the collection. Output: assets/ui_art/medals/medal_<name>.png.
Needs Pillow:  pip install pillow
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui_art" / "medals"
SIZE = 128
SS = 4  # supersampling

MEDALS = {
    "bronze": ((214, 140, 82), (140, 78, 36), (92, 48, 20)),
    "silver": ((236, 240, 245), (160, 168, 180), (96, 102, 114)),
    "gold": ((255, 222, 120), (214, 150, 40), (128, 82, 18)),
}
RIBBONS = {
    "bronze": ((150, 52, 40), (112, 36, 28)),
    "silver": ((52, 92, 150), (36, 64, 112)),
    "gold": ((46, 112, 70), (30, 80, 50)),
}


def star(cx: float, cy: float, r_out: float, r_in: float) -> list[tuple[float, float]]:
    points = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5
        r = r_out if i % 2 == 0 else r_in
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    return points


def draw(name: str) -> Image.Image:
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    light, mid, dark = MEDALS[name]
    rib_a, rib_b = RIBBONS[name]
    # Ribbon (two tails behind the medal).
    w = s * 0.16
    d.polygon([(s * 0.30, 0), (s * 0.30 + w, 0), (s * 0.52, s * 0.50), (s * 0.40, s * 0.52)], fill=rib_a)
    d.polygon([(s * 0.70 - w, 0), (s * 0.70, 0), (s * 0.60, s * 0.52), (s * 0.48, s * 0.50)], fill=rib_b)
    # Shadow.
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([s * 0.17, s * 0.33, s * 0.87, s * 0.99], fill=(40, 22, 8, 120))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(s * 0.02)))
    # Disc: rim, body with vertical gradient, inner ring.
    cx, cy, r = s * 0.5, s * 0.63, s * 0.33
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=dark)
    body = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    r2 = r * 0.9
    for i in range(int(2 * r2)):
        t = i / (2 * r2)
        col = tuple(int(light[k] * (1 - t) + mid[k] * t) for k in range(3)) + (255,)
        y = cy - r2 + i
        half = math.sqrt(max(0.0, r2 * r2 - (y - cy) ** 2))
        bd.line([(cx - half, y), (cx + half, y)], fill=col)
    img.alpha_composite(body)
    d = ImageDraw.Draw(img)
    r3 = r * 0.72
    d.ellipse([cx - r3, cy - r3, cx + r3, cy + r3], outline=dark, width=int(s * 0.012))
    d.polygon(star(cx, cy + s * 0.005, r * 0.48, r * 0.2), fill=dark)
    d.polygon(star(cx, cy - s * 0.008, r * 0.46, r * 0.19), fill=light)
    # Gloss.
    gloss = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).ellipse([cx - r * 0.6, cy - r * 0.85, cx + r * 0.2, cy - r * 0.35], fill=(255, 255, 255, 70))
    img.alpha_composite(gloss.filter(ImageFilter.GaussianBlur(s * 0.01)))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in MEDALS:
        draw(name).save(OUT / f"medal_{name}.png")
        print("wrote", OUT / f"medal_{name}.png")


if __name__ == "__main__":
    main()
