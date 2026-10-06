# Archeoblocks · ART V1

**Выбранное направление:** светлый песчаниковый двор, цветные минералы, спокойная земля, локальное золото целей.

## Смотреть

- [Review gallery](index.html) — два master screens, размеры 360/390/430/720, grayscale и baseline. Можно открыть локально в браузере; Интернет не нужен.
- [Master menu](master_menu.png)
- [Master gameplay](master_gameplay.png)
- [Практический style guide](STYLE_GUIDE.md)
- [План следующих asset milestones](PRODUCTION_ROADMAP.md)
- [Art review, проверки и полный список файлов](REVIEW.md)

Основа игрового референса: Chapter III / 3–5, девять реальных ходов, 290 очков, 0/3 фрагментов. [Точное состояние и история](gameplay_state.json). Подсказка квадратом внизу справа допустима по текущей модели игры.

Созданы два выбранных изображения через встроенный ImageGen, всего три вызова с одной адресной правкой. [Полный prompt set](prompts.json). Никаких новых production batches. Папка исключена из Godot импортирования через `.gdignore`.

## Повторить проверки

`validate_review.py` читает изображения и данные, проверяет геометрию состояния и локальные ссылки, затем обновляет `validation.json`. Нужны Python и Pillow; библиотека доступна в bundled runtime текущего окружения.

Для повторного снятия baseline использовать установленный Godot 4.7 в корне проекта:

```text
godot --path . --script art_review/art_v1/capture_reference.gd
```

Это запускает текущие сцены и заменяет только ART V1 baseline screenshots, state JSON и явно заданный log. `--headless` подходит для данных, но не обновляет изображения. Utility разрешён только в debug build и не добавлен в сцены, resources или export. Оконный capture здесь выполнен скрытым процессом.

## Граница milestone

Рисунки служат художественными reference screens. В production должны использоваться отдельные текстуры, theme resources и настоящие UI nodes; текст из PNG не вырезается. Сцены, gameplay и Web export не изменены. Следующий этап: клеточные состояния и минералы, затем obstacles/marker/hint, затем рамка и UI family.
