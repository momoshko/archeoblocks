# ART V2A · production plan

Status: complete — 16 production exports, six review images, exact prompts, manifest and verification delivered. 56/56 technical checks and static visual acceptance passed. Acceptance is based on visual quality and verification, as authorized by the user. Runtime integration is outside this milestone.

Generated with the available built-in ImageGen; exact underlying image model/quality tier was not exposed by the tool.

## Scope

16 production sprites at 256×256 PNG RGBA; six required review PNGs; README, manifest, exact prompts and verification report. No scene, gameplay, theme, export or existing asset edits.

Authoritative style: ART V1 Light Sandstone Courtyard, final gameplay reference with organic branching Roots. V2A instructions override V1 on Stone signals (no bars/strokes), hint opacity (~0.52), and root warning prominence above marker.

## Shared geometry

- Canvas 256×256; origin (0,0), pivot (128,128).
- Cell content rect [8,8,240,240]; shared terrain cutline, radius 6 px.
- Blocks: shared master alpha, body within [18,18,220,220]. Every color uses the same export transform and alpha, never independent auto-trimming.
- Obstacles: center within cell, target visible bounds no larger than 220×220. Stone derives cracked art from intact without changing perspective or scale. Roots preserve transparent holes between branches.
- Overlays: full common canvas, content inside [8,8,240,240]. Valid/invalid use one shared master source crop. Each distinct signal family is normalized once to its master bounds; no per-item trimming in review or future placement.
- Light: upper-left. No independent rotations to hide repeats.
- Review pitch 48 px: sample the same [8,8,240,240] region for every layer; at least 1 px cell separation in board composites.

## Generation dependency graph

1. Soil depth 1 master → edit to excavated depth 0 → edit original master to dense depth 2.
2. Green mineral master → five reference-locked color edits. Same silhouette, bevel and texture structure. Target distinct value bands; retain color and grayscale review.
3. Intact Stone master → cracked Stone edit, with large readable structural fracture and missing chip. No numbers, bars or metallic facets.
4. Root master → root-themed warning overlay using the same visual language, keeping most of the interior transparent.
5. Artifact marker overlay: local gold ring/diamond, thin keyed outline, visible on terrain, blocks and obstacles.
6. Valid overlay → invalid edit preserving geometry, replacing check with X and changing mint to terracotta.

Technical export can align, downsample, normalize alpha and assemble review sheets. It must not replace generated material artwork with procedural illustration. A repaired matte must be checked on both light/dark backgrounds, including internal root gaps.

## Compositing stack

1 terrain → 2 optional buried clue (none newly required) → 3 obstacle → 4 placed block → 5 hint OR valid/invalid → 6 artifact marker → 7 root warning.

Obstacle and placed block cannot overlap in a plausible stress board. An invalid placement preview may overlap an obstacle because it demonstrates rejection. Hint cells must be free, and one polyomino must use one block color. Marker may persist above a block or obstacle. Warning is the strongest temporary signal and must remain legible above a hint and marker.

Hint: reuse real block texture at alpha 0.52, soften highlight contrast before alpha modulation in review, without altering the production block files. Demonstrate real block versus hint versus valid versus invalid on equal terrain. No six-color ghost atlas.

## Review matrix

- All 16 sprites on light and dark neutral backgrounds, exactly 48×48 display cells.
- Same matrix in grayscale; enlarged panels only as supplements, clearly labelled.
- Marker over all three terrains, all six blocks, both Stones and Root.
- Warning above all three terrains and hint; include warning + marker together.
- Valid/invalid over terrain and occupied cells, with visible underlay and readable distinct symbols.
- 8×8 base stress board with mixed terrain, all six block colors, intact/cracked Stone, Roots, markers, one threatened cell.
- Same board + legal hint, with a separate valid-preview example; never hint and drag feedback on the same cell.
- Same board + invalid footprint intersecting an obstacle and an occupied cell.

## Acceptance gates

PNG RGBA8/sRGB, transparent exterior, exact sizes, shared terrain alpha, identical block alpha hashes, no checkerboard mattes, no opaque overlay rectangle, all required files present, readable silhouettes at 48 px, quiet repeated terrain, Stone not metal, Roots not tokens, gold primarily on targets. Do not mark complete while required visual or provenance checks fail.
