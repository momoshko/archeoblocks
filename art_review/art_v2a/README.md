# Archeoblocks · ART V2A

Статус: **пакет принят по результатам статической проверки материалов**. 16 production PNG, 6 review PNG. Интеграция в Godot не выполнялась.

Generated with the available built-in ImageGen; exact underlying image model/quality tier was not exposed by the tool.

## Направление

Утверждённый ART V1 **Light Sandstone Courtyard**: тёплая спокойная земля, цветные минералы с мягким объёмом, матовый обколотый камень и открытые ветвистые корни. Свет сверху слева. Золото сосредоточено в сигнале артефакта; предупреждение о корнях — оливковое. Референсы: `art_review/art_v1/master_menu.png` и `art_review/art_v1/master_gameplay.png` с органическими Roots.

Terrain, блоки и Stone получены через master → edit. Пять цветов блока используют один зелёный мастер; cracked Stone — intact; обе placement-версии — один valid master. Точные запросы и пути входных изображений сохранены в [prompts.json](prompts.json), исходные результаты — в `sources/` (17 PNG, включая промежуточный valid master).

## Production-файлы

Все пути ниже относительно корня репозитория. Все изображения — **256×256, PNG RGBA8, sRGB ICC, настоящий прозрачный внешний фон**.

| Каталог | Файлы | Назначение |
|---|---|---|
| `assets/art_v2a/cells/` | `cell_excavated_depth0_v2a.png`, `cell_soil_depth1_v2a.png`, `cell_soil_depth2_v2a.png` | Раскопанная, обычная и плотная земля |
| `assets/art_v2a/blocks/` | `block_green_v2a.png`, `block_blue_v2a.png`, `block_red_v2a.png`, `block_amber_v2a.png`, `block_purple_v2a.png`, `block_turquoise_v2a.png` | Шесть цветов одного минерального блока |
| `assets/art_v2a/obstacles/` | `stone_intact_v2a.png`, `stone_cracked_v2a.png` | Прочность 2 и 1; без цифр и полос |
| `assets/art_v2a/obstacles/` | `root_obstacle_v2a.png`, `root_growth_warning_v2a.png` | Корень и предупреждение на клетке назначения |
| `assets/art_v2a/overlays/` | `artifact_target_marker_v2a.png`, `preview_valid_v2a.png`, `preview_invalid_v2a.png` | Цель и временная обратная связь размещения |

Полный машинный список, роли, размеры, координаты и SHA-256: [manifest.json](manifest.json).

## Геометрия и alpha

- Canvas 256×256, pivot (128,128); верхний левый угол — (0,0).
- Terrain: общий rect (8,8,240,240), радиус внешнего угла 6 px и идентичная alpha всех трёх состояний.
- Блоки: rect (18,18,220,220); общий crop зелёного мастера и **побайтно одинаковая alpha всех шести цветов**. Не обрезать каждый цвет отдельно.
- Stone: общий crop intact для обеих версий; 220×220 в центре. Root также размещён в центральном rect 220×220, с открытыми промежутками.
- Marker/warning/placement: общий canvas, сигнал внутри (8,8,240,240). Valid/invalid используют один source crop промежуточного мастера. Разные семейства сигналов имеют собственные мастер-силуэты.
- В review все слои одинаково берутся из rect (8,8,240,240). Матрицы показывают его в 48×48; поле использует шаг 48 px: 47 px изображения + 1 px разделителя. При будущей интеграции сохранить это отображение общего rect, иначе масштаб содержимого будет отличаться от review.

Генератор вернул RGB с нарисованной нейтральной шахматной подложкой. При техническом экспорте удалена подложка и очищены внутренние промежутки корней/сигналов; края проверены на светлом и тёмном фоне. Alpha блоков унифицирована по мастеру, terrain — по общей линии обрезки. Исходники сохранены без изменений. Подробности: [export_report.json](export_report.json), [export_pack.cjs](export_pack.cjs).

Финальная числовая коррекция палитры сохраняет рисунок, положение граней и alpha: RGB power curve зелёного — 1.20, фиолетового — 0.65; warning переведён в оливковый HSL hue 85°, saturation=min(0.42, original×0.55), lightness=original+0.07×sin(π×original). Две дополнительные попытки генеративной цветокоррекции вернули лимит использования без изображения; итог использует сохранённые исходники и указанные операции.

## Слои и Hint

1. Terrain.
2. Buried clue, если нужен (здесь не демонстрируется).
3. Stone или Root.
4. Установленный блок.
5. Hint **или** valid/invalid preview.
6. Artifact target marker.
7. Root growth warning.

Hint использует **настоящую текстуру блока**, без отдельных ghost-спрайтов: `alpha = originalAlpha × 0.52`; `RGB = meanRGB + (RGB − meanRGB) × 0.72`. В review meanRGB — среднее по пикселям с alpha > 200 после уменьшения. Это смягчает блики и фактуру; форма фигуры остаётся той же. Marker и warning рисуются поверх.

## Review-файлы и выводы

| Файл в этом каталоге | Проверка |
|---|---|
| [gameplay_material_sheet.png](gameplay_material_sheet.png) | Все 16 материалов по категориям, увеличенные образцы 128 px |
| [readability_48px.png](readability_48px.png) | Все 16 в 48 px на двух фонах; marker на 12 подложках; real/hint/valid/invalid и warning на трёх грунтах |
| [grayscale_readability_48px.png](grayscale_readability_48px.png) | Та же матрица без цвета |
| [stress_test_board_8x8.png](stress_test_board_8x8.png) | Смешанные глубины, все цвета, препятствия, цели и warning |
| [stress_test_hint_valid.png](stress_test_hint_valid.png) | Легальный hint из трёх клеток и отдельный valid footprint |
| [stress_test_invalid.png](stress_test_invalid.png) | Invalid пересекает установленный блок и Roots; содержимое клеток видно |

Проверять при масштабе просмотра 100%. У блоков читаются общий объём и свет; они выделяются над грунтом. Stone выглядит матовым камнем, крупный раскол отличает повреждённый вариант. Root сохраняет ветвистый силуэт. Сигнал цели виден на всех 12 подложках; оливковые углы warning заметнее локального кольца и остаются поверх hint. Check/X и пустой центр отделяют placement от terrain. Повторение грунта не создаёт 64 декоративные рамки.

В grayscale средняя яркость центральных 128×128 экспортов по тому же преобразованию Sharp: blue 67.06, red 89.28, green 121.30, amber 136.25, purple 160.68, turquoise 188.93. Минимальный промежуток 14.95/255 поддерживает визуальное различение, но сам по себе не является тестом восприятия.

Fixture описан в [review_board_state.json](review_board_state.json). Это арт-макет, не сохранённая игровая сессия. Hint и valid стоят на разных свободных клетках для сравнения; invalid намеренно конфликтует. Предупреждённая клетка свободна и соседствует с Root.

## Проверка и ограничения

[verification.json](verification.json): **56/56 технических проверок**, плюс визуальная оценка шести review-файлов. [VERIFICATION.md](VERIFICATION.md) — краткий отчёт.

- Это статическая проверка агентом при 48 px и grayscale, без пользовательского тестирования и полной проверки нарушений цветового зрения.
- Depth0 и depth2 различаются также формой: углубление против крупных трещин. На маленьком экране важны оба сигнала.
- Фильтрация Godot, анимация, сжатие и масштабирование на устройствах ещё не проверялись. Тонкие placement-линии требуют проверки при будущей интеграции.
- `.gdignore` в production- и review-каталогах намеренно предотвращает импорт на этом этапе. Его изменение относится к будущей интеграции.
- Сцены, gameplay, темы, настройки экспорта и прежние assets не изменены. Godot не запускался. Ранее существовавшие правки проекта сохранены.

## Воспроизведение

Из корня репозитория, Node.js с Sharp. В скриптах указан доступный на этой машине bundled runtime; на другой машине потребуется заменить путь `require` на установленный `sharp`.

```powershell
node art_review/art_v2a/export_pack.cjs
node art_review/art_v2a/build_reviews.cjs
node art_review/art_v2a/verify_pack.cjs
```

Экспорт не вызывает ImageGen повторно: он использует неизменённые файлы `sources/`. Скрипты записывают только два каталога ART V2A.
