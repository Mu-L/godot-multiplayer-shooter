# 🎮 Godot 4 多人射击游戏练习

<p align="center">
  <img src="icon.svg" width="64" alt="Game Icon">
</p>

<p align="center">
  <a href="https://godotengine.org/"><img src="https://img.shields.io/badge/Godot-4.6-blue?logo=godot-engine&logoColor=white" alt="Godot 4.6"></a>
  <a href="#"><img src="https://img.shields.io/badge/Multiplayer-Online%2FLocal-green" alt="Multiplayer"></a>
  <a href="#"><img src="https://img.shields.io/badge/Genre-Shooter-orange" alt="Genre"></a>
</p>

一个使用 **Godot 4** 开发的多人合作射击游戏练习项目，支持在线联机与本地单人游玩。

---

## ✨ 特性

| 功能 | 描述 |
|------|------|
| 🌐 **多人联机** | 基于 Godot 4 Multiplayer API，支持多人在线合作 |
| 🏛️ **大厅系统** | 玩家准备机制，全员就绪后自动开始游戏 |
| 🎯 **射击战斗** | WASD 移动，鼠标瞄准射击，流畅的操作体验 |
| 🤖 **敌人 AI** | 状态机驱动的智能敌人（巡逻、追击、蓄力攻击） |
| 💥 **视觉特效** | 粒子效果、受击闪白、相机抖动、死亡痕迹 |
| ❤️ **状态显示** | 玩家血条、名称标签、本地/远程玩家区分 |
| 🔄 **复活机制** | 回合制复活，死亡玩家在每波敌人清除后复活 |
| ⏸️ **暂停菜单** | 多人/单人模式下均可暂停游戏 |

---

## 🎮 操作说明

| 按键 | 功能 |
|------|------|
| `W` `A` `S` `D` / `↑` `↓` `←` `→` | 移动 |
| `鼠标移动` | 瞄准 |
| `鼠标左键` | 射击 |
| `ESC` / `P` | 暂停游戏 |
| `R` | 准备就绪（大厅模式） |

---

## 🏗️ 项目结构

```
📁 项目根目录
├── 📁 autoload/              # 自动加载的全局脚本
├── 📁 components/            # 可复用组件
│   ├── health_component/     # 生命值组件
│   ├── hitbox_component/     # 伤害判定组件
│   ├── hurtbox_component/    # 受击判定组件
│   └── lobby_component/      # 大厅逻辑组件
├── 📁 entities/              # 游戏实体
│   ├── player/               # 玩家角色
│   ├── enemy/                # 敌人（含状态机）
│   └── bullet/               # 子弹
├── 📁 ui/                    # 用户界面
│   ├── menu/                 # 主菜单
│   ├── multiplayer_menu/     # 多人游戏菜单
│   ├── pause_menu/           # 暂停菜单
│   └── game_ui/              # 游戏内 UI
├── 📁 effects/               # 视觉特效场景
├── 📁 scripts/               # 通用脚本（状态机等）
└── 📁 assets/                # 游戏资源
```

---

## 🚀 运行项目

### 前置要求
- [Godot 4.6](https://godotengine.org/download) 或更高版本

### 运行步骤
1. 克隆本仓库
   ```bash
   git clone <repository-url>
   cd 01-multi-player
   ```
2. 使用 Godot 导入项目（选择 `project.godot` 文件）
3. 点击 **运行** 按钮或按 `F5`

---

## 🎯 游戏玩法

1. **单人模式** - 直接开始游戏，独自对抗敌人波次
2. **多人模式** - 创建或加入房间，等待所有玩家准备后开始
3. **生存挑战** - 击败不断刷新的敌人，坚持更多回合
4. **团队协作** - 所有玩家死亡则游戏结束，互相配合生存下去！

---

## 📸 开发历程

<details>
<summary>点击查看开发日志</summary>

| 提交 | 功能 |
|------|------|
| `feat: 新增大厅功能` | 多人游戏准备功能 |
| `feat: 玩家复活仅1血` | 复活机制与多人暂停菜单 |
| `feat: 新增Player状态栏` | 血量显示与碰撞调整 |
| `feat: Player名称显示` | 玩家名称与血条 |
| `feat: 新增错误弹窗` | 连接错误处理 |
| `feat: 游戏菜单` | 主菜单与导航 |
| `feat: 新增相机抖动` | 射击反馈效果 |
| `feat: 新增敌人受击闪白效果` | 视觉反馈 |
| `feat: 击中粒子特效` | 粒子效果系统 |
| `feat: 玩家断连处理` | 网络异常处理 |
| `feat: 玩家死亡与复活` | 游戏失败检测 |
| `feat: 敌人状态机实现` | AI 行为系统 |
| `feat: 基础状态机实现` | 状态机框架 |

</details>

---

## 📝 技术亮点

- **状态机模式** - 敌人 AI 使用模块化状态机（生成/巡逻/追击/攻击/死亡）
- **组件化设计** - 生命值、碰撞检测等功能拆分为可复用组件
- **RPC 同步** - 使用 Godot 的远程过程调用实现状态同步
- **权威服务器** - 服务端权威架构，防止客户端作弊

---

## 📄 许可证

本项目为学习练习项目，代码仅供参考学习使用。

---

<p align="center">
  Made with ❤️ using <a href="https://godotengine.org/">Godot Engine</a>
</p>
