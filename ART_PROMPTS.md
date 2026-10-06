# Промпты для замены временного арта

Сейчас фон, эмблема, иконка и обложка нарисованы кодом (`tools/draw_menu_art.py`).
Когда сгенерируете настоящие картинки, положите их с **теми же именами и размерами** —
игра подхватит без правок. Стиль — утверждённый «Light Sandstone Courtyard» из
`art_review/art_v1/STYLE_GUIDE.md`; как референс прикладывайте
`art_review/art_v1/master_menu.png` и `master_gameplay.png`.

Общее для всех промптов: без текста, букв, цифр, логотипов и водяных знаков;
тёплый песчаник, мягкий свет сверху слева, спокойные детали.

## 1. Фон меню и экранов — `assets/ui_art/menu/background.jpg`

Размер 1080×1920 (или 1440×2560), JPG. Используется на всех экранах; в игре он
автоматически затемняется.

> Vertical 9:16 illustration of a sunlit ancient sandstone courtyard seen from the inside:
> weathered stone arch and walls, a few clay amphorae, olive branches at the edges,
> soft warm morning light from the upper left, blue sky visible through the arch.
> Calm, slightly desaturated, painterly casual-game style. Keep the central vertical
> area (about 70% width) low-detail and even in tone so UI panels can sit on top.
> No people, no text, no UI.

## 2. Эмблема — `assets/ui_art/menu/emblem.png`

512×512 PNG с прозрачным фоном (генерировать 1024×1024 и уменьшить).

> Round carved sandstone medallion with a golden sun-spiral in the centre, sixteen short
> rays around the rim, chipped worn edges, subtle engraved dots, soft drop shadow,
> upper-left light, game UI emblem, isolated on transparent background, no text.

## 3. Иконка — `build/store/icon_512.png` (в игру не входит)

512×512 PNG, для черновика Яндекса. Нельзя просто скриншот.

> Square game icon: the carved sandstone sun-spiral medallion in front of a few glossy
> mineral blocks (emerald, lapis, carnelian, amber) arranged like a block puzzle,
> warm sandstone background, strong readable silhouette at small size, no text.

## 4. Обложка — `build/store/cover_800x470.png` (в игру не входит)

800×470 PNG. Можно без названия — тогда одна обложка подходит для обоих языков.

> Wide game cover: a partly excavated 8×8 stone grid in an ancient sandstone courtyard,
> colourful mineral blocks placed in rows, a golden mask half revealed under brown soil,
> warm light, small brush and trowel at the edge, inviting casual puzzle mood, no text.

## 5. Hero-картинка (по желанию) — 1560×520

> Panoramic banner of the same sandstone courtyard with an excavation site in the centre,
> golden artifacts glinting in the soil, mineral puzzle blocks stacked nearby, no text.

## После генерации

1. Сохраните файл с тем же именем, проверьте размер.
2. Запишите источник, дату и тариф в `CREDITS.md` (Яндекс требует лицензию на всё).
3. Снимите экраны: `tools/capture_screens.gd` (см. EDITOR_GUIDE_RU.md).
