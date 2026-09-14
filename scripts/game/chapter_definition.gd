class_name ChapterDefinition
extends Resource

@export var id: StringName
@export var number_ru := "Глава I"
@export var title_ru: String
@export var subtitle_ru: String
@export var completion_title_ru: String
@export var expeditions: Array[ExpeditionDefinition] = []
@export_range(0, 10000, 1) var completion_reward_coins := 0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("chapter id must not be empty")
	if expeditions.is_empty():
		errors.append("chapter must contain at least one expedition")
	var ids: Dictionary = {}
	for expedition in expeditions:
		if expedition == null:
			errors.append("chapter contains a null expedition")
			continue
		if ids.has(expedition.id):
			errors.append("duplicate chapter expedition id: %s" % expedition.id)
		ids[expedition.id] = true
	return errors


func expedition_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for expedition in expeditions:
		if expedition != null:
			result.append(expedition.id)
	return result


func is_finale(expedition_id: StringName) -> bool:
	return not expeditions.is_empty() and expeditions[-1] != null and expeditions[-1].id == expedition_id
