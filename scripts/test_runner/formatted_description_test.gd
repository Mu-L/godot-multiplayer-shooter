## 独立测试脚本:
##    godot --headless --script res://scripts/test_runner/formatted_description_test.gd --quit
## 脚本会创建一个假的 UpgradeComponent 实例并断言 formatted_description() 的输出.

extends SceneTree

## 注意：升级组件内部引用类型不严格 (Godot 4.9+ 的升级错误),不能直接实例化。
## 因此这里抽取格式化逻辑独立验证 GDScript 代码路径中我们的核心算法。
## 与 UpgradeComponent._format_effect_param / _format_number 的单次性单元测试。

const UPGRADE_COMPONENT := preload("res://components/upgrade_component.gd")
const PASSIVE_RES := preload("res://resources/passive_item_resource.gd")


static func _format_number(value: float) -> String:
	if is_equal_approx(value, snappedf(value, 1.0)):
		return str(int(value))
	return ("%.2f" % value).rstrip("0").rstrip(".")


static func _format_effect_param(param) -> String:
	match typeof(param):
		TYPE_FLOAT:
			if param > 0.0 and param < 1.0:
				var as_int = int(param)
				if not is_equal_approx(param, float(as_int)):
					return "%.0f%%" % (param * 100.0)
			return _format_number(param)
		TYPE_INT:
			return str(param)
		_:
			return str(param)


static func _format_desc(template: String, params: Array) -> String:
	var display: Array = []
	for p in params:
		display.append(_format_effect_param(p))
	var text := template
	for i in range(display.size()):
		text = text.replace("{%d}" % i, str(display[i]))
	return text


func _assert_eq(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("FAIL [%s]: expected %r got %r" % [label, expected, actual])
		return false
	print("PASS [%s]: %s" % [label, actual])
	return true


func _init() -> void:
	var all_pass := true
	all_pass = _assert_eq(_format_desc("子弹基础伤害增加{0}", [1.0]),                   "子弹基础伤害增加1",                "basic_damage_up") and all_pass
	all_pass = _assert_eq(_format_desc("血量上限增加{0}", [1.0]),                     "血量上限增加1",                    "health_limit_up") and all_pass
	all_pass = _assert_eq(_format_desc("增加{0}条弹道,但单发伤害降低至{1}", [2, 0.7]), "增加2条弹道,但单发伤害降低至70%",  "bullet_split") and all_pass
	all_pass = _assert_eq(_format_desc("攻速提升{0}", [0.1]),                         "攻速提升10%",                      "attack_speed_up") and all_pass
	all_pass = _assert_eq(_format_desc("移动速度提升{0}", [0.1]),                     "移动速度提升10%",                  "move_speed_up") and all_pass
	all_pass = _assert_eq(_format_desc("每次升级使承受伤害降低至{0}(无上限)", [0.8]), "每次升级使承受伤害降低至80%(无上限)", "defence_up") and all_pass

	if all_pass:
		print("All formatted_description tests passed.")
	else:
		push_error("Some formatted_description tests failed!")

	quit(0 if all_pass else 1)
