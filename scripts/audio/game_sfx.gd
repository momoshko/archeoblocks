extends Node

## Turns GameSession feedback events into sound effects.
## Lives in the game screen so gameplay code never talks to audio directly.

@export var game_session_path: NodePath


func _ready() -> void:
	var session := get_node_or_null(game_session_path) as GameSession
	if session == null:
		push_error("GameSfx requires a GameSession")
		return
	session.feedback_event.connect(_on_feedback_event)


func _on_feedback_event(kind: StringName, strength: int) -> void:
	match kind:
		&"line_clear":
			AudioManager.play_sfx(&"line_clear_multi" if strength >= 2 else &"line_clear")
		&"dig":
			AudioManager.play_sfx(&"dig", randf_range(0.92, 1.08))
		&"place":
			AudioManager.play_sfx(&"place", randf_range(0.95, 1.05))
		# Endless Excavation: the streak chime climbs with every step.
		&"streak":
			var streak_sound := &"streak" if AudioManager.has_sfx(&"streak") else &"line_clear_multi"
			AudioManager.play_sfx(streak_sound, minf(1.45, 1.0 + 0.06 * strength))
		&"board_clear":
			AudioManager.play_sfx(&"fragment_found")
		&"depth":
			AudioManager.play_sfx(&"dig", 0.8)
		&"record":
			AudioManager.play_sfx(&"victory")
		_:
			AudioManager.play_sfx(kind)
