# ART V2B production plan

Status: complete as an offline production-candidate for user review. All16 production sprites, five required review sheets, supplementary alpha audit and documentation delivered. 99/99 technical checks passed; visual review passed. Built-in ImageGen only. Exact hidden model and quality tier are not exposed. No runtime integration or implied user approval.

## Family and dependencies

Sandstone header anchor → board frame, small header, label, popup, green primary, piece slot.
Primary → secondary → disabled, compact back base, selected outline.
Piece slot → open chapter → locked/completed; piece slot → known collection → unknown.
Keep reference-derived material, clipped corners, upper-left light and clean text areas. No text or icons in production assets.

## Target export sizes

| Asset | Canvas px |
|---|---|
| board_frame | 1024×1024 |
| panel_header_large | 768×224 |
| panel_header_small | 512×160 |
| panel_label_small | 384×128 |
| popup_panel | 768×1024 |
| button_primary / secondary / disabled / selected_frame | 768×192 |
| button_small_back | 192×192 |
| piece_slot | 384×320 |
| chapter_card_open / locked / completed | 768×320 |
| collection_card_known / unknown | 384×480 |

PNG RGBA8 sRGB. Export margins and text-safe rects will be measured and recorded in manifest. Shared source crop and alpha for matching state families. Selection outline retains transparent center. Board opening and outer margin must be truly transparent. Preserve generated alpha if available; document any neutral-matte extraction, alignment or numeric normalization. Sources remain unchanged.

## Review composition

Five required review PNGs: ui_family_overview, readability_48px, grayscale_readability, gameplay_mockup_ui_only, menu_mockup_ui_only.
Mockups at720×1280 use separate review-only text and a plain quiet neutral backdrop. Preserve V1 menu action order and gameplay information/board/tray/actions/counters structure; combine secondary information to reduce stacked heavy plates. Reuse V2A board and piece art without changes. No new background generation, full-screen generation or gameplay changes.
Button/back examples at48 and64px relevant heights; cards at practical mobile widths. Test blank states and separately composited labels. Grayscale must preserve primary/secondary/disabled distinction through value and bevel as well as hue.

## Acceptance

16 required assets, exact manifest paths, safe transparent padding, uncropped shadows, shared state geometry, blank text-safe regions, clean inner board opening. Inspect all five review sheets, primary hierarchy, sibling cards, quiet frame, readable labels at mobile sizes. Document any remaining integration risks; do not mark complete if an essential gate fails.
