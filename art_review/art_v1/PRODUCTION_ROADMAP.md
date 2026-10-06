# ART V1 → production roadmap

Работать по одному milestone. Ниже — очередь производства, не уже изготовленные ассеты. Master screens задают материал и иерархию; координаты и gameplay берутся из сцен и `gameplay_state.json`.

| Этап | Набор | Что изготовить и как использовать | Критерий завершения |
| --- | --- | --- | --- |
| 1 | Cell + block refinement | Три terrain base; два burial overlays; шесть минералов. Корректировать существующие packs, сохранять canvas 256 и совместимый origin | 8×8 без сеточного шума; amber не похож на marker; 31/48 px |
| 2 | Obstacles + gameplay signals | Stone 1/2 durability и damaged transition; root; root growth warning; marker; hint/valid/invalid | Прочность понятна статично; marker виден при перекрытии; hint отличается от факта размещения |
| 3 | Board frame | Четыре угла и стороны / texture для StyleBoxTexture или NinePatchRect; тихая внутренняя кромка | Square board, неизменный pitch, corners не растягиваются, декор вне сетки |
| 4 | Panel family | Светлая основная панель, малый HUD panel, три slot panels, modal | Общие края и свет; чистая середина; 9-slice на узкой и широкой панели |
| 5 | Button family | Primary jade, secondary sandstone; normal/hover/pressed/disabled/focus. Отдельные векторные/узловые иконки | Без текста в PNG; одна размерная система; клавиатурный focus различим |
| 6 | Menu background | Один двор без текста, кнопок и эмблемы; центральная quiet zone; отдельная эмблема | Фон выдерживает 9:16 и высокие экраны; элементы не вплетены в controls |
| 7 | Artifact presentation frames | Небольшая подложка preview, reveal frame, fragment progress treatment | Существующий Artifact Pack v1 вписывается без нового масштаба частей; золото локально |
| 8 | Collection card system | locked / partial / complete / selected; область артефакта, имени и прогресса отдельными узлами | Реальные длинные названия и все формы находок; цвет не единственный сигнал состояния |
| 9 | Chapter accents | По одному малому набору: двор / разрушенное святилище / корни катакомб | Общие кнопки и поле неизменны; смена главы узнаётся по периферии |
| 10 | Scene integration + focused QA | Подключить утверждённые textures и theme resources к существующим сценам | Меню, один реальный Chapter III mid-game, pause/reveal/collection; targeted checks |

Не начинать с полного перерисовывания всех глав. Первый production milestone — связка **terrain + blocks + marker**, затем obstacles: она решает главные риски чтения поля. Меню можно производить после фиксации базовых материалов.

## Форматы и поставка

- Runtime/export filenames: Latin ASCII, без пробелов. Номера версии обязательны; старые наборы не перезаписывать.
- PNG RGBA, sRGB, прозрачность настоящая, без шахматной подложки. Для рисунков master source хранить отдельно; import/compression выбирать после теста в Godot.
- У слоя есть manifest: canvas, visible bounds, origin, padding, scale/fit, slicing margins, illumination, смысл состояния.
- UI nine-slice: margins определять по финальному рисунку; не копировать произвольное значение из master screenshot. Отдельно проверять, что скол не попал в растягиваемый центр.
- Крупный фон: ориентир 1440×2560 для 720×1280 @2x, без UI. Это production target; ограничения памяти Web проверяются на этапе импорта.
- Никаких растровых строк «Играть», «Подсказка», чисел прочности или счёта в skin-ассетах. Текст и простые glyphs — настоящие Label/Button/Control nodes.

## Карта будущей интеграции

| Существующий узел / сцена | Подключаемая презентация |
| --- | --- |
| `MainMenu/Background`, `SideDecorLeft/Right` | Фон двора и адаптивная периферия |
| `.../MenuPanel`, `MenuLayout/EmblemPlaceholder` | Nine-slice panel; TextureRect эмблемы в той же иерархии |
| `GameTitle`, `Subtitle`, четыре `Button` | Theme/font overrides и отдельные button skins; текст остаётся текстом |
| `GameScreen/.../Header`, `ObjectiveText`, `ObjectiveSecondary` | Типографика, спокойные подложки, переносы |
| `.../BoardFrame` | Каменная рамка, самостоятельная от содержимого |
| `CellView` children | State textures и marker/preview visuals; модель не переписывается |
| `StoneObstacle`, `RootObstacle`, `RootGrowthWarning` | Отдельные сцены препятствий и предупреждения |
| `PieceTray/LSlot`, `TSlot`, `LineSlot` | Общий skin слота; имя и клетки сохраняются |
| `Actions/UndoButton`, `HintButton`, `Stats` | Theme skins; реальные счётчики помощи и статистики |
| Collection / result / discovery scenes | Следующий этап после проверки основного поля |

Существующие имена слотов — имена узлов, не ограничение формы: в реальном состоянии туда загружаются квадрат, вертикальная линия и большая Г. Не рисовать три фиксированные формы в skin слотов.

## Ограничения механики

Изменение вида hint/marker не меняет выбор подсказки, доступность хода, получение награды и стоимость помощи. Release использует реальные доступные действия; значения debug unlimited не переносятся в production. Rewarded action выдаёт ценность только после `reward_granted`, с уникальным request id и защитой от дублей — ART V1 не касается этой логики.

## Gate перед интеграцией

Согласованный cell contract → native-size readability sheet → mixed-board stress test → scene-based skin integration → targeted runtime review. Если падает различимость marker/amber или stone/depth2, корректировать маленький набор до производства остальных экранов.
