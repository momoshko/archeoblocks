class_name ScoreConfig
extends Resource

@export_range(0, 1000, 1) var successful_placement := 10
@export var simultaneous_line_scores: Array[int] = [100, 250, 450, 700]
@export_range(0, 1000, 1) var extra_line_score := 300
@export_range(0, 1000, 1) var excavation_hit := 10
@export_range(0, 5000, 1) var new_fragment := 200
@export_range(0, 10000, 1) var complete_artifact := 500


func score_for_lines(line_count: int) -> int:
	if line_count <= 0:
		return 0
	if line_count <= simultaneous_line_scores.size():
		return simultaneous_line_scores[line_count - 1]
	var base: int = simultaneous_line_scores.back() if not simultaneous_line_scores.is_empty() else 0
	return base + (line_count - simultaneous_line_scores.size()) * extra_line_score
