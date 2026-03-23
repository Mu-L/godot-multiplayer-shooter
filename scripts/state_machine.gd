class_name StateMachine
extends Node

signal state_changed(old: String, new: String)

# 当前状态, 空字符串表示没有状态
var _current_state: String = String()
var current_state: String:
	get:
		return _current_state
	set(value):
		if value != _current_state:
			_state_transition.call_deferred(value)

var states: Dictionary[String,State] = {}


func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_state_transition)


func _process(_delta: float) -> void:
	if current_state:
		states[current_state].update()


func _state_transition(next: String) -> void:
	if next not in states:
		push_warning("Transition to a non-exists state: %s" % next)
		return
	if current_state == next:
		push_warning("Transition to a same state: %s" % next)
		return
	if current_state in states:
		states[current_state].exit()
	var old_state = _current_state
	_current_state = next
	states[current_state].enter()
	state_changed.emit(old_state, current_state)


func _on_state_transition(next: String) -> void:
	current_state = next
