"""Cuts sound candidates for every game sound out of the downloaded packs.

    python tools/build_sfx_candidates.py --packs C:/dev/audio_packs

Writes audio_review/sfx_candidates_v2/<slot>/<n>_<name>.ogg (0_current = the
sound the game plays now). Every candidate: mono 44.1 kHz, silence trimmed,
cut to the slot's length with a short fade, peak-normalised, plus a per-slot
level so quiet UI ticks do not shout over the music. Needs ffmpeg.
Listen in audio_review/index.html, choose in audio_review/sfx_choice.txt,
apply with tools/apply_sfx.py.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "audio_review" / "sfx_candidates_v2"
SFX = ROOT / "assets" / "audio" / "sfx"

KI = "kenney_impact-sounds/Audio/"
KR = "kenney_rpg-audio/Audio/"
TP = "01_Click_Tap/"
TH = "02_Hover/"
LO = "OGG/UI SFX_"

# slot: (max seconds, slot level dB (average = level - 14), [(name, source or [(source, delay ms)])])
SLOTS: dict[str, tuple[float, float, list]] = {
	"ui_click": (0.35, -8, [
		("wooden_button", TP + "03_Wooden_Button_Click_v1.wav"),
		("xylophone_tap", TP + "09_Xylophone_Bubble_Tap_v1.wav"),
		("marimba_confirm", LO + "MENU_Confirm.ogg"),
		("wood_knock", KI + "impactWood_light_000.ogg"),
	]),
	"pick": (0.4, -8, [
		("soft_bubble_pop", TP + "01_Soft_Bubble_Pop_v1.wav"),
		("glass_bead", TP + "05_Glass_Bead_Click_v1.wav"),
		("marimba_hover", LO + "MENU_Hover.ogg"),
		("cloth_lift", KR + "cloth1.ogg"),
	]),
	"place": (0.5, -5, [
		("wood_block", KI + "impactWood_medium_000.ogg"),
		("stone_step", KI + "footstep_concrete_000.ogg"),
		("plank", KI + "impactPlank_medium_000.ogg"),
		("soft_thud", KI + "impactSoft_heavy_000.ogg"),
		("marshmallow", TP + "10_Marshmallow_Squish_v1.wav"),
	]),
	"invalid": (0.7, -7, [
		("marimba_negative", LO + "FEEDBACK_Negative.ogg"),
		("quick_descend", LO + "EXTRA_Quick Sub Descending.ogg"),
		("rubber_tap", TP + "02_Rubber_Toy_Tap_v1.wav"),
		("soft_bump", KI + "impactSoft_medium_000.ogg"),
	]),
	"line_clear": (1.2, -4, [
		("star_twinkle", TH + "14_Star_Twinkle_v1.wav"),
		("candy_shimmer", TH + "18_Candy_Shimmer_v1.wav"),
		("leaf_sparkle", TH + "17_Leaf_Flick_Sparkle_v1.wav"),
		("marimba_positive", LO + "FEEDBACK_Positive.ogg"),
	]),
	"line_clear_multi": (1.8, -3, [
		("magical_sparkle", TH + "11_Magical_Sparkle_v1.wav"),
		("glockenspiel_hop", LO + "EXTRA_Glockenspiel Hopping.ogg"),
		("marimba_hop", LO + "EXTRA_Marimba Hopping.ogg"),
		("fairy_dust", TH + "20_Fairy_Dust_Sweep_v1.wav"),
	]),
	"dig": (0.6, -8, [
		("brush", TH + "13_Feather_Brush_v1.wav"),
		("sand_step", KI + "footstep_grass_000.ogg"),
		("gravel_step", KI + "footstep_concrete_001.ogg"),
		("soft_dirt", KI + "impactSoft_medium_000.ogg"),
	]),
	"stone_hit": (0.5, -5, [
		("pick_on_stone", KI + "impactMining_000.ogg"),
		("pick_on_stone_2", KI + "impactMining_002.ogg"),
		("stone_plate", KI + "impactPlate_light_000.ogg"),
		("light_knock", KI + "impactGeneric_light_000.ogg"),
	]),
	"stone_break": (0.9, -3, [
		("pick_crack", KI + "impactMining_003.ogg"),
		("crack_and_gravel", [(KI + "impactMining_001.ogg", 0), (KI + "footstep_concrete_001.ogg", 60)]),
		("heavy_crack", KI + "impactMining_004.ogg"),
		("crumble", KI + "impactGlass_heavy_000.ogg"),
	]),
	"root_cut": (0.6, -5, [
		("chop", KR + "chop.ogg"),
		("knife_slice", KR + "knifeSlice.ogg"),
		("draw_knife", KR + "drawKnife1.ogg"),
		("plank_snap", KI + "impactPlank_medium_001.ogg"),
	]),
	"root_grow": (1.2, -7, [
		("wood_creak", KR + "creak1.ogg"),
		("soft_woom", LO + "FEEDBACK_Woom.ogg"),
		("leather_stretch", KR + "beltHandle1.ogg"),
	]),
	"fragment_found": (1.8, -3, [
		("magical_sparkle", TH + "11_Magical_Sparkle_v2.wav"),
		("bell", KI + "impactBell_heavy_002.ogg"),
		("coins", KR + "handleCoins2.ogg"),
		("chime_save", LO + "InGameMenu_Save.ogg"),
	]),
	"victory": (4.5, -2, [
		("start_jingle", LO + "EXTRA_Start Button.ogg"),
		("menu_load_jingle", LO + "InGameMenu_Load.ogg"),
		("glockenspiel_hop", LO + "EXTRA_Glockenspiel Hopping.ogg"),
		("sparkle_and_bell", [(TH + "11_Magical_Sparkle_v1.wav", 0), (KI + "impactBell_heavy_002.ogg", 150)]),
	]),
	"no_moves": (1.6, -5, [
		("marimba_negative", LO + "FEEDBACK_Negative.ogg"),
		("quick_descend", LO + "EXTRA_Quick Sub Descending.ogg"),
		("alert", LO + "FEEDBACK_Alert.ogg"),
		("low_bell", KI + "impactBell_heavy_000.ogg"),
	]),
	"popup_open": (0.9, -9, [
		("marimba_open", LO + "InGameMenu_Open.ogg"),
		("airy_bell", TH + "12_Airy_Swoosh_Bell_v1.wav"),
		("book_open", KR + "bookOpen.ogg"),
	]),
	"score_count": (0.8, -9, [
		("coins", KR + "handleCoins.ogg"),
		("toy_chime", TH + "16_Toy_Chime_Tick_v1.wav"),
		("marimba_tick", LO + "MENU_Scroll.ogg"),
	]),
	"hint": (1.0, -6, [
		("star_twinkle", TH + "14_Star_Twinkle_v2.wav"),
		("fairy_dust", TH + "20_Fairy_Dust_Sweep_v2.wav"),
		("alert", LO + "FEEDBACK_Alert.ogg"),
	]),
	"streak": (1.0, -4, [
		("candy_shimmer", TH + "18_Candy_Shimmer_v2.wav"),
		("woop", LO + "FEEDBACK_Woop.ogg"),
		("bubble_rise", TH + "15_Bubble_Rise_Pop_v1.wav"),
	]),
}
FADE = 0.08

# Shown on the listening page.
SLOT_INFO = {
	"ui_click": ("Нажатие любой кнопки", "короткий, мягкий, не надоедает после сотни нажатий"),
	"pick": ("Взял фигуру из лотка", "лёгкий и тихий — звучит каждый ход"),
	"place": ("Поставил фигуру на поле", "глухой «тук» блока, очень короткий"),
	"invalid": ("Фигура не встала", "мягкий отказ, не сирена"),
	"line_clear": ("Собрана 1 линия", "главная награда хода: звонко, «самоцветно»"),
	"line_clear_multi": ("Собраны 2+ линии сразу", "ярче и богаче, чем одна линия"),
	"dig": ("Снят слой грунта", "песок/земля, короткий; звучит часто"),
	"stone_hit": ("Удар по камню (трещина)", "каменный стук кирки"),
	"stone_break": ("Камень разбит", "раскол и осыпь"),
	"root_cut": ("Корни срезаны", "хлёсткий срез"),
	"root_grow": ("Корни растут (угроза)", "тревожно, но не страшно"),
	"fragment_found": ("Открыт фрагмент находки", "«ценное нашлось!»"),
	"victory": ("Победа, окно экспедиции", "самый праздничный звук игры"),
	"no_moves": ("Тупик — фигурам нет места", "грустное «ой», без злости"),
	"popup_open": ("Открылось окно (пауза, итог)", "лёгкий и тихий"),
	"score_count": ("Счёт докручивается в окне победы", "звон, один раз"),
	"hint": ("Показана подсказка", "мягкое «дзинь»"),
	"streak": ("Серия в бесконечных раскопках", "играет выше с каждой ступенью"),
}
PACK_NAMES = {
	KI: "Kenney Impact Sounds (CC0)",
	KR: "Kenney RPG Audio (CC0)",
	TP: "Tiny Pops & Sparkles",
	TH: "Tiny Pops & Sparkles",
	LO: "lolurio Cozy UI (CC BY 4.0)",
}


def pack_of(path: str) -> str:
	for prefix, name in PACK_NAMES.items():
		if path.startswith(prefix):
			return name
	return ""


def write_index(built: dict[str, list[tuple[int, str, str, float]]]) -> None:
	parts = ["""<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Археоблоки — выбор звуков</title>
<style>body{font-family:system-ui,sans-serif;background:#2a2119;color:#f3e6c8;max-width:900px;margin:0 auto;padding:16px}
section{background:#3a2e22;border-radius:12px;padding:12px 16px;margin:12px 0}h2{margin:4px 0;color:#ffd98a}
.opt{display:grid;grid-template-columns:28px 1fr 300px;gap:8px;align-items:center;margin:6px 0}.opt small{grid-column:2;color:#b9a888}
.opt audio{grid-column:3;grid-row:1/3;width:300px;max-width:100%}b{color:#ffd98a}
@media(max-width:600px){.opt{grid-template-columns:28px 1fr}.opt audio{grid-column:1/3;grid-row:auto}}</style>
<h1>Звуки Археоблоков: что послушать (вариант 2)</h1>
<p>Паки: Kenney Impact и RPG Audio, Tiny Pops &amp; Sparkles, lolurio Cozy UI. Каждый вариант обрезан, сведён в моно,
громкость внутри одного звука выровнена. <b>0</b> — нынешний звук игры.</p>
<p>Номера впишите в <code>audio_review/sfx_choice.txt</code> и запустите <code>python tools/apply_sfx.py</code>.
Звуки lolurio можно брать, только указав в титрах «UI Sound Effects by lolurio».</p>
"""]
	for slot, options in built.items():
		title, need = SLOT_INFO[slot]
		parts.append(f'<section><h2>{slot}</h2><p><b>{title}.</b> Что нужно: {need}.</p>')
		for number, name, source, length in options:
			path = f"sfx_candidates_v2/{slot}/{number}_{name}.ogg"
			label = "нынешний звук игры" if number == 0 else f"{source} · {length:.2f} с"
			parts.append(
				f'<div class="opt"><b>{number}</b> <span>{name.replace("_", " ")}</span> '
				f'<small>{label}</small><audio controls preload="none" src="{path}"></audio></div>'
			)
		parts.append("</section>")
	(ROOT / "audio_review" / "index.html").write_text("".join(parts) + "</html>", encoding="utf-8")


def run(*args: str) -> str:
	return subprocess.run(args, capture_output=True, text=True, check=True).stderr


def levels(path: Path) -> tuple[float, float]:
	"""(mean dB, peak dB)."""
	log = run("ffmpeg", "-hide_banner", "-i", str(path), "-af", "volumedetect", "-f", "null", "-")
	mean = re.search(r"mean_volume: (-?[\d.]+) dB", log)
	peak = re.search(r"max_volume: (-?[\d.]+) dB", log)
	return (float(mean.group(1)) if mean else -20.0, float(peak.group(1)) if peak else 0.0)


def peak_db(path: Path) -> float:
	return levels(path)[1]


def duration(path: Path) -> float:
	out = subprocess.run(
		["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
		capture_output=True, text=True, check=True).stdout.strip()
	return float(out) if out not in ("", "N/A") else 0.0


def build(sources: list[tuple[Path, int]], target: Path, seconds: float, peak: float) -> None:
	raw = target.with_suffix(".raw.wav")
	cut = target.with_suffix(".cut.wav")
	inputs: list[str] = []
	chains: list[str] = []
	for index, (src, delay) in enumerate(sources):
		inputs += ["-i", str(src)]
		chains.append(f"[{index}:a]aformat=channel_layouts=mono,aresample=44100,adelay={delay}[a{index}]")
	mix = "".join(f"[a{i}]" for i in range(len(sources)))
	graph = ";".join(chains) + f";{mix}amix=inputs={len(sources)}:normalize=0"
	run("ffmpeg", "-y", "-hide_banner", *inputs, "-filter_complex", graph, str(raw))
	# Peak to -1 dB first (quiet recordings), then trim silence relative to it.
	gain = -1.0 - peak_db(raw)
	run("ffmpeg", "-y", "-hide_banner", "-i", str(raw), "-af",
		f"volume={gain:.2f}dB,"
		"silenceremove=start_periods=1:start_threshold=-45dB,"
		"areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
		f"atrim=0:{seconds}", str(cut))
	length = duration(cut)
	if length <= 0.0:
		raise RuntimeError(f"{target.name}: nothing left after trimming silence")
	# Equal loudness inside a slot: average level = slot level - 14 dB,
	# never louder than -1 dB peak.
	mean, top = levels(cut)
	level = min(peak - 14.0 - mean, -1.0 - top)
	fade_start = max(0.0, length - FADE)
	run("ffmpeg", "-y", "-hide_banner", "-i", str(cut), "-af",
		f"volume={level:.2f}dB,afade=t=out:st={fade_start:.3f}:d={FADE},alimiter=limit=0.95",
		"-c:a", "libvorbis", "-q:a", "5", str(target))
	raw.unlink()
	cut.unlink()


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--packs", required=True, help="folder with the unpacked sound packs")
	packs = Path(parser.parse_args().packs)
	if shutil.which("ffmpeg") is None:
		print("ffmpeg not found (Windows: winget install ffmpeg)")
		return 1
	built: dict[str, list[tuple[int, str, str, float]]] = {}
	for slot, (seconds, peak, options) in SLOTS.items():
		built[slot] = []
		folder = OUT / slot
		if folder.exists():
			shutil.rmtree(folder)
		folder.mkdir(parents=True)
		current = next((p for p in (SFX / f"{slot}.ogg", SFX / f"{slot}.wav") if p.exists()), None)
		if current is not None:
			run("ffmpeg", "-y", "-hide_banner", "-i", str(current), "-c:a", "libvorbis", "-q:a", "5", str(folder / "0_current.ogg"))
			built[slot].append((0, "current", "", 0.0))
		for number, (name, source) in enumerate(options, start=1):
			layers = source if isinstance(source, list) else [(source, 0)]
			target = folder / f"{number}_{name}.ogg"
			build([(packs / path, delay) for path, delay in layers], target, seconds, peak)
			source_text = " + ".join(f"{pack_of(path)}: {Path(path).stem}" for path, _ in layers)
			built[slot].append((number, name, source_text, duration(target)))
		print(f"{slot}: {len(options)} options")
	write_index(built)
	print("listening page: audio_review/index.html")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
