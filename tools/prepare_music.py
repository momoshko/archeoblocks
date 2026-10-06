"""Turns Suno downloads into game music.

Put the downloaded tracks into audio_review/music_raw/ named by game track:
    menu.mp3, gameplay.mp3, gameplay_ancient_courtyard.mp3, ... (see MUSIC_SUNO_RU.md)
Then from the project folder:  python tools/prepare_music.py

Each track becomes assets/audio/music/<name>.ogg: silence trimmed, loudness
evened out (-18 LUFS, so tracks do not jump in volume), soft fade-in and a
longer fade-out (the game loops the track; the fade hides the seam), 44.1 kHz,
Vorbis quality 3 (~2.3 MB for 3 minutes).
Needs ffmpeg on PATH (Windows: winget install ffmpeg).
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "audio_review" / "music_raw"
OUT = ROOT / "assets" / "audio" / "music"
KNOWN = {
    "menu", "gameplay", "gameplay_ancient_courtyard", "gameplay_ruined_shrine",
    "gameplay_overgrown_catacombs", "gameplay_endless", "restoration",
}
FADE_IN = 0.5
FADE_OUT = 2.5
# Vorbis quality: 3 (~110 kbps) is plenty for quiet background music and keeps
# the Web download small (every track is inside the .pck the player loads).
QUALITY = 3


def duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True,
    ).stdout
    return float(out.strip())


def main() -> int:
    if shutil.which("ffmpeg") is None:
        print("ffmpeg not found. Install it (winget install ffmpeg) or send the files to Claude.")
        return 1
    files = [p for p in sorted(RAW.glob("*")) if p.suffix.lower() in (".mp3", ".wav", ".ogg", ".flac", ".m4a")]
    if not files:
        print("nothing in", RAW)
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    for src in files:
        name = src.stem
        if name not in KNOWN:
            print(f"{src.name}: unknown track name, expected one of {sorted(KNOWN)}")
            continue
        target = OUT / f"{name}.ogg"
        trimmed = OUT / f"_{name}_tmp.wav"
        subprocess.run([
            "ffmpeg", "-y", "-v", "error", "-i", str(src),
            "-af", "silenceremove=start_periods=1:start_threshold=-55dB,"
                   "areverse,silenceremove=start_periods=1:start_threshold=-55dB,areverse,"
                   "loudnorm=I=-18:TP=-1.5:LRA=11",
            "-ar", "44100", "-ac", "2", str(trimmed),
        ], check=True)
        length = duration(trimmed)
        subprocess.run([
            "ffmpeg", "-y", "-v", "error", "-i", str(trimmed),
            "-af", f"afade=t=in:d={FADE_IN},afade=t=out:st={max(0.0, length - FADE_OUT):.2f}:d={FADE_OUT}",
            "-c:a", "libvorbis", "-q:a", str(QUALITY), str(target),
        ], check=True)
        trimmed.unlink()
        print(f"{src.name} -> {target.relative_to(ROOT)}  {length:.0f} s, {target.stat().st_size // 1024} KB")
    print("done. Open the project in Godot once so it imports the music; add every track to CREDITS.md.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
