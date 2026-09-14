class_name HelpConfig
extends Resource

@export_range(0, 5, 1) var free_undos := 1
@export_range(0, 5, 1) var rewarded_undos := 1
@export_range(0, 5, 1) var free_hints := 1
@export_range(0, 5, 1) var rewarded_hints := 2
@export_range(1.0, 30.0, 0.5) var idle_hint_seconds := 8.0
@export_range(0.5, 5.0, 0.1) var hint_display_seconds := 2.0
@export var debug_unlimited_hints := false

@export_category("Hint Heuristic")
@export_range(0, 2000000, 1000) var hint_expedition_victory_bonus := 1000000
@export_range(0, 100000, 1000) var hint_fragment_completed_weight := 50000
@export_range(0, 20000, 100) var hint_artifact_excavation_weight := 5000
@export_range(0, 5000, 50) var hint_artifact_cell_weight := 500
@export_range(0, 5000, 10) var hint_excavation_weight := 150
@export_range(0, 5000, 50) var hint_obstacle_damage_weight := 400
@export_range(0, 10000, 100) var hint_obstacle_destroyed_weight := 1200
@export_range(0, 5000, 50) var hint_root_damage_weight := 500
@export_range(0, 10000, 100) var hint_root_destroyed_weight := 1600
@export_range(0, 5000, 50) var hint_root_growth_prevented_weight := 700
@export_range(0, 10000, 100) var hint_root_new_growth_penalty := 1800
@export_range(0, 20000, 100) var hint_blocked_piece_penalty := 6000
@export_range(0, 50, 1) var hint_remaining_placement_weight := 3
@export_range(0, 1000, 10) var hint_line_weight := 100
@export_range(0, 20, 1) var hint_free_cell_weight := 1

@export_category("Hint Planner")
@export_range(3, 8, 1) var hint_planning_depth := 5
@export_range(4, 64, 1) var hint_beam_width := 12
@export_range(1, 100, 1) var hint_leaf_legal_placement_weight := 8
@export_range(1, 500, 1) var hint_leaf_connected_region_weight := 18
@export_range(1, 1000, 10) var hint_leaf_large_piece_space_weight := 120
@export_range(1, 10000, 50) var hint_leaf_artifact_depth_weight := 800
