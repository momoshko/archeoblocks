# Как редактировать интерфейс

- Главное меню: откройте `scenes/screens/main_menu.tscn`.
- Игровой экран: откройте `scenes/screens/game_screen.tscn`.
- Поле: в дереве игрового экрана откройте `PortraitContent/MainLayout/BoardFrame/Board`; его отдельная сцена — `scenes/game/board_view.tscn`.
- Размер текста: выберите `Label`, затем в Inspector откройте **Theme Overrides → Font Sizes → Font Size**.
- Размер кнопки: выберите `Button` и измените **Layout → Transform/Container Sizing → Custom Minimum Size**. Стиль кнопок хранится в `theme/archeoblocks_theme.tres`; локальный вид можно менять через **Theme Overrides → Styles**.
- Отступы поля: выберите `BoardFrame`, затем измените его **Theme Overrides → Styles → Panel** либо размеры/отступы контейнера вокруг него.
- Фон: выберите `Background` и поменяйте цвет или замените `ColorRect` на `TextureRect`, сохранив Full Rect anchors.
- Чтобы запустить открытую сцену, нажмите **F6**. Для запуска всего проекта нажмите **F5**.

## Проверка M1

- Откройте scenes/screens/game_screen.tscn и нажмите **F6**.
- Мышь: зажмите фигуру в одном из трёх PieceSlot, перенесите на поле и отпустите.
- Touch в редакторе: откройте **Project → Project Settings → Input Devices → Pointing**, временно включите **Emulate Touch From Mouse**, затем повторите drag.
- Touch-подъём редактируется у узла GameSession в свойстве **Touch Drag Lift**. Значение по умолчанию — 82 px.
- На телефоне Godot сначала присылает «мышиное» нажатие, сделанное из касания (устройство −1), и только потом само касание. `PieceSlot` считает такое нажатие пальцем, поэтому фигура поднимается на Touch Drag Lift. Вторым пальцем вторую фигуру взять нельзя. Проверка — тест `touch_input`.
- Внешний вид клетки: scenes/game/cell_view.tscn.
- Размер и расположение поля: scenes/game/board_view.tscn или BoardFrame/Board внутри игрового экрана.
- Внешний вид слота: scenes/game/piece_slot.tscn.
- Расстояние между слотами: узел PieceTray в scenes/game/piece_tray.tscn, свойство **Theme Overrides → Constants → Separation**.
- Цвета valid/invalid preview находятся в ValidPreview и InvalidPreview сцены клетки; цвет плавающего invalid preview — в Inspector сцены drag_piece_preview.tscn.

## Редактирование M2

- Данные тестовой экспедиции: откройте resources/expeditions/expedition_01.tres.
- Обычный грунт задаётся массивом Normal Soil Cells, усиленный — Strong Soil Cells.
- В Artifact Fragments раскройте каждый вложенный Resource и измените его Cells.
- Все координаты записываются как Vector2i(x, y) для поля 8×8, от (0, 0) до (7, 7).
- Внешний вид обычного грунта: CellView/SoilVisual.
- Внешний вид усиленного грунта: CellView/StrongSoilVisual.
- Подсказка находки: CellView/ArtifactHint; прозрачность по глубине находится на корневом CellView.
- Вспышка раскопки: CellView/DigFlash.
- Окно победы и поражения: scenes/ui/result_popup.tscn.
- Для запуска M2 откройте scenes/screens/game_screen.tscn и нажмите **F6**.

## Редактирование M2.1

- Лимиты Undo/Hint и задержка idle-подсказки находятся в `resources/config/help_config.tres`.
- Все значения очков находятся в `resources/config/score_config.tres`.
- Награда Coins за победу находится в `resources/config/economy_config.tres`.
- Rescue/Victory layout редактируется в `scenes/ui/result_popup.tscn`.
- Текстовый feedback редактируется в `scenes/ui/action_feedback.tscn`.
- Restart в паузе — реальный узел `RestartButton` в `scenes/ui/pause_popup.tscn`.
- Подсветка выбранной Hint-фигуры — `HintHighlight` в `scenes/game/piece_slot.tscn`.
- `RewardedActionService` использует mock только в debug/editor; production-награды без настоящего provider не выдаются.

## ARTIFACT READABILITY

- Откройте `scenes/game/cell_view.tscn`.
- `ArtifactHint` и его `Symbol` задают знак артефакта под грунтом.
- `ArtifactTargetBorder` отмечает ещё не завершённую цель поверх грунта.
- Цвет и прозрачность `SoilVisual` / `StrongSoilVisual` отвечают за различие depth 1 / depth 2.
- Значения alpha и мягкого акцента оставшихся целей доступны на корневом `CellView` в Inspector.

## PLACEMENT PREVIEW

- `ValidPreview` и `InvalidPreview` в `cell_view.tscn` задают snapped target на поле.
- Размер и прозрачность переносимой фигуры редактируются на корне `scenes/ui/drag_piece_preview.tscn`.
- Current target должен оставаться главным сигналом; отдельная заливка всех legal origins намеренно не используется.

## PIECE SLOT

- Карточка, preview area, текст и used state находятся в `scenes/game/piece_slot.tscn`.
- Общие `preview_cell_size`, `preview_gap` и `preview_padding` редактируются на корне PieceSlot.
- Runtime центрирует bounding box любой PieceDefinition по обеим осям без индивидуальных offsets.

## DEBUG UNLIMITED HINT

- В debug/editor откройте `resources/config/help_config.tres` и включите `debug_unlimited_hints`.
- Начните Expedition 1, нажимайте Hint и вручную выполняйте ровно предложенный ход до Victory или Rescue.
- Hint allowance и rewarded provider в этом режиме не используются. В release флаг не действует.
- Последняя выбранная фигура, origin, линии, excavation/artifact hits и оставшиеся legal moves печатаются в Output.

## ЗВУК И НАСТРОЙКИ

- Музыка — `assets/audio/music/`: `menu.ogg` (меню и экраны вокруг), `gameplay.ogg` (экспедиции), по желанию `gameplay_ancient_courtyard.ogg` / `gameplay_ruined_shrine.ogg` / `gameplay_overgrown_catacombs.ogg` для отдельной главы. Файлы подхватываются по имени, зацикливаются и плавно сменяются. Нет файла — тишина, ошибок нет. Громкость — `MUSIC_VOLUME_DB` в `scripts/audio/audio_manager.gd` или шина `Music`.
- Все звуки лежат в `assets/audio/sfx/` и ищутся по имени файла. Чтобы заменить звук, положите новый `.wav` с тем же именем (например, `place.wav`).
- Текущие звуки синтезированы скриптом `tools/generate_sfx.py` (свои, без чужих лицензий).
- Громкость групп — в нижней панели **Audio**: шины `Music` и `SFX` (`default_bus_layout.tres`).
- Проигрывание — автозагрузка `AudioManager` (`scenes/app/audio_manager.tscn`): музыка — узел `MusicPlayer`, эффекты — `SfxPlayers`.
- Какие события игры звучат — `scripts/audio/game_sfx.gd` (узел `GameSfx` в игровом экране).
- Переключатели Музыка/Звуки — `scenes/screens/settings.tscn`; кнопка «Звук» в паузе — `SoundButton` в `scenes/ui/pause_popup.tscn`. Настройки сохраняются в `user://settings.cfg`.

## МОНЕТЫ

- Монеты начисляются и сохраняются, но скрыты в интерфейсе, пока нет магазина. Включить показ — `SHOW_COINS` в `scripts/game/feature_flags.gd`.

## ПРОДОЛЖЕНИЕ КАМПАНИИ

- Кнопка «Играть/Продолжить» открывает первую непройденную экспедицию. Порядок — `scripts/game/campaign_route.gd`, сцена каждой экспедиции — поле `Game Scene Path` в её `.tres`.

## ТЕСТЫ

- Все тесты одной командой (PowerShell, из папки проекта):
  `.\tools\run_tests.ps1 -Godot "C:\путь\к\Godot_v4.7-stable_win64_console.exe"`
- Один тест: добавьте `-Filter turn_race`. Полные логи — в папке `.test_logs`.
- Два самых долгих теста (автопрохождение кампании подсказками) идут 1–3 минуты.
- Перед тестами скрипт один раз открывает проект без окна (`--editor --quit`), чтобы Godot увидел новые скрипты и файлы. Лог — `.test_logs/_import.log`.

## ЯЗЫК (РУССКИЙ / АНГЛИЙСКИЙ)

- Русские тексты в сценах, скриптах и `.tres` остаются исходными — пишите и правьте их как раньше.
- Английский перевод — файл `translations/en.po` (открывается любым текстовым редактором или Poedit). В нём пары: `msgid` — точный русский текст, `msgstr` — английский.
- **Если поменяли русский текст** (в Label, кнопке, названии экспедиции, цели, имени находки), найдите старый `msgid` в `en.po` и замените его на новый. Иначе в английской версии этот текст останется русским. Новые тексты тоже добавляйте в `en.po`. Проверка — тест `locale_test`.
- `%d` и `%s` в тексте — места для чисел и слов, их сохраняйте в обоих языках. `\n` — перенос строки.
- Label и Button переводятся сами (свойство **Auto Translate** = Inherit). Текст, который ставится из кода, оборачивается в `tr("…")`. Чтобы текст никогда не переводился (например, «Русский» / «English» в выборе языка), поставьте **Auto Translate → Disabled**.
- Язык выбирает автозагрузка `Locale` (`scripts/platform/locale.gd`): выбор игрока в настройках → язык Яндекса (`i18n.lang`) → язык браузера → русский. Русский получают `ru, be, kk, uk, uz`, все остальные — английский.
- Переключатель — `LanguageRow` / `LanguageOption` в `scenes/screens/settings.tscn`; выбор сохраняется в `user://settings.cfg`.
- В редакторе игра запускается на русском (или на языке, выбранном в настройках игры). Посмотреть английский: запустите игру, **Настройки → Язык → English**. Вернуть — там же.
- Автотесты всегда стартуют на русском, даже если в игре выбран английский.

## ЯНДЕКС ИГРЫ

- SDK подключён через автозагрузку `YandexGames` (папка `addons/yandex_games`, плагин с нашими исправлениями — см. `PATCHES.md`). Игра общается только с автозагрузкой `Platform` (`scripts/platform/platform.gd`).
- В редакторе и тестах SDK работает в режиме заглушки: реклама «показывается» мгновенно, прогресс хранится локально.
- `LoadingAPI.ready()` вызывается из главного меню после загрузки облачного прогресса. `GameplayAPI.start/stop` — в `scripts/game_screen.gd` (старт уровня, пауза, результат, выход).
- Полноэкранная реклама — по кнопке «Дальше» после победы. Rewarded — «Отменить · реклама» и «Подсказка · реклама».
- Правила рекламы (`scripts/platform/platform.gd`): после rewarded-ролика полноэкранная реклама не показывается 60 секунд (`INTERSTITIAL_GAP_AFTER_REWARDED_SECONDS`); пока открыта одна реклама, вторую не запросить. Если нажать «Отменить» или «Подсказка · реклама», пока фигура в руке (например, вторым пальцем), фигура сначала возвращается в лоток.
- Прогресс сохраняется локально и копируется в облако Яндекса после каждой победы; при запуске облачная и локальная версии объединяются (пройденное не теряется).
- Шаблон страницы — `web/yandex_shell.html`.

### Сборка для Яндекса

1. **Project → Export → Yandex Release**, снимите галочку **Export With Debug**, сохраните в `build/yandex/index.html`.
2. Упакуйте: `.\tools\package_yandex.ps1` → `build\archeoblocks-yandex.zip`.
3. Локальная проверка с SDK (нужен Node.js): `npx @yandex-games/sdk-dev-proxy -p build/yandex --dev-mode=true` и откройте адрес из консоли.
4. В черновике Яндекса включите галочку **Облачные сохранения**.
5. В черновике Яндекса добавьте **английский** в языки игры и заполните английские название, описание и скриншоты. Проверить английскую версию локально: в запущенной сборке **Настройки → Язык → English**; как Яндекс подставляет язык в черновике — см. раздел «Языки и домены» в документации Яндекс Игр.

## ПРОВЕРКА ЭКРАНОВ (СКРИНШОТЫ RU/EN)

- Скрипт `tools/capture_screens.gd` открывает все экраны (меню, настройки, главы, коллекция, обучение, игра, пауза, тупик, победа) на русском и английском и сохраняет PNG.
- Запуск из папки проекта (обычный `Godot_v4.7-stable_win64_console.exe`, не headless):
  `& "C:\godot\Godot_v4.7-stable_win64_console.exe" --path . -s res://tools/capture_screens.gd`
- Другой размер окна: добавьте в конец `-- --size=1280x720` (компьютер) или `-- --size=390x844` (телефон).
- Если экран ноутбука ниже 1280 px, Windows может уменьшить окно — тогда берите `-- --size=540x960` (те же пропорции).
- Картинки — в `build/screens/<размер>/ru` и `.../en`. Папка помечена `.gdignore`, в игру не попадает.
- Строки `LAYOUT:` в консоли — текст, который не помещается (шире кнопки, шире родителя или за краем окна). В конце — `layout problems=0`, если всё в порядке.
- Прогресс для скриншотов пишется во временный файл, ваши сохранения не трогаются.

## ЧЕРНОВИК ЯНДЕКСА

- Тексты для черновика (название, описания, «Как играть», ключевые слова) на русском и английском — в `STORE_LISTING.md`. Длины уже проверены по ограничениям формы.
- Название в черновике должно совпадать с названием в игре: «Археоблоки» / «Archeoblocks».
- Ручная проверка собранной сборки перед загрузкой — раздел «M3.3 manual pass» в `YANDEX_RELEASE_CHECKLIST.md`.
- Тест `filenames` следит, чтобы в именах файлов и папок не было пробелов и русских букв.

## ОФОРМЛЕНИЕ (ART V2A / V2B)

- Картинки, которые грузит игра, лежат в `assets/ui_art/` и сделаны скриптом `python tools/export_runtime_art.py` из больших исходников `assets/art_v2a` и `assets/art_v2b` (они помечены `.gdignore` и в сборку не попадают). Поменяли исходник — запустите скрипт ещё раз.
- Клетки, блоки, камни, корни, маркер находки: `scenes/game/cell_view.tscn`, `stone_obstacle_view.tscn`, `root_obstacle_view.tscn`, `root_growth_warning.tscn`; цвета блоков → картинки: `resources/visuals/block_textures_v2a.tres`.
- Кнопки и панели задаёт тема `theme/archeoblocks_theme.tres`. У кнопки в Inspector есть **Theme Type Variation**:
  - пусто — обычная кнопка из песчаника;
  - `PrimaryButton` — зелёная главная («Играть», «Продолжить», «Дальше», «Понятно»);
  - `SmallButton` — маленькая квадратная («Назад», «Пауза», «Пропустить»);
  - `ChapterCard` / `ChapterCardDone` — карточки глав и экспедиций (Done — пройдено, ставится из кода).
- Панели: по умолчанию `PanelContainer` — большая песчаная панель; `PanelCard` — поменьше (подсказки обучения); `CollectionKnown` / `CollectionUnknown` — карточки коллекции.
- Заголовки экранов используют `HeaderLabel` (шрифт PT Serif). Основной шрифт — PT Sans.
- Рамка поля — `StyleBoardFrame` у `BoardFrame` в `game_screen.tscn`; размер клетки — `custom_minimum_size` корня `cell_view.tscn` (63 px).
- Фон всех экранов — узел `Background` (картинка `assets/ui_art/menu/background.jpg`, в игре затемнён через Modulate). Эмблема меню — узел `Emblem` в `main_menu.tscn`.
- Фон, эмблема, иконка и обложка пока нарисованы кодом: `python tools/draw_menu_art.py` (иконка и обложка — в `build/store/`). Промпты для настоящих картинок — `ART_PROMPTS.md`.

## ФИГУРЫ (ГЕНЕРАЦИЯ)

- Какие фигуры выпадают и как часто — `resources/config/pieces_chapter_1.tres`, `_2`, `_3` (одна на главу). В Inspector: список **Pieces** и рядом **Weights** — чем больше вес, тем чаще фигура; 0 — не выпадает совсем.
- **Max Same Piece** — сколько одинаковых фигур может быть в одной тройке (сейчас 2).
- Если ни одна фигура тройки не влезает на поле, тройка перебрасывается (**Fairness Attempts** раз), потом одна фигура заменяется на **Fallback Piece** (одиночный блок).
- У экспедиции (`resources/expeditions/*.tres`):
  - **Opening Piece Set** — самая первая тройка (для обучения);
  - **Curated Piece Sequence** — заданные вручную тройки после неё, играются один раз;
  - **Piece Generation** — какой конфиг главы брать дальше;
  - **Piece Seed** — 0 = зерно из id экспедиции. Поменяйте число, чтобы получить другую последовательность фигур для этой экспедиции.
- Последовательность одинакова при каждом прохождении и совпадает с тем, что видит подсказка. Отмена хода возвращает те же фигуры.
- Проверить сложность после правок (процент побед бота на каждой экспедиции):
  `Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tools/difficulty_probe.gd -- --runs=40 --policy=player --level=2-7`
  - `--policy=player` — бот-«игрок»: читает цель и заполняет строки и столбцы через находки, избегает тупиков. По нему выставлены цели M4.1. Есть ещё `casual` (без цели), `careful` и `smart`.
  - `--level=2-7,2-8` — только эти экспедиции; `--chapter=2` — вся глава.
  - `--seed-scan=8` — сыграть ту же раскладку с 8 другими зёрнами фигур и показать средний процент. Так видно, насколько трудна сама раскладка, а не одна последовательность фигур.
  - `--seed=15838` — попробовать зерно, не меняя файл. Понравилось — впишите его в **Piece Seed**.
  - `--verbose` — печатает поле и фигуры в каждом проигрыше.
- Цели M4.1 (бот `player`, без отмен и подсказок): Глава I — почти 100%; Глава II — от 100% до ~40% к 2-8; Глава III — от ~85–100% до ~30% к 3-10. Одно зерно может отличаться от среднего по раскладке на ±25%, поэтому после правки раскладки проверяйте `--seed-scan`, а для «неудачного» зерна подберите другое.
- **Expected Moves Min/Max** — середина (от 25% до 75%) числа ходов в выигранных партиях бота `player`. Это ориентир темпа, на игру не влияет.

## БЕСКОНЕЧНЫЕ РАСКОПКИ (M4.2)

- Экран — `scenes/screens/endless_screen.tscn`. Он наследует `game_screen.tscn`: поле, лоток, пауза и окно итога общие. Свои только верхняя панель **EndlessHud** (очки, рекорд, глубина, серия) и скрытые кнопки отмены и подсказки. Если поменять раскладку `game_screen.tscn`, бесконечный экран поменяется вместе с ней.
- Правила — `resources/endless/endless_default.tres` (в Inspector):
  - **Layers** — слои по глубине: название, с какого метра начинается и какие веса фигур брать (**Piece Generation**, те же конфиги глав);
  - **Lines Per Meter** — сколько линий на 1 метр (сейчас 10);
  - **Streak Grace Moves** — сколько ходов можно сделать без линии, пока серия не сгорела (3);
  - **Streak Step** и **Streak Max Multiplier** — рост множителя серии (+0,5 за шаг, максимум ×4);
  - **Board Clear Bonus** — бонус за полностью чистое поле (1000 × множитель серии);
  - **Unlock Expedition Id** — после какой экспедиции открывается кнопка в меню (`expedition_03`).
- Отмены и подсказки в режиме нет. Рекорд очков и глубины хранится в прогрессе и в облаке Яндекса.
- Кнопка **«Бесконечные раскопки»** в главном меню неактивна, пока не пройдена экспедиция 1-3; под ней подпись **EndlessLockHint**.
- Музыка режима: файл `gameplay_endless` в `assets/audio/music/` (если его нет — играет общая `gameplay`).
- «Ещё раз» после конца партии может показать межстраничную рекламу (логическая пауза; не сразу после rewarded). «Начать заново» из паузы — без рекламы.
- Тест режима: `tests/endless_mode_test.gd`.

## РЕСТАВРАЦИЯ НАХОДОК (ПРОТОТИП)

- Экран — `scenes/screens/restoration_screen.tscn`. Открыть и нажать **F6**, либо в debug-сборке кнопка «Реставрация (тест)» в главном меню (в релизе её нет).
- Какую находку чистить — поле **Expedition Definition** у корневого узла (сейчас изумрудный идол). Берётся её обычная картинка `full_artifact_texture`; отдельный «грязный» арт не нужен.
- Как ощущается — в Inspector у корня:
  - **Brush Radius** / **Sponge Radius** — размер кисти и губки (в пикселях маски 256×256);
  - **Brush Strength** / **Sponge Strength** — сколько снимает одно касание (меньше = дольше тереть);
  - цвета пыли **Soil Particle Color** / **Patina Particle Color**.
- Вид грунта и налёта — в материале **ArtifactView** (шейдер `resources/shaders/restoration.gdshader`): цвета **Soil Dark / Soil Light**, оттенок налёта **Patina Tint**.
- Этап засчитывается сам, когда очищено ~90%. «Пропустить» сразу делает находку чистой.
- Отреставрированные находки сохраняются в прогрессе и облаке (раздел `restored_artifacts`).
- Тест: `tests/restoration_test.gd`.
