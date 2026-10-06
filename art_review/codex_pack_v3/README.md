# Задание для Codex: находки v3 (и остальной арт)

Этот пакет — для Codex с встроенной генерацией изображений. Claude в этом проекте
генерировать картинки не может; он подготовил задание и потом подключит результат
(`.tres` экспедиций, тесты, скриншоты).

## 1. Находки — 21 штука (главное)

Сейчас у этих экспедиций нет картинок, в коллекции и окне победы пусто.
Промпты и точные имена файлов — в [prompts.json](prompts.json).

Требования (как в `art_review/artifact_presentation_pack_v1`):

- **512×512 PNG RGBA8, sRGB, настоящий прозрачный фон.** Если генератор нарисует
  шахматную подложку — удалить её, как в прошлый раз, и срезать 1 px каймы.
- Находка вписана по длинной стороне в **384 px**, поля не меньше 64 px.
- Стиль и масштаб — как у референсов: `golden_mask_full_v1.png`,
  `courtyard_seal_full_v1.png`, `stone_amulet_full_v1.png`
  (все в `assets/artifacts/ancient_courtyard/`). Прикладывать их к каждому запросу.
- Фронтальный вид, свет сверху слева, без текста, рамок и теней-подложек.
- Для находок из 2–3 частей: фрагменты **вырезаются из того же master** по неровным
  взаимодополняющим границам (без «пазловых» выступов), примерно равной площади,
  каждый на своём холсте 512×512 **на своём месте** — как `golden_mask_fragment_*_v1.png`.
  Отдельно фрагменты не генерировать.
- Файлы класть сразу в `assets/artifacts/<глава>/` с именами из prompts.json
  (`<id>_full_v1.png`, `<id>_fragment_a_v1.png` …).
- Обзорный лист и prompts с фактическими запросами — в эту папку (`review/`),
  как в прошлых паках. `.gdignore` здесь уже лежит.

| № | id | Название | Частей | Как делить |
| --- | --- | --- | --- | --- |
| 1 | `bronze_key` | Бронзовый ключ / Bronze Key | 1 | - |
| 2 | `mosaic_tablet` | Мозаичная табличка / Mosaic Tablet | 2 | horizontal (top / bottom) |
| 3 | `guardian_figurine` | Фигурка хранителя / Guardian Figurine | 3 | horizontal (head / torso / legs and plinth) |
| 4 | `stone_charm` | Каменный оберег / Stone Charm | 2 | vertical (left / right) |
| 5 | `bronze_bell` | Бронзовый колокольчик / Bronze Bell | 2 | horizontal (top with loop / lower rim) |
| 6 | `priest_seal` | Печать жреца / Priest's Seal | 2 | diagonal or vertical |
| 7 | `stele_fragment` | Обломок стелы / Stele Fragment | 2 | horizontal (relief / glyphs) |
| 8 | `ritual_bracelet` | Ритуальный браслет / Ritual Bracelet | 3 | three arcs of the ring |
| 9 | `incense_vessel` | Сосуд для благовоний / Incense Vessel | 3 | horizontal (lid / bowl / foot) |
| 10 | `altar_medallion` | Алтарный медальон / Altar Medallion | 3 | horizontal thirds |
| 11 | `shrine_idol` | Идол святилища / Shrine Idol | 3 | horizontal (head / torso / legs and base) |
| 12 | `stone_comb` | Каменный гребень / Stone Comb | 2 | vertical (left / right) |
| 13 | `copper_pendant` | Медная подвеска / Copper Pendant | 2 | horizontal (top / bottom) |
| 14 | `burial_tablet` | Погребальная табличка / Burial Tablet | 2 | horizontal (arch / text rows) |
| 15 | `carved_vessel` | Резной сосуд / Carved Vessel | 2 | horizontal (neck / body) |
| 16 | `vine_amulet` | Амулет лозы / Vine Amulet | 3 | horizontal thirds |
| 17 | `fresco_fragment` | Фрагмент фрески / Fresco Fragment | 3 | along existing cracks |
| 18 | `bone_clasp` | Костяная застёжка / Bone Clasp | 3 | left plate / pin / right plate |
| 19 | `ritual_bowl` | Ритуальная чаша / Ritual Bowl | 3 | vertical thirds |
| 20 | `guardian_seal` | Печать хранителя / Guardian's Seal | 3 | horizontal thirds |
| 21 | `emerald_idol` | Изумрудный идол / Emerald Idol | 3 | horizontal (crown and head / body / base) |

Главы: `ancient_courtyard` — тёплый песчаник и бронза; `ruined_shrine` — серый
камень храма, бронза, золото; `overgrown_catacombs` — кость, медь, терракота,
мох, изумруд. Изумрудный идол — финальная и самая ценная находка.

## 2. Меню и витрина Яндекса

Промпты — в корневом `ART_PROMPTS.md`: фон `assets/ui_art/menu/background.jpg`
(1080×1920), эмблема `assets/ui_art/menu/emblem.png` (512×512, прозрачная),
иконка `build/store/icon_512.png`, обложка `build/store/cover_800x470.png`.
Сейчас там временные картинки, нарисованные кодом, — заменить файлами с теми же именами.

## 3. Иконки на кнопки (по желанию, следующий шаг)

128×128 PNG RGBA в `assets/ui_art/icons/`: `pause`, `back`, `hint` (лампа или лупа),
`undo` (стрелка назад), `sound_on`, `sound_off`, `settings`, `play`.
Кремовый глиф с тёмно-коричневым контуром, чтобы читался и на зелёной, и на песчаной
кнопке (`assets/ui_art/ui/button_primary.png`, `button_secondary.png`). Без текста.

## 4. Эффекты (по желанию)

256×256 PNG RGBA в `assets/ui_art/fx/`: `dust_puff` (облачко грунта),
`sparkle` (золотая искра-звезда), `glint` (блик), `stone_chip` (осколок камня).
Светлые, мягкие края, на прозрачном фоне; будут частицами при раскопке и находке.
