# Промпты для Gemini — все по порядку

Как пользоваться — в [README_RU.md](README_RU.md). Коротко: приложить картинки-образцы, вставить промпт,
сохранить результат как `raw/<id>_white.png`, потом отправить «второй проход» и сохранить `raw/<id>_black.png`.

**Второй проход (одинаковый для всех, кроме фона меню, иконки и обложки для Яндекса):**

```
Now make exactly the same image: the same object, in the same position and size, with the same lighting and details. Only replace the white background with plain pure black #000000. Do not change, move or redraw the object.
```

## 1. Находки (главное) — 21 шт.

### `bronze_key` — Бронзовый ключ

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ancient_courtyard/bronze_key_full_v1.png` · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: warm sandstone, bronze and gold, sunlit courtyard. Object: Old bronze key: round bow with three small knobs and a small turquoise inlay, straight shaft with two raised collars, bit with notched teeth; green patina only in the grooves.
```

### `mosaic_tablet` — Мозаичная табличка

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ancient_courtyard/mosaic_tablet_full_v1.png` · частей: 2 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: warm sandstone, bronze and gold, sunlit courtyard. Object: Rectangular sandstone tablet with rounded chipped corners, inset mosaic of small square tesserae forming an eight-petal rosette in terracotta, lapis blue, turquoise and a gold centre.
```

### `guardian_figurine` — Фигурка хранителя

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ancient_courtyard/guardian_figurine_full_v1.png` · частей: 3 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: warm sandstone, bronze and gold, sunlit courtyard. Object: Small standing terracotta guardian statuette with arms folded, calm stylised face, gold headband with a carnelian, gold collar, square plinth; friendly, not scary.
```

### `stone_charm` — Каменный оберег

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ruined_shrine/stone_charm_full_v1.png` · частей: 2 (по вертикали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: grey temple stone, bronze and gold, a little soot and wear. Object: Shield-shaped grey shrine-stone charm with an engraved border line, a sand-coloured eye motif and a round lapis inlay in the centre, worn edges.
```

### `bronze_bell` — Бронзовый колокольчик

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ruined_shrine/bronze_bell_full_v1.png` · частей: 2 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: grey temple stone, bronze and gold, a little soot and wear. Object: Small bronze temple bell with a hanging loop on top, two thin gold bands, a row of engraved dots, the round clapper visible under the rim, light green patina.
```

### `priest_seal` — Печать жреца

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ruined_shrine/priest_seal_full_v1.png` · частей: 2 (по диагонали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: grey temple stone, bronze and gold, a little soot and wear. Object: Round seal of dark basalt set in a beaded gold rim; a carved eye under a rising sun inlaid in gold.
```

### `stele_fragment` — Обломок стелы

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ruined_shrine/stele_fragment_full_v1.png` · частей: 2 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: grey temple stone, bronze and gold, a little soot and wear. Object: Broken upper part of a grey stone stele with a jagged broken top, a sun-disc relief and four rows of simple carved geometric glyphs (no real letters).
```

### `ritual_bracelet` — Ритуальный браслет

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ruined_shrine/ritual_bracelet_full_v1.png` · частей: 3 (дугами по кругу, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: grey temple stone, bronze and gold, a little soot and wear. Object: Gold bangle seen from the front as a ring, alternating carnelian and lapis cabochons in small gold settings, one engraved line along the band.
```

### `incense_vessel` — Сосуд для благовоний

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ruined_shrine/incense_vessel_full_v1.png` · частей: 3 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: grey temple stone, bronze and gold, a little soot and wear. Object: Bronze censer: domed pierced lid with a knob, wide bowl with a gold band and diamond ornament, stemmed foot; light patina.
```

### `altar_medallion` — Алтарный медальон

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ruined_shrine/altar_medallion_full_v1.png` · частей: 3 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: grey temple stone, bronze and gold, a little soot and wear. Object: Large gold medallion with a hanging loop, raised eight-pointed star, dotted rim and a central carnelian cabochon.
```

### `shrine_idol` — Идол святилища

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/ruined_shrine/shrine_idol_full_v1.png` · частей: 3 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: grey temple stone, bronze and gold, a little soot and wear. Object: Seated grey stone idol with a gold headdress, gold eyes, hands resting on the knees and a gold collar; weathered stone, calm expression.
```

### `stone_comb` — Каменный гребень

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/stone_comb_full_v1.png` · частей: 2 (по вертикали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Sandstone comb with an arched back carved with a small turquoise-inlaid vine and a row of long even teeth; one tooth chipped.
```

### `copper_pendant` — Медная подвеска

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/copper_pendant_full_v1.png` · частей: 2 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Teardrop copper pendant with a loop, embossed leaf with veins, strong green patina in the recesses.
```

### `burial_tablet` — Погребальная табличка

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/burial_tablet_full_v1.png` · частей: 2 (дугами по кругу, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Arched grey stone tablet with a six-rayed star inside a carved ring and rows of simple carved signs; green moss on the lower corners.
```

### `carved_vessel` — Резной сосуд

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/carved_vessel_full_v1.png` · частей: 2 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Terracotta amphora with two loop handles and incised zigzag bands, slightly weathered.
```

### `vine_amulet` — Амулет лозы

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/vine_amulet_full_v1.png` · частей: 3 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Round bronze amulet with a hanging loop, wreathed by a vine of small emerald leaves, rhombic emerald in the centre.
```

### `fresco_fragment` — Фрагмент фрески

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/fresco_fragment_full_v1.png` · частей: 3 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Irregular broken plaster fragment painted with a blue bird among green leaves between a red upper border and a blue lower border, fine cracks.
```

### `bone_clasp` — Костяная застёжка

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/bone_clasp_full_v1.png` · частей: 3 (по вертикали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Ivory-coloured bone clasp: two oval plates carved with spirals, joined by a bronze pin with round ends.
```

### `ritual_bowl` — Ритуальная чаша

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/ritual_bowl_full_v1.png` · частей: 3 (по вертикали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Shallow terracotta bowl on a small foot seen from the side, black meander band under the rim and a row of cream dots.
```

### `guardian_seal` — Печать хранителя

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/guardian_seal_full_v1.png` · частей: 3 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Square turquoise-jade seal in a gold frame with gold corner studs, a stylised calm guardian face carved in the middle.
```

### `emerald_idol` — Изумрудный идол

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/artifacts/overgrown_catacombs/emerald_idol_full_v1.png` · частей: 3 (по горизонтали, режет скрипт) · второй проход: нужен

```
Game asset for a casual mobile puzzle game about archaeology. Match the attached reference images exactly in style, rendering, detail level and lighting: painterly but crisp, polished, warm light from the upper left, soft ambient occlusion in carved grooves, rich natural colours (not neon), clean silhouette that still reads at 48 px. One single object, orthographic front view, centred, the whole object visible with empty margins around it (the object fills about 70% of the frame). Background: plain pure white #FFFFFF, perfectly flat and even, no shadow under the object, no gradient, no floor, no vignette. No text, no letters, no numbers, no frame, no plate, no border, no watermark. Square 1:1. Chapter look: bone, copper, terracotta, a touch of moss; the emerald idol is the most precious find of the game. Object: Small idol carved from deep green emerald with a gold crown and collar, a carnelian on the chest, standing on a gold base; the most precious find of the game.
```

## 2. Меню и витрина Яндекса

### `emblem` — Эмблема меню

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/ui_art/menu/emblem.png` · второй проход: нужен

```
Game UI asset for a casual mobile puzzle game about archaeology, same art style as the attached references: painterly but crisp, warm light from the upper left, warm sandstone palette. Centred, empty margins around it. Background: plain pure white #FFFFFF, perfectly flat, no shadow on the background, no gradient. No text, no letters, no numbers, no watermark. Square 1:1. Object: round carved sandstone medallion with a golden sun-spiral in the centre, sixteen short rays around the rim, chipped worn edges, subtle engraved dots.
```

### `background` — Фон меню и экранов

Образцы: `screen_menu.png`, `screen_game.png`, `golden_mask_on_white.png` · файл: `assets/ui_art/menu/background.jpg` · второй проход: не нужен (картинка без прозрачности)

```
Vertical 9:16 illustration for the background of a casual mobile puzzle game about archaeology, same painterly style and warm palette as the attached references: a sunlit ancient sandstone courtyard seen from the inside, weathered stone arch and walls, a few clay amphorae, olive branches at the edges, soft warm morning light from the upper left, blue sky visible through the arch. Calm, slightly desaturated. Keep the central vertical area (about 70% of the width) low in detail and even in tone, because UI panels sit on top. No people, no text, no UI, no watermark.
```

### `store_icon` — Иконка для Яндекса

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `build/store/icon_512.png` · второй проход: не нужен (картинка без прозрачности)

```
Square 1:1 game icon for a casual mobile puzzle game about archaeology, same art style as the attached references: the carved sandstone sun-spiral medallion in front of a few glossy mineral blocks (emerald, lapis, carnelian, amber) arranged like a block puzzle, warm sandstone background filling the whole square, strong readable silhouette at small size, no text, no watermark.
```

### `store_cover` — Обложка для Яндекса

Образцы: `screen_menu.png`, `screen_game.png`, `golden_mask_on_white.png` · файл: `build/store/cover_800x470.png` · второй проход: не нужен (картинка без прозрачности)

```
Wide 16:9 game cover for a casual mobile puzzle game about archaeology, same art style as the attached references: a partly excavated 8x8 stone grid in an ancient sandstone courtyard, colourful mineral blocks placed in rows, a golden mask half revealed under brown soil, warm light, a small brush and trowel at the edge, inviting casual puzzle mood. No text, no logo, no watermark.
```

## 3. Иконки на кнопки (по желанию)

### `icon_pause` — Иконка: pause

Образцы: `buttons_on_white.png`, `screen_game.png` · файл: `assets/ui_art/icons/pause.png` · второй проход: нужен

```
Flat-ish game UI icon glyph: cream colour #F3E6C4 with a dark brown #4A3322 outline about 6% of the icon width, slight bevel, readable at 40 px, works on both a green and a sand-coloured button. Centred, empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no letters, no watermark. Square 1:1. Glyph: two vertical rounded bars.
```

### `icon_back` — Иконка: back

Образцы: `buttons_on_white.png`, `screen_game.png` · файл: `assets/ui_art/icons/back.png` · второй проход: нужен

```
Flat-ish game UI icon glyph: cream colour #F3E6C4 with a dark brown #4A3322 outline about 6% of the icon width, slight bevel, readable at 40 px, works on both a green and a sand-coloured button. Centred, empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no letters, no watermark. Square 1:1. Glyph: arrow pointing left.
```

### `icon_hint` — Иконка: hint

Образцы: `buttons_on_white.png`, `screen_game.png` · файл: `assets/ui_art/icons/hint.png` · второй проход: нужен

```
Flat-ish game UI icon glyph: cream colour #F3E6C4 with a dark brown #4A3322 outline about 6% of the icon width, slight bevel, readable at 40 px, works on both a green and a sand-coloured button. Centred, empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no letters, no watermark. Square 1:1. Glyph: small magnifying glass.
```

### `icon_undo` — Иконка: undo

Образцы: `buttons_on_white.png`, `screen_game.png` · файл: `assets/ui_art/icons/undo.png` · второй проход: нужен

```
Flat-ish game UI icon glyph: cream colour #F3E6C4 with a dark brown #4A3322 outline about 6% of the icon width, slight bevel, readable at 40 px, works on both a green and a sand-coloured button. Centred, empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no letters, no watermark. Square 1:1. Glyph: curved arrow turning back to the left.
```

### `icon_sound_on` — Иконка: sound_on

Образцы: `buttons_on_white.png`, `screen_game.png` · файл: `assets/ui_art/icons/sound_on.png` · второй проход: нужен

```
Flat-ish game UI icon glyph: cream colour #F3E6C4 with a dark brown #4A3322 outline about 6% of the icon width, slight bevel, readable at 40 px, works on both a green and a sand-coloured button. Centred, empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no letters, no watermark. Square 1:1. Glyph: loudspeaker with two sound waves.
```

### `icon_sound_off` — Иконка: sound_off

Образцы: `buttons_on_white.png`, `screen_game.png` · файл: `assets/ui_art/icons/sound_off.png` · второй проход: нужен

```
Flat-ish game UI icon glyph: cream colour #F3E6C4 with a dark brown #4A3322 outline about 6% of the icon width, slight bevel, readable at 40 px, works on both a green and a sand-coloured button. Centred, empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no letters, no watermark. Square 1:1. Glyph: loudspeaker with a small cross.
```

### `icon_settings` — Иконка: settings

Образцы: `buttons_on_white.png`, `screen_game.png` · файл: `assets/ui_art/icons/settings.png` · второй проход: нужен

```
Flat-ish game UI icon glyph: cream colour #F3E6C4 with a dark brown #4A3322 outline about 6% of the icon width, slight bevel, readable at 40 px, works on both a green and a sand-coloured button. Centred, empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no letters, no watermark. Square 1:1. Glyph: gear with eight teeth.
```

### `icon_play` — Иконка: play

Образцы: `buttons_on_white.png`, `screen_game.png` · файл: `assets/ui_art/icons/play.png` · второй проход: нужен

```
Flat-ish game UI icon glyph: cream colour #F3E6C4 with a dark brown #4A3322 outline about 6% of the icon width, slight bevel, readable at 40 px, works on both a green and a sand-coloured button. Centred, empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no letters, no watermark. Square 1:1. Glyph: triangle pointing right.
```

### `icon_endless` — Иконка: endless

Образцы: `buttons_on_white.png`, `screen_game.png` · файл: `assets/ui_art/icons/endless.png` · второй проход: нужен

```
Flat-ish game UI icon glyph: cream colour #F3E6C4 with a dark brown #4A3322 outline about 6% of the icon width, slight bevel, readable at 40 px, works on both a green and a sand-coloured button. Centred, empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no letters, no watermark. Square 1:1. Glyph: infinity sign made of a coiled rope, for the Endless Dig mode.
```

## 4. Эффекты (по желанию)

### `fx_dust_puff` — Эффект: dust_puff

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/ui_art/fx/dust_puff.png` · второй проход: нужен

```
Soft game particle sprite, light and airy, painterly, warm colours, soft edges, centred with wide empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no watermark. Square 1:1. Sprite: small puff of light brown soil dust.
```

### `fx_sparkle` — Эффект: sparkle

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/ui_art/fx/sparkle.png` · второй проход: нужен

```
Soft game particle sprite, light and airy, painterly, warm colours, soft edges, centred with wide empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no watermark. Square 1:1. Sprite: four-pointed golden sparkle star with a soft glow.
```

### `fx_glint` — Эффект: glint

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/ui_art/fx/glint.png` · второй проход: нужен

```
Soft game particle sprite, light and airy, painterly, warm colours, soft edges, centred with wide empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no watermark. Square 1:1. Sprite: thin bright light glint streak.
```

### `fx_stone_chip` — Эффект: stone_chip

Образцы: `golden_mask_on_white.png`, `courtyard_seal_on_white.png`, `stone_amulet_on_white.png` · файл: `assets/ui_art/fx/stone_chip.png` · второй проход: нужен

```
Soft game particle sprite, light and airy, painterly, warm colours, soft edges, centred with wide empty margins. Background: plain pure white #FFFFFF, perfectly flat. No text, no watermark. Square 1:1. Sprite: small chip of grey-beige stone with a sharp broken edge.
```
