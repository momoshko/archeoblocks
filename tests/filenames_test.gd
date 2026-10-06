extends SceneTree

# Yandex rule 1.22: no spaces or Cyrillic in file and folder names of the build.
# Every folder the game can ship from (no .gdignore, not hidden) must use only
# Latin letters, digits, "_", "-" and ".".

const ALLOWED := "^[A-Za-z0-9_.\\-]+$"

var _failures: Array[String] = []
var _checks := 0
var _pattern := RegEx.create_from_string(ALLOWED)


func _init() -> void:
	_scan("res://")
	if _failures.is_empty():
		print("FILENAMES_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _scan(path: String) -> void:
	if FileAccess.file_exists(path.path_join(".gdignore")):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = false
	for file_name in dir.get_files():
		_check(path, file_name)
	for folder in dir.get_directories():
		if folder.begins_with("."):
			continue
		_check(path, folder)
		_scan(path.path_join(folder))


func _check(path: String, file_name: String) -> void:
	_checks += 1
	if _pattern.search(file_name) == null:
		_failures.append("Not ASCII-safe: %s" % path.path_join(file_name))
