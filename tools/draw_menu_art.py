"""Code-drawn placeholder art until real illustrations exist.

Writes (Python 3 + Pillow, run from the project folder):
  assets/ui_art/menu/background.jpg   1080x1920 sandstone wall, dark enough for cream text
  assets/ui_art/menu/emblem.png       512x512 carved sun-spiral medallion
  build/store/icon_512.png            store icon (not shipped in the game)
  build/store/cover_800x470.png       store cover without text (not shipped)

Replace any of them with an illustration of the same size and name; see
ART_PROMPTS.md for ready prompts.
"""

import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MENU = os.path.join(ROOT, "assets", "ui_art", "menu")
STORE = os.path.join(ROOT, "build", "store")
BLOCKS = os.path.join(ROOT, "assets", "ui_art", "blocks")

SAND_LIGHT = (222, 186, 128)
SAND = (196, 152, 94)
SAND_DARK = (120, 84, 46)
GOLD = (236, 190, 86)
GOLD_DARK = (150, 100, 34)


def noise(size, scale, seed, strength):
    """Soft value noise as an L image centred on 128."""
    rnd = random.Random(seed)
    small = Image.new("L", (max(2, size[0] // scale), max(2, size[1] // scale)))
    small.putdata([128 + int(rnd.uniform(-strength, strength)) for _ in range(small.width * small.height)])
    return small.resize(size, Image.BICUBIC)


def apply_noise(image, layers):
    out = image
    for scale, seed, strength in layers:
        n = noise(image.size, scale, seed, strength).convert("RGB")
        out = ImageChops.add(out, n, scale=1.0, offset=-128)
    return out


def sandstone(size, seed):
    base = Image.new("RGB", size, SAND)
    return apply_noise(base, [(64, seed, 18), (12, seed + 1, 10), (3, seed + 2, 7)])


def draw_background(width=1080, height=1920):
    rnd = random.Random(7)
    wall = sandstone((width, height), 11)
    draw = ImageDraw.Draw(wall)
    shade = Image.new("L", (width, height), 0)
    shade_draw = ImageDraw.Draw(shade)
    # Irregular masonry courses with bevels.
    y = -40
    row = 0
    while y < height:
        course = rnd.randint(150, 210)
        x = -rnd.randint(0, 200) if row % 2 else -rnd.randint(60, 260)
        while x < width:
            block_w = rnd.randint(220, 380)
            box = (x + 5, y + 5, x + block_w - 5, y + course - 5)
            tone = rnd.randint(-14, 14)
            draw.rectangle(box, outline=None, fill=None)
            shade_draw.rectangle(box, fill=128 + tone)
            # Mortar gaps.
            draw.rectangle((x, y, x + block_w, y + 4), fill=(160, 118, 70))
            draw.rectangle((x, y, x + 4, y + course), fill=(160, 118, 70))
            # Bevel: light top-left, dark bottom-right.
            draw.line((box[0], box[1], box[2], box[1]), fill=SAND_LIGHT, width=4)
            draw.line((box[0], box[1], box[0], box[3]), fill=SAND_LIGHT, width=3)
            draw.line((box[0], box[3], box[2], box[3]), fill=(150, 108, 62), width=5)
            draw.line((box[2], box[1], box[2], box[3]), fill=(150, 108, 62), width=4)
            # A few chips and cracks.
            if rnd.random() < 0.35:
                cx = rnd.randint(box[0] + 20, box[2] - 20)
                cy = rnd.randint(box[1] + 20, box[3] - 20)
                points = [(cx, cy)]
                for _ in range(rnd.randint(2, 4)):
                    cx += rnd.randint(-40, 40)
                    cy += rnd.randint(-25, 25)
                    points.append((cx, cy))
                draw.line(points, fill=(140, 100, 58), width=2)
            x += block_w
        y += course
        row += 1
    tint = shade.filter(ImageFilter.GaussianBlur(2)).convert("RGB")
    wall = ImageChops.add(wall, tint, scale=1.0, offset=-128)
    wall = wall.filter(ImageFilter.GaussianBlur(1.6))
    # Darken for UI contrast: warm dusk multiply + strong vignette.
    dusk = Image.new("RGB", (width, height), (96, 70, 46))
    wall = ImageChops.multiply(wall, dusk)
    vignette = Image.new("L", (width, height), 0)
    vdraw = ImageDraw.Draw(vignette)
    for i in range(60):
        t = i / 59
        inset_x = int(width * 0.5 * t)
        inset_y = int(height * 0.5 * t)
        vdraw.ellipse((-width * 0.35 + inset_x, -height * 0.25 + inset_y,
                       width * 1.35 - inset_x, height * 1.25 - inset_y), fill=int(255 * t ** 1.4))
    vignette = vignette.filter(ImageFilter.GaussianBlur(80))
    dark = Image.new("RGB", (width, height), (24, 16, 10))
    wall = Image.composite(wall, dark, vignette)
    # Warm light from the top.
    glow = Image.new("L", (width, height), 0)
    ImageDraw.Draw(glow).ellipse((width * 0.1, -height * 0.25, width * 0.9, height * 0.35), fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    wall = Image.composite(Image.new("RGB", (width, height), (255, 214, 150)), wall, glow)
    return wall


def draw_emblem(size=512):
    ss = 4
    s = size * ss
    c = s / 2
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def circle(r, **kw):
        d.ellipse((c - r, c - r, c + r, c + r), **kw)

    # Shadow.
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((c - s * 0.46 + 18, c - s * 0.46 + 30, c + s * 0.46 + 18, c + s * 0.46 + 30), fill=(20, 10, 4, 150))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(40)))
    d = ImageDraw.Draw(img)
    # Outer ring with notches (sun rays).
    circle(s * 0.46, fill=SAND_DARK)
    circle(s * 0.445, fill=SAND)
    for i in range(16):
        a = i / 16 * math.tau
        r1, r2 = s * 0.36, s * 0.44
        w = 0.07
        pts = [(c + math.cos(a - w) * r1, c + math.sin(a - w) * r1),
               (c + math.cos(a) * r2, c + math.sin(a) * r2),
               (c + math.cos(a + w) * r1, c + math.sin(a + w) * r1)]
        d.polygon(pts, fill=SAND_LIGHT if i % 2 == 0 else (206, 164, 104))
        d.line(pts[1:], fill=SAND_DARK, width=10)
    circle(s * 0.36, fill=SAND_DARK)
    circle(s * 0.345, fill=(214, 174, 116))
    # Inner gold disc.
    circle(s * 0.27, fill=GOLD_DARK)
    circle(s * 0.258, fill=GOLD)
    # Carved spiral.
    pts = []
    turns = 3.2
    for i in range(700):
        t = i / 699
        a = t * turns * math.tau
        r = s * 0.02 + t * s * 0.2
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.line(pts, fill=(118, 72, 20), width=int(s * 0.028), joint="curve")
    d.line([(x - 6, y - 6) for x, y in pts], fill=(255, 226, 150), width=int(s * 0.008), joint="curve")
    # Dots on the stone ring.
    for i in range(16):
        a = (i + 0.5) / 16 * math.tau
        r = s * 0.305
        x, y = c + math.cos(a) * r, c + math.sin(a) * r
        d.ellipse((x - 14, y - 14, x + 14, y + 14), fill=SAND_DARK)
    # Texture on stone parts.
    tex = noise((s, s), 40, 3, 22).convert("RGB")
    rgb = ImageChops.add(img.convert("RGB"), tex, scale=1.0, offset=-128)
    img = Image.merge("RGBA", (*rgb.split(), img.split()[3]))
    # Top-left light.
    light = Image.new("L", (s, s), 0)
    ImageDraw.Draw(light).ellipse((c - s * 0.5, c - s * 0.55, c + s * 0.2, c + s * 0.15), fill=70)
    light = light.filter(ImageFilter.GaussianBlur(120))
    lit = Image.composite(Image.new("RGB", (s, s), (255, 240, 200)), img.convert("RGB"), light)
    img = Image.merge("RGBA", (*lit.split(), img.split()[3]))
    return img.resize((size, size), Image.LANCZOS)


def draw_store(background, emblem):
    os.makedirs(STORE, exist_ok=True)
    # Icon: emblem on a warm square.
    icon = background.resize((1080, 1920)).crop((0, 420, 1080, 1500)).resize((512, 512))
    icon = icon.convert("RGBA")
    medal = emblem.resize((440, 440), Image.LANCZOS)
    icon.alpha_composite(medal, (36, 40))
    icon.convert("RGB").save(os.path.join(STORE, "icon_512.png"))
    # Cover 800x470: wall, emblem, a few blocks.
    cover = background.resize((800, 1422)).crop((0, 300, 800, 770)).convert("RGBA")
    cover.alpha_composite(emblem.resize((330, 330), Image.LANCZOS), (235, 60))
    names = ["green", "blue", "red", "amber", "purple", "turquoise"]
    blocks = [Image.open(os.path.join(BLOCKS, f"block_{n}.png")).convert("RGBA").resize((72, 72), Image.LANCZOS) for n in names]
    layout = [(40, 330, 0), (112, 330, 0), (112, 258, 0), (40, 402, 3), (112, 402, 3),
              (616, 330, 1), (688, 330, 1), (688, 258, 1), (616, 402, 2), (688, 402, 5)]
    for x, y, index in layout:
        cover.alpha_composite(blocks[index], (x, y - 40))
    cover.convert("RGB").save(os.path.join(STORE, "cover_800x470.png"))


if __name__ == "__main__":
    os.makedirs(MENU, exist_ok=True)
    bg = draw_background()
    bg.save(os.path.join(MENU, "background.jpg"), quality=86)
    emblem = draw_emblem()
    emblem.save(os.path.join(MENU, "emblem.png"), optimize=True)
    draw_store(bg, emblem)
    print("menu art written to", MENU, "and", STORE)
