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

## Next milestone

- [ ] Keep M3 scoped separately; add the versioned save schema before persistent campaign/economy state.
- [ ] Integrate real Yandex services only in their dedicated future milestone.

## Not before first publication

No city building, equipment, pets, currencies, shop, battle pass, daily reward, profile, online leaderboard, procedural expeditions, runtime level generator, multiple biomes, or player rotation.
