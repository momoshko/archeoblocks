extends Node

## Game language (autoload `Locale`).
##
## Russian texts in scenes, scripts and resources are the source text.
## The English translation lives in `translations/en.po`: each `msgid` is the
## exact Russian text, `msgstr` is its English version. Labels and Buttons
## translate their text automatically; scripts wrap strings in `tr()`.
##
## Choice order: the player's choice in Settings → Yandex interface language
## (i18n.lang) → browser language (web only) → Russian.

signal language_changed(code: String)

const RUSSIAN := "ru"
const ENGLISH := "en"
const SUPPORTED: Array[String] = [RUSSIAN, ENGLISH]
## Yandex Games / browser languages that get the Russian version.
const RUSSIAN_SPEAKING: Array[String] = ["ru", "be", "kk", "uk", "uz"]

var _platform_language := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless runs (automated tests) always start in Russian, whatever was
	# chosen while playing in the editor.
	var saved := "" if _is_headless() else SettingsStore.get_language()
	_apply(resolve(saved, "", _system_language()))


## Current game language: "ru" or "en".
func current() -> String:
	return RUSSIAN if TranslationServer.get_locale().begins_with(RUSSIAN) else ENGLISH


## Player's explicit choice from Settings. Saved and wins over auto-detection.
func set_language(code: String) -> void:
	var normalized := code if SUPPORTED.has(code) else normalize(code)
	SettingsStore.set_language(normalized)
	_apply(normalized)


## Called by Platform after the Yandex SDK started.
func apply_platform_language(lang: String) -> void:
	_platform_language = lang
	_apply(resolve(SettingsStore.get_language(), _platform_language, _system_language()))


## Pure choice rule (tested): saved choice, then platform, then system language.
static func resolve(saved: String, platform_language: String, system_language: String) -> String:
	if SUPPORTED.has(saved):
		return saved
	if not platform_language.is_empty():
		return normalize(platform_language)
	if not system_language.is_empty():
		return normalize(system_language)
	return RUSSIAN


## "ru", "ru-RU", "be" → "ru"; any other language → "en".
static func normalize(code: String) -> String:
	var base := code.strip_edges().to_lower().replace("_", "-").get_slice("-", 0)
	if base.is_empty() or RUSSIAN_SPEAKING.has(base):
		return RUSSIAN
	return ENGLISH


func _apply(code: String) -> void:
	var changed := TranslationServer.get_locale() != code
	TranslationServer.set_locale(code)
	if changed:
		language_changed.emit(code)


func _system_language() -> String:
	# Desktop/editor runs stay Russian; on the web the browser language is used
	# until the Yandex SDK reports its own.
	if _is_headless() or not OS.has_feature("web"):
		return ""
	return OS.get_locale_language()


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
