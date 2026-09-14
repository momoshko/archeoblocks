class_name HelpState
extends RefCounted

signal changed

var free_undos_remaining := 0
var rewarded_undos_remaining := 0
var free_hints_remaining := 0
var rewarded_hints_remaining := 0


func reset(config: HelpConfig) -> void:
	free_undos_remaining = config.free_undos
	rewarded_undos_remaining = config.rewarded_undos
	free_hints_remaining = config.free_hints
	rewarded_hints_remaining = config.rewarded_hints
	changed.emit()


func consume_free_undo() -> bool:
	if free_undos_remaining <= 0:
		return false
	free_undos_remaining -= 1
	changed.emit()
	return true


func consume_rewarded_undo() -> bool:
	if rewarded_undos_remaining <= 0:
		return false
	rewarded_undos_remaining -= 1
	changed.emit()
	return true


func consume_free_hint() -> bool:
	if free_hints_remaining <= 0:
		return false
	free_hints_remaining -= 1
	changed.emit()
	return true


func consume_rewarded_hint() -> bool:
	if rewarded_hints_remaining <= 0:
		return false
	rewarded_hints_remaining -= 1
	changed.emit()
	return true


func capture_state() -> Dictionary:
	return {
		"free_undos_remaining": free_undos_remaining,
		"rewarded_undos_remaining": rewarded_undos_remaining,
		"free_hints_remaining": free_hints_remaining,
		"rewarded_hints_remaining": rewarded_hints_remaining,
	}


func restore_state(state: Dictionary) -> void:
	free_undos_remaining = state.get("free_undos_remaining", 0)
	rewarded_undos_remaining = state.get("rewarded_undos_remaining", 0)
	free_hints_remaining = state.get("free_hints_remaining", 0)
	rewarded_hints_remaining = state.get("rewarded_hints_remaining", 0)
	changed.emit()
