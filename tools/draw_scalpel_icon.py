"""Draws assets/ui_art/icons/scalpel.png (restoration: crust stage) in the style
of the other tool icons: dark brown outline, wooden handle, pale metal blade.
Needs Pillow."""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SIZE, SS = 96, 6
OUTLINE = (74, 44, 22, 255)


def rotate(points, angle_deg, cx, cy):
    import math
    a = math.radians(angle_deg)
    return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a), cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a)) for x, y in points]


def main() -> None:
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = s / 2, s / 2
    u = s / 96
    # Shapes drawn horizontally (blade to the right), then rotated 45 degrees.
    handle = [(10 * u, 44 * u), (52 * u, 41 * u), (56 * u, 44 * u), (56 * u, 52 * u), (52 * u, 55 * u), (10 * u, 52 * u), (7 * u, 48 * u)]
    ferrule = [(54 * u, 40.5 * u), (61 * u, 40.5 * u), (61 * u, 55.5 * u), (54 * u, 55.5 * u)]
    blade = [(60 * u, 43 * u), (74 * u, 42 * u), (90 * u, 47 * u), (74 * u, 53.5 * u), (60 * u, 53 * u)]
    edge = [(74 * u, 53.5 * u), (90 * u, 47 * u), (76 * u, 50.5 * u)]
    # Thicker than drawn: stretch across the tool around its axis (y = 48).
    def fat(poly):
        return [(x, 48 * u + (y - 48 * u) * 1.55) for x, y in poly]
    handle, ferrule, blade, edge = fat(handle), fat(ferrule), fat(blade), fat(edge)
    angle = -40
    w = int(3.2 * u)
    for poly, fill in ((handle, (176, 112, 62, 255)), (ferrule, (150, 140, 128, 255)), (blade, (222, 218, 206, 255))):
        p = rotate(poly, angle, cx, cy)
        d.polygon(p, fill=fill)
        d.line(p + [p[0]], fill=OUTLINE, width=w, joint="curve")
    d.polygon(rotate(edge, angle, cx, cy), fill=(250, 248, 240, 255))
    # Wood grain and a highlight on the handle.
    for y in (45.5, 50.5):
        d.line(rotate([(14 * u, y * u), (48 * u, (y - 0.8) * u)], angle, cx, cy), fill=(140, 84, 42, 255), width=int(1.4 * u))
    d.line(rotate([(14 * u, 44.5 * u), (50 * u, 42.5 * u)], angle, cx, cy), fill=(214, 156, 98, 255), width=int(1.6 * u))
    img.resize((SIZE, SIZE), Image.LANCZOS).save(ROOT / "assets" / "ui_art" / "icons" / "scalpel.png")


if __name__ == "__main__":
    main()
