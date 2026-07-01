# 关卡递进系统设计文档

> **版本**: v1.0  **创建日期**: 2026-07-01  **状态**: 设计已定，待实现
> **本ドキュメントを新しい会話で開いたら**: まず "实现任务清单" セクションから着手。各タスクの "作業詳細" に必要なコードパッチとファイルパスを記載している。インクリメンタルに実装・コミット可能。

---

## 1. 设计目标

1. 10 关线性递进难度，前 5 关为"前半段"，第 5 关为奖励关；第 10 关为 BOSS
2. 每关拥有独立的 **刷怪配置表**（敌人类型权重、属性倍率、时长、刷怪间隔）
3. 修复刷怪的**不均匀波动**：替换当前的"纯随机爆量"为"受控节奏 + 小波峰"
4. 奖励关: 纯拾取物 (60% 药品: 药瓶/医疗包随机, 40% 升级: 免费三选一被动)
5. BOSS 关: 多阶段 Boss 敌人，击败即通关

---

## 2. 关卡配置总览

### 2.1 难度曲线

```
 强度
  │            ╭──╮        ╭───╮
  │      ╭──╮╱    ╮  ╭───╮    ╮ ╰── BOSS
  │  ╭─╮╱    ╰─╮  ╮╱     ╰─╮  │
  │╱    ╲       ╰─╯        ╰─╯ │
 ├────┬──┬───┬──┬────┬──┬───┬──▶ 关卡
  1  2  3  4  5  6  7  8  9  10
           ↑              ↑
         奖励(低谷)      BOSS(终峰)
```

### 2.2 关卡配置表

| 关卡 | 主题 | Slime% | Poppy% | Stone% | 时长(s) | HP× | Dmg× | 刷怪间隔(s) | 组 min | 组 max | 单人总敌 | 多人(4p)总敌 | 特殊规则 |
|------|------|--------|--------|--------|---------|-----|------|-------------|--------|--------|---------|-------------|----------|
| **1** | 热身 | 100 | 0 | 0 | 15 | 0.6 | 0.5 | 3.0 | 1 | 2 | ~5 | ~12 | 史莱姆专场，熟悉操作 |
| **2** | 引入 | 80 | 20 | 0 | 18 | 0.7 | 0.6 | 2.8 | 1 | 3 | ~9 | ~20 | 首次出现气球 |
| **3** | 熟悉 | 60 | 40 | 0 | 20 | 0.9 | 0.8 | 2.5 | 2 | 4 | ~14 | ~27 | 混合威胁初现 |
| **4** | 预压 | 45 | 35 | 20 | 25 | 1.0 | 1.0 | 2.4 | 2 | 5 | ~22 | ~40 | 石刺入场，最紧前半段 |
| **5** | **🎁奖励关** | — | — | — | **20** | — | — | — | — | — | — | — | **无敌人，刷新 5-7 个拾取物** |
| **6** | 二阶启动 | 35 | 40 | 25 | 25 | 1.1 | 1.0 | 2.2 | 3 | 5 | ~28 | ~48 | 后半段开始，压力回升 |
| **7** | 坦克潮 | 25 | 30 | 45 | 30 | 1.3 | 1.1 | 2.0 | 3 | 6 | ~36 | ~60 | 高血量为主，考验火力 |
| **8** | 气球暴 | 10 | 80 | 10 | 28 | 1.0 | 1.2 | 1.6 | 4 | 7 | ~52 | ~84 | **密集爆炸威胁**，考验集火 |
| **9** | 终极测试 | 30 | 30 | 40 | 35 | 1.6 | 1.4 | 1.9 | 4 | 8 | ~52 | ~88 | 全方位高压 |
| **10** | **🔥 BOSS** | — | — | — | **45** | Boss | Boss | — | — | — | — | — | 多阶段 Boss 战 |

> `组 min/max` = 单次刷怪的敌人数量范围。组内同类型敌人独立计算属性。多人线性增量: +1/人 (不含 host)。

### 2.3 数据配置形式

选择一个方向 (推荐 Option A，与现有 CSV 体制一致):

- **Option A**: 新增 `config/round_config.csv`，运行时由 `CSVResourceCache` 或直接在 `EnemySpawnComponent._ready()` 加载解析。
- **Option B**: 直接在 `EnemySpawnComponent` 顶部写 `const ROUND_CONFIGS: Array[Dictionary]` 硬编码。

本文档按 **Option B (硬编码常量)** 给出实现指引，便于快速迭代；后续可平滑迁移到 CSV。

---

## 3. 各系统改动方案

### 3.1 刷怪平滑化 + 群组化 (Spawn Smoothing + Group Spawning)

#### 现状问题

`enemy_spawn_component.gd` `_spawn_enemy()` 的当前实现:
```gdscript
var multi_enemy_rate := randf_range(0.0, 0.1 * peers + 0.05 * round_count)
var is_multi_enemy_spawn := randf() < multi_enemy_rate
var spawn_count := randi_range(peers, int((peers + round_count * peers))) if is_multi_enemy_spawn else 1
```

问题:
- `multi_enemy_rate` 本身是 `randf_range` 随机值，**连续判涨时爆量不可控**
- `spawn_count` 上限 `peers + round_count × peers` → 第 10 关 4 人局最多一次刷 40+ 只
- 没有保底，可能连续几只单刷 → 节奏断裂

#### 替换方案：配置化群组 (min/max) + 间隔固定 + 多人线性扩展

**核心思路**: 每次刷怪 = 刷一组。组大小由配置表 `[group_min, group_max]` 界定。引入**有界随机**（不是完全任意的），多人在线时线性增量。

```gdscript
# 新逻辑: 每次刷一组敌人, 数量由 round 配置决定
# group_min / group_max 界定方差上界, 不爆量
# 多人每人 +1 只, 线性增长
func _spawn_enemy() -> void:
    if not is_multiplayer_authority():
        return
    var group_size := randi_range(current_group_min, current_group_max)
    var peers := Tools.get_game_peers_count()
    if peers > 1:
        group_size += (peers - 1)
    for i in range(group_size):
        _spawn_one_enemy()
    spawn_timer.start(randf_range(round_min_spawn_interval, round_max_spawn_interval))
```

**组内同型机制**: 同一 tick 内的组，所有敌人取自**同一种敌人类型**（按 round 配置的权重随机选一种）。
- 好处: "一群气球冲过来"、"几只石刺并排" → 战术主题清晰
- 随机发生在"这次出哪类"而非"组内混编"

**对比旧代码效果**:

| 场景 | 旧代码最坏 | 新代码最坏 | 体感 |
|------|-----------|-----------|------|
| 单人 R4 | 一次 1 只 | 一次 5 只 | 密集但可应对 |
| 单人 R9 | 一次 9 只 | 一次 8 只 | 混乱但依旧不公 |
| 四人 R4 | 一次 16 只 | 一次 8 只 | 壮观且不卡 |
| 四人 R9 | 一次 40 只 | 一次 11 只 | **有趣而非绝望** |

**各关群组配置参考** (可在 round_config.csv 调整):

| 关卡 | 组 min | 组 max | 间隔(s) | 1人总敌 | 4人总敌 | 体验关键词 |
|------|--------|--------|---------|---------|---------|-----------|
| 1 | 1 | 2 | 3.0 | ~5 | ~12 | 慢热启蒙 |
| 2 | 1 | 3 | 2.8 | ~9 | ~20 | 小群试探 |
| 3 | 2 | 4 | 2.5 | ~14 | ~27 | 有压力的抱团 |
| 4 | 2 | 5 | 2.4 | ~22 | ~40 | 前半段高峰 |
| **5** | — | — | — | — | — | **奖励关** |
| 6 | 3 | 5 | 2.2 | ~28 | ~48 | 二阶起手 |
| 7 | 3 | 6 | 2.0 | ~36 | ~60 | 坦克潮涌动 |
| 8 | 4 | 7 | 1.6 | ~52 | ~84 | **气球暴风** |
| 9 | 4 | 8 | 1.9 | ~52 | ~88 | 终极混编高压 |
| 10 | — | — | — | — | — | **BOSS (带召唤)** |

> **实测后可选加强**: 若 R8/R9 仍简单，第 8/9 关可加"召唤波" Timer (每 8s 一次，额外刷 6-10 只)，但建议初期禁用。

#### 多人 scaling 公式

```
final_size = randi_range(group_min, group_max) + max(0, peers - 1)
```

线性增长，**不指数爆炸**。

---

#### 3.1.1 旧版 `_spawn_enemy()` 需要清除的代码

删除以下变量和计算逻辑 (全部来自旧随机爆量系统):
- `multi_enemy_rate` (局部 var)
- `is_multi_enemy_spawn` (局部 var)
- `spawn_count` 的 `peers + round_count * peers` 项
- `spawn_timer` 重置混在普通 spawn 路径里的情况

替换为干净的群组逻辑后，没有"单双数概率"，只有"每 tick 一组"。

### 3.2 敌人属性缩放

#### 改动点

| 文件 | 改动 |
|------|------|
| `enemy1/enemy1.gd`, `enemy2/enemy2.gd`, `enemy3/enemy3.gd` 的 `apply_enemy_config()` | 新增参数 `hp_scale: float = 1.0`, `dmg_scale: float = 1.0`，对 `health` 和 `damage` 做乘法 |
| `enemy_spawn_component.gd` 的 `_spawn_one_enemy()` | 传 `hp_scale` / `dmg_scale` 给 enemy |

#### 实现伪码

```gdscript
# Enemy1/2/3.gd
func apply_enemy_config(config: EnemyResource, hp_scale: float = 1.0, dmg_scale: float = 1.0) -> void:
    var health := _random_value_from_range(config.health_range) * hp_scale
    health_component.max_health = health
    health_component.reset(health)
    hitbox_component.damage = _random_value_from_range(config.damage_range) * dmg_scale
```

### 3.3 敌人类型权重选择

替换 `_select_enemy_config()`:

```gdscript
func _select_enemy_config(weights: Dictionary) -> EnemyResource:
    var total := 0.0
    for w in weights.values():
        total += w
    var roll := randf() * total
    var acc := 0.0
    for id in weights:
        acc += weights[id]
        if roll <= acc:
            return _enemy_dict[id]  # 需建立 id->config 字典
    return enemy_configs[0]  # fallback
```

或更 GDScript-idiomatic: 直接构建加权数组 `Array[EnemyResource]` 并按权重重复 `append`，然后 `pick_random`。

### 3.4 资源文件改动

#### 新增文件

| 路径 | 类型 | 描述 |
|------|------|------|
| `entities/pickup/pickup_area.gd` | GDScript | 拾取物逻辑（气泡 + 物品图标） |
| `entities/pickup/pickup_area.tscn` | PackedScene | 拾取物场景 |
| `entities/boss/boss.gd` | GDScript | Boss 主逻辑 |
| `entities/boss/boss.tscn` | PackedScene | Boss 场景 |
| `entities/boss/state_*.gd` (6-8 个文件) | GDScript | Boss 状态机 |

#### 修改文件

| 路径 | 改动描述 |
|------|----------|
| `components/enemy_spawn_component.gd` | 1) 加入关卡配置表 2) `_start_round()` 读配置 3) `_spawn_one_enemy()` 传缩放 4) 奖励/BOSS 分支逻辑 |
| `entities/enemy/enemy1/enemy1.gd` | `apply_enemy_config` 签名加参数 |
| `entities/enemy/enemy2/enemy2.gd` | 同上 |
| `entities/enemy/enemy3/enemy3.gd` | 同上 |
| `components/upgrade_component.gd` | 新增免费升级方法 (不经过全玩家同步流程) |
| `main.gd` | BOSS 死亡 → 通关; 奖励关 UI 提示 |

### 3.5 物理层配置

拾取物需要新的物理层:

```
layer_1 = wall
layer_2 = enemy
layer_3 = enemy_hit
layer_4 = player
layer_5 = pickup     ← NEW
layer_9 = bullet
```

在 `project.godot` 添加 `2d_physics/layer_5="pickup"`。

**拾取物碰撞配置**:
- `pickup_area` 是 `Area2D` (不是 body)，`collision_layer = layer_5`，`collision_mask = layer_4 (player hurtbox 所在层)`
- 玩家 `hurtbox_component` 需 `collision_mask` 加入 `layer_5`

但玩家 `HurtboxComponent` 目前是专门检测 `HitboxComponent` (layer 3)。为了确保拾取区域与玩家交互:

**方案**: 拾取物 `pickup_area` 的 `area_entered` 检测 `body.is_in_group("player")`。拾取物 collision_mask 只包含 `layer_4`。玩家 body 目前 `collision_layer = 8 (layer_4)`，但拾取物的检测要做 `area_entered` (仅 area 端做)，需要在拾取物的层配置。

**更简单的方案**: 拾取物不依赖碰撞，使用**周期性距离检测**:
- 拾取物拥有 `Area2D` + `CollisionShape2D (Circle)`
- 在 `_ready()` 中 `area_entered.connect(_on_player_entered)` (仅 authority)
- Area2D `collision_layer = layer_5`, `collision_mask = layer_4`
- 需要确保 `player` body Area2D 的 area_entered 在 authority 端可触发

> **决定**: 使用 Area2D 方案，需要调整玩家 `HurtboxComponent` 的 collision layer 不影响拾取检测。拾取物单独处理不依赖 hurtbox。

### 3.6 奖励关实现细节

**流程**:

```
_on_upgrade_finished() (通关前) or round_completed
    ↓
_start_round() → 判断 is_bonus
    ↓ (is_bonus = true)
停止 spawn_timer
启动 round_timer (20s)
在 spawn_rect 范围内随机生成 5-7 个 pickup_area 实例
    ↓
pickup_area 进入视野: 显示气泡 + 物品图标 (药瓶/医疗包/升级随机)
player 进入拾取范围 → 拾取消耗
    ↓
收集完毕 OR 时间到 → round_completed.emit() → upgrade_component.generate_options() → 下一关
```

**拾取物内容** (权重随机):
- 30% → 药瓶 (healing_potion, +1 HP)
- 30% → 医疗包 (medkit, +3 HP)
- 40% → 免费升级 (随机获得一个被动，无需选)

**免费升级实现**: 不走 `UpgradeComponent.generate_options()` 的全玩家流程，直接 `peer_selected_passives[id]++` 然后对特定 player 调用对应刷新 (`_refresh_health_limit`, `_notify_defense_changed` 等)。由拾取物的 `authority` 逻辑 RPC 化。

### 3.7 Boss 实现细节

#### 场景结构 (参考现有 enemy)

```
Boss (CharacterBody2D, layer_2)
├── HealthComponent (较大的 max_health, 如 80)
├── HurtboxComponent
├── HitboxComponent (多个: body 冲撞 + 技能多段)
├── MultiplayerSynchronizer
├── StateMachine
│   ├── Spawn (入场动画)
│   ├── Phase1Normal (常规追踪)
│   ├── Phase1Charge (冲撞玩家)
│   ├── Phase1Attack (冲撞)
│   ├── PhaseTransition (阶段切换动画: 倒地/咆哮 + 短暂无敌)
│   ├── Phase2Normal (更快追踪)
│   ├── Phase2Charge (冲撞)
│   ├── Phase2Slam (重击地面: 圆形 AOE 伤害区域)
│   ├── Phase2SpikeRing (刺环扩散: 向 8 方向发射子弹状刺弹)
│   └── Died
├── Visual
│   ├── FlashSpriteComponent (Boss 外观)
│   ├── Shadow
│   └── WarningIcon
└── TrackTimer
```

#### 多阶段逻辑

| 阶段 | 触发条件 | 新增能力 | 属性变化 |
|------|----------|----------|----------|
| Phase 1 | 初始 | 追踪 + 冲撞 | 速度 30，冲撞 600 |
| **转换动画** | HP < 50% | 2s 无敌 + 咆哮镜头抖动 | — |
| Phase 2 | 转换结束 | 追踪 + 冲撞 + **大地重击** + **尖刺圆环** | 速度 40，冲撞 700，重击 AOE 半径 60，刺环 12 方向 |

#### 各状态简介

- **Phase1Normal / Phase2Normal**: 冷却后决定追踪/Charge 切换
- **Phase1Charge / Phase2Charge**: 蓄力后直线冲撞 (复用 Enemy1 逻辑变体)
- **Phase2Slam**: 原地跳跃砸地，对半径内玩家造成伤害 (圆形 Area2D 在落地瞬间启用 0.2s)
- **Phase2SpikeRing**: 固定 8-12 个方向发射"尖刺弹"(复用 Bullet 或自定义弹道)，每发独立伤害
- **PhaseTransition**: 状态机通用节点，2s 内播放动画 + 镜头抖动 + 短暂无敌，然后切到 Phase2Normal

#### Boss 敌人配置

在 `enemy_config.csv` 最后新增一行:
```
"Boss: 多阶段BOSS",boss,res://entities/boss/boss.tscn,BOSS_NAME,50.0;50.0,2.0;4.0,BOSS_DESCRIPTION,,
```
然后在 `_select_enemy_config()` 时如果是第 10 关直接强制选 boss。

---

## 4. 实现任务清单

### 进度总览

> `[ ]` 待做  `[~]` 进行中  `[x]` 完成

```
[ ] Phase 0: 配置基础设施
    [ ] 任务 0.1: 添加物理层 layer_5 = pickup
    [ ] 任务 0.2: 在 enemy_spawn_component 中定义 ROUND_CONFIGS 常量

[ ] Phase 1: 刷怪系统重构
    [ ] 任务 1.1: 实现敌人类型加权选择
    [ ] 任务 1.2: 实现敌人属性缩放
    [ ] 任务 1.3: 实现配置化群组刷怪 (替换旧爆量逻辑)
    [ ] 任务 1.4: 集成: _start_round 读取 ROUND_CONFIGS
    [ ] 任务 1.5 (可选): 召唤波机制

[ ] Phase 2: 拾取物系统
    [ ] 任务 2.1: 创建 pickup_area 场景 + 动画 (气泡浮动)
    [ ] 任务 2.2: 实现拾取逻辑 (authority area_entered 检测)
    [ ] 任务 2.3: 实现拾取效果 (药品治疗 / 免费升级)
    [ ] 任务 2.4: 拾取物 multiplayer 同步 (server 验证 + broadcast 拾取)

[ ] Phase 3: 奖励关
    [ ] 任务 3.1: EnemySpawnComponent 奖励关分支 (停止刷怪、启动拾取物生成)
    [ ] 任务 3.2: 关卡完成逻辑适配 (时间到或全部拾取完)
    [ ] 任务 3.3: 奖励关 UI 提示 ("BONUS ROUND")

[ ] Phase 4: Boss
    [ ] 任务 4.1: Boss 基础场景 + 节点结构搭建
    [ ] 任务 4.2: 状态机 + Spawn/Phase1Normal/Phase1Charge/Phase1Attack/Died
    [ ] 任务 4.3: Phase2Normal/Phase2Charge + PhaseTransition 状态
    [ ] 任务 4.4: Phase2Slam (AOE 重击)
    [ ] 任务 4.5: Phase2SpikeRing (尖刺圆环弹道)
    [ ] 任务 4.6: 阶段切换逻辑 (HP 触发 + 短暂无敌)
    [ ] 任务 4.7: BOSS UI (特殊血条 / 阶段提示)

[ ] Phase 5: 整合与收尾
    [ ] 任务 5.1: main.gd 适配 BOSS 死亡 → 游戏通关
    [ ] 任务 5.2: 物理层/碰撞修复 (确保拾取物交互正常)
    ] 任务 5.3: 单机 + 多人联调测试
    [ ] 任务 5.4: 平衡性数值调优
```

---

### Phase 0: 配置基础设施

#### ☐ 任务 0.1: 添加物理层 layer_5 = pickup

- **文件**: `project.godot`
- **改动**:
  ```ini
  [layer_names]
  2d_physics/layer_5="pickup"
  ```
- **验证**: 编辑器中可见 layer 5 拾取

#### ☐ 任务 0.2: 在 enemy_spawn_component 中定义 ROUND_CONFIGS

- **文件**: `components/enemy_spawn_component.gd`
- **改动位置**: 文件顶部常量区，在 `MAX_ROUND` 后新增
- **设计常量结构**:
  ```gdscript
  const ROUND_CONFIGS: Array[Dictionary] = [
      # [1] 热身 - 组小(1~2), 低频(3.0s), 低属性
      { "slime": 1.0, "poppy": 0.0, "stone_poke": 0.0, "round_time": 15.0, "hp_scale": 0.6, "dmg_scale": 0.5, "spawn_interval": Vector2(3.0, 3.0), "group_min": 1, "group_max": 2, "is_bonus": false, "is_boss": false },
      # [2] 引入 - 出现气球, 组1~3
      { "slime": 0.8, "poppy": 0.2, "stone_poke": 0.0, "round_time": 18.0, "hp_scale": 0.7, "dmg_scale": 0.6, "spawn_interval": Vector2(2.8, 2.8), "group_min": 1, "group_max": 3, "is_bonus": false, "is_boss": false },
      # [3] 熟悉 - 混编, 组2~4
      { "slime": 0.6, "poppy": 0.4, "stone_poke": 0.0, "round_time": 20.0, "hp_scale": 0.9, "dmg_scale": 0.8, "spawn_interval": Vector2(2.5, 2.5), "group_min": 2, "group_max": 4, "is_bonus": false, "is_boss": false },
      # [4] 预压 - 石刺入场, 组2~5, 间隔收紧
      { "slime": 0.45, "poppy": 0.35, "stone_poke": 0.20, "round_time": 25.0, "hp_scale": 1.0, "dmg_scale": 1.0, "spawn_interval": Vector2(2.4, 2.4), "group_min": 2, "group_max": 5, "is_bonus": false, "is_boss": false },
      # [5] 奖励关 - 无敌人, 拾取物
      { "is_bonus": true, "round_time": 20.0, "pickup_count": 6 },
      # [6] 二阶启动 - 组3~5, 后半段正式起手
      { "slime": 0.35, "poppy": 0.40, "stone_poke": 0.25, "round_time": 25.0, "hp_scale": 1.1, "dmg_scale": 1.0, "spawn_interval": Vector2(2.2, 2.2), "group_min": 3, "group_max": 5, "is_bonus": false, "is_boss": false },
      # [7] 坦克潮 - 石刺主导, 组3~6
      { "slime": 0.25, "poppy": 0.30, "stone_poke": 0.45, "round_time": 30.0, "hp_scale": 1.3, "dmg_scale": 1.1, "spawn_interval": Vector2(2.0, 2.0), "group_min": 3, "group_max": 6, "is_bonus": false, "is_boss": false },
      # [8] 气球暴 - 大量爆炸, 组4~7, 间隔压缩
      { "slime": 0.10, "poppy": 0.80, "stone_poke": 0.10, "round_time": 28.0, "hp_scale": 1.0, "dmg_scale": 1.2, "spawn_interval": Vector2(1.6, 1.6), "group_min": 4, "group_max": 7, "is_bonus": false, "is_boss": false },
      # [9] 终极测试 - 均衡混编, 高属性, 组4~8
      { "slime": 0.30, "poppy": 0.30, "stone_poke": 0.40, "round_time": 35.0, "hp_scale": 1.6, "dmg_scale": 1.4, "spawn_interval": Vector2(1.9, 1.9), "group_min": 4, "group_max": 8, "is_bonus": false, "is_boss": false },
      # [10] BOSS - 单敌人, 多阶段
      { "is_boss": true, "round_time": 45.0 },
  ]
  ```
- **索引**: 数组索引 0-9 对应关卡 1-10 (或添加 `{ }` 占位 index 0 让索引对齐)

---

### Phase 1: 刷怪系统重构

#### ☐ 任务 1.1: 实现敌人类型加权选择

- **文件**: `components/enemy_spawn_component.gd`
- **改动函数**: `_select_enemy_config()` → 签名增加 `weights: Dictionary`
- **实现**:
  ```gdscript
  func _select_enemy_config(weights: Dictionary) -> EnemyResource:
      var weighted_list: Array[EnemyResource] = []
      for config in enemy_configs:
          var w: float = weights.get(config.id, 0.0)
          if w <= 0.0:
              continue
          var count := max(1, int(w * 10))  # 精度放大
          for i in count:
              weighted_list.append(config)
      if weighted_list.is_empty():
          return enemy_configs.pick_random()
      return weighted_list.pick_random()
  ```
- **或者** 经典的 "累积概率" 实现 (性能更优)

#### ☐ 任务 1.2: 实现敌人属性缩放

- **文件**: `entities/enemy/enemy1/enemy1.gd`, `enemy2/enemy2.gd`, `enemy3/enemy3.gd`
- **签名变更**:
  ```gdscript
  func apply_enemy_config(config: EnemyResource, hp_scale: float = 1.0, dmg_scale: float = 1.0) -> void:
  ```
- **具体改动** (以 enemy1.gd 为例):
  ```gdscript
  func apply_enemy_config(config: EnemyResource, hp_scale: float = 1.0, dmg_scale: float = 1.0) -> void:
      var health := _random_value_from_range(config.health_range) * hp_scale
      health_component.max_health = health
      health_component.reset(health)
      hitbox_component.damage = _random_value_from_range(config.damage_range) * dmg_scale
  ```
- 修改调用方: `enemy_spawn_component.gd` 的 `_spawn_one_enemy()` 传入 hp_scale / dmg_scale

#### ☐ 任务 1.3: 实现配置化群组刷怪 (替换旧爆量逻辑)

- **文件**: `components/enemy_spawn_component.gd`
- **改动**: 完整重写 `_spawn_enemy()`
- **实现**:
  ```gdscript
  func _spawn_enemy() -> void:
      if not is_multiplayer_authority():
          return
      var group_size := randi_range(current_group_min, current_group_max)
      var peers := Tools.get_game_peers_count()
      if peers > 1:
          group_size += (peers - 1)
      # 同组同型: 只选一次类型
      var config := _select_enemy_config(_current_round_config)
      if config == null:
          push_error("[EnemySpawn] No enemy config selected")
          spawn_timer.start(randf_range(round_min_spawn_interval, round_max_spawn_interval))
          return
      for i in range(group_size):
          var enemy := config.scene.instantiate() as Node2D
          spawn_root.add_child(enemy, true)
          if enemy.has_method("apply_enemy_config"):
              enemy.apply_enemy_config(config, current_hp_scale, current_dmg_scale)
          enemy.global_position = _get_random_position()
          enemy_count += 1
      spawn_timer.start(randf_range(round_min_spawn_interval, round_max_spawn_interval))
  ```
- **组内同型机制**: 同一 tick 内全部敌人使用同一个 `EnemyResource` 配置 (同类型)
- **独立属性**: 每个敌人各自调用 `apply_enemy_config` → 在health/damage_range 内独立随机
- **多人 linear scale**: `peers - 1` 增量线性增长，非乘算
- **删除**: 旧版 `peers`, `multi_enemy_rate`, `spawn_count` 爆量计算（全删）
- **警告**: 旧的 `_spawn_one_enemy()` 已在任务 1.3 中被吸收到 `_spawn_enemy()` 的循环中。如果想做更细粒度的拆分，可保留 `_spawn_one_enemy(config)` 签名接受外部传入的 config，但此任务直接合并更简洁。

#### ℹ️ 任务 1.5 (可选/bonus): 召唤波

详见 § 3.1 末尾的"实测后可选加强"。不建议在 Phase 1 实现，建议在 Phase 5 平衡调优阶段根据实测反馈决定。

#### ☐ 任务 1.4: 集成 `_start_round` 读取 ROUND_CONFIGS

- **文件**: `components/enemy_spawn_component.gd`
- **改动位置**: `_start_round()` 方法
- **将常量换成配置表读值**:
  ```gdscript
  func _start_round() -> void:
      round_count += 1
      print("Round %s start" % round_count)
      var config: Dictionary = ROUND_CONFIGS[round_count - 1]  # index 对齐
      _current_round_config = config
      if config.get("is_bonus", false):
          _start_bonus_round(config)
          return
      if config.get("is_boss", false):
          _start_boss_round(config)
          return
      # 普通关
      var interval: Vector2 = config["spawn_interval"]
      round_min_spawn_interval = interval.x
      round_max_spawn_interval = interval.y
      current_group_min = config.get("group_min", 1)
      current_group_max = config.get("group_max", 2)
      current_hp_scale = config["hp_scale"]
      current_dmg_scale = config["dmg_scale"]
      round_timer.start(config["round_time"])
      spawn_timer.start(randf_range(round_min_spawn_interval, round_max_spawn_interval))
      synchronize()
  ```
- **需新增实例变量** (添加到 EnemySpawnComponent 顶部原常量区):
  ```gdscript
  var _current_round_config: Dictionary = {}
  var current_group_min: int = 1
  var current_group_max: int = 2
  var current_hp_scale: float = 1.0
  var current_dmg_scale: float = 1.0
  ```
- **奖励/BOSS 分支**: 调用 `_start_bonus_round()` / `_start_boss_round()` (Phase 3/4)

---

### Phase 2: 拾取物系统

#### ☐ 任务 2.1: 创建 pickup_area 场景 + 动画

- **文件 (新增)**:
  - `entities/pickup/pickup_area.gd`
  - `entities/pickup/pickup_area.tscn`
- **场景结构**:
  ```
  PickupArea (Area2D, collision_layer=layer_5, collision_mask=layer_4)
  ├── BubbleSprite (Sprite2D, texture=bubble.tres)
  ├── IconSprite  (Sprite2D, 动态设置 icon, 放在气泡中央)
  └── CollisionShape2D (CircleShape2D radius=12)
  ```
- **动画**: `_ready()` 启动上下浮动循环 Tween (振幅 3px, 周期 1.5s)

#### ☐ 任务 2.2: 实现拾取检测

- **文件**: `entities/pickup/pickup_area.gd`
- **实现**:
  ```gdscript
  extends Area2D

  enum PickupType { HEALING_POTION, MEDKIT, UPGRADE }
  const HEALING_POTION = PickupType.HEALING_POTION
  const MEDKIT = PickupType.MEDKIT
  const UPGRADE = PickupType.UPGRADE

  @export var pickup_type: PickupType = HEALING_POTION
  @export var healing_amount: int = 1  # for MEDKIT override

  var _collected: bool = false

  @onready var bubble_sprite: Sprite2D = $BubbleSprite
  @onready var icon_sprite: Sprite2D = $IconSprite

  func _ready() -> void:
      if is_multiplayer_authority():
          area_entered.connect(_on_area_entered)
      _setup_appearance()
      _play_idle_animation()

  func _setup_appearance() -> void:
      match pickup_type:
          HEALING_POTION:
              icon_sprite.texture = load("res://assets/healing_potion.tres")
          MEDKIT:
              icon_sprite.texture = load("res://assets/medkit.tres")
          UPGRADE:
              # 随机选一个升级图标 (暂用 basic_damage_up)
              icon_sprite.texture = load("res://assets/basic_damage_up.tres")

  func _on_area_entered(area: Area2D) -> void:
      if not is_multiplayer_authority() or _collected:
          return
      # 寻找所有者是 player 的 hurtbox
      var player_node := _find_player_from_area(area)
      if player_node == null or player_node.is_dead:
          return
      _collect(player_node)

  func _collect(player: Player) -> void:
      _collected = true
      rpc("_sync_collect")  # 通知所有 peer 播放消失动画
      _apply_effect(player)
      queue_free()

  @rpc("authority", "call_local")
  func _sync_collect() -> void:
      # 播放消失特效 (缩放消失 + 粒子)
      var tween := create_tween()
      tween.tween_property(bubble_sprite, "scale", Vector2.ZERO, 0.15)
      tween.tween_callback(queue_free)

  func _apply_effect(player: Player) -> void:
      match pickup_type:
          HEALING_POTION:
              player.healing(1)
          MEDKIT:
              player.healing(999)  # 满血
          UPGRADE:
              _apply_random_upgrade(player)

  func _apply_random_upgrade(player: Player) -> void:
      # 通过 UpgradeComponent 单人次免费升级
      UpgradeComponent.apply_free_upgrade(player.input_peer_id)
  ```

#### ☐ 任务 2.3: 拾取物效果 - 免费升级 (UpgradeComponent 改动)

- **文件**: `components/upgrade_component.gd`
- **新增 static 方法**:
  ```gdscript
  static func apply_free_upgrade(peer_id: int) -> void:
      if not is_instance_valid(instance):
          return
      # 随机选择一个 passive id (不含已满的如果要做的话, 这里简化全部参与随机)
      var all_passives := instance.resources_id_dict.keys()
      var chosen: String = all_passives[randi() % all_passives.size()]
      var peer_passive_count_dic: Dictionary = instance.peer_selected_passives.get_or_add(peer_id, {})
      var count: int = peer_passive_count_dic.get_or_add(chosen, 0)
      peer_passive_count_dic[chosen] = count + 1
      print("[FreeUpgrade] peer %s got %s (count: %s)" % [peer_id, chosen, count + 1])
      # 找到对应 player 并触发属性刷新
      var players := get_tree().get_nodes_in_group("player")
      for p in players:
          if p is Player and p.input_peer_id == peer_id:
              p._on_free_upgrade_applied(chosen)
              return
  ```

- **Player.gd 新增方法**:
  ```gdscript
  func _on_free_upgrade_applied(item_id: String) -> void:
      if item_id == UpgradeComponent.ITEM_ID_HEALTH_LIMIT_UP:
          _refresh_health_limit()
      elif item_id == UpgradeComponent.ITEM_ID_DEFENCE_UP:
          _notify_defense_changed.rpc_id(input_peer_id, _get_defense_percent())
      # 其他属性无需实时刷新 (攻击/移速等在下一次 _get_xxx 时自动生效)
  ```

#### ☐ 任务 2.4: 拾取物 multiplayer 同步

- 拾取物由**服务端在奖励关开始时批量生成**，需要通过 MultiplayerSpawner 或手动 add_child
- **方案**: 走 `MultiplayerSpawner.add_spawnable_scene` + `spawn()` RPC，确保客户端也有实例
- **拾取验证**: 仅 authority 端的 `area_entered` 生效; 非法客户端拾取不能绕过 authority
- **消耗同步**: 拾取后服务端调用 `_collect(player)` 处理逻辑 + 广播同步动画

---

### Phase 3: 奖励关

#### ☐ 任务 3.1: EnemySpawnComponent 奖励关分支

- **文件**: `components/enemy_spawn_component.gd`
- **新增方法**:
  ```gdscript
  func _start_bonus_round(config: Dictionary) -> void:
      _is_bonus_round = true
      _is_boss_round = false
      _bonus_pickups_remaining = 0
      var pickup_count: int = config.get("pickup_count", 6)
      round_timer.start(config["round_time"])
      # 在 spawn_rect 范围内随机生成 pickup
      for i in range(pickup_count):
          var ptype := _roll_pickup_type()
          var pos := _get_random_position()
          _spawn_pickup(ptype, pos)
      synchronize()

  func _roll_pickup_type() -> int:
      var roll := randf()
      if roll < 0.30:
          return PickupArea.HEALING_POTION
      elif roll < 0.60:
          return PickupArea.MEDKIT
      else:
          return PickupArea.UPGRADE

  func _spawn_pickup(pickup_type: int, pos: Vector2) -> void:
      if not is_multiplayer_authority():
          return
      var scene := preload("res://entities/pickup/pickup_area.tscn")
      var pickup := scene.instantiate()
      pickup.pickup_type = pickup_type
      pickup.global_position = pos
      pickup.tree_exited.connect(func(): _on_pickup_removed())
      spawn_root.add_child(pickup)
      _bonus_pickups_remaining += 1

  func _on_pickup_removed() -> void:
      _bonus_pickups_remaining -= 1
      if _bonus_pickups_remaining <= 0:
          _check_round_completed()

  @rpc("authority", "call_remote", "reliable")
  func _sync_bonus_pickups() -> void:
      # 向新加入的 peer 同步当前拾取物状态
      pass
  ```
- **新增实例变量**:
  ```gdscript
  var _is_bonus_round: bool = false
  var _is_boss_round: bool = false
  var _bonus_pickups_remaining: int = 0
  ```

#### ☐ 任务 3.2: 关卡完成逻辑适配

- **改动文件**: `components/enemy_spawn_component.gd` 的 `_check_round_completed()`
- **改动**:
  ```gdscript
  func _check_round_completed() -> void:
      if _is_bonus_round:
          # 奖励关仅需 timer 到即可
          if round_timer.is_stopped():
              print("Bonus Round %s completed!" % round_count)
              _is_bonus_round = false
              if round_count < MAX_ROUND:
                  round_completed.emit()
              else:
                  max_round_end.emit()
          return
      if _is_boss_round:
          # BOSS 关: BOSS 死亡由 enemy_count==0 判定 (BOSS 也是 enemy)
          if round_timer.is_stopped() and enemy_count == 0:
              _is_boss_round = false
              if round_count < MAX_ROUND:
                  round_completed.emit()
              else:
                  max_round_end.emit()
          return
      # 普通关: 保持原逻辑
      if !round_timer.is_stopped():
          return
      if enemy_count == 0:
          ...
  ```

#### ☐ 任务 3.3: 奖励关 UI 提示

- 在 `round_timer_ui.gd` 或 main.tscn 中当检测到 `is_bonus_round` 时显示 "🎁 BONUS ROUND 🎁" 标签
- **简化版**: 复用 round_win_ui 组件或直接 emit 信号在 main.gd 中弹出临时的 "BONUS ROUND" 文字
- **接入**: 在 `enemy_spawn_component.gd` 发射 signal `bonus_round_started()` / `boss_round_started()`

---

### Phase 4: Boss

#### ☐ 任务 4.1: Boss 基础场景 + 节点结构搭建

- **文件 (新增)**: `entities/boss/boss.tscn`
- **场景结构**:
  ```
  Boss (CharacterBody2D, layer_2, collision_mask=3, groups=["enemy"])
  ├── HealthComponent (max_health=80)
  ├── HurtboxComponent (collision_mask=256)
  │   └── HurtCollisionShape2D (CircleShape2D radius=20)
  ├── HitboxComponent_Body (layer=3, 多个子节点)
  │   ├── HitCol_Body (CircleShape2D radius=18, 接触伤害)
  │   └── HitCol_Slam  (CircleShape2D radius=60, AOE 禁用待激活)
  ├── MultiplayerSynchronizer
  │   (复制 global_position, health, current_state, phase)
  ├── StateMachine
  │   ├── Spawn
  │   ├── Phase1Normal
  │   ├── Phase1Charge
  │   ├── Phase1Attack
  │   ├── PhaseTransition
  │   ├── Phase2Normal
  │   ├── Phase2Charge
  │   ├── Phase2Attack
  │   ├── Phase2Slam
  │   ├── Phase2SpikeRing
  │   └── Died
  ├── Visual
  │   ├── Shadow (Sprite2D)
  │   └── FlashSpriteComponent (Boss 外观)
  ├── WarningIcon
  ├── TrackTimer (wait_time=0.15)
  ├── ChargeTimer (one_shot)
  └── AttackCoolDownTimer (one_shot)
  ```
- **注意**: 新建 `entities/boss/` 目录
- Boss 外观暂用大尺寸的 stone_poke 或新建占位贴图 (纹理大小不影响)

#### ☐ 任务 4.2: Boss 状态机 (Phase 1 部分)

- **文件 (新增)**:
  - `entities/boss/boss.gd`
  - `entities/boss/state_spawn.gd`
  - `entities/boss/state_phase1_normal.gd`
  - `entities/boss/state_phase1_charge.gd`
  - `entities/boss/state_phase1_attack.gd`
  - `entities/boss/state_died.gd`

- **boss.gd 主逻辑 概要**:
  ```gdscript
  class_name Boss
  extends CharacterBody2D

  const HIT_EFFECT = preload(...)
  const BOSS_DIED_EFFECT = preload(...)
  var track_target: Vector2
  var has_track_target: bool = false
  var charge_tip_tween: Tween
  var current_phase: int = 1:
      get: return current_phase
      set(v):
          current_phase = v
          phase_changed.emit(v)

  signal phase_changed(new_phase: int)

  @onready var health_component: HealthComponent = $HealthComponent
  @onready var state_machine: StateMachine = $StateMachine
  @onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
  ...

  func _ready() -> void:
      if is_multiplayer_authority():
          health_component.health_depleted.connect(_on_health_depleted)
          health_component.health_changed.connect(_on_health_changed)
          ...

  func _on_health_changed(_max: float, _current: float) -> void:
      if current_phase == 1 and health_component.current_health <= health_component.max_health * 0.5:
          # 触发阶段转换
          if state_machine.current_state != "phase_transition":
              state_machine.current_state = "phase_transition"

  func apply_enemy_config(config: EnemyResource, hp_scale: float = 1.0, dmg_scale: float = 1.0) -> void:
      # 覆盖 hp 为 BOSS 专用值 (忽略 config 范围的随机)
      health_component.max_health = 80 * hp_scale  # 或写死 80
      health_component.reset()
      hitbox_component.damage = 2.0 * dmg_scale  # BOSS 基础接触伤害
  ```

- **Phase1 状态** 可参考现有 enemy1 实现 (追踪 + 蓄力 + 冲撞):
  - `state_phase1_normal`: 追踪玩家, 冷却后发出 charge (沿用 enemy1 normal 框架)
  - `state_phase1_charge`: 显示警告 + 蓄力 0.6s
  - `state_phase1_attack`: 直线冲撞 800 速度, 减速后回到 normal

#### ☐ 任务 4.3: Phase2 + PhaseTransition 状态

- **文件 (新增)**:
  - `entities/boss/state_phase_transition.gd`
  - `entities/boss/state_phase2_normal.gd`
  - `entities/boss/state_phase2_charge.gd`
  - `entities/boss/state_phase2_attack.gd`

- **phase_transition 状态**:
  ```gdscript
  extends State

  const TRANSITION_DURATION: float = 2.0

  var boss: Boss

  func enter() -> void:
      boss = owner
      if is_multiplayer_authority():
          boss.velocity = Vector2.ZERO
          # 短暂无敌 (禁用所有 hitbox 接收 hurtbox 伤害的反向：玩家无法被 Boss 伤害) -- 实际上是禁止 Boss 受伤
          boss.hurtbox_component.get_child(0).disabled = true  # hurt collision
          boss.hitbox_component.get_child(0).disabled = false  # boss 身体伤害保留或取消
      # 镜头抖动 + 咆哮效果
      GameCamera.shake()
      # 2s 后转 Phase2
      await get_tree().create_timer(TRANSITION_DURATION).timeout
      if is_multiplayer_authority():
          boss.hurtbox_component.get_child(0).disabled = false
          boss.current_phase = 2
      transitioned.emit("phase2_normal")
  ```

#### ☐ 任务 4.4: Phase2Slam (AOE 重击)

- **文件 (新增)**: `entities/boss/state_phase2_slam.gd`
- **逻辑**:
  - 蓄力 0.8s (视觉高大 + 警告圈扩大)
  - 落地瞬间启用 AOE Hitbox (半径 60) 0.2s, 判定命中玩家
  - 进入冷却
  - 参考代码:
  ```gdscript
  func enter() -> void:
      boss = owner
      if is_multiplayer_authority():
          boss.velocity = Vector2.ZERO
          # 蓄力
          await get_tree().create_timer(0.8).timeout
          # 砸地 - 启用 AOE hitbox
          boss.enable_slam_hitbox.rpc(true)
          GameCamera.shake()
          await get_tree().create_timer(0.2).timeout
          boss.enable_slam_hitbox.rpc(false)
      transitioned.emit("phase2_normal")
  ```

#### ☐ 任务 4.5: Phase2SpikeRing (尖刺圆环)

- **文件 (新增)**: `entities/boss/state_phase2_spike_ring.gd`
- **逻辑**: 同时发射 12 个方向的"刺弹"
- **刺弹**: 复用 `entities/bullet` 的场景，修改贴图或用带自定义方向的直线弹道 + 更大的 CollisionShape
- 在 boss.gd 中导出 `spike_scene` PackedScene 引用:
  ```gdscript
  @export var spike_scene: PackedScene = preload("res://entities/boss/spike_projectile.tscn")
  func spawn_spike_ring() -> void:
      if not is_multiplayer_authority():
          return
      const dirs := 12
      for i in range(dirs):
          var angle := TAU * i / dirs
          var proj = spike_scene.instantiate()
          proj.global_position = global_position
          proj.direction = Vector2.RIGHT.rotated(angle)
          proj.damage = 1.5 * current_dmg_scale
          get_parent().add_child(proj)
  ```

#### ☐ 任务 4.6: 阶段切换逻辑 (HP 触发 + 短暂无敌)

- 见 4.2 中 `_on_health_changed` 触发 `phase_transition` 状态
- 需要防止重复触发 (用 `current_phase` 守卫)
- 短暂无敌通过 disable hurtbox 实现 (在 transition enter/exit 时切换)

#### ☐ 任务 4.7: BOSS UI (特殊血条 / 阶段提示)

- **新增文件**: `ui/game_ui/boss_health_bar.tscn` + `.gd`
- 大尺寸血条在屏幕上方, 显示 Boss 名 + HP 百分比 + 阶段数字
- 阶段切换时弹出 "PHASE 2" 大字动画
- 在 `main.gd` 中连接 Boss 的 `health_changed` / `phase_changed` 信号

---

### Phase 5: 整合与收尾

#### ☐ 任务 5.1: main.gd 适配 BOSS 死亡 → 游戏通关

- 现有逻辑: `max_round_end` 信号直接在 round 10 结束时触发, 但现在 BOSS 关需要等 BOSS **死亡**而非"时间到"
- **改动**: `enemy_spawn_component.gd` 在 BOSS 死亡 (`enemy_count==0`) 时 emit `max_round_end` (已在 _check_round_completed 中覆盖)
- 或者 Boss 单独 emit `boss_defeated` 信号，在 main.gd 中直接调 `_game_completed.rpc(true)`

#### ☐ 任务 5.2: 物理层/碰撞修复

- 确保拾取物 `Area2D` 在 `layer_5`, mask 包含 `layer_4`
- 需要验证 player body 在 `layer_4` 的 collision layer 是否能让 area_entered 触发
- 如不能正常工作，改用 `_process` 中遍历 `get_overlapping_areas()` 方案
- 完成后编写测试: 单机进奖励关 → 走近期拾取物 → 泡泡消失 + 血量恢复 / 升级生效

#### ☐ 任务 5.3: 单机 + 多人联调测试

- 单人全流程: 1→2→...→10 通关一遍，验证每关难度爬坡体感
- 多人: 2 玩家, 验证拾取物同步、Boss 阶段切换同步
- 关注点:
  - 拾取物拾取后客户端视觉效果
  - Boss 阶段切换时 client 端动画正确
  - 网络延迟下拾取判定

#### ☐ 任务 5.4: 平衡性数值调优

- 基于测试反馈调整 ROUND_CONFIGS 中的数值
- 重点关注:
  - 第 1 关是否过于简单/难
  - 奖励关数量和时长是否让玩家觉得"爽"
  - 第 8 关气球暴是否太密集导致不可玩
  - BOSS 45s 是否够用 (武器 build 差异大时可调整)
  - 属性倍率是否过高或过低

---

## 6. 技术风险与备忘

### 6.1 已知约束

- `apply_enemy_config` 签名同步: Enemy1/2/3 三个文件必须同步加参数，否则 Phase 1 编译失败
- `PickupArea` 的 `area_entered` 在 Godot multiplayer 中只在 **authority 端**触发, 与设计预期一致
- 玩家 `hurtbox` collision_mask 当前是 `256 (layer_9)`, 不影响拾取物（拾取物 mask 检测 player body 自身, 不是 hurtbox）
- **拾取物碰撞用的是 player 的 CharacterBody2D body**, 目前在 `layer_4 (8)`, 其 mask 是 `4 (enemy layer_2)`, 所以拾取物 mask 必须包含 `layer_4` ✓

### 6.2 可选后续扩展 (不在当前范围)

- 拾取物掉落系统: 击杀敌人后概率掉落 (需要另一种刷怪机制)
- Boss 掉落传说级物品
- BOSS 阶段 3 (HP 25% 狂暴)
- 中途难度动态调整 (基于玩家死亡次数)

---

*End Of Document - Total 15 任务条目, 5 Phase*