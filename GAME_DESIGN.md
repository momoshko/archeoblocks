# Archeoblocks — locked V1 game design

## Core rules

- Board: 8×8.
- Tray: 3 block pieces.
- Placement: a piece must fit entirely in empty cells.
- A full row or column clears the placed blocks in that line.
- Each cleared line removes one soil layer from every crossed cell.
- If a row and column clear simultaneously, their intersection receives one excavation from each line.
- Normal soil depth is 1; strong soil depth is 2.
- Each expedition contains one main collectible artifact split into 2–3 buried fragments.
- Fragments are partially hinted beneath soil.
- Fully excavating every fragment wins the expedition.
- The player loses when none of the remaining tray pieces can be legally placed.
- The current campaign contains 24 curated expeditions: Chapter I has 6, Chapter II has 8, and Chapter III has 10.
- Every campaign expedition may start with scripted pieces (`opening_piece_set`, `curated_piece_sequence`), then uses seeded weighted piece generation (M4.0, see below).
- V1 has no player rotation button. Rotated shapes are separate piece definitions.
- Block colors are cosmetic and are not matching mechanics.
- Score and move count are feedback/statistics, not the primary victory requirement.

## Out of scope before first publication

- City building
- Equipment
- Pets
- Persistent currency wallet or premium currency
- Shop
- Battle pass
- Daily reward
- Account profile
- Online leaderboard
- Procedural expeditions
- Runtime level generator
- Multiple visual biomes
- Player-controlled piece rotation

## M1 implementation details

- M1 uses three deterministic piece sets in a loop:
  1. small L, small T, horizontal line 3;
  2. square 2×2, vertical domino, horizontal line 3;
  3. single, horizontal domino, vertical line 3.
- A piece is dragged from any available tray slot and snaps by an anchor cell near the center of its definition.
- Mouse drag uses an 8 px visual lift by default.
- Touch drag uses an 82 px visual lift by default so the finger does not cover the preview.
- Mouse and touch lift values are presentation settings on the GameSession node.
- Green-tinted target cells represent a legal placement; red-tinted cells and drag preview represent an illegal placement.
- A used slot stays empty until all three pieces have been placed, then the next deterministic set appears.
- Every full row and column found after one placement clears in the same action.
- M1 intentionally has no fairness generator, score system, soil, excavation, or artifact gameplay.

## Expedition difficulty plan

- Expeditions 1–2: normal soil, 2 fragments, easy geometry.
- Expedition 3: 3 fragments.
- Expeditions 4–6: introduce strong soil at depth 2.
- Expeditions 7–9: fragments are farther apart and create competing row/column targets.
- Expeditions 10–12: strong soil covers important cells and excavation geometry is less convenient.

This is a design plan. M2 implements only the curated sample resource for Expedition 1.

## M2 implementation details

- Block occupancy and excavation state are independent models.
- Normal soil has depth 1; strong soil has depth 2.
- Every cleared row and column adds one excavation hit to each crossed cell.
- Row/column intersections retain both hits.
- Artifact fragments collect once, after every cell belonging to that fragment reaches depth 0.
- Victory is resolved before tray refill and NO_MOVES.
- The M1 deterministic piece sequence remains unchanged.

## M2.1 help and rescue foundation

- Victory remains full excavation of the main artifact. Score never replaces that condition.
- NO_MOVES is evaluated in one place after the placed slot is consumed and an empty tray is refilled. Only active pieces participate.
- NO_MOVES opens a rescue state with Undo, free Restart, and Menu instead of an immediate terminal loss.
- Each attempt starts with one free Undo and one free Hint. Configurable rewarded limits are one additional Undo and two additional Hints.
- Undo restores the complete pre-turn board, excavation, fragment, tray, sequence, move, score, and run-counter snapshot. The last snapshot is consumed after Undo.
- Campaign Hint uses deterministic bounded lookahead. It favors expedition victory and unfinished artifact excavation, but structurally rejects immediate-loss branches while a surviving recommendation exists.
- Idle Hint nudge starts after the configured delay and never plays a move or opens an ad automatically.

## Score and feedback

- Successful placement: +10.
- Simultaneous line totals: 1 = +100, 2 = +250, 3 = +450, 4 = +700.
- Every line beyond four adds the configurable `extra_line_score` to the four-line total.
- Applied excavation hit: +10; newly collected fragment: +200; completed artifact: +500.
- Simultaneous lines are a per-turn bonus. M2.1 has no combo chain between turns.
- Score is reusable feedback/statistics and does not affect expedition victory.

## Economy foundation

- The only planned soft currency is Coins. There is no premium currency.
- Coins are for cosmetics only: block skins, board frames, backgrounds, clear effects, and collection presentation.
- Campaign progress is earned by completing expeditions and is never purchased with Coins.
- M2.1 calculates `base_victory_coins = 20` for the run result but does not persist a wallet.
- `DOUBLE_COINS` is reserved as a future optional rewarded action; M2.1 exposes no production button for it.

## Endless Excavation (M4.2)

Full design and later steps: `ENDLESS_MODE_RU.md`.

- Screen `scenes/screens/endless_screen.tscn` inherits `game_screen.tscn`; its GameSession has `endless_definition = resources/endless/endless_default.tres` and no expedition.
- Same 8×8 board, pieces and score core; no victory. A run ends at NO_MOVES; there is no Undo or Hint (the record must mean something).
- Each run uses a new random piece seed (`GameSession.endless_seed_override` fixes it in tests).
- Streak: a move with a line adds a step; after a line the player has `streak_grace_moves` (3) moves to clear the next one. Line score × (1 + 0.5 × (streak − 1)), capped at ×4.
- Clean board (no blocks after a clear): +1000 × streak multiplier.
- Depth: every 10 lines = 1 m. Layers switch the piece weights: Topsoil 0 m (Chapter I weights), Clay 5 m (Chapter II), Catacombs 10 m (Chapter III). The seed and set number stay, so a run is reproducible.
- Records: best score, best depth and run count in `progress.cfg` section `records`, mirrored to the cloud; merge keeps the larger values.
- Unlocks in the main menu after `expedition_03`.
- Not yet (M4.3): buried finds, Stones/Roots by layer, rewarded "clear 3×3" continue, probe support.

## Future M3 save schema

- `save_version`
- `campaign`: `highest_expedition`, `completed_expeditions`, `best_scores`
- `economy`: `coins`
- `cosmetics`: `owned_skins`, `selected_block_skin`, `selected_board_skin`
- `records`: `endless_high_score`
- A current-attempt section may be added later. M2.1 implements no serialization.

## Rewarded and interstitial policy

- Planned rewarded actions: Extra Undo, Extra Hint, and future Double Coins.
- Gameplay talks to a provider-independent rewarded service. A reward is granted only after `reward_granted` for a unique request id.
- Duplicate, failed, and unavailable callbacks grant nothing. The local mock provider exists only in editor/debug builds.
- Future interstitials are limited to logical pauses such as between completed expeditions.
- Never interrupt drag or active turn resolution, gate basic Restart, auto-open rewarded ads, or stack an interstitial immediately after rewarded content.
- Real Yandex SDK integration belongs to a future milestone.

## M2.2 readability and Hint quality

- Every unfinished artifact target remains visually hinted through both normal and strong soil. A completed fragment remains visible but loses its target border.
- Strong soil, normal soil, excavated artifact, player blocks, and valid/invalid placement previews must stay visually distinct in the editor-authored CellView.
- Piece previews use their definition bounding box and one shared scale/padding calculation; no per-piece offsets are used at runtime.
- Selecting a piece with no legal placement shows a short explanation. The existing Rescue flow remains the only all-pieces-blocked state.
- Hint simulates the complete immediate transition (lines, excavation, Stone/Root resolution, tray consumption/refill, and NO_MOVES), proves sequential feasibility of the current three-piece tray where possible, then searches a configured depth-5/beam-12 horizon. Profiling showed beam 8 was insufficient for Expedition 2-8; 12 is the smallest tested budget kept for final campaign validation.
- Candidate safety is structural rather than a tunable score: `IMMEDIATE_VICTORY` > `PLAN_SURVIVES` > `SHORT_SURVIVES` > `IMMEDIATE_LOSS`.
- Search-state deduplication includes board occupancy, excavation and fragment state, typed obstacles, exact tray slots, sequence position, refill generation, and pending Root growth.
- Leaf evaluation combines remaining artifact depth with legal fits, connected free area, representative large-piece space, and remaining obstacle pressure. Numeric weights stay in `HelpConfig`.
- The planner is bounded guidance, not unbounded solving or a production autoplay system. It does not promise survival beyond its configured horizon or reason about genuinely unknown future random refills.
- Debug builds expose selected-plan diagnostics and a guarded test-only move applicator used to validate curated campaigns; release builds cannot invoke that shortcut.
- Production Hint allowances remain one free plus the configured rewarded limit.
- `debug_unlimited_hints` is a test-only option guarded by `OS.is_debug_build()`; it spends no allowance and requests no reward.

## Current chapter-first campaign

- Chapter I — Ancient Courtyard: 6 onboarding expeditions.
- Chapter II — Ruined Shrine: 8 expeditions introducing normal and reinforced Stone plus large-piece space pressure.
- Chapter III — Overgrown Catacombs: 10 expeditions using predictable one-cell-per-turn Root growth together with existing Stone, soil-depth, artifact, and large-piece rules.
- Chapters unlock sequentially; completed chapters remain replayable. Each chapter owns a resource-driven collection and a one-time completion reward.
- Campaign Hint uses the bounded planner documented above and is validated through deterministic Hint-only runs across curated content.
- `Ctrl+Alt+H` is a hidden debug-Web playtest toggle for unlimited free Hints. Its handler requires both the Web platform feature and a debug build, is never persisted, and is not a production feature.

## M4.0 seeded weighted piece generation

- Each chapter has a `PieceGenerationConfig` (`resources/config/pieces_chapter_1..3.tres`): pieces, weights, `max_same_piece`, `fairness_attempts`, `fallback_piece`.
- An expedition plays `opening_piece_set` (if any), then its `curated_piece_sequence` triples once, then generated sets. Without a config the old fixed loop is used (prototypes, tests).
- A generated set depends only on the expedition seed (`piece_seed`, or a stable FNV-1a hash of the expedition id), the set number and the board at refill time. Undo, Hint planning, autoplay validation and the difficulty probe therefore see exactly the same pieces as the player.
- Fairness: if none of the three pieces fits the board, the set is re-rolled up to `fairness_attempts` times; then one piece is replaced by the fallback (single block) if that fits. It only guarantees one playable piece; it is not a solver.
- Chapter I has no Cross 5 and few large pieces; Chapters II and III add large pieces gradually. Balancing individual expeditions is M4.1 and uses `tools/difficulty_probe.gd`.

## M4.1 difficulty curve

- Reference: `tools/difficulty_probe.gd --policy=player` — a one-step bot that reads the objective (fills rows/columns crossing unexcavated finds), keeps room for the tray and never uses Undo or Hint. Real players with help do better; the numbers are for comparing expeditions.
- Targets and result (40 games each): Chapter I ≈ 100%; Chapter II 100 → ~40% (2-8); Chapter III 85–100 → ~30% (3-10), with a short breather at 3-6.
- Levers used: fewer and weaker Stones in the middle of Chapter II, less strong soil on finds, fewer central Roots, shorter curated heavy-piece starts on 2-7, 2-8, 3-7, 3-9 (the old 12-piece scripts killed runs in the first dozen moves), and a representative `piece_seed` where the id-derived seed was an outlier (2-7, 3-7).
- `expected_moves_min/max` = middle half of the winning move counts of the same bot.
