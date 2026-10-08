# Open Aim Trainer — 模块架构报告

| 项目 | 内容 |
| --- | --- |
| 项目名称 | Open Aim Trainer（开源瞄靶训练器） |
| 引擎版本 | Godot 4.7 stable（项目 `config/features = 4.5 / Forward Plus`） |
| 主场景 | `res://scenes/ui/MainScreen.tscn` |
| 运行平台 | Windows 桌面（主）/ Web（导出，功能降级） |
| 报告版本 | v1.0 |
| 编写时间 | **2026-10-08 20:49** |
| 代码基线 | 2026-10-08 20:26（`translations.csv` 时间戳）/ 20:44 完成翻译编译 |
| 关联文档 | `OpenAimTrainer_项目分析报告_20261008.md`、`OpenAimTrainer_缺陷排查与优化评估报告_20261008.md`、`OpenAimTrainer_优化进度记录_20261008.md` |

---

## 1. 项目总览

### 1.1 定位

一个 FPS 射击训练器：提供 **3D 第一人称练枪**（可移动、可跳跃、带弹道扩散与子弹飞行视觉）与 **2D 点击反应训练**（Gridshot / Reflex / 移动靶）两类玩法，支持灵敏度换算、准星自定义、成绩记录、多语言与配置导入导出。

### 1.2 技术栈

| 层次 | 选型 |
| --- | --- |
| 引擎 | Godot 4.x，Forward+ 渲染后端 |
| 脚本语言 | GDScript（静态/动态混用，`@onready` + `preload`） |
| 场景组织 | 一屏一场景（`change_scene_to_file`），无跨场景常驻节点 |
| 持久化 | `user://open_aim_trainer.json`（`JSON.stringify` / `FileAccess`） |
| 国际化 | CSV 源 → 编译为 3 个 `.translation`，运行时 `TranslationServer` |
| 3D 命中 | `RayCast3D` 射线检测 + `Bullet` 节点做弹道视觉 |
| 2D 命中 | `TextureButton.pressed` 信号 |
| 配置下发 | `Global` 内常量字典（`models3d` / `models2d` / `games_sensitivities`） |
| 构建工具 | `tools/build_translations.gd`（`--headless --script` 命令行工具） |

### 1.3 关键工程约束

- **基准分辨率 3840×2160**（`project.godot`：`viewport_width/height`），`stretch/mode = canvas_items`、`aspect = expand`，`gui/theme/default_theme_scale = 4.0` —— 因此所有 UI 尺寸、滑条样式、2D 靶尺寸都必须按 4K 基准放大，否则在 4K 下不可见。
- **默认全屏**（`window/size/mode = 3`），可通过设置页改为窗口 / 最大化。
- **Web 降级**：`OS.has_feature("web")` 分支下隐藏画质滑条、退出按钮、显示模式切换，导入导出改用 `JavaScriptBridge`。

---

## 2. 项目架构总图

```
┌─────────────────────────────────────────────────────────────────────┐
│ 引擎层  Godot 4.7 (SceneTree / DisplayServer / Input / Translation)  │
├─────────────────────────────────────────────────────────────────────┤
│ 自动加载层 (Autoload)                                                │
│   Global (scripts/global.gd)      —— 配置字典 / 显示模式 / 成绩记录   │
│   DataManager (scripts/data_manager.gd) —— JSON 存档读写 + locale 恢复│
├─────────────────────────────────────────────────────────────────────┤
│ 场景层 (scenes/)                                                     │
│   ui/    MainScreen · Options · ModePreview3D/2D · (Crosshair 内嵌)  │
│   levels/ World(3D) · World2D · Bullet                               │
│   characters/ target.tscn(3D) · Target2D.tscn                        │
├─────────────────────────────────────────────────────────────────────┤
│ 脚本层 (scripts/)  —— 与场景一一对应的 *.gd                          │
│   ui/ · levels/ · characters/                                        │
├─────────────────────────────────────────────────────────────────────┤
│ 资源层 (assets/)   themes · fonts · images · text(翻译)              │
│ 工具层 (tools/)    build_translations.gd                             │
│ 数据层 (user://)   open_aim_trainer.json                             │
└─────────────────────────────────────────────────────────────────────┘
```

**分层原则**：自动加载层是唯一全局单例；场景之间不共享节点，靠 `Global.game_type` 传递"选了哪个模式"，靠 `DataManager` 传递"用户怎么设置的"。

---

## 3. 目录结构与文件清单

```
OpenAimTrainer-main/
├─ project.godot                 引擎配置（autoload / input map / i18n / display）
├─ scripts/
│  ├─ global.gd                  ★ 自动加载：配置字典 + 显示模式 + 成绩记录
│  ├─ data_manager.gd            ★ 自动加载：JSON 存档
│  ├─ ui/
│  │  ├─ MainScreen.gd           主菜单：模式列表生成、灵敏度、画质滑条、F 键
│  │  ├─ Options.gd              设置页：准星/颜色/语言/显示/窗口大小/导入导出
│  │  ├─ Crosshair.gd            准星自绘控件（_draw）
│  │  ├─ Bullet.gd               3D 子弹（由 levels/Bullet.tscn 绑定，目录路径为历史遗留）
│  │  ├─ ModePreview3D.gd        3D 模式缩略图（SubViewport 内程序化建墙 + 摆靶）
│  │  └─ ModePreview2D.gd        2D 模式缩略图
│  ├─ levels/
│  │  ├─ World.gd                3D 关卡：刷靶、命中统计、结算、鼠标捕获守卫
│  │  ├─ World2D.gd              2D 关卡：计时、刷靶、计分、结算、暂停
│  │  ├─ Pause.gd                暂停/结算面板（仅 World.tscn 的 Pause 节点使用）
│  │  └─ PauseInput.gd           常驻输入转发器（process_mode = 3）
│  └─ characters/
│     ├─ CharacterBody3D.gd      玩家：视角/移动/射击/散布/计时
│     ├─ target.gd               3D 靶子（CharacterBody3D + health）
│     └─ Target2D.gd             2D 靶子（TextureButton + 反弹运动）
├─ scenes/  （与 scripts 同名同构的 .tscn）
├─ assets/
│  ├─ themes/{theme,normal,hover}.tres   自定义 UI 主题
│  ├─ fonts/100_outline.tres             描边字体
│  ├─ images/                            Logo / 靶纹理 / 模式封面图
│  └─ text/translations.csv + *.translation
├─ tools/build_translations.gd   CSV → .translation 编译脚本
├─ web/                          Web 导出壳（index.html / icon / svg）
├─ other/                        rcedit、原始数值表 .ods（.gdignore 排除）
└─ docs/                         分析与报告文档
```

---

## 4. 模块详解

### M1 `Global`（`scripts/global.gd`，自动加载）

**职责**：静态配置中心 + 显示模式管理 + 成绩记录。无 `_ready` 逻辑，纯数据/工具。

| 成员 | 类型 | 说明 |
| --- | --- | --- |
| `string_to_vector3d(s)` | func | `"(x,y,z)"` → `Vector3` |
| `string_to_color(s)` | func | `"(r,g,b,a)"` → `Color`（存档里颜色以字符串保存） |
| `games_sensitivities` | Dict | 3 款游戏的 4K 灵敏度换算系数（Valorant / CounterStrike / Fortnite）；**key 同时用于存档，不可改** |
| `GAME_TR_KEYS` | Dict | 游戏 key → 翻译键（`GAME_VALORANT` / `GAME_COUNTERSTRIKE` / `GAME_FORTNITE`） |
| `game_display_name(key)` | func | 按当前界面语言返回游戏显示名（查 `translations.csv` 的 `GAME_*` 行） |
| `models3d` | Dict | 4 个 3D 模式的配置（生成范围、是否移动、尺寸、初始靶数） |
| `models2d` | Dict | 3 个 2D 模式的配置（边距、尺寸、初始靶数、时长、是否移动） |
| `game_type` | var | **跨场景传递当前模式名**的唯一通道 |
| `DISPLAY_WINDOWED/MAXIMIZED/FULLSCREEN` | const | 0 / 2 / 3，对应 `DisplayServer.WindowMode` |
| `WINDOW_SIZES` | Array[Vector2i] | 1280×720 / 1600×900 / 1920×1080 / 2560×1440 |
| `get_display_mode()` / `set_display_mode(mode)` | func | 读写 `DataManager["display_mode"]`，写后立即应用 |
| `apply_display_mode()` | func | 调 `DisplayServer.window_set_mode`；窗口态时按屏幕可用区收敛尺寸并居中 |
| `get_window_size_index()` / `set_window_size_index(i)` | func | 选具体尺寸即隐式切回窗口模式 |
| `toggle_fullscreen()` | func | 全屏 ⇄ 窗口，返回切换后的模式（主菜单 F 键用） |
| `get_record(mode)` / `save_record(mode, score, acc)` | func | 读写 `DataManager["records"]`，取最大分与最高命中率 |

**依赖**：`DataManager`（读取/写入）、`DisplayServer`。**被依赖**：几乎所有模块。

### M2 `DataManager`（`scripts/data_manager.gd`，自动加载）

**职责**：唯一存档出入口。

| 成员 | 说明 |
| --- | --- |
| `file_path` | `user://open_aim_trainer.json` |
| `game_data` | 内存中的 `Dictionary` 缓存（所有读写先走它） |
| `_ready()` | `load_all_data()` → 恢复 `locale` → `Global.apply_display_mode()`（**最早应用显示模式，避免启动闪一下全屏**） |
| `load_all_data(dir)` | `FileAccess` 读 + `JSON.parse`，失败则 `game_data = {}` 并打印 `File not found.` |
| `save_data(key, value)` | 改缓存后**整文件重写**（`JSON.stringify` + `store_line`） |
| `save_all_data(dir)` | 用于导出到任意路径 |
| `load_all_data_from_param(json)` | Web 导入回调使用 |
| `save_all_data_to_file_web()` | `JavaScriptBridge.download_buffer` 触发浏览器下载 |

**存档键表**（见 §6.3）。

### M3 `MainScreen`（`scripts/ui/MainScreen.gd` + `scenes/ui/MainScreen.tscn`）

**职责**：入口界面——模式选择、2D/3D 切换、灵敏度、3D 渲染缩放、退出。

**节点结构（简化）**

```
MainScreen (Control)
├─ BoxContainer/Logo
└─ MarginContainer/ScrollContainer/HBoxContainer
   ├─ VBoxContainer
   │  ├─ Play · HSeparator · CheckButton(2D/3D)
   │  ├─ ResolutionLabel
   │  ├─ QualityRow (HBoxContainer)
   │  │  ├─ QualitySlider (HSlider, tick_count=8, ticks_on_border)
   │  │  └─ QualityValue (Label, 实时百分比)
   │  ├─ HBoxContainer [GameLabel · Game(OptionButton) · SensitivityLabel · Sensitivity(LineEdit)]
   │  ├─ Options · Quit
   └─ VBoxContainer2        ← 模式列表（运行时动态填充）
```

**关键函数**

| 函数 | 说明 |
| --- | --- |
| `_ready()` | 应用显示模式 → `style_quality_slider()` → 填灵敏度游戏列表 → 恢复存档 → `AddGames()` → 绑定 `size_changed` |
| `AddGames()` / `AddGames2D()` | 遍历 `Global.models3d/2d`，动态生成 `HBoxContainer[预览(300×300) + 按钮]`，按钮 `pressed` 绑定 `startTraining(bind(name))`；末尾统一调 `sync_mode_layout()` |
| `sync_mode_layout(buttons)` | `await process_frame` 后按最宽文字统一按钮宽度（×1.1），并按 **左列实际高度**均分行高、按钮几乎撑满行高（上下各 12px），使左右两列等高对齐 |
| `_on_left_column_resized()` | 左列高度变化（字体异步加载 / 切语言 / 2D↔3D）时自动重跑 `sync_mode_layout()` |
| `startTraining(type)` / `startTraining2D(type)` | 写 `Global.game_type`，切换场景；3D 额外 `Input.set_mouse_mode(CAPTURED)` |
| `_on_play_pressed()` | 随机抽一个模式直接开始 |
| `_on_quality_slider_value_changed(v)` | `viewport.scaling_3d_scale = v` + 刷新标签 + 存档 |
| `update_resolution_label()` | 显示"渲染缩放：W × H (N%)"（**注意：改的是 3D 渲染缩放，不是窗口大小**） |
| `style_quality_slider()` | 代码内构造高对比 `StyleBoxFlat`（轨道 / 已填充区 / 滑块）与刻度颜色 |
| `update_ui_visibility(is_3d)` | 3D 才显示灵敏度行、画质行、Options 按钮 |
| `_input(event)` | `f_pressed` 且焦点不在输入框 → `Global.toggle_fullscreen()` |

### M4 `Options`（`scripts/ui/Options.gd` + `scenes/ui/Options.tscn`）

**职责**：准星参数、目标颜色、语言、显示模式、窗口大小、配置导入导出。

**机制要点**

- **`Persist` 组驱动加载**：`loadSaved()` 遍历 `get_nodes_in_group("Persist")`，按节点类名分派（`CheckButton` / `LineEdit` / `ColorPickerButton` / `OptionButton`），以**节点名作为存档键**。
  - 特例：`Language` / `Display` / `WindowSize` 保存的不是索引（分别是 locale 字符串、模式枚举、尺寸索引），`continue` 跳过通用读取，改由 `sync_*_selection()` 单独同步。
- **`PutLabel` 组动态标签**：`putLabel()` 为每个控件前面插入一个 `Label`（文本 `tr(节点名)`），并把映射记入 `put_labels`，供切换语言后手动刷新。
- **信号 `refresh_crosshair`**：所有准星/颜色改动都 `emit_signal`，实时重绘预览准星。

**关键函数**

| 函数 | 说明 |
| --- | --- |
| `_ready()` | Web 注入 `getFile` 回调 → 填充 Language/Display/WindowSize 选项 → `loadSaved()` → 三个 `sync_*` → 处理 `PutLabel` |
| `sync_language_selection()` | 用 `TranslationServer.get_locale()` 反查索引；首次运行把系统 locale 落盘 |
| `locale_to_index(locale)` | 把任意 locale 映射到 `LOCALES` 索引：`zh_TW`/`zh_Hant*` → 繁體（台灣），`zh_HK`/`zh_MO` → 繁體（香港），其余 `zh*` → 简体；再按两字母前缀匹配其余语言；都不中则回退英文 |
| `sync_display_selection()` / `sync_window_size_selection()` | 按 `Global` 当前值设 `selected` |
| `refresh_dynamic_texts()` | 刷新 `put_labels` 与 `DISPLAY_HINT` |
| `_on_language_item_selected(i)` | `set_locale` → 存档 → `refresh_dynamic_texts()` → **`reload_current_scene()`**（彻底重译编辑器静态文案） |
| `_on_display_item_selected(i)` / `_on_window_size_item_selected(i)` | 调 `Global.set_display_mode` / `set_window_size_index` |
| `_on_*_toggled / _on_*_text_changed / _on_*_color_changed` | 逐一 `DataManager.save_data(...)` + `emit_signal("refresh_crosshair")` |
| `_on_export_pressed` / `_on_import_pressed` | 桌面走 `FileDialog`，Web 走 `JavaScriptBridge`；导入后 `load_all_data(path)` + `save_all_data()` 回写 `user://` |

### M5 `Crosshair`（`scripts/ui/Crosshair.gd`）

**职责**：纯 `_draw()` 自绘准星（不依赖贴图），参数全部来自存档。

| 成员 | 说明 |
| --- | --- |
| `loadSave()` | 读 11 个键（开关 4 + 数值 4 + 颜色 2 …），并按参数**预计算四个多边形顶点数组**（dot / left / top / right / bottom inner） |
| `_draw()` | 按开关 `draw_polygon` + `outlinePolygonDrawer()` 描边 |
| `polygonDrawer()` / `outlinePolygonDrawer()` | `draw_polygon` 填充 + `draw_line` 逐边描边 |
| `redraw(_value)` / `_on_options_refresh_crosshair()` | `queue_redraw()` |

**挂载位置**：`World.tscn → Player/Head/Camera3D/Crosshair`（跟随相机中心）；`Options.tscn` 内另有一份用于实时预览。

### M6 `World`（3D 关卡，`scripts/levels/World.gd` + `scenes/levels/World.tscn`）

**节点结构**

```
World (Node3D)
├─ DirectionalLight3D · WorldEnvironment · Building(CSG) · PlayerPrison(CSG)
├─ TargetPrison (CSGBox3D)          ← 由 fit_target_prison() 按模式动态改尺寸
├─ Player (CharacterBody3D, script=CharacterBody3D.gd)
│   └─ CollisionShape3D · Head
│       ├─ Camera3D → RayCast3D → Crosshair
│       ├─ Kill · Timer · Kills (Label)
│       └─ AnimationKill (AnimationPlayer)
├─ CanvasLayer
│   ├─ Pause (Control, script=Pause.gd, process_mode=3)
│   │   └─ ColorRect · Buttons[Kills, Resume, Restart, Menu]
│   ├─ FullScreenRequest      ← 鼠标未捕获时的守卫弹窗
│   └─ MouseCapturedRequested
└─ Timer (60s 倒计时)
```

**关键函数**

| 函数 | 说明 |
| --- | --- |
| `_ready()` | 隐藏弹窗 → 初始化计数 → `fit_target_prison()` → 建常驻 `FullScreenGuard` Timer(0.5s) → 按 `number_of_initial_targets` 刷初始靶 |
| `fit_target_prison()` | 按模式生成范围计算靶笼中心与尺寸，同步子 `CSGBox3D`，防止移动靶飞出 |
| `randomize_vector()` | 在 `spawn_location_x_0/1`、`y_0/1` 范围内随机，固定 `z = -25` |
| `check_distance()` | 与 `last_vectors` 中现存靶比较，最小间距 `size*2 + 1` |
| `spawn_target()` | 最多重试 100 次找到合规坐标 → `target.init(size, id, movement)` → 连接 `target_kill` 信号 |
| `target_killed(id)` | 清坐标缓存 → `messageHit()` → 补刷新靶 |
| `messageHit()` | `count_kills++`、刷新 HUD、`AnimationKill.play("kill")` |
| `full_screen_requested()` | **只校验鼠标是否 CAPTURED**（不再要求全屏）→ 未捕获则显示弹窗并 `paused = true` |
| `_on_full_screen_needed_pressed()` | `Global.apply_display_mode()` + 捕获鼠标 + 关弹窗 + 取消暂停 |
| `_on_timer_timeout()` | 计算命中率 → `Global.save_record()` → 写 `RESULT_TEXT` |

### M7 `Player`（`scripts/characters/CharacterBody3D.gd`）

| 成员 | 说明 |
| --- | --- |
| `_ready()` | 读 `sensitivity_game_value`（换算系数）与 `sensitivity`（用户值）→ `mouse_sensitivity = user × conversion`（Web 再 ×0.6786） |
| `_input(event)` | `InputEventMouseMotion` → `head.rotate_y` / `camera.rotate_x`（俯仰 clamp 到 ±89°）；`ui_cancel` → `emit_signal("pause_game")` |
| `fire()` | `Input.is_action_just_pressed("fire")` 且 `RayCast3D` 命中 → 生成子弹（延迟 `add_child` 到 root + 延迟设 transform）、命中对象在 `Enemy` 组则 `health -= damage`、`hit_count++`；每次开火 `shot_count++`，首发射击启动倒计时 Timer |
| `_physics_process(delta)` | `fire()` → 重力/跳跃 → 加减速移动（`SPEED=20`、`ACCEL=50`、`DECEL=5`）→ 弹道散布 → `move_and_slide()` |
| `random_spread()` | 基础 ±2°，按 `velocity/SPEED` 归一化（**曾因直接用 `velocity.length()` 导致 ±40° 散布，已修复**） |
| `_on_timer_timeout()` | 每秒 -1；归零则显示 `Kills`、隐藏 `Resume`、`emit_signal("pause_game")` 进入结算 |
| `_exit_tree()` | 清理所有子弹实例，避免切场景残留 |

### M8 `target.gd`（3D 靶子）

- `CharacterBody3D`，属于 **`Enemy` 组**（射线命中判定依据）。
- `init(size, id, movement)`：设置缩放；`movement` 为真时赋随机 `lavelocitat` 速度向量。
- `_process()`：`health <= 0` → `emit_signal("target_kill", id)` + `queue_free()`。
- `_physics_process()`：`move_and_collide` + 碰撞法线 `bounce()` 反弹。
- `_ready()`：读 `TargetColor` 生成 `StandardMaterial3D` 覆盖材质。

### M9 `Bullet`（`scripts/ui/Bullet.gd` + `scenes/levels/Bullet.tscn`）

- `Node3D`，`BULLET_SPEED = 1000`。
- `_physics_process`：朝 `target`（射线命中点）匀速直线飞行，用方向点积判断是否"越过"目标点 → 吸附到目标点、置 `has_reached_target`；命中态 `hited` 时下一帧 `queue_free()`。
- `_on_timer_timeout()`：兜底自动销毁。
- 说明：脚本位于 `scripts/ui/` 但语义属于关卡层（历史遗留路径）。

### M10 `World2D`（2D 关卡，`scripts/levels/World2D.gd`）

**节点结构**

```
World2D (Control)
├─ Background (ColorRect)
├─ TargetContainer (Control)
├─ HUD (CanvasLayer) → Score · Timer (Label)
├─ PauseInput (Node, process_mode=3, script=PauseInput.gd)
├─ GameTimer (Timer, 1s)
└─ CanvasLayer → Pause (Control, process_mode=3)
    └─ ColorRect · VBoxContainer[Score, ResumeButton, RestartButton, MenuButton]
```

**关键函数**

| 函数 | 说明 |
| --- | --- |
| `_ready()` | 读 `models2d[game_type].duration` → 刷新 HUD → 刷初始靶 → `$GameTimer.start()` |
| `spawn_target()` | 按 `REFERENCE_WIDTH = 1920` 计算 `ui_scale`，放大间距与靶尺寸（4K 下不至于过小）；随机坐标 → `t.init / set_target_size` → 连接 `target_kill` |
| `_on_target_killed()` | 加分、刷新 HUD、补刷新靶 |
| `_on_game_timer_timeout()` | 每秒 -1；归零 → `end_game()` |
| `end_game()` | 停 Timer → 显示鼠标 → **`get_tree().paused = true`** → `Global.save_record` → 写结算文案 → 隐藏 `ResumeButton` → 显示面板 |
| `toggle_pause()` | 结算态（`!game_active && pause_menu.visible`）下不再响应，避免"恢复已结束的回合" |
| `_notification()` | `NOTIFICATION_APPLICATION_FOCUS_OUT` 且进行中 → 自动暂停 |
| `_on_menu_pressed` / `_on_restart_pressed` | 先 `paused = false` 再切场景 / 重载 |

### M11 `Target2D`（`scripts/characters/Target2D.gd`）

- `TextureButton`，`pressed` → `emit_signal("target_kill")` + `queue_free()`。
- `init(size_px, id, movement)`：移动模式给随机单位向量 × 200 速度并 `set_process(true)`。
- `set_target_size()`：设 `custom_minimum_size`；无贴图时动态挂一个 `ColorRect`（`MOUSE_FILTER_IGNORE`）作外观。
- `_process()`：边界反弹（父容器 / `SubViewportContainer` / `get_viewport_rect()` 三级兜底）。
- `_ready()`：`modulate = TargetColor`（着色同时作用于动态 `ColorRect`）。

### M12 `Pause` / `PauseInput`（暂停与结算）

> 两种关卡的 `Pause` 节点**布局相似但实现不同**：3D 的 `Pause` 挂 `Pause.gd`；2D 的 `Pause` **无脚本**，三个按钮的信号直接连到 `World2D.gd` 的方法。二者共享的关键约定只有 `process_mode = 3`。

| 模块 | 说明 |
| --- | --- |
| `Pause.gd`（仅 3D） | `trigger_pause(state)` 统一处理：`paused = state`、面板 `visible`、焦点分配（结算态 `Resume` 隐藏则聚焦 `Restart`）、鼠标模式切换、发 `pause_game`/`resume_game` 信号；`_notification(FOCUS_OUT)` 自动暂停；`_on_menu_pressed` / `_on_restart_pressed` 先取消暂停再切场景/重载 |
| `World2D` 内结算/暂停（2D） | `toggle_pause()`、`end_game()`、`_on_resume_pressed`、`_on_restart_pressed`、`_on_menu_pressed` 直接操作 `CanvasLayer/Pause` 的 `visible` 与子节点可见性 |
| `PauseInput.gd` | `process_mode = 3` 的常驻 `Node`，`_input` 中监听 `ui_cancel` 并 `emit_signal("pause_toggled")`（因为 `paused = true` 后普通节点的 `_input` 不再被调用，2D 关卡靠它才能用 Esc 恢复） |
| 场景侧 | `World.tscn` / `World2D.tscn` 的 `Pause` 节点均为 **`process_mode = 3`（ALWAYS）**，保证树暂停时按钮仍可点击 |

### M13 `ModePreview3D` / `ModePreview2D`

- `SubViewportContainer` + `SubViewport`，在主菜单每个模式按钮旁渲染 300×300 缩略图。
- `setup_scene(mode_name, mode_data)`：清空旧靶 → 按模式数据摆放最多 5 个靶（位置 clamp 到可视安全区）→ 3D 版额外程序化生成 6 面 `StaticBody3D` 墙（`create_walls()`），并把移动靶的 z 速度强制为 0 以保证预览稳定。
- 关键注释：`init()` 不设置尺寸，**必须再调 `set_target_size()`**（2D 版已处理）。

### M14 国际化（i18n）

| 组成 | 说明 |
| --- | --- |
| `assets/text/translations.csv` | 源表，首行 `key,<locale>...`，现为 **15 个 locale 列 × 58 条**（含模式名、准星参数、结算文本、显示提示与 `GAME_*` 游戏名） |
| `tools/build_translations.gd` | 自写 CSV 解析（支持引号、引号内逗号、`""` 转义）；**输出语言由 CSV 表头动态决定**，逐 locale `Translation.add_message` → `ResourceSaver.save` 出 `translations.<locale>.translation` |
| `project.godot → locale/translations` | 注册 **15 个** `.translation`，`fallback = en` |
| `translations.csv.import` | 引擎导入器配置，`dest_files` 需与 CSV 列一一对应（新增语言时同步更新） |
| 运行时切换 | `Options._on_language_item_selected` → `set_locale` → 刷新动态文本 → `reload_current_scene()` |
| 启动恢复 | `DataManager._ready` 按存档 `locale` 调 `set_locale` |

**15 种语言**（`Options.LOCALES`，顺序即下拉框顺序）：
`en` · `es` · `zh_CN` · `zh_TW` · `zh_HK` · `ja` · `ko` · `fr` · `de` · `pt_BR` · `ru` · `it` · `tr` · `ar` · `vi`

**构建命令**（改 CSV 后必须执行，二者选一）：

```powershell
# 推荐：引擎导入器，按 CSV 列自动生成全部 15 个 .translation
godot --headless --path . --import

# 备选：自写脚本（同样按表头生成）
godot --headless --path . --script res://tools/build_translations.gd
```

### M15 主题与资源

`assets/themes/theme.tres`（主）、`normal.tres` / `hover.tres`（按钮态）、`assets/fonts/100_outline.tres`（描边字体，用于 HUD 文字在任意背景下可读）。

### M16 Web 适配

- `JavaScriptBridge.create_callback(file_parser)` + `window.getFile(cb)` 实现文件导入；`download_buffer` 实现导出。
- UI 上隐藏画质滑条 / 分辨率标签 / 退出按钮；`Global.apply_display_mode()` 直接 return（不允许改窗口模式）。
- 灵敏度额外乘 `0.6786`（Web 画布缩放补偿）。
- `web/` 目录为导出壳；`other/rcedit-x64.exe` 用于 Windows 图标替换。

---

## 5. 结构关系

### 5.1 模块依赖图

```
                 ┌──────────┐
                 │  Global  │◀───────────────┐
                 └────┬─────┘                │
             读/写     │  提供配置字典         │
                 ▼    │                      │
            ┌──────────────┐           ┌─────┴─────┐
            │ DataManager  │◀──读──────│ MainScreen│
            └──────┬───────┘           └─────┬─────┘
                   ▲                          │ Global.game_type
       读设置       │                          ▼
   ┌───────────────┼──────────────────┬───────────────┐
   │               │                  │               │
┌──┴───┐      ┌────┴─────┐      ┌─────┴────┐    ┌─────┴─────┐
│World │      │Character │      │  target  │    │  World2D  │
│ (3D) │─────▶│ Body3D   │─────▶│  3D 靶   │    │   (2D)    │
└──┬───┘  生成 │ 玩家     │ 射线  └───────────┘    └─────┬─────┘
   │          └────┬─────┘                              │
   │               │ 实例化                              │ 实例化
   │          ┌────▼─────┐                        ┌──────▼──────┐
   ├─────────▶│  Bullet  │                        │  Target2D   │
   │          └──────────┘                        └─────────────┘
   │  Pause ◀── pause_game 信号                 PauseInput ──▶ toggle_pause
   │  Crosshair(自绘)                            Pause(结算/暂停)
   └─────────────────────────────────────────────────────────
                        Options ──refresh_crosshair──▶ Crosshair
                        Options ──DataManager──▶ user://*.json
```

### 5.2 信号与事件一览

| 发出者 | 信号 | 接收者 / 处理 | 触发时机 |
| --- | --- | --- | --- |
| `target.gd` | `target_kill(id)` | `World.target_killed` | 3D 靶 `health <= 0` |
| `Target2D.gd` | `target_kill` | `World2D._on_target_killed` | 点击 2D 靶 |
| `CharacterBody3D.gd` | `pause_game` | `Pause._on_player_pause_game` | Esc 按下 / 60s 结束 |
| `PauseInput.gd` | `pause_toggled` | `World2D.toggle_pause` | 2D 中按 Esc（树暂停也有效） |
| `Options.gd` | `refresh_crosshair` | `Crosshair._on_options_refresh_crosshair` | 任意准星/颜色设置变更 |
| `Timer`(World) | `timeout` | `Player._on_timer_timeout` + `World._on_timer_timeout` | 3D 每秒 / 结束 |
| `GameTimer`(World2D) | `timeout` | `World2D._on_game_timer_timeout` | 2D 每秒 |
| `FullScreenGuard` | `timeout` | `World.full_screen_requested` | 3D 每 0.5s 校验鼠标捕获 |
| 引擎 | `viewport.size_changed` | `MainScreen.update_resolution_label` | 窗口/缩放变化 |
| 引擎 | `NOTIFICATION_APPLICATION_FOCUS_OUT` | `Pause.trigger_pause(true)` / `World2D.toggle_pause` | 窗口失焦 |

### 5.3 场景切换关系

```
MainScreen ──Play/模式按钮──▶ World.tscn (3D)
          ──模式按钮(2D)────▶ World2D.tscn (2D)
          ──Options────────▶ Options.tscn ──Back──▶ MainScreen
World     ──Restart────────▶ reload_current_scene()
          ──Menu───────────▶ MainScreen.tscn
World2D   ──Restart────────▶ reload_current_scene()
          ──Menu───────────▶ MainScreen.tscn
```

> 所有跨场景跳转前都会显式 `get_tree().paused = false`，否则回到主菜单后整个 UI 仍处于暂停态（点击无响应）。

---

## 6. 运行流程

### 6.1 启动流程

```
1. 引擎加载 project.godot
   ├─ 注册 autoload：Global → DataManager（顺序即初始化顺序）
   ├─ 注册 3 个 .translation（locale/fallback = en）
   └─ 应用 display 设置：3840×2160、mode=3（全屏）、stretch=canvas_items/expand
2. DataManager._ready()
   ├─ load_all_data()  ← user://open_aim_trainer.json（不存在则空字典）
   ├─ TranslationServer.set_locale(存档 locale)   ← 若无存档则跟随系统
   └─ Global.apply_display_mode()                ← 最早恢复显示模式
3. 载入 MainScreen.tscn
4. MainScreen._ready()
   ├─ Global.apply_display_mode()（非 Web 再确认一次）
   ├─ style_quality_slider()  ← 高对比滑条样式
   ├─ AddGamesSensitivities() ← 填 Valorant/CS/Fortnite
   ├─ 恢复 resolution / sensitivity / sensitivity_game / is_3d_mode
   ├─ AddGames() 或 AddGames2D()  ← 动态生成模式列表 + SubViewport 预览
   └─ update_ui_visibility() + update_resolution_label()
```

### 6.2 3D 训练主循环

```
[进入] MainScreen.startTraining(type)
        └─ Global.game_type = type；鼠标 CAPTURED；change_scene World.tscn
[World._ready]
        └─ fit_target_prison() → 按模式刷 N 个初始靶 → 启动 FullScreenGuard(0.5s)
[每帧] CharacterBody3D._physics_process
        ├─ fire()：is_action_just_pressed("fire")
        │     ├─ RayCast3D 命中？
        │     │    ├─ 是 → 生成 Bullet（延迟入树 + 延迟设 transform）
        │     │    │       目标在 Enemy 组 → health -= 10；hit_count++
        │     │    └─ 否 → 仅计 shot_count
        │     └─ 首发射击 → 启动 60s Timer
        ├─ 重力 / 跳跃 / 加减速移动 / move_and_slide()
        └─ random_spread() → RayCast3D 随机偏转（±2° × 速度比）
[命中] target.health <= 0 → target_kill(id)
        └─ World.target_killed → last_vectors.erase → messageHit() → 补刷新靶
[0.5s] FullScreenGuard → 鼠标未捕获？显示守卫弹窗 + paused
[60s]  Timer.timeout
        ├─ Player._on_timer_timeout：显示 Kills、隐藏 Resume、emit pause_game
        └─ World._on_timer_timeout：算命中率 → Global.save_record → RESULT_TEXT
[结算] Pause.trigger_pause(true) → 面板可见（process_mode=3 保证按钮可点）
        └─ Restart → reload；Menu → paused=false → MainScreen
```

### 6.3 2D 训练主循环

```
[进入] MainScreen.startTraining2D(type) → Global.game_type = type → World2D.tscn
[World2D._ready] 读 duration → 刷初始靶 → GameTimer.start(1s)
[每秒] time_left -= 1 → 刷新 HUD → <=0 则 end_game()
[点击] Target2D.pressed → target_kill → score++ → 刷新 HUD → spawn_target()
[结算] end_game()：停 Timer → 鼠标可见 → get_tree().paused = true
        → save_record → 写结算文案 → 隐藏 ResumeButton → pause_menu.visible = true
[Esc]  PauseInput._input(ui_cancel) → pause_toggled → toggle_pause()
```

### 6.4 数据持久化键表

| 键 | 类型 | 写入方 | 读取方 |
| --- | --- | --- | --- |
| `sensitivity` | float | `MainScreen._on_sensitivity_text_changed` / 首次运行 | `Player._ready`（`user_sensitivity`） |
| `sensitivity_game` | int(索引) | `MainScreen._on_game_item_selected` | `MainScreen._ready`（`game.selected`） |
| `sensitivity_game_value` | float | 同上（`games_sensitivities` 查表） | `Player._ready`（`conversion_sensitivity`） |
| `resolution` | float | `_on_quality_slider_value_changed` | `MainScreen._ready`（`scaling_3d_scale`） |
| `is_3d_mode` | bool | `_on_check_button_toggled` | `MainScreen._ready`（CheckButton 状态） |
| `locale` | String | `Options._on_language_item_selected` / `sync_language_selection` | `DataManager._ready` |
| `display_mode` | int | `Global.set_display_mode` | `Global.apply_display_mode` |
| `window_size` | int(索引) | `Global.set_window_size_index` | `Global.apply_display_mode` |
| `records` | Dict | `Global.save_record(mode, score, acc)` | `get_record(mode)` |
| `Crosshair` / `Outline` / `CrosshairInner` / `Dot` | bool | `Options._on_*_toggled` | `Crosshair.loadSave` |
| `DotSize` / `OutlineSize` / `CrosshairHeight` / `CrosshairWidth` / `CrosshairSpace` | float | `Options._on_*_text_changed` | `Crosshair.loadSave` |
| `CrosshairColor` / `OutlineColor` / `TargetColor` | String(Color) | `Options._on_*_color_changed` | `Crosshair.loadSave` / `target._ready` / `Target2D._ready` |
| `Persist` 组同名键 | — | 由 `Options.loadSaved()` 按节点名读写 | 同左 |

### 6.5 设置变更 → 生效路径

| 设置项 | 生效方式 |
| --- | --- |
| 准星 / 颜色 | 写存档 → `emit refresh_crosshair` → `Crosshair.queue_redraw()`（**立即**，3D 关卡内需重新进入才可见新准星实例） |
| 目标颜色 | 写存档 → 下次生成靶子时 `target._ready` / `Target2D._ready` 读取生效 |
| 灵敏度 | 写存档 → **下次进入 3D 关卡** `Player._ready` 重算 `mouse_sensitivity` |
| 3D 渲染缩放 | 立即改 `viewport.scaling_3d_scale`（当前场景即生效）+ 存档 |
| 显示模式 / 窗口大小 | `Global.set_*` → 立即 `apply_display_mode()` → `DisplayServer` |
| 语言 | `set_locale` → 刷新动态文本 → `reload_current_scene()`（**立即重载**） |

---

## 7. 技术方案要点

### 7.1 配置驱动的模式系统

模式不写死在场景里，而是 `Global.models3d / models2d` 两个字典；主菜单遍历字典**动态生成按钮与预览**，关卡 `_ready` 再按 `Global.game_type` 查表取参数。新增模式 = 加一条字典 + 加一张封面图 + 加一条翻译键，无需新建场景。

### 7.2 无状态跨场景通信

`change_scene_to_file` 会销毁全部节点，故用两个"全局通道"：
- `Global.game_type`（字符串）—— 传递"当前模式"；
- `DataManager`（JSON 存档）—— 传递"用户设置"。

代价：设置改动大多**下一次进入关卡才生效**（准星/灵敏度），这是当前架构的固有取舍。

### 7.3 命中判定：射线 + 视觉弹道分离

`RayCast3D.is_colliding()` 做**瞬时判定**（含随机散布），`Bullet` 节点只负责"看得见的弹道飞行"（1000 单位/秒直线插值），命中与否在开火瞬间已决定。这样既保证手感确定性，又保留弹道反馈。伤害 `damage = 10`、靶子 `health = 10`，一枪一杀。

### 7.4 灵敏度换算

```
mouse_sensitivity = user_sensitivity × conversion_sensitivity
conversion_sensitivity = games_sensitivities[所选游戏]   （4K 基准换算系数）
Web 平台额外 × 0.67857142857142857143
```
视角：`head.rotate_y(-dx × s)`、`camera.rotate_x(-dy × s)`，俯仰 clamp ±89°。

### 7.5 暂停与输入的三种 `process_mode`

| 节点 | `process_mode` | 原因 |
| --- | --- | --- |
| `World/World2D` 主节点 | 默认（INHERIT/PAUSABLE） | 树暂停时停止物理与计时 |
| `CanvasLayer/Pause` | **3（ALWAYS）** | 树暂停时按钮仍需接收 `_gui_input`（2D 结算未暂停树时也要可点） |
| `PauseInput`（2D） | **3（ALWAYS）** | 树暂停后普通节点收不到 `_input`，靠它转发 Esc |

> 这是本项目最容易踩坑的点：把面板设为 `2（WHEN_PAUSED）` 会导致"未暂停树时按钮点了没反应"（缺陷 D30）。

### 7.6 分辨率与缩放三层

1. **窗口尺寸**：`DisplayServer.window_set_size`（`WINDOW_SIZES`，按屏幕可用区收敛并居中）；
2. **渲染缩放**：`viewport.scaling_3d_scale`（画质滑条 **0.5–2.0，步进 0.25，7 档**）——只影响 3D 内部分辨率，**不改窗口大小**；
3. **UI 缩放**：`stretch = canvas_items` + `theme/default_theme_scale = 4.0`，2D 靶尺寸另按 `REFERENCE_WIDTH = 1920` 做 `ui_scale` 放大。

### 7.7 国际化管线

```
translations.csv（源，首行 key,<locale>×15）
   │  godot --headless --path . --import
   │  （或 --script tools/build_translations.gd）
   ▼
translations.{en,es,zh_CN,zh_TW,zh_HK,ja,ko,fr,de,pt_BR,ru,it,tr,ar,vi}.translation
   │  project.godot: locale/translations 注册 15 个
   ▼
运行时 tr(key) ── 场景内静态文本自动翻译
代码生成的文本（PutLabel / QualityValue / DISPLAY_HINT）── 需手动 refresh_dynamic_texts()
   └─ 彻底切换：reload_current_scene()
```

### 7.8 准星自绘

不依赖贴图：`loadSave()` 把参数预计算成 5 组 `Vector2` 顶点数组（中心点 + 上下左右四臂），`_draw()` 用 `draw_polygon` 填充 + `draw_line` 逐边描边。好处：任意分辨率清晰、参数即时预览；代价：每次 `queue_redraw()` 都重新读一遍存档。

### 7.9 模式预览

`SubViewportContainer + SubViewport` 隔离渲染：3D 版程序化生成 6 面 `StaticBody3D` 墙并 clamp 靶位置；2D 版按 300×300 视口等比缩放。两者都在 `setup_scene()` 中先 `queue_free()` 旧靶，避免切换 2D/3D 时残留。

### 7.10 输入映射（`project.godot`）

| Action | 按键 | 用途 |
| --- | --- | --- |
| `left/right/up/down` | A / D / W / S | 3D 移动 |
| `jump` | Space | 跳跃 |
| `fire` | 鼠标左键 | 开火 |
| `esc` | Esc | （保留） |
| `f_pressed` | F | 主菜单切换全屏/窗口 |
| `ui_cancel`（引擎内置） | Esc | 暂停 |

---

## 8. 已知约束与技术债

| 项 | 说明 | 建议 |
| --- | --- | --- |
| 设置延迟生效 | 准星/灵敏度/目标颜色需重进关卡 | 改为信号驱动或设置页直接改全局单例 |
| `scripts/ui/Bullet.gd` 位置错位 | 关卡层脚本放在 `ui/` | 迁至 `scripts/levels/` |
| 每次 `save_data` 全量重写文件 | 单键修改也整文件序列化 | 可接受（键数少），但需注意并发写 |
| `load_all_data` 无异常兜底 | 存档损坏 → `game_data = {}` → 设置全部回默认 | 加 schema 校验 + 备份 |
| `Crosshair._draw()` 每次重读全部存档 | 高频重绘下有冗余 IO | ✅ 已修复（2026-10-08）：参数在 `_ready()` / `refresh_crosshair` 时加载，`_draw()` 只做懒加载兜底；描边不再每帧 `new Polygon2D()` |
| `ModePreview3D` 中大量手工 clamp 常量 | 可维护性一般 | 抽成配置或统一坐标映射函数 |
| `scenes/ui/*.tmp`、`assets/images/games/3d_F1FE.tmp` | 编辑器临时残留文件 | 清理并加入 `.gitignore` |
| 翻译为生成物 | 改 CSV 后必须跑编译脚本 | 可挂到导出前钩子 |

---

## 9. 附录

### 9.1 命令速查

```powershell
# 编译翻译（改 CSV 后必做）
godot --headless --path . --script res://tools/build_translations.gd

# 无头启动冒烟检查
godot --headless --path . --quit-after 150

# 运行临时校验脚本
godot --headless --path . --script res://<script>.gd
```

### 9.2 关键数值

| 项 | 值 |
| --- | --- |
| 基准分辨率 | 3840 × 2160 |
| UI 主题缩放 | 4.0 |
| 3D 时长 | 60 s |
| 2D 时长 | 60 s（`models2d[*].duration`） |
| 移动速度 / 加速度 / 减速度 | 20 / 50 / 5 |
| 子弹速度 | 1000 |
| 靶子血量 / 单发伤害 | 10 / 10 |
| 弹道散布 | ±2° ×（速度 / 最大速度） |
| 渲染缩放范围 | **0.5 – 2.0（步进 0.25，7 档，默认 1.0）** |
| 窗口尺寸档位 | 1280×720 / 1600×900（默认）/ 1920×1080 / 2560×1440 |
| 翻译条目 | **58 条 × 15 语言** |
| 默认灵敏度 / 换算 | 0.215（Valorant）；Web 端再 ×0.6786 |

### 9.3 模式清单

| 3D 模式 | 靶数 | 尺寸 | 移动 | 生成范围 |
| --- | --- | --- | --- | --- |
| `3D_HEAD_LEVEL_V1` | 1 | 0.5 | 否 | x ±24，y 4 |
| `3D_MULTIPLE_BASIC_TARGETS_V1` | 6 | 0.5 | 否 | x ±12，y 4–20 |
| `3D_MULTIPLE_BASIC_TARGETS_MOVEMENT_V1` | 6 | 0.5 | **是** | x ±12，y 4–20 |
| `3D_MULTIPLE_MEDIUM_TARGETS_V1` | 3 | 3 | 否 | x ±11，y 4–15 |

| 2D 模式 | 靶数 | 尺寸 | 移动 | 时长 |
| --- | --- | --- | --- | --- |
| `2D_GRIDSHOT_V1` | 3 | 60 px | 否 | 60 s |
| `2D_REFLEX_V1` | 1 | 40 px | 否 | 60 s |
| `2D_MOVING_TARGETS_V1` | 5 | 40 px | **是** | 60 s |

---

---

## 10. 变更记录（2026-10-08 增补）

| 变更 | 涉及文件 | 说明 |
| --- | --- | --- |
| 语言由 3 种扩至 **15 种** | `assets/text/translations.csv`、`translations.csv.import`、`project.godot`、`scripts/ui/Options.gd` | CSV 列 → 15 个 locale；`LOCALES` / `LOCALE_NAMES` 与下拉框同步；`locale_to_index()` 处理 `zh_TW` / `zh_HK` / `pt` 等变体 |
| 游戏显示名随语言 | `scripts/global.gd`、`translations.csv`（`GAME_*` 键）、`scripts/ui/MainScreen.gd` | 内部 key 存 `set_item_metadata`，显示名走 `tr()`，换算系数与旧存档不受影响 |
| 首页左右列等高对齐 | `scripts/ui/MainScreen.gd` | `sync_mode_layout()` + `_on_left_column_resized()`；按钮等宽、行高按左列高度均分 |
| 翻译编译脚本自适应 | `tools/build_translations.gd` | 输出语言由 CSV 表头动态决定，新增语言无需改脚本 |
| 文档补全 | `README.md`、`docs/OpenAimTrainer_使用说明.md` | README 新增帮助章节；新增独立使用手册 |

*报告结束 · 编写于 2026-10-08 20:49 · 增补于 2026-10-08（15 语言与布局对齐后）*
