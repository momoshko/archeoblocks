class_name TurnSnapshot
extends RefCounted

var board_state: Array = []
var obstacle_state: Dictionary = {}
var excavation_state: Dictionary = {}
var tray_state: Array[PieceDefinition] = []
var sequence_position := 0
var moves := 0
var score := 0
var root_threat_source := Vector2i(-1, -1)
var root_threat_cell := Vector2i(-1, -1)
var transient_counters: Dictionary = {}
