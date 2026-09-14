# Core Cell Pack v2

M2.5A.1b: seven separate 256x256 PNG RGBA assets, not integrated into Godot. The v1 pack is preserved.

## Production contract

The content rectangle is (8,8,240,240) in a 256x256 canvas. All files have at least eight fully transparent pixels at the outer edges. The three bases share a pixel-identical alpha cutline with 6px corner radius. Generated artwork was cropped, downsampled and aligned; the common cutline removes edge drift between states.

Composition: base -> separately supplied artifact -> generic burial clue/opening -> separately supplied block -> placement preview.

At depth2 the generic gold edge hints at a buried item. At depth1 the opening overlay has a fully transparent center; draw an external artifact in that opening before drawing the soil edge. The review uses an artifact fit rectangle (90,88,76,80). This overlay is not a mask and does not clip oversized artwork or erase previously drawn soil. At depth0 show the separately supplied artifact on the recessed base without burial overlays.

Keep all layers on the same origin and scale. Do not crop overlays to their individual visible bounds. For atlas regions/tight tiling, use the same (8,8,240,240) content region on every layer. No block or artifact identity is included in this pack.

## Review

Review files are in ../../../art_review/core_cell_pack_v2/ and excluded from Godot scanning with .gdignore.

- comparison_overview.png: old/new bases and v2 layer compositions.
- readability_48px.png: native 48px color/grayscale samples and previews over four underlays.
- stress_test_8x8_48px.png: mixed 64-cell board, 384x384 pixels, 48px pitch including a 1px divider.
- stress_test_v1_vs_v2.png: same board distribution for direct comparison.
- prompts.json: chosen ImageGen prompts and export details.
- validation.json: pixel-format, padding and shared-alpha checks.

The existing Golden Mask appears only in review composites to demonstrate separately supplied artwork. It is not baked into any production PNG. No engine import or gameplay test was needed for this asset-only task.

## Readability and remaining risks

The repeated bright per-cell frame is removed; soil remains flat and the excavation has internal shadows. The depth2 clue is visibly larger at 48px than the v1 clue. Valid/invalid symbols differ by checkmark and X, also in grayscale, while terrain stays visible beneath them.

Repeated soil textures/cracks are visible in large same-state groups. The excavated cell's inner lip remains more contrasty than flat soil by design. White preview symbols may compete with bright gold highlights in the external artifact. Future artifact silhouettes need fitting in the generic opening and final-device contrast checks. The review uses no rotated or alternate textures to conceal repetition.
