extends SceneTree

# Restoration prototype: soil -> patina -> shine -> done, auto-finish at ~90 %,
# Skip, the restored flag in the save and in the cloud format.

const TEST_PROGRESS_PATH := "res://tests/.restoration_progress.cfg"
const SCENE := "res://scenes/screens/restoration_screen.tscn"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	ProgressStore.storage_path = ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	ProgressStore.changed_hook = Callable()
	DirAccess.remove_absolute(ProgressStore.storage_path)

	# A: the full path of a find with every stage (emerald idol: soil ->
	# shards -> crust -> patina -> shine -> done).
	var screen := await _open()
	var S := RestorationScreen.Stage
	_expect(screen.stages == [S.SOIL, S.SHARDS, S.CRUST, S.PATINA], "A: the idol has all four stages (%s)" % [screen.stages])
	_expect(screen.stage == S.SOIL, "A: starts with the soil")
	_expect(screen.get_progress() == 0.0, "A: nothing is clean at the start")
	_expect(screen.artifact_view.texture != null, "A: the find's artwork is shown")
	screen.rub_uv_line(Vector2(0.45, 0.45), Vector2(0.55, 0.45))
	_expect(screen.get_progress() > 0.0 and screen.get_progress() < 0.5, "A: a short stroke cleans a little (%.2f)" % screen.get_progress())
	_expect(screen.stage == S.SOIL, "A: one stroke does not finish the stage")
	await _rub_everything(screen)
	_expect(screen.stage == S.SHARDS, "A: under the soil the find is broken")
	_expect(screen.shard_count() == 5, "A: five shards (%d)" % screen.shard_count())
	await create_timer(0.7).timeout
	var scattered := true
	for index in screen.shard_count():
		scattered = scattered and screen.shard_offset(index).length() > RestorationScreen.SNAP_DISTANCE
	_expect(scattered, "A: the shards fly apart from their places")
	_expect(not screen.drop_shard(0, Vector2(0.3, 0.0)), "A: a shard dropped far away does not snap")
	_expect(screen.drop_shard(0, Vector2(0.02, -0.03)), "A: a shard dropped near its place snaps in")
	_expect(screen.is_shard_placed(0) and screen.get_progress() > 0.15, "A: the progress counts placed shards")
	for index in range(1, 5):
		screen.drop_shard(index, Vector2.ZERO)
	await create_timer(1.3).timeout
	_expect(screen.stage == S.CRUST, "A: all shards glued -> the crust")
	_expect(screen.scalpel_icon.visible and not screen.brush_icon.visible, "A: the scalpel is shown for the crust")
	# One stroke over every spot (rows a scalpel width apart) does not chip it off.
	for y in range(0, 257, 26):
		screen.rub_uv_line(Vector2(0.0, y / 256.0), Vector2(1.0, y / 256.0))
	await create_timer(0.8).timeout
	_expect(screen.stage == S.CRUST and screen.get_progress() < 0.9, "A: one stroke per spot is not enough for the hard crust (%.2f)" % screen.get_progress())
	await _rub_everything(screen, 3)
	_expect(screen.stage == S.PATINA, "A: crust -> patina")
	await _rub_everything(screen)
	await create_timer(1.5).timeout
	_expect(screen.stage == S.DONE, "A: patina -> shine -> done")
	_expect(screen.done_button.visible and not screen.skip_button.visible, "A: Done replaces Skip at the end")
	_expect(screen.info_card.visible and screen.info_title.text == screen.expedition_definition.artifact_name_ru, "A: the card names the find")
	_expect(ProgressStore.is_artifact_restored(&"emerald_idol"), "A: the restored find is saved")
	await _close(screen)

	# A2: the first find stays simple: soil and patina only.
	RestorationScreen.pending_expedition = load("res://resources/expeditions/expedition_01.tres") as ExpeditionDefinition
	screen = await _open()
	_expect(screen.stages == [S.SOIL, S.PATINA], "A2: the first find has two stages")
	_expect(screen.stage == S.SOIL and screen.shard_count() == 0, "A2: no shards, starts with the brush")
	await _rub_everything(screen)
	_expect(screen.stage == S.PATINA, "A2: soil -> patina (no crust)")
	await _close(screen)

	# B: Skip finishes at once.
	DirAccess.remove_absolute(ProgressStore.storage_path)
	screen = await _open()
	var finished := [false]
	screen.restoration_finished.connect(func(_id: StringName) -> void: finished[0] = true)
	screen.skip_button.pressed.emit()
	await process_frame
	_expect(screen.stage == RestorationScreen.Stage.DONE and finished[0], "B: Skip goes straight to the end")
	_expect(ProgressStore.is_artifact_restored(&"emerald_idol"), "B: Skip also saves the find as restored")
	await _close(screen)

	# C: another find can be passed in by the caller.
	var seal := load("res://resources/expeditions/ruined_shrine_03.tres") as ExpeditionDefinition
	RestorationScreen.pending_expedition = seal
	screen = await _open()
	_expect(screen.expedition_definition == seal and screen.artifact_name.text == seal.artifact_name_ru, "C: pending_expedition picks the find")
	_expect(RestorationScreen.pending_expedition == null, "C: pending_expedition is used once")
	await _close(screen)

	# D: save format.
	var state := ProgressStore.export_state()
	_expect(state.has("restored_artifacts") and bool(state.restored_artifacts.get("emerald_idol", false)), "D: restored finds go to the cloud save")
	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.merge_state({"restored_artifacts": {"golden_mask": true}})
	_expect(ProgressStore.is_artifact_restored(&"golden_mask"), "D: merge brings restored finds from the cloud")
	_expect(not ProgressStore.is_artifact_restored(&"bronze_key"), "D: other finds stay dirty")

	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("RESTORATION_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _open() -> RestorationScreen:
	var screen := (load(SCENE) as PackedScene).instantiate() as RestorationScreen
	root.add_child(screen)
	await process_frame
	await process_frame
	return screen


func _close(screen: Node) -> void:
	root.remove_child(screen)
	screen.queue_free()
	await process_frame


## Rubs the whole square twice, then waits for the auto-finish tween.
func _rub_everything(screen: RestorationScreen, passes: int = 2) -> void:
	for pass_index in passes:
		for y in range(0, 257, 10):
			screen.rub_uv_line(Vector2(0.0, y / 256.0), Vector2(1.0, y / 256.0))
			if screen.stage == RestorationScreen.Stage.CRUST:
				# The scalpel is thin: half-way rows too.
				screen.rub_uv_line(Vector2(0.0, (y + 5) / 256.0), Vector2(1.0, (y + 5) / 256.0))
		await process_frame
	await create_timer(0.8).timeout
