# Core Cell States Pack v1

M2.5A.1. Nine individual 256x256 RGBA PNGs. No scenes or gameplay resources reference this pack yet.

| File | State | Use |
| --- | --- | --- |
| cell_excavated_depth0.png | Empty recessed cell | Complete cell |
| cell_soil_depth1.png | Light, shallow soil at board surface | Complete cell |
| cell_soil_depth2.png | Darker compact soil with larger cracks | Complete cell |
| cell_artifact_hidden_depth2.png | Almost buried artifact, small muted gold trace | Complete cell |
| cell_artifact_hidden_depth1.png | Partly visible mask beneath shallow soil | Complete cell |
| cell_artifact_revealed.png | Visible mask inside excavated recess | Complete cell |
| cell_occupied_block.png | Raised turquoise block, representative color | Complete cell example |
| preview_valid.png | Translucent mint outline and checkmark | Overlay over a cell |
| preview_invalid.png | Translucent coral outline and X | Overlay over a cell |

## Geometry and export

- Square orthographic view; upper-left lighting; warm sandstone perimeter.
- All files have a centered 256x256 canvas and at least 8 fully transparent pixels at every edge. Original generation padding remains inside this border; solid tiles occupy approximately 190-194 pixels of the canvas.
- PNG RGBA, straight alpha. Artwork and alpha were generated with built-in ImageGen; final size conversion preserves the image and alpha.
- Base artwork interiors are near-opaque; preview fills use low alpha. The preview symbols and outlines are deliberately stronger.
- When packing an atlas later, preserve padding and do not independently stretch or trim variants. The preview glow is slightly wider than the solid-cell silhouette.
- The seven complete cells include their sandstone border. The occupied example includes its underlay; it is not a standalone block sprite.
- Artifact states demonstrate a mask per cell. They do not define a multi-cell fragment atlas or change gameplay fragment rules.

## Readability review

Reviewed at 256px and 48px, in color and grayscale; preview overlays were also composited over soil. All nine passed pixel checks for size, transparent exterior, and an 8px clear border.

Open risks for the future board integration:
- The depth-2 gold trace becomes very subtle at 48px and below. It may need slightly more visible area after real-device testing.
- Repeated bright sandstone rims could compete with gold targets across an 8x8 board.
- Generated variants are visually aligned but not pixel-identical at their frame edges; rapid state swaps may reveal slight texture/edge changes.
- Previews differ by checkmark versus X as well as color. Their final contrast still needs evaluation over every underlying board state.

See ../../../art_review/core_states_v1/ for the transparent overview, 48px inspection image, exact prompts and pixel validation report. These review files are excluded from Godot scanning using .gdignore.
