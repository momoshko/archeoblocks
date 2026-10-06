# Черновик Яндекс Игр: тексты и материалы

Готовые тексты для вкладки «Описание и продвижение» (отдельно для русского и английского)
и полей вкладки «Общее». Длины проверены по ограничениям формы (в скобках — символов).

Правило 5.1.3: название в черновике должно совпадать с названием в самой игре
для каждого языка. В игре: «Археоблоки» (главное меню, `main_menu.tscn`) и
«Archeoblocks» (`translations/en.po`). Если меняете одно — меняйте и другое.

## Общее (для всех языков)

- Платформы: Desktop и Mobile.
- Ориентация на мобильных: **портретная** (игра рассчитана на 720×1280; на компьютере
  поле по центру, по бокам декор).
- Языки: русский, английский.
- Облачные сохранения: **включить**.
- Категории (не больше двух): головоломки; логические (выберите близкие из списка формы).
- Ключевые слова, RU (74/100): `головоломка, блоки, блок пазл, линии, раскопки, археология, артефакты, 8x8`
- Ключевые слова, EN (79/100): `puzzle, block puzzle, blocks, lines, 8x8, dig, archaeology, artifacts, treasure`

## Русский

**Название** (10/50): Археоблоки

**Краткое описание** (68/70):
> Головоломка с блоками: собирайте линии и откапывайте древние находки

**SEO-описание** (135, нужно 50–160):
> Археоблоки — головоломка с блоками на поле 8×8: собирайте линии, снимайте слои грунта и откапывайте древние артефакты в 24 экспедициях.

**Об игре** (658, нужно 100–1000):
> Археоблоки — спокойная головоломка с блоками на поле 8×8, где каждая собранная линия приближает вас к древней находке. Под грунтом спрятаны фрагменты артефактов: золотой маски, каменного оберега, старинной печати и других сокровищ. Ставьте фигуры, собирайте ряды и столбцы — и снимайте слой за слоем, пока находка не покажется целиком.
>
> В игре 24 экспедиции в трёх главах: Древний двор, Разрушенное святилище и Заросшие катакомбы. Вас ждут твёрдый грунт в два слоя, каменные завалы и корни, которые разрастаются после каждого хода. Каждая пройденная экспедиция пополняет коллекцию находок. Подсказка покажет удачный ход, а прогресс сохраняется автоматически.

**Как играть** (572, нужно 100–1000):
> Перетащите одну из трёх фигур снизу на поле. Фигура должна целиком поместиться в свободные клетки, поворачивать фигуры нельзя.
> Заполните ряд или столбец целиком: линия исчезнет и снимет слой грунта с клеток под ней. Твёрдый грунт нужно снять дважды.
> Отмеченные клетки скрывают фрагменты находки. Откопайте все фрагменты — и экспедиция пройдена.
> Новые фигуры появляются, когда поставлены все три. Если ни одна не помещается, отмените последний ход или начните заново.
> «Подсказка» показывает удачный ход. Дополнительные подсказки и отмены можно получить за просмотр рекламы.

## English

**Title** (12/50): Archeoblocks

**Short description** (57/70):
> A block puzzle dig: clear lines and uncover ancient finds

**SEO description** (123, 50–160):
> Archeoblocks is an 8×8 block puzzle: clear lines, remove layers of soil and dig up ancient artifacts across 24 expeditions.

**About the game** (661, 100–1000):
> Archeoblocks is a relaxing 8×8 block puzzle where every cleared line brings you closer to an ancient find. Fragments of artifacts are hidden under the soil: a golden mask, a stone amulet, an old seal and other treasures. Place pieces, complete rows and columns, and remove the soil layer by layer until the whole find is revealed.
>
> The game has 24 expeditions in three chapters: the Ancient Courtyard, the Ruined Shrine and the Overgrown Catacombs. Expect hard soil with two layers, stone rubble, and roots that spread after every move. Each finished expedition adds a find to your collection. A hint shows a good move, and your progress is saved automatically.

**How to play** (552, 100–1000):
> Drag one of the three pieces from the bottom onto the board. A piece must fit entirely into empty cells; pieces cannot be rotated.
> Fill a whole row or column: the line disappears and removes one layer of soil from the cells under it. Hard soil has to be cleared twice.
> Marked cells hide fragments of the find. Dig up every fragment to complete the expedition.
> New pieces appear once all three are placed. If none of them fits, undo your last move or start over.
> The Hint button shows a good move. Extra hints and undos are available for watching an ad.

## Картинки и видео (нужно сделать самому)

- Иконка 512×512 PNG и обложка 800×470 PNG — обязательны. Нельзя просто скриншот.
  Логотипа в игре пока нет: в главном меню на его месте жёлтый прямоугольник.
- Скриншоты: минимум 2 на платформу; мобильные 9:16, для компьютера 16:9, длинная
  сторона 1280–2560 px. На скриншоте должен быть реальный игровой процесс.
  Для каждого языка — свои скриншоты с интерфейсом на этом языке.
- Горизонтальное видео 16:9, MP4, до 28 секунд — обязательно; вертикальное — по желанию.
- Черновые скриншоты всех экранов на обоих языках делает `tools/capture_screens.gd`
  (см. EDITOR_GUIDE_RU.md → «Проверка экранов»). Для витрины лучше снять
  середину партии: несколько собранных линий, частично открытая находка.
