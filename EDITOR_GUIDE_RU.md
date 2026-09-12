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
- Внешний вид клетки: scenes/game/cell_view.tscn.
- Размер и расположение поля: scenes/game/board_view.tscn или BoardFrame/Board внутри игрового экрана.
- Внешний вид слота: scenes/game/piece_slot.tscn.
- Расстояние между слотами: узел PieceTray в scenes/game/piece_tray.tscn, свойство **Theme Overrides → Constants → Separation**.
- Цвета valid/invalid preview находятся в ValidPreview и InvalidPreview сцены клетки; цвет плавающего invalid preview — в Inspector сцены drag_piece_preview.tscn.
