extends SceneTree

# Offline ART V1 evidence only. Never referenced by a production scene.
const OUT := "res://art_review/art_v1/"
var history: Array = []

func _init() -> void:
	call_deferred("run")

func screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + filename)

func run() -> void:
	if not OS.is_debug_build():
		quit(1)
		return
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(720, 1280)
	var menu: Control = load("res://scenes/screens/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await screenshot("baseline_menu.png")
	root.remove_child(menu)
	menu.queue_free()
	var game: Control = load("res://scenes/screens/game_screen_ch3_05.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var session: GameSession = game.get_node("GameSession")
	Engine.time_scale = 8.0
	for turn in 9:
		var hint: Dictionary = session.find_best_hint()
		if hint.is_empty():
			quit(2)
			return
		history.append({"slot": hint.slot_index, "origin": [hint.origin.x, hint.origin.y]})
		if not session.try_place_piece(hint.slot_index, hint.origin):
			quit(3)
			return
		while session._busy:
			await process_frame
		await process_frame
	Engine.time_scale = 1.0
	var hint: Dictionary = session.find_best_hint()
	var cells: Array = []
	for y in 8:
		for x in 8:
			var cell := Vector2i(x,y)
			var value: Variant = session.board_model.get_value(cell)
			cells.append({"x": x, "y": y, "soil": session.excavation_model.get_soil_depth(cell), "block": value.to_html(false) if value is Color else "", "obstacle": session.obstacle_model.get_kind(cell), "durability": session.obstacle_model.get_durability(cell), "artifact": str(session.excavation_model.get_artifact_fragment_id(cell))})
	var tray: Array = []
	for i in 3:
		var piece := session.piece_tray.get_definition(i)
		var offsets: Array = []
		if piece != null:
			for cell in piece.cells:
				offsets.append([cell.x, cell.y])
		tray.append({"id": str(piece.id) if piece != null else "", "cells": offsets, "color": piece.cosmetic_color.to_html(false) if piece != null else ""})
	var hint_cells: Array = []
	for cell in hint.get("cells", []):
		hint_cells.append([cell.x, cell.y])
	var threat := session.get_root_threat_cell()
	var data := {"scene": "scenes/screens/game_screen_ch3_05.tscn", "moves": session.moves, "score": session.score, "fragments": session.excavation_model.collected_fragment_count(), "fragment_total": session.excavation_model.fragment_count(), "history": history, "cells": cells, "tray": tray, "hint_slot": hint.get("slot_index", -1), "hint_cells": hint_cells, "root_threat": [threat.x, threat.y]}
	var file := FileAccess.open(OUT + "gameplay_state.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	session._clear_hint_feedback()
	await screenshot("baseline_gameplay.png")
	session._show_hint(hint)
	await screenshot("baseline_gameplay_hint.png")
	print("ART_V1_CAPTURE_OK moves=", session.moves, " score=", session.score)
	quit()
