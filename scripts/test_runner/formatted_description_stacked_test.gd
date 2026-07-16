## 独立测试脚本: 验证 UpgradeComponent.formatted_description_stacked() 六种 case 与边界行为.
##    godot --headless --script res://scripts/test_runner/formatted_description_stacked_test.gd --quit
##
## 设计说明:
## - UpgradeComponent 的静态函数直接调用 TranslationServer.translate(). 我们把英文 .mo 预先加载到 TranslationServer,
##   并确保 instance == null, 这样 TranslationServer.translate() 就能稳定返回英文模板.
## - 用 ClassDB.instantiate 直接造"空壳"实例(不进 scene tree). 测试函数内部不再依赖 _ready()/is_multiplayer_authority 等.
## - 每个道具配独立的翻译模板 (PASSIVE_STACKED_*), 数值由对应 case 语义算出后 % int 注入,
##   因此本测试直接断言"模板 + 该语义数值"的最终字符串, 不依赖格式化 token 类型推断.

extends SceneTree

const UPGRADE_COMPONENT := preload("res://components/upgrade_component.gd")
const PASSIVE_RES := preload("res://resources/passive_item_resource.gd")


# Build a stub resource.  Kept as a bare Node-less object by manually constructing the resource row.
func _make_res(id: String, params: Array) -> PassiveItemResource:
	var r := PASSIVE_RES.new()
	r.id = id
	r.effect_params = params
	return r


func _assert_eq(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("FAIL [%s]: expected %r got %r" % [label, expected, actual])
		return false
	print("PASS [%s]: %s" % [label, actual])
	return true


func _init() -> void:
	# Make sure no stale instance from a previous UpgradeComponent._ready().
	# (Not normally an issue in headless, but defensive.)
	# Load English .mo so TranslationServer.translate() can return English templates.
	var en_translation: Translation = load("res://translate/en_us.mo")
	if en_translation:
		TranslationServer.add_translation(en_translation)
	TranslationServer.set_locale("en_us")

	# Critical: mark static "instance" as invalid by never calling _ready(); this forces the TranslationServer path.
	# Verify the key exists.
	var probe := TranslationServer.translate("PASSIVE_STACKED_BASIC_DAMAGE_UP")
	if probe.is_empty():
		push_error("English translation for PASSIVE_STACKED_BASIC_DAMAGE_UP not found; make sure res://translate/en_us.mo was recompiled after .po edits.")
		quit(1)
		return

	# Stub (no scene tree) so the test runs in headless.
	# We deliberately do NOT assign it to UpgradeComponent.instance -> keeps TranslationServer path active.

	var all_pass := true
	# 基础/血量: 整数加法.
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("basic_damage_up", [1.0]), 3), "Damage +3", "basic_damage_up count=3") and all_pass
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("health_limit_up", [1.0]), 2), "Health +2", "health_limit_up count=2") and all_pass
	# count=1 应该回退到 formatted_description (用 description_key).
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("basic_damage_up", [1.0]), 1), "Basic bullet damage increased by 1.", "basic_damage_up count=1 -> fallback uses description_key (单级文案)") and all_pass
	# 攻速/移速: 比例累加 (浮点精度陷阱 0.1*3*100=29.99.. 已通过 snappedi 修掉).
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("attack_speed_up", [0.1]), 2), "Attack Speed +20%", "attack_speed_up count=2") and all_pass
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("attack_speed_up", [0.1]), 3), "Attack Speed +30%", "attack_speed_up count=3 (float-precision fix)") and all_pass
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("move_speed_up", [0.1]), 4), "Move Speed +40%", "move_speed_up count=4") and all_pass
	# 防御: 累乘 0.8^count -> 减伤 = (1-r)*100.
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("defence_up", [0.8]), 2), "Dmg Reduction 36%", "defence_up count=2") and all_pass
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("defence_up", [0.8]), 3), "Dmg Reduction 49%", "defence_up count=3") and all_pass
	# 子弹分裂: 整数弹道数 + 比例伤害 (累乘).
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("bullet_split", [2, 0.7]), 2), "4 new projectiles, single-shot damage 49%", "bullet_split count=2") and all_pass
	all_pass = _assert_eq(UpgradeComponent.formatted_description_stacked(_make_res("bullet_split", [2, 0.7]), 3), "6 new projectiles, single-shot damage 34%", "bullet_split count=3") and all_pass

	if all_pass:
		print("All formatted_description_stacked tests passed.")
	else:
		push_error("Some formatted_description_stacked tests failed!")

	quit(0 if all_pass else 1)
