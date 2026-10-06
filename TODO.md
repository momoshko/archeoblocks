# Roadmap

## M0 — scene-first foundation

- [x] Editable screens and reusable UI scenes
- [x] Static 8×8 board and three sample pieces
- [x] Navigation and pause overlay
- [x] Responsive portrait-first shell
- [ ] Yandex SDK (future milestone)

## M1 — core block puzzle

- [x] Piece placement rules
- [x] Line detection and clearing
- [x] Tray refill rules
- [x] Legal-move/loss detection
- [x] Targeted gameplay tests

## M2 — excavation / artifact core

- [x] Soil depth state
- [x] Excavation from cleared lines
- [x] Buried artifact fragments
- [x] Expedition victory condition
- [x] Lose flow presentation

## M2.1 — help / rescue / score foundation

- [x] Unified active-piece NO_MOVES evaluation
- [x] Rescue popup with free Restart and Menu
- [x] Full one-turn Undo snapshot
- [x] Configurable free/rewarded Hint and Undo limits
- [x] Deterministic Hint evaluator and idle nudge
- [x] Provider-independent rewarded action service with debug-only mock
- [x] Score, multi-line feedback, fragment/victory points
- [x] Non-persistent victory Coins result
- [x] Pause Restart
- [x] Targeted M2.1 regression tests

## M2.2 — gameplay readability / Hint quality

- [x] Persistent artifact target readability across soil depths
- [x] Distinct completed and unfinished artifact fragment states
- [x] Strong valid/invalid snapped placement previews
- [x] No-placement Piece feedback
- [x] Bounding-box PieceSlot centering
- [x] Debug-only unlimited Hint testing option
- [x] Artifact-oriented immediate Hint safety and debug output
- [x] Focused M2.2 checks

## M2.9A — bounded campaign Hint planning

- [x] Shared complete-move simulator for first and deeper candidate moves
- [x] Structural victory / plan-survival / short-survival / immediate-loss ordering
- [x] Sequential current-tray feasibility with real deterministic refill state
- [x] Profiled configurable depth-5, beam-12 bounded lookahead with state deduplication
- [x] Artifact, legal-fit, connected-region, and large-piece leaf evaluation
- [x] Debug-only Hint autoplay validation for all 14 curated Chapter I/II expeditions

## M2.10 — Chapter III / Web playtest

- [x] Ten curated Overgrown Catacombs expeditions with predictable Roots
- [x] Chapter-first progression, 10-slot Collection, and one-time 200-Coin reward
- [x] Chapter III Hint-only and Root-pressure validation
- [x] Structurally guarded debug-Web unlimited-Hint hotkey
- [x] Dedicated non-threaded static Web playtest export preset

## M3.0 — stabilization for release

- [x] Undo/Hint are blocked while a turn animates; Restart/Undo invalidate a suspended turn (turn generation guard)
- [x] Play continues from the first unfinished expedition (`CampaignRoute`, `game_scene_path`)
- [x] Guided tutorial only until Expedition 1 is completed; objective card once per visit
- [x] Coins hidden in UI until a shop exists (`FeatureFlags.SHOW_COINS`)
- [x] Working Music/Sound settings, pause sound toggle, mute on focus loss
- [x] Procedural sound effects for gameplay events
- [x] Hint planner discounts future gains so it prefers useful moves now
- [x] Whole test suite green again; `tools/run_tests.ps1` / `tools/run_tests.sh`

## M3.1 — Yandex platform

- [x] Yandex Games SDK plugin vendored with fixes (callbacks kept alive, ad flows finish)
- [x] `Platform` facade: boot + cloud progress merge, LoadingAPI.ready after menu, GameplayAPI boundaries
- [x] Platform pause opens the pause menu and mutes audio; ads mute without opening the menu
- [x] Rewarded Undo/Hint through the SDK (reward only on onRewarded)
- [x] Interstitial after "Дальше" on victory
- [x] Versioned save format (`save_version`) and cloud mirror of progress
- [x] "Yandex Release" export preset, page shell without context menu/scroll/selection, zip script
- [x] Browser smoke test with a local SDK stand-in; YGChecker: 22 ok, 0 errors
- [x] Rescue "В меню" no longer opens the next expedition

## M3.2 — English and language detection

- [x] Russian texts stay the source; English lives in `translations/en.po` (msgid = Russian text)
- [x] Scene Labels/Buttons translate themselves; code strings and resource texts go through `tr()`
- [x] `Locale` autoload: player's choice → Yandex `i18n.lang` → browser language → Russian; ru/be/kk/uk/uz → Russian, others → English
- [x] Language switch in Settings (Русский / English), saved in `user://settings.cfg`
- [x] Plugin `auto_apply_locale` off — only `Locale` sets the language
- [x] `tests/locale_test.gd`: detection rule, every chapter/expedition/piece text has English
- [x] Check English layout on all screens (long English titles) — in the engine at 720×1280, 390×844 and 1280×720 with `tools/capture_screens.gd`; the exported build is checked in M3.3

## M3.3 — release preparation

- [x] Touch drag uses the touch lift on real phones (the emulated mouse press from a finger counts as touch)
- [x] A second finger cannot start a second drag
- [x] Undo and rewarded Hint first drop a held piece back to the tray (no stale drag under an ad)
- [x] No interstitial within 60 s after a rewarded video; no ad call while another ad is open
- [x] `tests/filenames_test.gd`: ASCII-only file and folder names (Yandex rule 1.22)
- [x] `tests/touch_input_test.gd`: finger/mouse lift, second finger, Undo while a piece is held
- [x] `tools/capture_screens.gd`: screenshots of every screen in RU/EN at any window size + text-fit check
- [x] `STORE_LISTING.md`: RU/EN title, descriptions, how-to-play, keywords (lengths checked)
- [ ] Icon 512×512, cover 800×470, 16:9 video, store screenshots per language
- [x] Main-menu emblem instead of `EmblemPlaceholder` (code-drawn placeholder, see M3.4)
- [ ] Exported "Yandex Release" build: every screen in English, phone + desktop browser, resize, ads (see YANDEX_RELEASE_CHECKLIST.md)

## M3.4 — look and sound before the draft

- [x] ART V2A in the game: terrain, six mineral blocks, stone intact/cracked, roots, root warning, marker, valid/invalid previews
- [x] ART V2B in the theme: primary/secondary/small/disabled buttons, popup and card panels, board frame, piece slots, chapter and collection cards
- [x] Runtime copies via `tools/export_runtime_art.py` (source packs stay `.gdignore`d review material)
- [x] PT Sans / PT Serif (OFL) with Cyrillic
- [x] Code-drawn wall background, emblem, store icon and cover (`tools/draw_menu_art.py`); prompts for real art in `ART_PROMPTS.md`
- [x] Music by file name from `assets/audio/music/` with loop and cross-fade (menu / gameplay / per chapter)
- [ ] Music files from the author
- [ ] Artwork for Bronze Key, Mosaic Tablet, Guardian Figurine and other finds without pictures
- [ ] Illustrated background/emblem/icon/cover to replace the code-drawn ones
- [x] Generate the finds with Gemini (Nano Banana Pro): packs v1 + v2 (21 finds; every expedition now has find art), processed by `tools/gemini_import.py` (white/black pair → alpha, fit, fragments, links the expedition)
- [ ] Gemini pack v2 (`art_review/gemini_pack_v2/GEMINI_BRIEF.md`): done 1–23 (18 finds, menu + 3 chapter backgrounds wired via `ChapterDefinition.background_texture` / `EndlessLayer.background_texture`, emblem) and sheets Л1–Л4. Left: store icon/cover/hero (24–26), soil texture (47), 3 chapter pictures (48–50)
- [x] Icon and FX sheets Л1–Л4 cut by `tools/gemini_import.py` (now: background colour read from the border, Gemini captions removed, closed white holes cleared, `"matte": "white"` for an unusable black pass, chip atlas); runtime sizes 96 px icons / 128 px FX / 256 px light burst
- [x] Icons in scenes (theme `icon_max_width`): Pause and Back icon-only with tooltip; Undo, Hint, pause menu, victory/rescue buttons, Play, Endless, Settings, tutorial Skip with icon + text; Music/Sound rows; padlock badge on closed expeditions and chapters; brush/sponge next to the restoration stage
- [x] Light FX: `scenes/ui/board_fx.tscn` (one-shot CPUParticles2D, ≤28 particles each) — dust + chips on line clear, dust on dug soil, chips on cracked/broken stone, sparkles + light burst + glint on an uncovered fragment; `scenes/ui/find_glow.tscn` in the victory window and the fragment card; restoration dust uses the dust sprite; `tests/icons_fx_test.gd`
- [ ] Check FX feel and FPS on a real phone and in the Yandex Web build; `m2_3a_test` (Hint replacement) is flaky — failed once before these changes, passed after

## M3.5 — interface polish (review `UI_REVIEW_RU.md`, 2026-10-04)

- [ ] Fonts: pick a pairing (recommended D: Yeseva One headers + Rubik text, outline on green buttons, header shadow); comparisons in `art_review/ui_review/`
- [ ] Readable text on 390×844: body ≥ 26 px, secondary ≥ 22 px in the 720 layout; remove piece names from the tray
- [ ] Main menu hierarchy: big Play with the next expedition, icon tiles (Expeditions, Collection, Endless), gear in the corner — needs sheet Л5
- [ ] Game HUD: one-line header, fragment silhouettes instead of "Фрагменты 0/2", score in the header; round Undo/Hint icon buttons with a counter badge and video icon
- [ ] Victory celebration: ribbon, score count-up, confetti, buttons after 0.6 s — needs Л8, Л9
- [ ] Chapter cards with pictures (48–50) and progress bar; expedition path with found-item thumbnails; collection silhouettes + museum background (51)
- [ ] Restoration: big brush/sponge tool buttons, workbench background (52)
- [ ] Tutorial hand pointer animation (Л6)
- [ ] Animations: button press, popup pop-in, piece lift/land, line pop wave with gem shards, combo shake, score count-up, fragment flies to header, lock opens (table in `UI_REVIEW_RU.md` §3)
- [ ] Gemini: sheets Л5–Л9 and items 51–53 described in `GEMINI_SHEETS.md` / `GEMINI_BRIEF.md` / `prompts.json`

## M4.0 — fair piece generation

- [x] `PieceGenerationConfig` per chapter: weights, max 2 equal pieces per set, fairness re-roll, single-block fallback
- [x] Deterministic sets from expedition seed + set number + board; curated triples play once as a scripted start
- [x] Hint planner, Undo and autoplay use the same refill as the real game (`tests/piece_generation_test.gd`)
- [x] `tools/difficulty_probe.gd` — casual/careful bot win rate per expedition

## M4.1 — difficulty curve

- [x] Probe: `--policy=player` (reads the objective; reference bot), `--level=`, `--seed=`, `--seed-scan=N`, `--verbose`, middle-half move counts
- [x] Chapter II: fewer/weaker Stones on 2-5, 2-7, 2-8; less strong soil on finds; 2-7 and 2-8 shorter heavy-piece scripts
- [x] Chapter III: fewer central Roots and Stones on 3-5, 3-7…3-10; 3-6 slightly harder; shorter scripts on 3-7, 3-9
- [x] Representative `piece_seed` for 2-7 and 3-7 (the id-derived seeds were outliers)
- [x] `expected_moves_min/max` recomputed for all 24 expeditions; results table in `GAME_ANALYSIS_M4_RU.md` (section 3а)
- [ ] Check the curve with real players in the Yandex draft (bot ≠ human with Undo/Hint)

## M4.2–M4.3 — endless excavation (planned, design in `ENDLESS_MODE_RU.md`)

- [x] M4.2: `endless_screen.tscn` + `EndlessDefinition`, no victory, score + streaks, depth meter, best score/depth in save and cloud, menu button (unlocks after 1-3), result screen, RU/EN, tests (`tests/endless_mode_test.gd`)
- [ ] M4.2 manual: play a few runs on Web; add `gameplay_endless` music if wanted
- [x] M4.3: buried finds from the collection (dig spots with a countdown), stones/roots by depth layer, `tools/endless_probe.gd` and tuning (`EndlessEvents`, `tests/endless_events_test.gd`)
- [x] Daily dig: shared seed per date, goal 3 finds, week stars, best score of the day (lobby `endless_lobby.tscn`)
- [ ] Later: rewarded continue, weekly reward, per-run tasks, online leaderboard, tools every 5 m (see `ENDLESS_MODE_RU.md` §9)

## M5 — final version for the Yandex draft (2026-10-06)

- [x] Volume sliders for music and sounds (Settings, 0–100 %, saved)
- [x] Campaign pieces are new on every attempt (expedition 1 keeps its tutorial script)
- [x] Site preparation levels: 23 «Расчистка участка» levels before every dig except the tutorial (47 levels in total), `tools/site_levels.json` + `tools/make_site_levels.gd`, bot probe `--sites`
- [x] Chapter page: one card per find with three steps (расчистка → раскопка → очистка)
- [x] Screen review RU/EN at 390×844 and 1280×720 (chapter column, popup text wrap)
- [ ] Manual pass on the exported build (`YANDEX_RELEASE_CHECKLIST.md`)

## M6 — difficulty, leaderboard, restoration stages (2026-10-06)

- [x] Debug «Реставрация (тест)» button removed from the main menu
- [x] Three playthroughs: Easy (open) → Medium (after the whole game on Easy) → Hard (after Medium); separate campaign progress per difficulty, old saves count as Easy (`Difficulty`, `ProgressStore`)
- [x] Difficulty picker on the chapters screen, difficulty under Play and on the chapter page, «Открыта сложность» on the final victory
- [x] Easy: 3 free Undo/Hint, small pieces more often, strong soil and reinforced stones one layer weaker; Medium: as before; Hard: soil over the find one layer deeper, move limit from the bot probe, no free help, score ×2
- [x] Medals (bronze/silver/gold) in the collection for the highest difficulty a find was dug up on
- [x] Endless leaderboard (`endlessScore`): «Лидеры» in the lobby, top 10 + own place, sign-in button for guests, score sent on a new record and after boot
- [x] Restoration stages by material: shards (drag and snap, glue seams), soil, crust (scalpel, several strokes), patina; own sounds; «Этап N из M»
- [ ] Create the leaderboard `endlessScore` in the Yandex console (see YANDEX_RELEASE_CHECKLIST.md)
- [ ] Play Hard on a phone: are the move limits fair with Undo/Hint for ads?

## Restoration of finds (`RESTORATION_RU.md`)

- [x] Prototype: `restoration_screen.tscn` + `restoration.gdshader` (brush soil → sponge patina → shine), auto-finish at ~90 %, Skip, restored flag in save + cloud, debug-only menu entry, `tests/restoration_test.gd`
- [x] R1: victory popup entry ("Очистить находку") for every find, return to the route after cleaning
- [ ] R1 manual: tune feel on a phone (brush size/strength), brush/sponge sounds
- [x] R2: collection shows dirty/clean finds, brush badge, restored counter; tap a find to clean it
- [ ] R3 (after release): assemble 2–3 fragments before cleaning
- [ ] R4 (after release): short stories of the finds, RU/EN

## Next milestone

- [ ] Keep M3 scoped separately; add the versioned save schema before persistent campaign/economy state.
- [ ] Integrate real Yandex services only in their dedicated future milestone.

## Not before first publication

No city building, equipment, pets, currencies, shop, battle pass, daily reward, profile, procedural expeditions, runtime level generator, multiple biomes, or player rotation.
