# OpenAimTrainer 项目分析报告

| 项目 | 内容 |
| --- | --- |
| 报告名称 | OpenAimTrainer 项目分析报告（架构 / 模块 / 功能 / 玩法） |
| 项目主题 | 开源跨平台（桌面 + Web）FPS 瞄准训练器 —— Open Aim Trainer |
| 报告生成时间 | 2026-10-08 19:33（UTC+8） |
| **最后更新时间** | **2026-10-08 20:45（UTC+8）** |
| 代码快照时间 | 2025-12-22 03:40（文件系统统一时间戳，为解压/检出时间，非真实开发时间） |
| 版本来源 | 无 `.git` 仓库，无法获取提交历史与作者时间线 |
| 引擎 / 渲染 | Godot 4.5，`Forward Plus`，GDScript（本机以 Godot 4.7 运行验证，未用编辑器保存） |
| 开源协议 | Apache License 2.0 |
| 分析范围 | 15 个 `.gd` 脚本、9 个 `.tscn` 场景、9 类资源、`project.godot` 全量配置 |
| 文档状态 | 本版已同步至 2026-10-08 20:45 的优化后代码（含汉化、窗口模式、成绩记录等） |
| 配套文档 | `OpenAimTrainer_缺陷排查与优化评估报告_20261008.md`（评估）、`OpenAimTrainer_优化进度记录_20261008.md`（进度） |

---

## 一、项目主旨

**Open Aim Trainer** 是一个免费、开源的**鼠标瞄准（Aim）训练器**，用于提升玩家在 2D 与 3D 射击游戏中的瞄准能力。其核心主旨有三点：

1. **训练肌肉记忆**：通过高重复度的"出靶 → 瞄准 → 点击 → 计分"闭环，训练定位（flick）、追踪（tracking）、目标切换（target switching）三类基础瞄准能力。
2. **跨游戏手感对齐**：内置 Valorant / CS / Fortnite 的**灵敏度换算系数**，让训练时的鼠标手感与目标游戏一致（这是同类工具的核心卖点）。
3. **完全可定制 + 零门槛**：准星形状/颜色/尺寸、目标颜色、渲染缩放、显示模式（窗口 / 最大化 / 全屏）与窗口大小均可调，配置可**导入/导出 JSON** 分享；同时提供 Web 版本，打开网页即可练枪，无需安装。

---

## 二、技术栈与运行环境

| 维度 | 内容 |
| --- | --- |
| 引擎 | Godot 4.5（`config/features = PackedStringArray("4.5", "Forward Plus")`） |
| 语言 | GDScript（静态类型部分使用） |
| 渲染 | Forward Plus，启用 `WorldEnvironment`（程序化天空 + Filmic 色调映射 + Glow） |
| 平台 | Windows 桌面（含 `icon.ico` 与 `rcedit-x64.exe` 用于改 exe 图标）、Web（`web/` 目录 + `JavaScriptBridge`） |
| 主入口 | `res://scenes/ui/MainScreen.tscn` |
| 视口 | 3840×2160（4K 基准），`stretch = canvas_items`，`aspect = expand`，主题缩放 `4.0` |
| 输入 | `left/right/up/down`（WASD）、`jump`（空格）、`fire`（鼠标左键）、`esc`、`f_pressed`（**F 键，主菜单切换全屏 / 窗口**） |
| 存档 | `user://open_aim_trainer.json`（Web 端退化为浏览器下载/上传） |
| 国际化 | **15 语**：`en / es / zh_CN / zh_TW / zh_HK / ja / ko / fr / de / pt_BR / ru / it / tr / ar / vi`，**58 键**，由引擎导入器（`godot --headless --path . --import`）或 `tools/build_translations.gd` 从 CSV 编译 |

> **4K 设计说明**：所有 UI 以 3840×2160 布局、`theme/default_theme_scale = 4.0`，配合 `canvas_items + expand` 拉伸，保证在高分屏下 UI 元素等比缩放而不失真。

---

## 三、目录结构（当前）

```
OpenAimTrainer-main/
├── project.godot              # 引擎配置：自动加载、输入映射、视口、i18n
├── icon.png / icon.ico        # 应用图标
├── LICENSE                    # Apache-2.0
├── README.md
├── docs/                      # 说明 / 评估 / 进度文档（2026-10-08）
├── tools/
│   └── build_translations.gd  # CSV → .translation 编译脚本
├── scripts/
│   ├── global.gd              # 自动加载：配置字典 + 成绩记录 + 显示模式 / 窗口尺寸
│   ├── data_manager.gd        # 自动加载：JSON 持久化、locale 恢复、显示模式应用
│   ├── characters/
│   │   ├── CharacterBody3D.gd # 玩家 FPS 控制器（移动 + 视角 + 射击 + 计时 + 命中统计）
│   │   ├── target.gd          # 3D 目标
│   │   └── Target2D.gd        # 2D 目标
│   ├── levels/
│   │   ├── World.gd           # 3D 关卡主控
│   │   ├── World2D.gd         # 2D 关卡主控
│   │   ├── Pause.gd           # 暂停 / 结算面板
│   │   └── PauseInput.gd      # 常驻输入节点（process_mode = ALWAYS）
│   └── ui/
│       ├── MainScreen.gd      # 主菜单
│       ├── Options.gd         # 设置页（准星 / 目标 / 语言 / 显示 / 导入导出）
│       ├── Crosshair.gd       # 准星绘制（_draw）
│       ├── Bullet.gd          # 弹道特效
│       ├── ModePreview3D.gd   # 3D 模式缩略图
│       └── ModePreview2D.gd   # 2D 模式缩略图
├── scenes/
│   ├── ui/{MainScreen,Options,ModePreview3D,ModePreview2D}.tscn
│   ├── levels/{World,World2D,Bullet}.tscn + World.gdshader（空文件，未使用）
│   └── characters/{target,Target2D}.tscn
├── assets/
│   ├── images/      # Logo、模式封面图（games/*.png）、地面贴图
│   ├── fonts/       # 100_outline.tres（描边字体设置）
│   ├── themes/      # theme.tres / normal.tres / hover.tres
│   └── text/        # translations.csv（15 个 locale 列）+ 15 个 .translation
├── web/             # 官网落地页 index.html + .htaccess + 图标
└── other/           # godot-valorant.ods（灵敏度换算表）、rcedit-x64.exe（已 .gdignore）
```

> README 中描述的 `assets/sounds`、`assets/models`、`resources/shaders` 目录**在实际代码中不存在**，属于文档与实现不同步（当前版本无音频）。

---

## 四、总体架构

### 4.1 分层架构

```
┌──────────────────────────────────────────────────────────┐
│                    表现层 / UI Layer                       │
│  MainScreen（模式选择 + 灵敏度 + 渲染缩放 + F 键切屏）      │
│  Options（准星编辑器 + 目标颜色 + 语言/显示/窗口 + 导入导出）│
│  Crosshair（CanvasItem._draw 自绘准星）                    │
│  Pause / FullScreenRequest / MouseCapturedRequest          │
├──────────────────────────────────────────────────────────┤
│                    玩法层 / Level Layer                    │
│  World.gd（3D 关卡：刷靶 / 计分 / 计时 / 鼠标捕获守卫）     │
│  World2D.gd（2D 关卡：刷靶 / 计分 / 倒计时 / 结算）         │
│  PauseInput.gd（ALWAYS 进程模式，暂停态键盘输入）           │
│  ModePreview3D / ModePreview2D（SubViewport 缩略图）       │
├──────────────────────────────────────────────────────────┤
│                    实体层 / Entity Layer                   │
│  CharacterBody3D.gd（玩家）  target.gd（3D靶）             │
│  Target2D.gd（2D靶）         Bullet.gd（弹道特效）          │
├──────────────────────────────────────────────────────────┤
│                    服务层 / Service Layer                  │
│  Global（Autoload：模式表 + 灵敏度表 + 成绩记录 + 显示模式）│
│  DataManager（Autoload：JSON 读写 / locale / Web 导入导出） │
└──────────────────────────────────────────────────────────┘
```

### 4.2 场景流转

```
        ┌─────────────┐
        │ MainScreen  │◄──────────────┐
        └──────┬──────┘               │ Back / Menu
   PLAY(随机) │  或点击模式按钮        │
             ▼                        │
   ┌───────────────────┐        ┌─────┴──────┐
   │ 3D → World.tscn   │        │  Options   │
   │ 2D → World2D.tscn │        └────────────┘
   └─────────┬─────────┘
             │ 60s 结束 / Esc / 失焦
             ▼
       Pause 结算（Kills / Score / 命中率 / 最佳
                  → Resume? / Restart / Menu）
```

- `Global.game_type` 作为**跨场景的模式令牌**：`MainScreen` 写入 → `World/World2D` 读取 → 查 `Global.models3d/models2d` 取参数。
- 3D 模式下 `MainScreen.startTraining()` 会先 `Input.set_mouse_mode(MOUSE_MODE_CAPTURED)` 锁定鼠标；进入关卡后守卫只校验"鼠标是否处于捕获态"，**不再强制全屏**。
- 结算态隐藏 `Resume`，保留 `Restart`（原地重开）与 `Menu`（回主菜单）。

### 4.3 数据流与持久化

```
UI 控件（Persist 组 / 显式调用）
        │  DataManager.save_data(key, value)
        ▼
game_data: Dictionary  ──JSON.stringify──►  user://open_aim_trainer.json
        ▲                                          │
        └──────── DataManager.load_all_data() ◄────┘
                          │
                          ▼
        Crosshair.loadSave() / target._ready() / CharacterBody3D._ready()
        DataManager._ready(): 恢复 locale → 应用显示模式
```

**持久化键清单**：

| 分类 | Key | 消费者 |
| --- | --- | --- |
| 准星 | `Crosshair` `Outline` `CrosshairInner` `Dot`（bool） | Crosshair.gd |
| 准星 | `DotSize` `OutlineSize` `CrosshairHeight` `CrosshairWidth` `CrosshairSpace`（float） | Crosshair.gd |
| 准星 | `CrosshairColor` `OutlineColor`（Color 字符串） | Crosshair.gd |
| 目标 | `TargetColor` | target.gd / Target2D.gd |
| 手感 | `sensitivity`、`sensitivity_game`、`sensitivity_game_value` | CharacterBody3D.gd |
| 画质 | `resolution`（3D 渲染缩放，**0.5~2.0，步长 0.25**） | MainScreen.gd |
| 模式 | `is_3d_mode`（CheckButton 状态） | MainScreen.gd |
| 成绩 | `records`（`{模式: {best_score, best_accuracy}}`） | Global.save_record() |
| 界面 | `locale`（15 种之一，如 `zh_CN` / `ja` / `pt_BR`） | DataManager._ready() |
| 显示 | `display_mode`（0 窗口 / 2 最大化 / 3 全屏） | Global.apply_display_mode() |
| 显示 | `window_size`（尺寸索引，默认 1 = 1600×900） | Global.apply_display_mode() |

### 4.4 信号协作（3D 关卡）

```
target.gd ──signal target_kill──► World.target_killed()
                                      ├─ messageHit()：击杀数 +1、播放 "kill" 动画（0.2s）
                                      └─ spawn_target()：立即补刷新靶

Player(CharacterBody3D) ──signal pause_game──► Pause._on_player_pause_game()
PauseInput ──signal pause_toggled──► World2D.toggle_pause()      （2D，ALWAYS 进程模式）
Options ──signal refresh_crosshair──► Crosshair._on_options_refresh_crosshair()
```

---

## 五、模块详解

### 5.1 Global（自动加载单例）

职责：**配置中心 + 字符串/向量转换工具 + 成绩记录 + 显示模式**，无场景依赖。

| 成员 | 说明 |
| --- | --- |
| `string_to_vector3d()` / `string_to_color()` | 把 `"(0,1,1,1)"` 形式的存档字符串还原为 `Vector3` / `Color` |
| `games_sensitivities` | 4K 基准换算系数：`Valorant 0.0707589285714285`、`CounterStrike 0.0222372497081799`、`Fortnite 0.00561534231977053` |
| `models3d` / `models2d` | 4 个 3D 模式 + 3 个 2D 模式配置（见第六、七节） |
| `game_type` | 当前所选模式名的全局传递变量 |
| `save_record()` / `get_record()` | 训练成绩记录读写（最佳击杀 / 最佳命中率），存于 `records` |
| `get/set/apply_display_mode()` | 显示模式（0 窗口 / 2 最大化 / 3 全屏）读写与立即应用 |
| `toggle_fullscreen()` | 全屏 ↔ 窗口切换（主菜单 F 键） |
| `WINDOW_SIZES` | 窗口尺寸表：1280×720 / 1600×900 / 1920×1080 / 2560×1440 |
| `get/set_window_size_index()` | 窗口尺寸读写；**选择尺寸时若当前非窗口模式，自动切为窗口** |

### 5.2 DataManager（自动加载单例）

| 方法 | 行为 |
| --- | --- |
| `save_data(key, value)` | 更新内存字典 → 全量覆写 JSON 文件 |
| `get_data(key)` | 读取字典值，缺省返回 `null`（各模块均做 null 判断，安全） |
| `save_all_data(path)` / `load_all_data(path)` | 支持导入导出到任意路径（FileDialog） |
| `save_all_data_to_file_web()` | Web 端用 `JavaScriptBridge.download_buffer()` 触发浏览器下载 |
| `load_all_data_from_param(json)` | Web 端导入：由 `window.getFile()` 回调把文件内容回传解析 |
| `_ready()` | 读档后：① 恢复 `locale` → `TranslationServer.set_locale()`；② 最早应用显示模式（避免窗口模式下先闪一下全屏） |

### 5.3 MainScreen（主菜单）

- **动态模式列表**：遍历 `Global.models3d` / `Global.models2d`，为每个模式生成 `HBoxContainer = [预览缩略图(300×300), 按钮(模式名)]`；切换 2D/3D 时先 `queue_free()` 清理再重建。
- **实时缩略图**：`ModePreview3D/2D` 是 `SubViewportContainer`，在菜单里用独立小视口**真实渲染**该模式的靶位布局（3D 版程序化生成 6 面 `StaticBody3D` 墙用于约束移动靶）。
- **灵敏度区**：`OptionButton`（游戏）× `LineEdit`（用户灵敏度）→ 实时写入存档，并带 `Game` / `Sensitivity` 文字标签。
- **渲染缩放滑块**：`QualityRow = [HSlider, QualityValue]`。档位 **0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0**（步长 0.25，`tick_count = 7`），改 `viewport.scaling_3d_scale`，右侧实时显示百分比，上方标签显示 `渲染缩放：W × H (N%)`。样式由 `style_quality_slider()` 用高对比 `StyleBoxFlat` 显式指定。
- **F 键**：`_input()` 监听 `f_pressed` → `Global.toggle_fullscreen()`（输入框有焦点时不拦截）。
- **PLAY**：从当前维度（3D/2D）的模式集合中**随机抽取**一个模式——主打"随机训练"。
- **平台适配**：Web 下隐藏 `Exit`、渲染缩放行与分辨率标签（浏览器无法控制）。

### 5.4 Options（设置页）

- **零硬编码的持久化**：需要在设置页持久化的控件加入 `Persist` 组，`loadSaved()` 按控件类名（`CheckButton` / `LineEdit` / `ColorPickerButton` / `OptionButton`）自动恢复；`PutLabel` 组的控件会被 `putLabel()` 自动包一层带名称标签的 `HBoxContainer`。
- **三个非索引型下拉框**：`Language`（存 locale 字符串）、`Display`（存显示模式枚举）、`WindowSize`（存尺寸索引）不走通用索引读取，分别由 `sync_language_selection()` / `sync_display_selection()` / `sync_window_size_selection()` 同步；`zh` / `es` 变体（如 `zh_TW`）会回退到同语系。
- **切换语言**：`set_locale()` + 落盘 → `refresh_dynamic_texts()` 重译代码生成的文本 → `reload_current_scene()` 重建场景，保证静态文案与动态文案全量切换。
- **准星实时预览**：任意参数变更 → `emit_signal("refresh_crosshair")` → 预览 `Crosshair` 节点 `queue_redraw()`。
- **导入/导出**：桌面走 `FileDialog`；Web 走 `JavaScriptBridge`（需在导出模板 HTML 中注入 `getFile()` 脚本，代码注释里已给出片段）。

### 5.5 Crosshair（准星绘制）

纯 `_draw()` 自绘，无贴图依赖：

- **中心点（Dot）**：边长 `dot_size×2` 的正方形点。
- **四臂（Inner）**：左 / 上 / 右 / 下 四条矩形，由 `CrosshairWidth`（臂长）、`CrosshairHeight`（臂粗）、`CrosshairSpace`（中心间隙）共同决定。
- **描边（Outline）**：`OutlineSize` 线宽 + `OutlineColor`，沿多边形边逐段 `draw_line()`。
- 每次 `_draw()` 都调用 `loadSave()` 重新读档，保证参数即时生效（已知优化项：改为变更时才读档）。

### 5.6 CharacterBody3D（玩家 / FPS 控制器）

| 子系统 | 实现 |
| --- | --- |
| 移动 | `SPEED 20`、`ACCELERATION 50`、`DECCELERATION 5`；方向反向时速度瞬时归零（急停手感） |
| 跳跃 | `JUMP_VELOCITY 25`，重力 `physics/3d/default_gravity × 6` |
| 视角 | `InputEventMouseMotion` → `head.rotate_y()`（水平）/ `camera.rotate_x()`（俯仰，`clamp ±89°`） |
| 灵敏度 | `mouse_sensitivity = user_sensitivity × conversion_sensitivity`；Web 端额外 `× 0.67857142857142857143`（浏览器鼠标采样差异补偿） |
| 射击 | **单路触发**：`_physics_process()` 中 `Input.is_action_just_pressed("fire")` → `fire()`（原线程轮询方案已删除，消除了退出关卡死锁与跨线程读输入的问题） |
| 命中判定 | `Camera3D/RayCast3D`（长度 1000）取 `get_collider()`，在 `Enemy` 组则 `health -= damage` |
| 弹道散布 | 按速度归一化（0~1），最大 **±2°**；仅当移动速度 > `SPEED × 0.3`（即 > 6）时产生散布 → **移动惩罚机制** |
| 统计 | `shot_count` / `hit_count`，用于结算命中率 |
| 计时 | 60 秒倒计时，归零后隐藏 Resume、触发暂停（结算态） |

### 5.7 target.gd / Target2D.gd（靶子）

| | 3D 靶（`CharacterBody3D`） | 2D 靶（`TextureButton`） |
| --- | --- | --- |
| 血量 | `health = 10`，子弹 `damage = 10` → **一枪即毁** | 点击（`pressed` 信号）即毁 |
| 尺寸 | `scale = Vector3(size, size, size)` | `custom_minimum_size = size`（按 1920 基准等比放大，适配 4K） |
| 移动 | 随机初速度各轴 ±10，`move_and_collide` + `bounce(normal)` 碰墙反弹 | 归一化随机方向 × 200 px/s（4K 下等比缩放），父容器边界反弹 |
| 外观 | `SphereMesh` + `StandardMaterial3D`，`_ready()` 用 `TargetColor` 覆盖 | 无贴图时动态创建 `ColorRect` 兜底，同样应用 `TargetColor` |
| 碰撞 | `collision_mask = 9`（1 世界 + 8 靶笼），`groups = ["Enemy"]` | GUI 点击 |

### 5.8 World.gd（3D 关卡主控）

- **刷靶**：`randomize_vector()` 在模式配置的 X/Y 区间内随机，Z 固定 `-25`；`check_distance()` 依据 `last_vectors` 保证最小间距（`size × 2 + 1`），避免重叠穿模；`spawn_target()` 实例化并 `connect("target_kill")`，击杀后**立即补一个**，保持场上靶数恒定。
- **计分与反馈**：`messageHit()` 累加 `count_kills`，更新 HUD 与结算文案，播放 0.2 秒的 `kill` 动画（屏幕中央红色 "X"）。
- **环境守卫**：`full_screen_requested()` 每 0.5s 检查**鼠标是否处于捕获态**（不再要求全屏），不满足则暂停并弹出引导层，点击后应用当前显示模式 + 捕获鼠标 + 恢复。
- **结算**：`_on_timer_timeout()` 计算命中率（命中数 / 射击数），写入并读取历史最佳，文案为 `N 次击杀 · 模式 ｜ 命中率 N% ｜ 最佳 N`。
- **关卡构成**（`World.tscn`）：`Building`（CSG 房间 + 材质贴图）、`PlayerPrison`、`TargetPrison`（`fit_target_prison()` 按模式范围自动调整）、`DirectionalLight3D`、`WorldEnvironment`。

### 5.9 World2D.gd（2D 关卡主控）

- 从 `Global.models2d` 取 `spawn_margin / size / number_of_initial_targets / duration / movement`，全部按 1920 基准缩放以适配 4K。
- 倒计时归零 → `end_game()`：停止刷靶、**暂停场景树**、显示结算面板（本轮得分 + 历史最佳 + `Restart` / `Main Menu`），隐藏 `Resume`，并释放鼠标。
- 暂停输入由常驻的 `PauseInput` 节点（`process_mode = ALWAYS`）转发 `ui_cancel`，结算态忽略暂停切换；窗口失焦同样自动暂停。

### 5.10 Pause.gd（暂停 / 结算）

- 监听 `NOTIFICATION_APPLICATION_FOCUS_OUT`：**窗口失焦即自动暂停**并释放鼠标。
- 面板 `process_mode = 3`（`PROCESS_MODE_ALWAYS`），保证无论场景树是否暂停，按钮都能收到点击。
- 提供 `_on_resume_pressed()` / `_on_restart_pressed()`（`reload_current_scene()`）/ `_on_menu_pressed()`；结算态 `Resume` 隐藏时把键盘焦点交给 `Restart`。

### 5.11 Bullet.gd（弹道特效）

`BULLET_SPEED = 1000`，从摄像机位置飞向 raycast 命中点，到达后若 `hited == true` 则自毁；命中与未命中都会留下可见弹道，用于视觉反馈。

---

## 六、功能清单

### 6.1 核心功能

| # | 功能 | 实现位置 |
| --- | --- | --- |
| F1 | 3D 射击训练（4 模式） | `World.gd` + `CharacterBody3D.gd` + `target.gd` |
| F2 | 2D 点击训练（3 模式） | `World2D.gd` + `Target2D.gd` |
| F3 | 模式实时缩略图预览 | `ModePreview3D.gd` / `ModePreview2D.gd` |
| F4 | 游戏灵敏度换算（Valorant / CS / Fortnite） | `Global.games_sensitivities` + `CharacterBody3D._ready()` |
| F5 | 渲染缩放（**7 档：50%~200%**） | `MainScreen._on_quality_slider_value_changed()` |
| F6 | 准星深度自定义（11 项参数） | `Options.gd` + `Crosshair.gd` |
| F7 | 目标颜色自定义（3D / 2D 均生效） | `Options._on_target_color_color_changed()` + `target/Target2D._ready()` |
| F8 | 配置导入 / 导出（JSON，含 Web 版） | `Options.gd` + `DataManager` |
| F9 | 暂停 / 失焦自动暂停 / 恢复 | `Pause.gd` + `PauseInput.gd` |
| F10 | 鼠标捕获守卫（**不再强制全屏**） | `World.full_screen_requested()` |
| F11 | 60 秒计时与结算（击杀 / 得分 / **命中率** / **历史最佳**） | `World._on_timer_timeout()` / `World2D.end_game()` |
| F12 | 结算原地重开 | `Pause._on_restart_pressed()`（3D / 2D） |
| F13 | **15 语界面**（en / es / zh_CN / zh_TW / zh_HK / ja / ko / fr / de / pt_BR / ru / it / tr / ar / vi，**58 键**） | `translations.csv` + 引擎导入器 / `tools/build_translations.gd` |
| F14 | 运行期语言切换 | `Options._on_language_item_selected()` + 场景重载 |
| F15 | 显示模式：窗口 / 最大化 / 全屏 | `Global.apply_display_mode()` + `DataManager._ready()` |
| F16 | 窗口大小：1280×720 / 1600×900 / 1920×1080 / 2560×1440 | `Global.set_window_size_index()`（选尺寸自动切窗口） |
| F17 | F 键快速切换全屏 / 窗口 | `MainScreen._input()` |
| F18 | 成绩记录持久化 | `Global.save_record() / get_record()` |
| F19 | Web 平台适配 | `OS.has_feature("web")` 分支 + `JavaScriptBridge` |
| F20 | 游戏显示名随语言（无畏契约 / 反恐精英 / 堡垒之夜 …） | `Global.GAME_TR_KEYS` + `game_display_name()` + CSV `GAME_*` 键 |
| F21 | 首页模式按钮等宽、左右两列等高对齐 | `MainScreen.sync_mode_layout()` + `_on_left_column_resized()` |
| F22 | locale 变体智能匹配（`zh_TW` / `zh_HK` / `pt` / `de_DE` …） | `Options.locale_to_index()` |

### 6.2 准星可调参数（完整）

`Crosshair(开关)`、`Crosshair inner(四臂开关)`、`Dot(中心点开关)`、`Outline(描边开关)`、`DotSize`、`OutlineSize`、`CrosshairHeight`、`CrosshairWidth`、`CrosshairSpace`、`CrosshairColor`、`OutlineColor`。默认：青色 `(0,1,1)`、黑色描边、臂长 12 / 臂粗 4 / 间隙 5 / 点径 6 / 描边 2。

---

## 七、玩法详解

### 7.1 3D 模式（`Global.models3d`，统一 Z = −25、60 秒、一枪一靶、击杀即补）

| 模式名（Key） | 靶数 | 靶尺寸 | 是否移动 | X 范围 | Y 范围 | 训练指向 |
| --- | --- | --- | --- | --- | --- | --- |
| `3D_HEAD_LEVEL_V1`（3D head level） | 1 | 0.5 | 否 | 24 → −24 | 4（固定，头线高度） | **头部高度精准定位**：单靶、极小，专练爆头线记忆与首发命中 |
| `3D_MULTIPLE_BASIC_TARGETS_V1` | 6 | 0.5 | 否 | 12 → −12 | 4 → 20 | **静态多目标切换**：小靶密集，练 target switching 与点击精度 |
| `3D_MULTIPLE_BASIC_TARGETS_MOVEMENT_V1` | 6 | 0.5 | 是 | 12 → −12 | 4 → 20 | **动态追踪**：小靶 + 三维随机速度反弹，练 tracking（最难模式） |
| `3D_MULTIPLE_MEDIUM_TARGETS_V1` | 3 | 3 | 否 | 11 → −11 | 4 → 15 | **大靶速射**：靶大、数量少，练快速甩枪与节奏 |

**操作**：鼠标移动视角 · 左键射击 · WASD 移动（**移动会产生弹道散布惩罚，最大 ±2°**）· 空格跳跃 · Esc 暂停。
**结算**：60 秒后暂停并显示 `N 次击杀 · <模式名> ｜ 命中率 N% ｜ 最佳 N`，可 `Restart` 重开或 `Menu` 返回。

### 7.2 2D 模式（`Global.models2d`，统一 60 秒、点击即得分）

| 模式名（Key） | 靶数 | 靶尺寸(px) | 是否移动 | 边距 | 训练指向 |
| --- | --- | --- | --- | --- | --- |
| `2D_GRIDSHOT_V1` | 3 | 60 | 否 | 100 | 经典 Gridshot：大靶三点，练速度与手眼协调 |
| `2D_REFLEX_V1` | 1 | 40 | 否 | 100 | 反应/点击：单靶瞬现瞬灭式点击，练反应速度 |
| `2D_MOVING_TARGETS_V1` | 5 | 40 | 是（200 px/s） | 100 | 2D 追踪：移动靶，练平滑追踪与提前量 |

**操作**：鼠标直接点击靶子 · Esc 暂停。
**结算**：倒计时结束 → 结算面板显示 `得分：N ｜ 最佳：N`，可 `Restart` 重开或 `Main Menu` 返回。

### 7.3 灵敏度换算玩法（核心差异化）

```
mouse_sensitivity(弧度/像素)
    = 用户在 UI 填写的 sensitivity        （默认 0.215 / 占位 0.215）
    × Global.games_sensitivities[游戏]   （Valorant 0.0707… / CS 0.0222… / Fortnite 0.00561…）
    × 0.67857142857142857143             （仅 Web 端）
```

系数以 **4K 分辨率**为基准标定（源码注释 `#4k`），配合 `other/godot-valorant.ods` 换算表维护。玩家只需填入自己在目标游戏里的灵敏度数值，即可在训练器中获得**一致的实际转身速度**。

### 7.4 显示与窗口（2026-10-08 新增）

| 入口 | 行为 |
| --- | --- |
| 设置 → 显示模式 | 窗口（按所选尺寸居中）/ 最大化 / 全屏，写入 `display_mode`，启动即生效 |
| 设置 → 窗口大小 | 1280×720 / 1600×900 / 1920×1080 / 2560×1440；**若当前是全屏会自动切换为窗口**，尺寸按屏幕可用区域收敛 |
| 主菜单 F 键 | 全屏 ↔ 窗口即时切换并落盘（输入框聚焦时不响应） |
| 设置 → 语言 | **15 种**（English / Español / 简体中文 / 繁體中文（台灣）/ 繁體中文（香港）/ 日本語 / 한국어 / Français / Deutsch / Português (Brasil) / Русский / Italiano / Türkçe / العربية / Tiếng Việt），切换后立即重载场景，全量刷新文案（含模式名与游戏名） |

### 7.5 游戏名与模式名的本地化

- 灵敏度换算表的 key（`Valorant` / `CounterStrike` / `Fortnite`）**保持不变**（参与存档与系数查询），界面显示名改由 `Global.game_display_name()` 从 `translations.csv` 的 `GAME_*` 键翻译得到：
  简体中文 → `无畏契约` / `反恐精英 (CS)` / `堡垒之夜`；繁體 → `特戰英豪` / `絕對武力 (CS)` / `堡壘之夜`；日本語 → `ヴァロラント` / `カウンターストライク (CS)` / `フォートナイト`。
- 下拉框建项时把原始 key 写入 `set_item_metadata()`，换算系数一律按 metadata 查，因此**切换语言不会影响已保存的灵敏度**。
- 7 个模式名同样是 CSV 里的翻译键（`3D_HEAD_LEVEL_V1` … `2D_MOVING_TARGETS_V1`），随语言变化。

### 7.6 典型训练循环

```
主菜单（可选：设置显示模式 / 窗口大小 / 语言 / 准星）
   → 选/随机模式 → 进入关卡
   → [鼠标捕获守卫] 点击一次即锁定鼠标（窗口 / 全屏均可）→ 开始
   → 60s 内尽可能多地命中（击杀数↑ / Score↑）
   → 时间到 → 结算面板（击杀 / 得分 ｜ 命中率 ｜ 历史最佳）
   → Restart 原地重开 / Menu 回主菜单
   → 成绩自动写入 records（最佳击杀 / 最佳命中率）
   → Options 微调准星与目标颜色 → 导出配置分享
```

---

## 八、问题与技术债（当前状态）

### 8.1 已修复（2026-10-08，见评估文档 D01–D38）

| 原问题 | 现状 |
| --- | --- |
| 退出 3D 关卡进程卡死（线程死锁） | ✅ 删除射击线程，改为 `_physics_process()` 单路 |
| 2D 暂停后键盘无法恢复 | ✅ `PauseInput`（`process_mode = ALWAYS`） |
| 选游戏灵敏度被踢到设置页 | ✅ 仅保存数据 |
| 一次点击生成两颗子弹 | ✅ 单路触发 |
| 移动中开枪几乎打不中（散布 ±40°） | ✅ 归一化后最大 ±2° |
| 靶子重叠 / 飞出靶笼 | ✅ 间距校验 + `fit_target_prison()` |
| 成绩不落盘 | ✅ `records` 持久化 + 结算展示历史最佳 |
| 2D 无结算 / 结算后按钮失灵 | ✅ 结算面板 + `process_mode = 3` + 暂停场景树 |
| 全屏强制、无窗口模式 | ✅ 显示模式 + 窗口大小 + F 键 |
| 界面英文、语言框与实际语言不一致 | ✅ **15 语 58 键** + 下拉框同步 + 切语言重载场景 + locale 变体匹配 |
| 渲染缩放滑条失效 / 过长 / 档位过细 | ✅ 修复信号连接；宽度 900；7 档 |
| 游戏下拉框显示英文名、不熟悉 | ✅ 显示名随语言（`GAME_*` 键），内部 key 走 metadata |
| 模式按钮被预览容器拉成厚框 | ✅ `SIZE_SHRINK_CENTER` + 统一高度 |
| 右侧模式列表与左列不等高、按钮长短不一 | ✅ `sync_mode_layout()` 等宽 + 按左列高度均分行高 + `resized` 自动重算 |

### 8.2 剩余技术债（不影响可玩性）

| 级别 | 问题 | 位置 | 计划 |
| --- | --- | --- | --- |
| 中 | 配置字段名 `movment`（3D）与 `movement`（2D）不一致 | `global.gd` | ✅ 已修复（统一为 `movement`，`World.gd` 加 `get()` 兜底） |
| 中 | 导入/导出对话框 `current_dir = "/"`，Windows 下落到盘符根目录 | `Options.gd` | ✅ 已修复（`default_save_dir()` 用系统文档目录） |
| 中 | `Crosshair._draw()` 每次重绘都全量 `loadSave()`（且每帧 `new Polygon2D()`） | `Crosshair.gd` | ✅ 已修复（参数缓存 + 描边直接用点数组绘制） |
| 中 | 灵敏度 / 准星尺寸输入框直接 `float()`，非法输入静默写 0 | `MainScreen.gd` / `Options.gd` | ✅ 已修复（D39：`parse_number()` 归一化 + 回退上一次有效值） |
| 低 | 无命中 / 结算音效（README 提到的 `assets/sounds` 不存在） | — | Phase 2 |
| 低 | 2D 模式无自定义准星、灵敏度不生效 | 设计取舍 | Phase 2 |
| 低 | `Target2D.tscn` 使用占位 uid、无贴图 | `scenes/characters/Target2D.tscn` | Phase 3 |
| 低 | 资源组织混乱（`Bullet` 场景在 `levels/`、脚本在 `ui/`；`World.gdshader` 为空） | 目录 | Phase 3 |
| 文档 | README 描述的 `sounds` / `models` / `resources/shaders` 目录不存在 | README | ✅ 已随本次文档重写修正（并补充帮助章节） |
| 低 | 阿拉伯语等 RTL 语言未做布局镜像 | `Options` / `MainScreen` | Phase 3 |

---

## 九、结语

OpenAimTrainer 是一个**结构清晰、体量精简的 Godot 4 训练器原型**：以两个自动加载单例（配置 + 存档）为骨架，以 `Global.game_type` 令牌串起"菜单 → 关卡"的场景流，用数据驱动的方式（`models3d` / `models2d` 字典）定义了 7 个训练模式，并围绕"灵敏度换算"与"准星定制"两个差异化点做深。其 Web + 桌面双平台、配置导入导出的设计，体现了明确的开源分享取向。

截至 2026-10-08 20:45，原型的阻断级缺陷已全部清除，并补齐了**中文界面、成绩记录、结算与重开、窗口/全屏切换**四项刚需能力，已达到"可稳定日常训练使用"的完成度。后续建议按 Phase 1（字段与规范收尾）→ Phase 2（音效、2D 准星、成绩曲线）→ Phase 3（配置 Resource 化、关卡基类、目录整理）推进。

---

*报告生成时间：2026-10-08 19:33 · 最后更新：2026-10-08（UTC+8，15 语言 / 游戏名本地化 / 布局对齐 / 文档补全后） · 分析对象：OpenAimTrainer-main（Godot 4.7 / Apache-2.0）*
*配套文档：`OpenAimTrainer_使用说明.md`（帮助手册）、`OpenAimTrainer_缺陷排查与优化评估报告_20261008.md`、`OpenAimTrainer_优化进度记录_20261008.md`、`OpenAimTrainer_模块架构报告_20261008.md`*
