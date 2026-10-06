# Credits and licenses

Every third-party or AI-generated file shipped in the game is listed here:
file → source → license → date → plan/tariff (for AI services).

## Audio

| Files | Source | License | Date |
| --- | --- | --- | --- |
| `assets/audio/sfx/*.wav` | Synthesized by `tools/generate_sfx.py` (no samples); kept as fallbacks, the `.ogg` with the same name wins | Project's own work | 2026-09-29 |
| `assets/audio/sfx/ui_click.ogg`, `place.ogg`, `dig.ogg`, `stone_hit.ogg`, `stone_break.ogg`, `root_cut.ogg`, `score_count.ogg` | [Kenney](https://kenney.nl) Impact Sounds and RPG Audio, cut and levelled by `tools/build_sfx_candidates.py` | CC0 | 2026-10-05 |
| `assets/audio/sfx/restore_brush.ogg`, `restore_sponge.ogg`, `restore_scalpel.ogg`, `restore_snap.ogg` | Kenney RPG Audio (cloth3, cloth4, drawKnife3) and Impact Sounds (impactPlate_light_001), cut, filtered and levelled with ffmpeg | CC0 | 2026-10-06 |
| `assets/audio/sfx/pick.ogg`, `invalid.ogg`, `root_grow.ogg`, `fragment_found.ogg`, `victory.ogg`, `no_moves.ogg`, `popup_open.ogg` | lolurio «Cozy Game UI SFX» ([lolurio.itch.io](https://lolurio.itch.io/)). **Credit required: «UI Sound Effects by lolurio»** (store description / credits) | CC BY 4.0 | 2026-10-05 |
| `assets/audio/sfx/line_clear.ogg`, `line_clear_multi.ogg`, `hint.ogg`, `streak.ogg` | «Tiny Pops & Sparkles» pack (folders `01_Click_Tap`, `02_Hover` in `audio_packs`) | **check the pack's license before release** | 2026-10-05 |
| `assets/audio/music/*.ogg` (menu, 3 chapter tracks, endless, restoration) | Generated in Suno by the author (prompts in `MUSIC_SUNO_RU.md`), trimmed and looped by `tools/prepare_music.py` | Suno terms for the plan used: **commercial use only on a paid plan** — write the plan here before release | 2026-10 |

## Images

| Files | Source | License | Date | Plan |
| --- | --- | --- | --- | --- |
| `assets/blocks/`, `assets/cells/`, `assets/artifacts/`, `assets/art_v2a/`, `assets/art_v2b/` | Generated with built-in ImageGen (see `art_review/*/prompts.json`) | Pre-generated AI material (Yandex rule 1.23 allows it) | 2026-09 | fill in |
| `assets/artifacts/ancient_courtyard/bronze_key_*`, `ruined_shrine/priest_seal_*`, `overgrown_catacombs/emerald_idol_*` | Google Gemini, Nano Banana Pro (Gemini 3 Pro Image); prompts in `art_review/gemini_pack_v1/`; background removed, fitted and cut into fragments by `tools/gemini_import.py` | AI-generated, Google terms for the plan used (check before release) | 2026-09-30 | fill in |
| `assets/artifacts/*/<18 finds from pack v2>_*`, `assets/ui_art/menu/background.jpg`, `assets/ui_art/menu/emblem.png`, `assets/ui_art/backgrounds/*.jpg` | Google Gemini, Nano Banana Pro (Gemini 3 Pro Image); prompts in `art_review/gemini_pack_v2/`; background removed / cropped, fitted and cut into fragments by `tools/gemini_import.py` | AI-generated, Google terms for the plan used (check before release) | 2026-09-30 | fill in |
| `assets/ui_art/icons/*.png` (16 button icons), `assets/ui_art/fx/*.png` (sparkle, glint, light burst, dust, 4 stone chips + `stone_chips_atlas.png`) | Google Gemini, Nano Banana Pro (Gemini 3 Pro Image), sprite sheets Л1–Л4 from `art_review/gemini_pack_v2/GEMINI_SHEETS.md`; cut, background removed (captions dropped) and downscaled by `tools/gemini_import.py` | AI-generated, Google terms for the plan used (check before release) | 2026-10-04 | fill in |
| `assets/ui_art/cells`, `blocks`, `obstacles`, `overlays`, `ui` | Downscaled copies of `art_v2a` / `art_v2b` made by `tools/export_runtime_art.py` | Same as the source packs | 2026-09-29 | — |
| `assets/ui_art/medals/medal_*.png`, `assets/ui_art/icons/scalpel.png` | Drawn by code, `tools/draw_medals.py`, `tools/draw_scalpel_icon.py` | Project's own work | 2026-10-06 | — |
| `assets/ui_art/menu/background.jpg`, `emblem.png`, `build/store/icon_512.png`, `cover_800x470.png` | Drawn by code, `tools/draw_menu_art.py` (placeholder until illustrations, see `ART_PROMPTS.md`) | Project's own work | 2026-09-29 | — |

## Fonts

| Files | Source | License |
| --- | --- | --- |
| `assets/fonts/pt_sans_regular.ttf`, `pt_sans_bold.ttf` | PT Sans by ParaType, [google/fonts](https://github.com/google/fonts/tree/main/ofl/ptsans) | SIL Open Font License 1.1 (`assets/fonts/OFL_PT_Sans.txt`) |
| `assets/fonts/pt_serif_bold.ttf` | PT Serif by ParaType, [google/fonts](https://github.com/google/fonts/tree/main/ofl/ptserif) | SIL Open Font License 1.1 (`assets/fonts/OFL_PT_Serif.txt`) |

## Code

| Files | Source | License |
| --- | --- | --- |
| `addons/yandex_games/` | [YandexGamesSDK4Godot](https://github.com/ineedmypills/YandexGamesSDK4Godot) by ineedmypills, commit 5c7b04b, with local fixes (see `PATCHES.md`) | MIT |
| `web/yandex_shell.html` | Based on the same plugin's `yandex_template.html` | MIT |
