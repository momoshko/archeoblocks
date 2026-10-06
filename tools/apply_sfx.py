"""Puts the chosen sound candidates into the game.

1. Open audio_review/index.html in a browser and listen.
2. Write the numbers into audio_review/sfx_choice.txt, e.g.  line_clear = 2
   (0 = keep / return to the old synthesized sound, empty = do not touch).
3. From the project folder:  python tools/apply_sfx.py

The chosen file is copied to assets/audio/sfx/<name>.ogg. The game prefers the
.ogg over the old .wav with the same name, so the old sound stays as a backup.
Choice 0 deletes the .ogg, so the old .wav plays again.
Needs only Python 3 (no extra packages).
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REVIEW = ROOT / "audio_review"
# Second round (Kenney, Tiny Pops, lolurio). The first round stays in sfx_candidates/.
CANDIDATES = REVIEW / "sfx_candidates_v2"
SFX = ROOT / "assets" / "audio" / "sfx"


def main() -> int:
    choice_file = REVIEW / "sfx_choice.txt"
    if not choice_file.exists():
        print("missing", choice_file)
        return 1
    changed = 0
    for raw in choice_file.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if "=" not in line:
            continue
        slot, number = (part.strip() for part in line.split("=", 1))
        if not number:
            continue
        target = SFX / f"{slot}.ogg"
        if number == "0":
            if target.exists():
                target.unlink()
                Path(str(target) + ".import").unlink(missing_ok=True)
                print(f"{slot}: back to the old sound")
                changed += 1
            continue
        matches = sorted((CANDIDATES / slot).glob(f"{number}_*.ogg"))
        if not matches:
            print(f"{slot}: no candidate number {number} in {CANDIDATES / slot}")
            continue
        shutil.copyfile(matches[0], target)
        print(f"{slot}: {matches[0].name} -> {target.relative_to(ROOT)}")
        changed += 1
    print(f"done: {changed} sounds changed. Open the project in Godot once so it imports them.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
