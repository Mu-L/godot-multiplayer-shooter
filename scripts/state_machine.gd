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

## 在 owner 子节点尚未全部进 tree 时 (客户端 spawn 同步阶段), 暂存 pending 的首次 enter 目标;
## 等所有 State 节点都进入 tree 后再真正触发 enter() — 避免 is_multiplayer_authority() 报错
var _pending_first_state: String = ""


func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_state_transition)


func _process(_delta: float) -> void:
	# 若之前有暂存的状态转换, 检查所有 State 节点是否都已进 tree
	if _pending_first_state != "":
		var all_in_tree := true
		for state_name in states:
			if not states[state_name].is_inside_tree():
				all_in_tree = false
				break
		if all_in_tree:
			var pending: String = _pending_first_state
			_pending_first_state = ""
			_state_transition(pending)
		return
	if current_state:
		states[current_state].update()


func _state_transition(next: String) -> void:
	if next not in states:
		push_warning("Transition to a non-exists state: %s" % next)
		return
	# (fix bug3) 切换首个状态时, 若 State 节点尚未全部进入 tree, 先暂存;
	# 避免在 enter() 内调用 is_multiplayer_authority() 报 "!is_inside_tree()" 错误
	if _current_state == "" and not _all_states_in_tree():
		_pending_first_state = next
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


func _all_states_in_tree() -> bool:
	for state_name in states:
		if not states[state_name].is_inside_tree():
			return false
	return true


func _on_state_transition(next: String) -> void:
	current_state = next
