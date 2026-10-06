extends SceneTree

## English translation and language auto-detection (M3.2).

const TEST_SETTINGS_PATH := "res://tests/.locale_settings.cfg"
const CHAPTERS := [
	"res://resources/chapters/ancient_courtyard.tres",
	"res://resources/chapters/ruined_shrine.tres",
	"res://resources/chapters/overgrown_catacombs.tres",
]
const PIECES_DIR := "res://resources/pieces"
## Texts from the main screens that must never stay Russian in English.
const UI_TEXTS := [
	"Играть", "Продолжить", "Экспедиции", "Коллекция", "Настройки", "Назад",
	"Пауза", "Начать заново", "В меню", "Отменить", "Подсказка", "Повторить", "Дальше",
	"ЭКСПЕДИЦИЯ ЗАВЕРШЕНА!", "РАСКОПКИ ЗАШЛИ В ТУПИК", "Неизвестная находка",
	"Раскопайте все фрагменты артефакта", "Собирайте строки и столбцы, чтобы снимать грунт",
	"Бесконечные раскопки", "Собирайте линии подряд: серия умножает очки", "Очки",
	"Откроется после экспедиции «Древний двор 3»", "РАСКОПКИ ЗАВЕРШЕНЫ", "Ещё раз",
	"Верхний слой", "Глина", "Катакомбы", "Серия: соберите линию", "Новый рекорд!",
	"Реставрация", "Кисть: снимите грунт", "Губка: сотрите налёт", "Пропустить", "Готово",
]

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	SettingsStore.storage_path = ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	DirAccess.remove_absolute(SettingsStore.storage_path)
	var locale := root.get_node("Locale")

	# Headless runs start in Russian; Russian texts are the source.
	_expect(locale.current() == "ru", "Tests start in Russian")
	_expect(TranslationServer.translate("Играть") == "Играть", "Russian text is shown as is")

	# Detection rule: saved choice > Yandex language > browser language > Russian.
	_expect(locale.normalize("ru-RU") == "ru" and locale.normalize("be") == "ru", "Russian-speaking codes map to Russian")
	_expect(locale.normalize("kk") == "ru" and locale.normalize("uz_UZ") == "ru", "CIS codes map to Russian")
	_expect(locale.normalize("en-US") == "en" and locale.normalize("tr") == "en", "Other languages map to English")
	_expect(locale.normalize("") == "ru", "Unknown language falls back to Russian")
	_expect(locale.resolve("", "en", "ru") == "en", "Yandex language wins over the browser")
	_expect(locale.resolve("", "", "de-DE") == "en", "Browser language is used without the SDK")
	_expect(locale.resolve("", "", "") == "ru", "No information means Russian")
	_expect(locale.resolve("ru", "en", "en") == "ru", "Player's choice wins over detection")
	_expect(locale.resolve("xx", "tr", "") == "en", "A broken saved value is ignored")

	# Yandex reports English: the game switches unless the player chose otherwise.
	locale.apply_platform_language("en")
	_expect(locale.current() == "en", "Yandex 'en' switches the game to English")
	_expect(tr("Играть") == "Play", "English text comes from translations/en.po")
	_expect(tr("Счёт: %d") % 5 == "Score: 5", "Formatted texts keep their numbers")
	for text in UI_TEXTS:
		_expect(tr(text) != text, "UI text has English: %s" % text)
	for chapter_path in CHAPTERS:
		_check_chapter(load(chapter_path) as ChapterDefinition)
	for file_name in DirAccess.get_files_at(PIECES_DIR):
		if file_name.ends_with(".tres"):
			var piece := load(PIECES_DIR.path_join(file_name)) as PieceDefinition
			_expect(tr(piece.display_name) != piece.display_name, "Piece name has English: %s" % piece.display_name)

	# Settings: choosing Russian is saved and beats the Yandex language.
	var settings := load("res://scenes/screens/settings.tscn").instantiate() as Control
	root.add_child(settings)
	await process_frame
	var option := settings.get_node("%LanguageOption") as OptionButton
	_expect(settings.get_node("%LanguageRow").visible, "Language row is visible")
	_expect(option.selected == 1, "Settings show English as the current language")
	option.select(0)
	option.item_selected.emit(0)
	_expect(locale.current() == "ru" and SettingsStore.get_language() == "ru", "Choosing Russian applies and saves it")
	(settings.get_node("%MusicSlider") as HSlider).value = 0.0
	_expect((settings.get_node("%MusicValue") as Label).text == "Выкл.", "Code-set texts refresh on language change")
	locale.apply_platform_language("en")
	_expect(locale.current() == "ru", "Saved choice is kept after the SDK reports another language")
	option.select(1)
	option.item_selected.emit(1)
	_expect(locale.current() == "en" and SettingsStore.get_language() == "en", "Choosing English applies and saves it")
	_expect((settings.get_node("%MusicValue") as Label).text == "Off", "Music value reads Off in English")
	settings.queue_free()
	await process_frame

	TranslationServer.set_locale("ru")
	DirAccess.remove_absolute(SettingsStore.storage_path)
	SettingsStore.storage_path = SettingsStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("LOCALE_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check_chapter(chapter: ChapterDefinition) -> void:
	for text in [chapter.number_ru, chapter.title_ru, chapter.subtitle_ru, chapter.completion_title_ru]:
		if not text.is_empty():
			_expect(tr(text) != text, "Chapter text has English: %s" % text)
	for expedition in chapter.expeditions:
		for text in [
			expedition.title_ru,
			expedition.card_title_ru,
			expedition.artifact_name_ru,
			expedition.objective_ru,
			expedition.instruction_ru,
		]:
			_expect(tr(text) != text, "Expedition text has English: %s" % text)
