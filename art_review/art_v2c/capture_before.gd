extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	ProgressStore.storage_path = "res://art_review/art_v2c/qa_progress.cfg"
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i(720, 1280)
	for pair in [["main_menu", "before_menu.png"], ["game_screen_ch3_05", "before_gameplay.png"]]:
		var scene := load("res://scenes/screens/%s.tscn" % pair[0]).instantiate()
		root.add_child(scene)
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("res://art_review/art_v2c/%s" % pair[1])
		print("CAPTURED ", pair[1], " ", image.get_size())
		scene.queue_free()
		await process_frame
	quit()
