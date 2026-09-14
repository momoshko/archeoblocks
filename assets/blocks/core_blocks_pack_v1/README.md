# Core Blocks Pack v1

M2.5A.2 asset delivery only. No Godot scene, resource or gameplay integration.

## Production files

Six 256 x 256 PNG RGBA8 sprites named block_{green,blue,red,amber,purple,turquoise}_v1.png. Exact paths and metadata are in manifest.json.

All variants share an identical generated alpha silhouette, centered 220 x 220 bounds, 18 px transparent padding, orthographic view and upper-left illumination. Generated color edits preserve the master bevel layout; RGB texture and shading are intentionally not pixel-identical.

## Layer alignment

Use the same 256 x 256 origin as Core Cell Pack v2. The terrain is below the block. For a tightly tiled board, sample [8,8,240,240] from every layer, not each sprite's individual visible bounds. At a 48 px cell pitch, the review paints a 47 px content rectangle and keeps a 1 px divider. The visible block body is about 43 px across within that cell.

## Review

Review files are in ../../../art_review/core_blocks_pack_v1 (excluded from Godot import with .gdignore):

- blocks_overview.png: six 256 px canvases with filenames outside the sprites.
- readability_48px.png: blocks alone, then over depth0, depth1 and depth2, top to bottom.
- board_composite_8x8.png: 768 x 768 composite, 96 px cell pitch.
- board_composite_8x8_48px.png: native 384 x 384 board, 48 px cell pitch.
- grayscale_review_row.png: native 432 x 48 strip. First three cells are bare depth0 / depth1 / depth2; next six are green / blue / red / amber / purple / turquoise on alternating terrain.
- board_composite_8x8_grayscale_48px.png: grayscale version of the native board.
- validation.json and validate_assets.ps1: format, opacity, padding and exact alpha identity checks.
- prompts.json: built-in ImageGen prompts, including iterations.

The board contains repeated single-cell sprites forming a blue line, green T, red square, amber L, purple line and turquoise pair. These are review composites, not polyomino assets.

## Generation and export

Built-in ImageGen generated the jade master and five reference-locked color edits. The first master was visually too busy; the adopted edit reduced the grain. Some edits returned a painted checker background, so production export reused the original generated alpha master, with a one-pixel matte inset and opaque stone interior. All colors use the same crop/scale and alpha. No hand-coded replacement illustration was used. The exporter only normalized raster geometry/alpha and assembled the requested review images.

## QA and remaining risks

All six pass PNG RGBA8, 256 x 256, transparent padding, matching alpha hash and opaque center checks. Visual inspection at 48 px confirms a bright upper-left bevel / dark lower-right bevel that reads raised, unlike the dark upper inset of excavated cells. Material colors remain distinct in the color review; grayscale is for terrain-versus-block height reading, not distinguishing all six color identities.

Saturated amber and cyan are prominent; their competition with future artifact/reveal effects still needs in-game review. At 48 px the fine stone grain softens; silhouette and bevel are the intended stable cues. Device display, Godot filtering/atlas settings, drag/preview states and actual touch play have not been tested because integration is explicitly out of scope.
