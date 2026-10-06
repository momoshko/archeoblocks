"""Builds the runtime copies of the approved ART V2A / V2B packs.

The source packs (assets/art_v2a, assets/art_v2b) stay .gdignore'd review
material in full resolution. The game loads the smaller copies written to
assets/ui_art/ by this script:

  * V2A cell sprites (terrain, blocks, obstacles, overlays): 256 -> 128 px.
  * V2B UI skins: scaled so their nine-patch corners fit mobile-sized
    controls; margins and transparent padding are scaled with the image and
    written to assets/ui_art/ui_metrics.json (used when editing the theme).

Usage (from the project folder, Python 3 + Pillow):
    python tools/export_runtime_art.py
Re-run after replacing a source PNG; file names stay the same.
"""

import json
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V2A = os.path.join(ROOT, "assets", "art_v2a")
V2B = os.path.join(ROOT, "assets", "art_v2b")
OUT = os.path.join(ROOT, "assets", "ui_art")

CELL_SIZE = 128

# name -> (scale, margins, padding[, source name]). Margins/padding from art_review/art_v2b/manifest.json,
# order [left, top, right, bottom].
UI = {
    "board_frame": (0.25, [153, 153, 153, 153], 32),
    "panel_header_large": (0.5, [70, 60, 70, 60], 24),
    "panel_header_small": (0.5, [43, 38, 43, 38], 16),
    "panel_label_small": (0.5, [37, 32, 37, 32], 16),
    "popup_panel": (0.5, [159, 159, 159, 159], 32),
    "popup_panel_small": (0.3, [159, 159, 159, 159], 32, "popup_panel"),
    "button_primary": (0.36, [64, 56, 64, 56], 24),
    "button_secondary": (0.36, [64, 56, 64, 56], 24),
    "button_disabled": (0.36, [64, 56, 64, 56], 24),
    "button_selected_frame": (0.36, [64, 56, 64, 56], 24),
    "button_small_back": (0.36, [45, 45, 45, 45], 16),
    "piece_slot": (0.5, [59, 50, 59, 50], 16),
    "chapter_card_open": (0.5, [84, 71, 84, 71], 24),
    "chapter_card_locked": (0.5, [84, 71, 84, 71], 24),
    "chapter_card_completed": (0.5, [84, 71, 84, 71], 24),
    "collection_card_known": (0.5, [79, 79, 79, 79], 16),
    "collection_card_unknown": (0.5, [79, 79, 79, 79], 16),
}


def resize(image: Image.Image, size) -> Image.Image:
    # Premultiplied resize avoids dark fringes around transparent edges.
    premultiplied = image.convert("RGBa")
    return premultiplied.resize(size, Image.LANCZOS).convert("RGBA")


def export_cells() -> list:
    written = []
    for folder in ("cells", "blocks", "obstacles", "overlays"):
        src_dir = os.path.join(V2A, folder)
        dst_dir = os.path.join(OUT, folder)
        os.makedirs(dst_dir, exist_ok=True)
        for name in sorted(os.listdir(src_dir)):
            if not name.endswith(".png"):
                continue
            image = Image.open(os.path.join(src_dir, name)).convert("RGBA")
            out_name = name.replace("_v2a.png", ".png")
            resize(image, (CELL_SIZE, CELL_SIZE)).save(os.path.join(dst_dir, out_name), optimize=True)
            written.append(f"{folder}/{out_name}")
    return written


def export_ui() -> dict:
    metrics = {}
    dst_dir = os.path.join(OUT, "ui")
    os.makedirs(dst_dir, exist_ok=True)
    for name, spec in UI.items():
        scale, margins, pad = spec[:3]
        source = spec[3] if len(spec) > 3 else name
        image = Image.open(os.path.join(V2B, f"{source}_v2b.png")).convert("RGBA")
        size = (round(image.width * scale), round(image.height * scale))
        resize(image, size).save(os.path.join(dst_dir, f"{name}.png"), optimize=True)
        metrics[name] = {
            "size": list(size),
            "texture_margins": [round(m * scale) for m in margins],
            "transparent_padding": round(pad * scale),
        }
    with open(os.path.join(OUT, "ui_metrics.json"), "w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=1)
    return metrics


if __name__ == "__main__":
    cells = export_cells()
    ui = export_ui()
    print(f"cells: {len(cells)} files, ui: {len(ui)} files -> {OUT}")
