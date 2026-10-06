"""Turn Gemini (Nano Banana Pro) images into game-ready art.

Gemini cannot draw a transparent background. So every picture is generated
twice: once on pure white, then the same picture with the background changed to
pure black. From the pair this script computes real transparency ("difference
matting": what differs between the two is background). With only the white
image it falls back to cutting out the white background.

Then, for finds, it trims the object, fits it into 384 px on a 512x512 canvas
(like the approved golden mask) and cuts the fragments along irregular broken
edges, each fragment in place on its own 512x512 canvas.

Usage (from the project folder; needs Python 3 with Pillow and numpy):
    python tools/gemini_import.py                  # everything found in raw/
    python tools/gemini_import.py bronze_key emblem
    python tools/gemini_import.py --check          # list what is still missing
    python tools/gemini_import.py --pack=gemini_pack_v1 bronze_key   # older pack
    python tools/gemini_import.py sheet_icons_1    # one sprite sheet (see below)

Input:  art_review/gemini_pack_v2/raw/<id>_white.png  (+ <id>_black.png)
        (another pack: --pack=gemini_pack_v1)
        .png, .jpg, .jpeg or .webp are all fine.
Sprite sheets (GEMINI_SHEETS.md): several icons or effects in one picture,
raw/<sheet id>_white.png (+ _black.png), or only raw/<sheet id>_black.png for
glowing effects drawn on black (transparency then comes from brightness).
The script finds every picture on the sheet by the empty space around it,
orders them in rows (left to right, top to bottom) and saves each one like a
single item. If the count does not match, it falls back to the grid.

Gemini sometimes signs every sprite ("icon_pause") and draws the "black"
pass on grey: captions are removed and both background colours are read
from the border of the picture. "matte": "white" on a sheet in prompts.json
ignores an unusable black pass; "atlas": "<path>" also saves all sprites of
the sheet side by side in one strip (for particles with random frames).

Output: the paths from art_review/gemini_pack_v2/prompts.json, plus review
        sheets in art_review/gemini_pack_v2/review/. A find is also linked to
        its expedition (resources/expeditions/*.tres with the same artifact_id):
        full_artifact_texture and fragment_textures are set there.
"""

from __future__ import annotations

import json
import math
import re
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / "art_review" / "gemini_pack_v2"
RAW = PACK / "raw"
REVIEW = PACK / "review"


def use_pack(name: str) -> None:
    global PACK, RAW, REVIEW
    PACK = ROOT / "art_review" / name
    RAW = PACK / "raw"
    REVIEW = PACK / "review"
EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp")


# ---------------------------------------------------------------- loading ----

def find_raw(item_id: str, variant: str) -> Path | None:
    for ext in EXTENSIONS:
        path = RAW / f"{item_id}_{variant}{ext}"
        if path.exists():
            return path
    return None


WORK_SIZE = 1024  # the game uses 384 px; bigger only slows the script down


def load_rgb(path: Path, size: tuple[int, int] | None = None, work_size: int = WORK_SIZE) -> np.ndarray:
    image = Image.open(path).convert("RGB")
    if size is None:
        scale = min(1.0, work_size / max(image.size))
        size = (round(image.width * scale), round(image.height * scale))
    if image.size != size:
        image = image.resize(size, Image.LANCZOS)
    return np.asarray(image, dtype=np.float32) / 255.0


# --------------------------------------------------------------- matting ----

def difference_matte(white: np.ndarray, black: np.ndarray) -> tuple[np.ndarray, float]:
    """Alpha and colour from the same picture on white and on black.

    On white a pixel shows a*C + (1-a); on black it shows a*C, so the difference
    is (1-a). Gemini redraws the object a little on the second pass, so inside
    the object the difference is noisy; the pair is trusted only for the
    silhouette. Everything more than 2 px away from the real background is
    solid; the thin edge band keeps the soft alpha. Colour comes from the white
    picture (the one you approved), un-mixed from the white background.
    Returns RGBA float and the share of pixels where the two clearly disagree.
    """
    # Gemini's "black" is sometimes grey or dark brown, and "white" is
    # sometimes off-white: take both background colours from the border.
    white_bg = border_colour(white)
    black_bg = border_colour(black)
    # On white a pixel is a*C + (1-a)*Wbg, on black a*C + (1-a)*Bbg,
    # so (white - black) / (Wbg - Bbg) = 1 - a.
    span = np.maximum(white_bg - black_bg, 0.25)
    diff = (white - black) / span
    disagreement = float(np.mean(np.any(diff < -0.08, axis=2)))
    raw_alpha = 1.0 - np.clip(diff.mean(axis=2), 0.0, 1.0)
    clear = raw_alpha < 0.05
    labels, sizes = _label(clear)
    # Big clear areas are background. Small ones are either real openings (the
    # gaps in a crown: pure white on one picture, pure black on the other) or
    # redraw noise inside the object; keep only the real openings.
    pure = (white.min(axis=2) > 0.93) & (np.abs(black - black_bg).max(axis=2) < 0.07)
    pure_share = np.bincount(labels.ravel(), weights=pure.ravel(), minlength=len(sizes))
    min_size = clear.size * 0.0005
    background_ids = [
        i for i, size in enumerate(sizes)
        if i and (size >= min_size or (size >= 12 and pure_share[i] >= 0.8 * size))
    ]
    real_background = np.isin(labels, background_ids)
    alpha = np.where(_dilate(real_background, 2), raw_alpha, 1.0)
    alpha[real_background] = 0.0
    safe = np.maximum(alpha, 1e-4)[..., None]
    colour = np.clip((white - (1.0 - safe) * white_bg) / safe, 0.0, 1.0)
    return np.dstack([colour, alpha]).astype(np.float32), disagreement


def border_colour(image: np.ndarray, band: int = 8) -> np.ndarray:
    """Median colour of the outer frame of the picture (= the background)."""
    edge = np.concatenate([
        image[:band].reshape(-1, 3), image[-band:].reshape(-1, 3),
        image[:, :band].reshape(-1, 3), image[:, -band:].reshape(-1, 3),
    ])
    return np.median(edge, axis=0).astype(np.float32)


def _label(mask: np.ndarray) -> tuple[np.ndarray, list[int]]:
    """Connected areas (4-neighbour): label image and size of every label (0 = none)."""
    try:
        from scipy import ndimage
        labels, count = ndimage.label(mask)
        sizes = [0] + [int(v) for v in np.bincount(labels.ravel())[1:count + 1]]
        return labels, sizes
    except ImportError:
        pass
    labels = np.zeros(mask.shape, dtype=np.int32)
    sizes = [0]
    height, width = mask.shape
    for y0, x0 in zip(*np.nonzero(mask)):
        if labels[y0, x0]:
            continue
        label = len(sizes)
        count = 0
        stack = [(y0, x0)]
        labels[y0, x0] = label
        while stack:
            y, x = stack.pop()
            count += 1
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = label
                    stack.append((ny, nx))
        sizes.append(count)
    return labels, sizes


def white_key_matte(white: np.ndarray, tolerance: float = 0.07, holes: bool = False) -> np.ndarray:
    """Cut out a white background that touches the image border.
    holes=True also clears closed pure-white areas inside a picture (the loops
    of an infinity sign, the inside of a padlock shackle) - used for sheets,
    where an icon never has large pure-white parts of its own."""
    height, width, _ = white.shape
    whiteness = 1.0 - white.min(axis=2)          # 0 = pure white
    near_white = whiteness < tolerance
    background = np.zeros((height, width), dtype=bool)
    stack = [(0, x) for x in range(width)] + [(height - 1, x) for x in range(width)]
    stack += [(y, 0) for y in range(height)] + [(y, width - 1) for y in range(height)]
    while stack:
        y, x = stack.pop()
        if background[y, x] or not near_white[y, x]:
            continue
        background[y, x] = True
        if y > 0:
            stack.append((y - 1, x))
        if y < height - 1:
            stack.append((y + 1, x))
        if x > 0:
            stack.append((y, x - 1))
        if x < width - 1:
            stack.append((y, x + 1))
    if holes:
        labels, sizes = _label(near_white & ~background & (white.min(axis=2) > 0.96))
        big = [i for i, size in enumerate(sizes) if i and size >= 0.0002 * near_white.size]
        background |= np.isin(labels, big)
    alpha = np.where(background, 0.0, 1.0).astype(np.float32)
    # Soft edge: object pixels next to the background get alpha from how
    # far they are from white, and their colour is un-mixed from white.
    edge = _dilate(background, 2) & ~background
    soft = np.clip(whiteness / 0.35, 0.0, 1.0)
    alpha = np.where(edge, np.minimum(alpha, soft), alpha)
    safe = np.maximum(alpha, 1e-4)[..., None]
    colour = np.clip((white - (1.0 - safe)) / safe, 0.0, 1.0)
    return np.dstack([colour, alpha])


def _dilate(mask: np.ndarray, steps: int) -> np.ndarray:
    result = mask.copy()
    for _ in range(steps):
        grown = result.copy()
        grown[1:, :] |= result[:-1, :]
        grown[:-1, :] |= result[1:, :]
        grown[:, 1:] |= result[:, :-1]
        grown[:, :-1] |= result[:, 1:]
        result = grown
    return result


def drop_specks(rgba: np.ndarray, keep_ratio: float = 0.03) -> np.ndarray:
    """Removes small separate blobs (Gemini's sparkle mark, dust) away from the object."""
    labels, sizes = _label(rgba[..., 3] > 0.5)
    if len(sizes) <= 2:
        return rgba
    biggest = max(sizes)
    keep = [index for index, size in enumerate(sizes) if index and size >= biggest * keep_ratio]
    keep_mask = _dilate(np.isin(labels, keep), 3)
    result = rgba.copy()
    result[..., 3] = np.where(keep_mask, result[..., 3], 0.0)
    return result


def _same_aspect(first: tuple, second: tuple) -> bool:
    return abs(first[1] / first[0] - second[1] / second[0]) < 0.01


def black_luma_matte(black: np.ndarray, floor: float = 0.04) -> np.ndarray:
    """Glow or dust drawn on black: the brighter the pixel, the more opaque.
    Colour is un-mixed from black, so the glow keeps its hue when drawn over
    anything (the result looks like "add" blending on a dark background)."""
    brightness = black.max(axis=2)
    alpha = np.clip((brightness - floor) / (1.0 - floor), 0.0, 1.0)
    colour = np.clip(black / np.maximum(brightness, 1e-4)[..., None], 0.0, 1.0)
    colour = np.where(alpha[..., None] > 1e-4, colour, 0.0)
    return np.dstack([colour, alpha]).astype(np.float32)


def matte(item_id: str, work_size: int = WORK_SIZE, specks: bool = True, holes: bool = False,
          white_only: bool = False) -> tuple[np.ndarray, str]:
    white_path = find_raw(item_id, "white")
    if white_path is None:
        black_only = find_raw(item_id, "black")
        if black_only is not None:
            return black_luma_matte(load_rgb(black_only, work_size=work_size)), "black only (brightness)"
        raise FileNotFoundError(f"raw/{item_id}_white.png is missing")
    finish = drop_specks if specks else (lambda rgba: rgba)
    white = load_rgb(white_path, work_size=work_size)
    black_path = None if white_only else find_raw(item_id, "black")
    if black_path is not None:
        with Image.open(black_path) as probe:
            black_size = probe.size
        black = None
        if _same_aspect((black_size[1], black_size[0]), white.shape):
            # Gemini sometimes returns the second pass at another resolution.
            black = load_rgb(black_path, (white.shape[1], white.shape[0]))
        if black is not None:
            rgba, disagreement = difference_matte(white, black)
            if disagreement < 0.01:
                return finish(rgba), "white+black"
            print(f"  {item_id}: the black version differs from the white one "
                  f"({disagreement:.1%} of pixels) - using the white background only")
        else:
            print(f"  {item_id}: white and black images have different shapes - using white only")
    return finish(white_key_matte(white, holes=holes)), "white only"


# ------------------------------------------------------------ fitting ----

def to_image(rgba: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(rgba * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def fit_on_canvas(image: Image.Image, canvas: int, fit: int) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        raise ValueError("the picture is empty after cutting out the background")
    obj = image.crop(bbox)
    scale = fit / max(obj.size)
    size = (max(1, round(obj.width * scale)), max(1, round(obj.height * scale)))
    # Resize premultiplied, so the edge does not get a white/black halo.
    premultiplied = np.asarray(obj, dtype=np.float32) / 255.0
    premultiplied[..., :3] *= premultiplied[..., 3:4]
    channels = [
        Image.fromarray((premultiplied[..., i] * 255).astype(np.uint8), "L").resize(size, Image.LANCZOS)
        for i in range(4)
    ]
    resized = np.dstack([np.asarray(c, dtype=np.float32) / 255.0 for c in channels])
    alpha = resized[..., 3:4]
    resized[..., :3] = np.where(alpha > 1e-4, resized[..., :3] / np.maximum(alpha, 1e-4), 0.0)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(to_image(resized), ((canvas - size[0]) // 2, (canvas - size[1]) // 2))
    return out


def fit_opaque(image: Image.Image, width: int, height: int) -> Image.Image:
    """Cover-crop an opaque picture (background, cover) to the exact size."""
    image = image.convert("RGB")
    scale = max(width / image.width, height / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left = (resized.width - width) // 2
    top = (resized.height - height) // 2
    return resized.crop((left, top, left + width, top + height))


# ------------------------------------------------------------- slicing ----

def _jagged(length: int, amplitude: float, rng: random.Random) -> np.ndarray:
    """A broken-edge profile: two slow waves plus small random steps."""
    t = np.arange(length, dtype=np.float32)
    wave = (
        0.6 * np.sin(2 * math.pi * t / rng.uniform(120, 170) + rng.uniform(0, 6.3))
        + 0.4 * np.sin(2 * math.pi * t / rng.uniform(40, 70) + rng.uniform(0, 6.3))
    )
    knots = np.array([rng.uniform(-1.0, 1.0) for _ in range(length // 10 + 2)], dtype=np.float32)
    steps = np.interp(t, np.arange(len(knots)) * 10.0, knots)
    return amplitude * (0.75 * wave + 0.45 * steps)


def fragment_regions(alpha: np.ndarray, parts: int, cut: str, seed: int) -> np.ndarray:
    """Region index (0..parts-1) for every pixel; complementary by construction."""
    height, width = alpha.shape
    rng = random.Random(seed)
    ys, xs = np.mgrid[0:height, 0:width].astype(np.float32)
    weight = (alpha > 0.1).astype(np.float32)
    if cut == "arcs":
        cy = float((ys * weight).sum() / weight.sum())
        cx = float((xs * weight).sum() / weight.sum())
        angle = (np.degrees(np.arctan2(ys - cy, xs - cx)) + 90.0 + 360.0) % 360.0  # 0 = top
        radius = np.hypot(ys - cy, xs - cx)
        profile = _jagged(int(radius.max()) + 2, 7.0, rng)
        angle = (angle + profile[radius.astype(int)] / np.maximum(radius, 20.0) * 57.3) % 360.0
        order = np.sort(angle[weight > 0])
        bounds = [order[int(len(order) * k / parts)] for k in range(1, parts)]
        return np.searchsorted(np.array(bounds), angle).astype(np.int32)
    if cut == "columns":
        along, across = xs, ys
    elif cut == "diagonal":
        along, across = (xs + ys) / math.sqrt(2), (xs - ys) / math.sqrt(2) + width
    else:  # rows (also "cracks")
        along, across = ys, xs
    values = along[weight > 0]
    thresholds = [float(np.quantile(values, k / parts)) for k in range(1, parts)]
    region = np.zeros((height, width), dtype=np.int32)
    lowest = None
    for threshold in thresholds:
        profile = _jagged(int(across.max()) + 2, 9.0, rng)
        boundary = threshold + profile[np.clip(across, 0, len(profile) - 1).astype(int)]
        if lowest is not None:
            boundary = np.maximum(boundary, lowest + 18.0)
        region += (along > boundary).astype(np.int32)
        lowest = boundary
    return region


def cut_fragments(full: Image.Image, parts: int, cut: str, seed: int) -> list[Image.Image]:
    rgba = np.asarray(full, dtype=np.float32) / 255.0
    region = fragment_regions(rgba[..., 3], parts, cut, seed)
    # Darken the broken edge a little (1 px strong, 2nd px softer).
    edge1 = np.zeros(region.shape, dtype=bool)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        shifted = np.roll(region, (dy, dx), axis=(0, 1))
        edge1 |= shifted != region
    edge2 = _dilate(edge1, 1) & ~edge1
    fragments = []
    for index in range(parts):
        piece = rgba.copy()
        own = region == index
        piece[..., 3] = np.where(own, piece[..., 3], 0.0)
        shade = np.ones(region.shape, dtype=np.float32)
        shade[edge1 & own] = 0.62
        shade[edge2 & own] = 0.82
        piece[..., :3] *= shade[..., None]
        fragments.append(to_image(piece))
    return fragments


# -------------------------------------------------------------- review ----

def review_sheet(item_id: str, images: list[Image.Image]) -> None:
    REVIEW.mkdir(parents=True, exist_ok=True)
    tile = 256
    sheet = Image.new("RGBA", (tile * len(images), tile * 2), (0, 0, 0, 0))
    for index, image in enumerate(images):
        small = image.resize((tile, tile), Image.LANCZOS)
        for row, colour in enumerate(((58, 46, 36, 255), (238, 226, 200, 255))):
            cell = Image.new("RGBA", (tile, tile), colour)
            cell.alpha_composite(small)
            sheet.paste(cell, (index * tile, row * tile))
    sheet.convert("RGB").save(REVIEW / f"{item_id}_review.png")


# -------------------------------------------------------------- sheets ----

SHEET_WORK_SIZE = 2048  # a sheet keeps full resolution: every cell is a small sprite


def _grow(mask: np.ndarray, distance: float) -> np.ndarray:
    try:
        from scipy import ndimage
        return ndimage.distance_transform_edt(~mask) <= distance
    except ImportError:
        return _dilate(mask, int(round(distance)))


def drop_captions(rgba: np.ndarray) -> tuple[np.ndarray, int]:
    """Gemini sometimes signs every sprite with its id ("icon_pause") under it.
    A caption is a short, dark, wide strip of letters below a picture, separated
    from it by an empty band. Inside every grid row, such strips are cleared."""
    alpha = rgba[..., 3]
    solid = alpha > 0.1
    rows_used = solid.any(axis=1)
    bands, start = [], None
    for y, used in enumerate(np.append(rows_used, False)):
        if used and start is None:
            start = y
        elif not used and start is not None:
            bands.append((start, y))
            start = None
    if len(bands) < 2:
        return rgba, 0
    tallest = max(b - a for a, b in bands)
    result = rgba.copy()
    dropped = 0
    for top, bottom in bands:
        strip = solid[top:bottom]
        if bottom - top > 0.5 * tallest:
            continue
        luma = rgba[top:bottom, :, :3].mean(axis=2)[strip]
        if luma.size and float(np.median(luma)) < 0.3:
            result[top:bottom, :, 3] = 0.0
            dropped += 1
    return result, dropped


def sheet_groups(alpha: np.ndarray, expected: int, grid: tuple[int, int]) -> tuple[list[np.ndarray], str]:
    """Masks of the separate pictures on a sheet, in reading order.

    Parts of one picture (the two bars of a pause icon, sound waves) are joined
    by growing every shape a little; pictures are further apart than that.
    """
    height, width = alpha.shape
    solid = alpha > 0.1
    joined = _grow(solid, max(4.0, 0.02 * max(height, width)))
    labels, sizes = _label(joined)
    min_area = 0.001 * height * width
    groups = []
    for index, size in enumerate(sizes):
        if not index:
            continue
        own = (labels == index) & (alpha > 0.02)
        if own.sum() < min_area:
            continue
        ys, xs = np.nonzero(own)
        groups.append((own, float(ys.mean()), float(xs.mean()), ys.max() - ys.min() + 1))
    if len(groups) == expected:
        groups.sort(key=lambda g: g[1])
        rows, current = [], [groups[0]]
        typical = float(np.median([g[3] for g in groups]))
        for group in groups[1:]:
            if group[1] - current[-1][1] > 0.5 * typical:
                rows.append(current)
                current = [group]
            else:
                current.append(group)
        rows.append(current)
        ordered = [g[0] for row in rows for g in sorted(row, key=lambda g: g[2])]
        return ordered, f"found {expected} pictures"
    # Fallback: every shape goes to the grid cell its centre is in.
    columns, rows_count = grid
    cells = [np.zeros_like(solid) for _ in range(columns * rows_count)]
    for own, cy, cx, _ in groups:
        cell = min(rows_count - 1, int(cy / height * rows_count)) * columns + min(columns - 1, int(cx / width * columns))
        cells[cell] |= own
    return cells, f"found {len(groups)} pictures instead of {expected} - used the {columns}x{rows_count} grid"


def process_sheet(sheet: dict, by_id: dict) -> None:
    sheet_id = sheet["id"]
    # "matte": "white" in prompts.json: the black pass of this sheet is not
    # usable (Gemini moved or redrew the icons), cut from the white one only.
    white_only = sheet.get("matte") == "white"
    rgba, method = matte(sheet_id, SHEET_WORK_SIZE, specks=False, holes=True, white_only=white_only)
    rgba, captions = drop_captions(rgba)
    if captions:
        method += f"; removed {captions} caption rows"
    cells = sheet["cells"]
    masks, how = sheet_groups(rgba[..., 3], len(cells), tuple(sheet["grid"]))
    images = []
    for cell_id, mask in zip(cells, masks):
        if cell_id is None:
            continue
        item = by_id[cell_id]
        if not mask.any():
            print(f"  {sheet_id}: {cell_id} - EMPTY cell, nothing saved")
            continue
        piece = rgba.copy()
        piece[..., 3] = np.where(mask, piece[..., 3], 0.0)
        output = ROOT / item["output"]
        output.parent.mkdir(parents=True, exist_ok=True)
        full = fit_on_canvas(to_image(piece), item.get("canvas", 256), item.get("fit", 224))
        full.save(output)
        images.append(full)
    if sheet.get("atlas") and images:
        # All sprites side by side in one strip: one particle system picks a
        # random frame (CanvasItemMaterial particles_anim_h_frames).
        tile = images[0].width
        atlas = Image.new("RGBA", (tile * len(images), tile), (0, 0, 0, 0))
        for index, image in enumerate(images):
            atlas.alpha_composite(image, (index * tile, 0))
        atlas.save(ROOT / sheet["atlas"])
        print(f"      atlas -> {sheet['atlas']}")
    review_sheet(sheet_id, images)
    print(f"  {sheet_id}: {len(images)} sprites ({method}; {how})")
    for cell_id in cells:
        if cell_id is not None:
            print(f"      {cell_id} -> {by_id[cell_id]['output']}")


# ------------------------------------------------------------- linking ----

def link_expeditions(item: dict) -> list[str]:
    """Sets full_artifact_texture / fragment_textures in every expedition .tres
    whose artifact_id is this find. Returns the changed file names."""
    folder = ROOT / "resources" / "expeditions"
    full_path = "res://" + item["output"]
    fragment_paths = ["res://" + str(Path(item["output"]).parent / name).replace("\\", "/")
                      for name in item.get("fragment_files", [])]
    changed = []
    for path in sorted(folder.glob("*.tres")):
        text = path.read_text(encoding="utf-8")
        if f'artifact_id = &"{item["id"]}"' not in text:
            continue
        ids = []
        for index, texture_path in enumerate([full_path] + fragment_paths):
            texture_id = "art_full" if index == 0 else f"art_fragment_{'abc'[index - 1]}"
            line = f'[ext_resource type="Texture2D" path="{texture_path}" id="{texture_id}"]'
            text = re.sub(rf'^\[ext_resource type="Texture2D"[^\n]*id="{texture_id}"\]\n', "", text, flags=re.M)
            last = list(re.finditer(r"^\[ext_resource [^\n]*\]$", text, re.M))[-1]
            text = text[:last.end()] + "\n" + line + text[last.end():]
            ids.append(texture_id)
        text = re.sub(r"^full_artifact_texture = .*\n", "", text, flags=re.M)
        text = re.sub(r"^fragment_textures = .*\n", "", text, flags=re.M)
        properties = f'full_artifact_texture = ExtResource("{ids[0]}")\n'
        if len(ids) > 1:
            listed = ", ".join(f'ExtResource("{texture_id}")' for texture_id in ids[1:])
            properties += f"fragment_textures = Array[Texture2D]([{listed}])\n"
        anchor = re.search(r"^artifact_fragments = .*\n", text, re.M)
        text = text[:anchor.end()] + properties + text[anchor.end():]
        path.write_text(text, encoding="utf-8")
        changed.append(path.name)
    return changed


# ---------------------------------------------------------------- main ----

def process(item: dict) -> None:
    item_id = item["id"]
    kind = item.get("kind", "find")
    output = ROOT / item["output"]
    output.parent.mkdir(parents=True, exist_ok=True)
    if kind == "opaque":
        path = find_raw(item_id, "white") or find_raw(item_id, "image")
        if path is None:
            raise FileNotFoundError(f"raw/{item_id}_image.png is missing")
        width, height = item["size"]
        picture = fit_opaque(Image.open(path), width, height)
        if output.suffix.lower() in (".jpg", ".jpeg"):
            picture.save(output, quality=90)
        else:
            picture.save(output)
        review_sheet(item_id, [picture.convert("RGBA").resize((512, round(512 * height / width)))])
        print(f"  {item_id}: {output.relative_to(ROOT)} {width}x{height}")
        return
    rgba, method = matte(item_id)
    canvas, fit = item.get("canvas", 512), item.get("fit", 384)
    full = fit_on_canvas(to_image(rgba), canvas, fit)
    full.save(output)
    images = [full]
    fragment_files = item.get("fragment_files", [])
    if fragment_files:
        seed = sum(ord(c) for c in item_id)
        pieces = cut_fragments(full, len(fragment_files), item.get("cut", "rows"), seed)
        for name, piece in zip(fragment_files, pieces):
            piece.save(output.parent / name)
        images += pieces
    review_sheet(item_id, images)
    linked = link_expeditions(item) if item.get("group") == "finds" else []
    print(f"  {item_id}: {output.relative_to(ROOT)} ({method}), fragments: {len(fragment_files)}"
          + (f", linked: {', '.join(linked)}" if linked else ""))


def main(argv: list[str]) -> int:
    for arg in argv:
        if arg.startswith("--pack="):
            use_pack(arg.split("=", 1)[1])
    pack = json.loads((PACK / "prompts.json").read_text(encoding="utf-8"))
    items = pack["items"]
    by_id = {item["id"]: item for item in items}
    sheets = {sheet["id"]: sheet for sheet in pack.get("sheets", [])}

    def has_raw(raw_id: str) -> bool:
        return any(find_raw(raw_id, v) for v in ("white", "image"))

    def sheet_ready(sheet_id: str) -> bool:
        mode = sheets[sheet_id].get("mode")
        return bool(find_raw(sheet_id, "black") if mode == "black_only" else find_raw(sheet_id, "white"))

    in_sheet = {cell: sheet_id for sheet_id, sheet in sheets.items() for cell in sheet["cells"] if cell}
    if "--check" in argv:
        missing = [i for i in by_id if not has_raw(i) and not (i in in_sheet and sheet_ready(in_sheet[i]))]
        print(f"ready: {len(by_id) - len(missing)} / {len(by_id)}")
        for item_id in missing:
            name = "image" if by_id[item_id].get("kind") == "opaque" else "white"
            where = f" (or sheet {in_sheet[item_id]})" if item_id in in_sheet else ""
            print(f"  missing raw/{item_id}_{name}.png{where}")
        return 0
    wanted = [a for a in argv if not a.startswith("--")]
    unknown = [a for a in wanted if a not in by_id and a not in sheets]
    if unknown:
        print("unknown ids:", ", ".join(unknown))
        return 1
    # A single raw picture wins over the sheet for that item (a redo of one icon).
    todo = wanted or ([s for s in sheets if sheet_ready(s)] + [i for i in by_id if has_raw(i)])
    if not todo:
        print("nothing in", RAW)
        return 1
    failed = 0
    for item_id in todo:
        try:
            if item_id in sheets:
                process_sheet(sheets[item_id], by_id)
            else:
                process(by_id[item_id])
        except Exception as error:  # keep going with the rest
            failed += 1
            print(f"  {item_id}: FAILED - {error}")
    print(f"done: {len(todo) - failed} ok, {failed} failed; review sheets in {REVIEW.relative_to(ROOT)}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
