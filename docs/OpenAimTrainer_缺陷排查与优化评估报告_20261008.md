# OpenAimTrainer 缺陷排查与优化评估报告（含汉化落地）

| 项目 | 内容 |
| --- | --- |
| 报告名称 | OpenAimTrainer 缺陷排查 / 优化评估 / 中文本地化报告 |
| 报告时间 | 2026-10-08 |
| 最后更新 | 2026-10-08（UTC+8，第五轮后） |
| 分析对象 | OpenAimTrainer-main（Godot 4.7 项目，Apache-2.0） |
| 验证环境 | Godot v4.7.stable.win64（`K:\Godot_v4.7-stable_win64\Godot.exe`）、Windows、headless 冒烟 + 实际试玩 |
| 本次结论 | 累计定位 **46 项缺陷**（D01–D46）；**39 项已修复**（含全部 4 项 P0 阻断级、全部影响体验项），**7 项为工程规范 / 素材类建议**；**本地化已扩至 15 语并通过抽样验证（58 键 × 15 语）** |
| 第一轮 | 静态审计 + 无头冒烟：P0 阻断 4 项、手感与数据 8 项、工程规范 12 项（D01–D24），并落地汉化 |
| 第二轮 | 依据实际试玩反馈，追加修复弹道散布、全屏二次弹窗、2D 靶过小、结算重开、成绩记录、结算按钮失灵等 6 项（D25–D30） |
| 第三轮 | 语言下拉与实际语言不同步、画质滑条看不清、没有窗口模式等 6 项（D31–D36） |
| 第四轮 | 滑条信号失效、窗口尺寸不生效、滑条过长档位过细等 3 项（D34 / D37 / D38） |
| 第五轮 | 语言扩容至 15 种、游戏显示名随语言、模式按钮厚度与等宽、左右两列等高对齐，以及由此引入的脚本解析错误修复（D39–D43） |
| 第六轮 | 数值输入校验、导入 / 读档健壮性增强、模式按钮改单选选中（D44–D46） |
| 第七轮 | 2D 主菜单与 3D 观感对齐：按钮样式与选中态、行高与预览可见性、按钮跨维度统一宽度、左列按钮长度；设置页「返回」移到右下角（D47–D50） |
| 进度明细 | 见 `OpenAimTrainer_优化进度记录_20261008.md` |

---

## 一、总体评估

| 维度 | 评分（5 分制） | 说明 |
| --- | --- | --- |
| 架构清晰度 | 4 | 单例 + 数据驱动模式表，结构轻量易读 |
| 功能完整度 | 2.5 | 3D 可玩；2D 缺结算、缺成绩记录、缺音效 |
| 稳定性 | 1.5 | **退出关卡存在卡死**、暂停后无法用键盘恢复 |
| 手感/核心体验 | 3 | 灵敏度换算 + 移动散布设计合理，但默认值不一致、射击双路触发 |
| 可用性/易用性 | 2 | 下拉框误跳转、参数标签无说明、结算缺失 |
| 国际化 | 1 → 4（修复后） | 原仅有 en/es 且只覆盖 4 个键，现已补齐 zh_CN 与运行期切换 |
| 工程规范 | 2.5 | 字段名拼写不一致、资源目录混乱、注释掉的死代码较多 |

**一句话结论**：项目是"能跑通主流程的原型"，但存在**退出关卡卡死**与**2D 暂停不可恢复**两个阻断级缺陷，加上若干"手感与数据不正确"的问题，正是"不好用"的直接来源；本次已修复阻断项与高优先级项，并完成中文本地化。

---

## 二、Debug 排查方法

1. **静态审计**：逐文件通读 14 个 `.gd` + 9 个 `.tscn`，比对脚本引用与场景节点路径、信号连接与回调签名。
2. **配置核对**：检查 `project.godot` 自动加载顺序、输入映射、i18n 资源列表与 `assets/text/*.import` 的 `dest_files` 是否一致。
3. **无头冒烟**：`godot --headless --path <proj> --quit-after 200`，过滤 `ERROR / Parse Error / Failed / null`，验证脚本零报错。
4. **翻译验证**：临时 `extends SceneTree` 脚本切换 `en / es / zh_CN` 三种 locale 打印 `tr()` 结果（验证后已删除临时文件）。
5. **资源重导入**：`godot --headless --path <proj> --import` 生成 `.translation` 资源。

---

## 三、缺陷清单

### 3.1 P0 —— 阻断级（已修复）

| ID | 现象 | 根因定位 | 修复方式 |
| --- | --- | --- | --- |
| **D01** | 3D 关卡点 `Menu` 返回主菜单时**进程卡死/无响应** | 射击子线程循环条件为 `while not get_tree().paused`，退出场景时树并未暂停，线程永不结束；而 `_exit_tree()` 调用 `thread.wait_to_finish()` 同步阻塞主线程 → 死锁 | 删除射击线程，射击判定统一放入 `_physics_process()`（帧精确，且无跨线程读 `Input` 的线程安全问题） |
| **D02** | 2D 模式按 Esc 暂停后，**再按 Esc 无反应**，只能用鼠标点 Resume | `SceneTree.paused = true` 后，`process_mode` 为 INHERIT 的节点不再收到 `_input`，`World2D._input()` 失效 | 新增 `scripts/levels/PauseInput.gd`（`process_mode = PROCESS_MODE_ALWAYS`），在 `World2D.tscn` 中以 `PauseInput` 节点常驻接收 `ui_cancel`，转发 `pause_toggled` 信号 |
| **D03** | 主菜单选择游戏灵敏度（Valorant/CS/Fortnite）后**被直接踢到设置页** | `MainScreen._on_game_item_selected()` 末尾多余一行 `get_tree().change_scene_to_file("Options.tscn")` | 删除该跳转，仅保存 `sensitivity_game` / `sensitivity_game_value` |
| **D04** | 一次点击**可能生成两颗子弹**、射击计数翻倍；且高帧率下偶发**吞射击** | `fire()` 被线程（50ms 轮询）与 `_physics_process()` 双路调用；轮询采样必然漏掉 `is_action_just_pressed()` 为真的那一帧 | 只保留 `_physics_process()` 单路调用 |

```111:111:scripts/characters/CharacterBody3D.gd
	fire()
```

### 3.2 P1 —— 影响手感与数据正确性

| ID | 现象 | 根因定位 | 状态 |
| --- | --- | --- | --- |
| **D05** | 2D 模式 60 秒结束后**没有结算**，只把计时文本改为 `Finished!` | `World2D.end_game()` | ✅ 已修复：复用暂停面板显示最终得分，隐藏"继续"按钮 |
| **D06** | 主菜单灵敏度输入框显示 `0.215`，实际却按 `0.14` 计算，手感与显示不一致 | `CharacterBody3D.gd` 中 `user_sensitivity = 0.14` 为硬编码兜底；用户从不改动输入框则永不写档 | ✅ 已修复：首次运行把输入框默认值落盘；无存档时默认选中第 0 项游戏 |
| **D07** | 选择 Valorant（索引 0）后**下次启动不恢复** | `MainScreen._ready()` 用 `if DataManager.get_data(...)` 做真值判断，`0` 被判为假 | ✅ 已修复：统一改为 `!= null` 判断 |
| **D08** | 设置页改"目标颜色"后 **2D 模式无效** | 仅 3D 的 `target.gd` 读取 `TargetColor`，`Target2D.gd` 未处理 | ✅ 已修复：`Target2D._ready()` 应用 `modulate` |
| **D09** | 3D 多目标模式靶子**重叠/穿模** | `World.check_distance()` 内防重叠逻辑被整段注释，`spawn_target()` 的 while 循环恒不生效 | ✅ 已修复（用 `last_vectors` 记录场上靶坐标，最小间距 `size × 2 + 1`） |
| **D10** | **任何训练成绩都不落盘**，退出即失忆，无历史/最佳记录 | `DataManager` 仅存设置项 | ✅ 已修复（`Global.save_record/get_record`，结算页展示历史最佳） |
| **D11** | 3D 60 秒结算后**无法原地重开**，只能回主菜单 | `CharacterBody3D._on_timer_timeout()` 隐藏 Resume 只留 Menu | ✅ 已修复（3D / 2D 均新增 `Restart` 按钮） |
| **D12** | 移动靶可能**逃出靶笼**或穿墙 | 刷靶 Y 区间为 4~20，`TargetPrison` 覆盖范围偏小；`move_and_collide` 后仅做一次 `bounce` | ✅ 已修复（`fit_target_prison()` 按模式刷靶范围生成靶笼，墙厚固定 1.0） |

```49:58:scripts/levels/World.gd
func check_distance():
	var vector_return = randomize_vector()
	var distance = 0
	var have_distance = true
	#if (DataManager.last_vectors.keys().size() > 0):
	#	for last_key in DataManager.last_vectors.keys():
	#		distance = DataManager.last_vectors[last_key].distance_to(vector_return)
	#		if(distance < (Global.models3d[Global.game_type].size * 2)):
	#			have_distance = false
	return [have_distance, vector_return, distance]
```

### 3.3 P2 —— 工程规范与体验

| ID | 问题 | 定位 | 状态 |
| --- | --- | --- | --- |
| D13 | `World._process()` 每帧 `await create_timer(0.5)`，持续创建定时器、逻辑退化为每帧执行 | `World.gd:33` | ✅ 已修复（改为常驻 `Timer` 节点，0.5s 触发） |
| D14 | 3D 配置字段名 `movment` 拼写错误，与 2D 的 `movement` 不一致 | `global.gd` / `World.gd:86` / `ModePreview3D.gd:95` | ✅ 已修复（4 处键名统一为 `movement`；`World.gd` 改用 `get("movement", false)` 兜底，缺键按静止靶处理） |
| D15 | 2D 三个模式名未进入翻译表（原表只有 4 个 3D 键） | `translations.csv` | ✅ 已修复 |
| D16 | 所有界面文案硬编码英文，**无中文** | 全局 | ✅ 已修复 |
| D17 | 无命中音效（README 提到 `assets/sounds` 但目录不存在） | — | ⚠️ 建议补命中/结算音效 |
| D18 | `Target2D.tscn` 使用占位 `uid://target2d_placeholder_uid`，无贴图，外观依赖运行时 `ColorRect` 兜底 | `scenes/characters/Target2D.tscn` | ⚠️ 建议补圆形贴图 |
| D19 | 资源组织混乱：`Bullet` 场景在 `levels/`、脚本在 `ui/`；`World.gdshader` 为空文件 | 目录 | ⚠️ 建议整理 |
| D20 | `Crosshair._draw()` 每次重绘都全量 `loadSave()` 解析存档字符串；`polygonDrawer()` 每帧 `new Polygon2D()` 只为取描边顶点 | `Crosshair.gd:92` | ✅ 已修复（参数改由 `_ready()` / 设置变更时加载，`_draw()` 只做懒加载兜底；描边直接用点数组绘制，不再创建临时节点） |
| D21 | 2D 模式无准星、灵敏度对 2D 不生效 | 设计取舍 | 建议显式说明或补准星 |
| D22 | 窗口失焦自动暂停**仅 3D 有**（`Pause.gd`），2D 缺失 | `scenes/levels/World2D.tscn` | ✅ 已修复（`World2D._notification()` 监听 `FOCUS_OUT`） |
| D23 | 导入/导出对话框 `current_dir = "/"`，Windows 下落到盘符根目录 | `Options.gd:341/351` | ✅ 已修复（新增 `default_save_dir()`，优先 `SYSTEM_DIR_DOCUMENTS`，取不到退回桌面 / `user://`） |
| D24 | 主菜单灵敏度区**没有任何文字标签**（只有下拉框和输入框） | `MainScreen.tscn` | ✅ 已修复（新增 `Game` / `Sensitivity` 标签，已加翻译） |
| D44 | 灵敏度 / 准星尺寸输入框直接 `float(new_text)`：空串、字母、中文全角标点（`0，5`）都会静默解析成 **0.0 并落盘**，表现为"视角完全不动""准星整块消失"，且**重启后仍是 0** | `MainScreen.gd` / `Options.gd` | ✅ 已修复（新增 `Global.parse_number()` / `parse_number_clamped()`：全角数字与 `。，、` 归一化，解析失败回退上一次有效值；灵敏度夹在 `0.001 ~ 1000`，启动时发现存档为 0 自动恢复默认 `1.0`） |

| D45 | 导入 / 读取到非 JSON 或格式不对的文件时，`load_all_data()` 用空字典顶替，紧接着 `save_all_data()` 把空设置写回 `user://`——**语言、显示、灵敏度、准星、成绩记录一次性全丢且不可逆**；Web 端 `file_parser()` 同样会清空 | `DataManager.gd` / `Options.gd` | ✅ 已修复（新增 `parse_game_data()`：解析失败或结果非 `Dictionary` 返回 `null`；`load_all_data()` / `load_all_data_from_param()` 返回 `false` 且**保留现有设置**；导入只在成功时落盘；存档损坏时先备份为 `.bak`） |
| D46 | `save_data()` / `save_all_data()` 未判 `FileAccess.open()` 返回 null，写盘失败（无权限 / 路径不存在）时直接崩溃 | `DataManager.gd` | ✅ 已修复（统一走 `write_all_data()`，打开失败返回 `false` 并 `push_error`，不再崩溃） |
| D47 | 切到 2D 模式后按钮**没有高对比样式、选中态几乎看不见**（回到默认黑底主题） | `MainScreen.gd` | ✅ 已修复（`AddGames()` / `AddGames2D()` 重建列表后统一 `UIStyle.apply_controls(gamelist)`，运行时切换与启动时观感一致） |
| D48 | 2D 模式下模式列表**行被压扁、预览被裁剪**（300×300 预览挤成一条），且预览 `transparent_bg` + 白色小靶点在主菜单背景上**几乎看不见** | `MainScreen.gd: sync_mode_layout()` / `ModePreview2D.tscn` | ✅ 已修复（行高下限 140 → 300，不再随左列变矮而压缩；2D 预览加 `Color(0.1,0.1,0.1)` 深色背景，与 3D 预览观感一致） |
| D49 | 模式按钮**长短不一**：3D 组内第一个按钮偏窄，且 2D 与 3D 按钮宽度不同 | `MainScreen.gd: sync_mode_layout()` | ✅ 已修复（① 布局未就绪（左列尺寸仍为 0）时下一帧重试而不是直接 `return`，否则宽度统一永不执行；② 用**挂进场景树的探测按钮**测量 3D+2D 全部模式名，取统一宽度，不再按各组文字分别测、也不再对上次结果反复 ×1.1 累乘） |
| D50 | 2D 模式下左列「开始训练 / 退出」被压短（3D 下由 900px 最小宽的画质滑条撑开，2D 隐藏这些行后左列收窄） | `MainScreen.gd: _ready()` | ✅ 已修复（左列固定最小宽度 `1250`，与 3D 布局实测宽度一致，两种模式下左列按钮等长） |

### 3.4 第二 ~ 五轮补充定位的体验缺陷（D25–D38，均已修复）

| ID | 现象 | 根因定位 | 修复方式 |
| --- | --- | --- | --- |
| **D25** | **移动中开枪几乎打不中**（最影响手感的 bug） | `CharacterBody3D.random_spread()` 用 `velocity.length()`（最大 20）直接作角度系数，散布高达 **±40°** | 散布强度改为按速度归一化（0~1），最大 **±2°** |
| **D26** | 进 3D 关卡要**连续点两次弹窗**（先全屏、再捕获鼠标）才能开始 | `World._on_full_screen_needed_pressed()` 之后又弹出 `MouseCapturedRequested` | 合并为一次点击：同时设置全屏 + 捕获鼠标并立即恢复 |
| **D27** | 2D 模式靶子**在 4K 下极小**、移动靶慢得几乎不动 | 视口为 3840×2160，而模式配置里的 `size`(40/60px)、`margin`(100) 与移动速度 200px/s 均按 1920 基准设计 | 以 1920 宽为基准等比缩放尺寸、边距与移动速度 |
| **D28** | 2D 结算后按 Esc 会把已结束的回合再次"继续" | `toggle_pause()` 未区分结算态 | 结算面板显示期间忽略暂停切换 |
| **D29** | 3D 结算只有击杀数，**看不到命中率** | 虽有 `shot_count` 但从未统计命中数、也未展示 | 新增 `hit_count`，结算展示 `击杀 / 命中率 / 历史最佳` |
| **D30** | 结算面板点了「重新开始 / 主菜单」**完全没反应** | `Pause` 面板 `process_mode = 2`（仅在树暂停时处理）；2D 的 `end_game()` 只把面板设为可见而**没有暂停场景树**，按钮可见却收不到 `_gui_input` | 两个场景的 `Pause` 面板改为 `process_mode = 3`（始终处理），2D `end_game()` 同时 `get_tree().paused = true`；结算态 `Resume` 隐藏时把键盘焦点改给 `Restart` |
| **D31** | 界面显示中文，但**语言下拉框却显示 English** | `Language` 属于 `Persist` 组，`loadSaved()` 按 `DataManager.get_data("Language")` 读索引 → 恒为 null → 选中项停在 0；真正的语言存在 `"locale"`（字符串）里，两者不同步 | 新增 `sync_language_selection()`：按 `TranslationServer.get_locale()` 反查索引；首次运行把系统识别到的 locale 落盘 |
| **D32** | 主菜单 3D 画质滑条**看不清、没有刻度** | 滑条沿用默认主题样式（4K 缩放下对比度极低），且未开 `tick_count`，也没有实时数值 | 代码内显式设置高对比 `StyleBoxFlat`（轨道 / 已填充区 / 滑块），开启 `ticks_on_border` 与刻度色，并新增 `QualityValue` 实时百分比标签 |
| **D33** | **没有窗口模式**，只能全屏 | `MainScreen._ready` 无条件 `window_set_mode(FULLSCREEN)`；`World.full_screen_requested()` 把「非全屏」当成错误并强制弹窗 | 新增显示模式设置（窗口 / 最大化 / 全屏）持久化到 `display_mode`；`DataManager._ready` 最早应用；`World` 只校验鼠标捕获态，不再要求全屏；主菜单 **F 键**可随时切换 |
| **D34** | 画质（渲染缩放）滑条**拖了没效果** | 把 `QualitySlider` 移进 `QualityRow` 后，`MainScreen.tscn` 里 `value_changed` 连接的 `from` 路径仍是旧路径，信号静默失效 | 连接路径改为 `.../VBoxContainer/QualityRow/QualitySlider`；标签改为「渲染缩放：W × H (N%)」，明确它改的是渲染分辨率而不是窗口大小 |
| **D35** | 想调**屏幕 / 窗口大小**却没有入口 | 只有渲染缩放滑条，窗口尺寸写死 1600×900 | 设置页新增「窗口大小」下拉框（1280×720 / 1600×900 / 1920×1080 / 2560×1440），持久化到 `window_size`，按屏幕可用区域收敛并居中 |
| **D36** | 切成 English 后**仍有中文残留** | `putLabel()` 等代码生成的文本只在 `_ready` 翻译一次；编辑器里的静态文案也不一定随 locale 变化重建 | 切换语言后刷新动态文本并重载当前场景，所有文案按 msgid 重新翻译；补齐 `CrosshairColor` / `OutlineColor` / `TargetColor` 等缺失键 |
| **D37** | 选了窗口尺寸**却还是全屏** | `set_window_size_index()` 只改尺寸，没有改显示模式；默认显示模式仍是全屏 | 选择具体尺寸时若当前不是窗口模式，自动把 `display_mode` 切为窗口并立即应用 |
| **D38** | 渲染缩放滑条**太长、档位太细** | `custom_minimum_size.x = 1400`；范围 0.25–2.0、步长 0.05（36 档） | 宽度收窄到 900；范围 0.5–2.0、步长 0.25（7 档：50 / 75 / 100 / 125 / 150 / 175 / 200%），`tick_count = 7` 与档位一一对应 |

### 3.5 第五轮补充定位（D39–D43，均已修复）

| ID | 现象 | 根因定位 | 修复方式 |
| --- | --- | --- | --- |
| **D39** | 语言设置只有 3 种，不满足多语言使用 | `translations.csv` 只有 `en/es/zh_CN` 三列，`Options.LOCALES` 与下拉框硬编码 3 项，`project.godot` 只注册 3 个 `.translation` | CSV 扩到 **15 列 / 58 键**；`LOCALES` + 新增 `LOCALE_NAMES`（母语写法）驱动下拉框；`project.godot` 与 `translations.csv.import` 同步登记 15 个产物；headless `--import` 重新生成全部 `.translation` |
| **D40** | 游戏下拉框只有英文名（`Valorant` / `CounterStrike` / `Fortnite`），不熟悉的人看不懂 | 显示名直接用 `games_sensitivities` 的 key，且换算系数靠 `get_item_text()` 反查，改成中文就会查不到系数 | 新增 `Global.GAME_TR_KEYS` + `game_display_name()`（走 `tr()`，键为 CSV 里的 `GAME_*`）；建项时 `set_item_metadata()` 存原始 key，系数一律按 metadata 查（`get_selected_game_key()` / `save_selected_game_value()`） |
| **D41** | 首页 3D/2D 模式按钮**被预览容器拉成厚框** | 按钮与 300×300 预览容器同处 `HBoxContainer`，默认 `SIZE_FILL` 被拉伸到 300px | `SIZE_SHRINK_CENTER` + 固定高度（先减半至 150，后由 `sync_mode_layout()` 统一） |
| **D42** | 模式按钮**长短不一**、右侧列表与左列**不等高** | 按钮宽度随文字自适应；行高写死 300，与左列实际高度无关 | `sync_mode_layout()`：`await process_frame` 后按最宽文字统一宽度（×1.1），按**左列实际高度**均分行高，按钮几乎撑满行高（上下各 12px） |
| **D43** | 改完布局后**首页整个失效**（脚本编译失败） | 新增的 `@onready` 用 `:=` 被推断为 `Node`，在其上取 `size.y` / 调 `get_theme_constant()` 得到 `Variant`，`var target := …` 无法推断类型 → `Parse Error: Cannot infer the type`，整个 `MainScreen.gd` 加载失败 | 显式声明 `@onready var gamelist: VBoxContainer` / `left_column: VBoxContainer`；并把布局同步改为监听 `left_column.resized` 自动重算（字体异步加载导致左列高度变化也能对齐） |

---

## 四、本次已实施的代码修改

| 文件 | 修改内容 | 对应缺陷 |
| --- | --- | --- |
| `scripts/characters/CharacterBody3D.gd` | 删除射击线程（`_fire_in_thread` / `start_thread` / `stop_thread` 及 `Thread` 成员），射击改由 `_physics_process()` 单路调用；倒计时改 `tr("TIME_LEFT")` | D01 / D04 / D16 |
| `scripts/levels/PauseInput.gd`（新增） | 常驻输入节点，`process_mode = ALWAYS`，转发 `ui_cancel` → `pause_toggled` | D02 |
| `scripts/levels/World2D.tscn` | 新增 `PauseInput` 节点与信号连接；暂停面板新增 `Score` 标签 | D02 / D05 |
| `scripts/levels/World2D.gd` | 移除失效的 `_input`；HUD 与结算文案 `tr()` 化；结算时展示最终得分 | D02 / D05 / D16 |
| `scripts/ui/MainScreen.gd` | 删除下拉框误跳转；存档恢复改用 `!= null`；首次运行落盘默认灵敏度并默认选中第 0 项；模式按钮 `tr(model)` | D03 / D06 / D07 / D16 |
| `scripts/characters/Target2D.gd` | 应用 `TargetColor` | D08 |
| `scripts/ui/Options.gd` | 新增语言下拉与 `_on_language_item_selected()`；`loadSaved()` 支持 `OptionButton`；`putLabel()` 标签 `tr()` 化 | D16 |
| `scripts/ui/Options.tscn` | 新增 `LabelLanguage` + `Language`（Persist 组）及信号连接 | D16 |
| `scripts/data_manager.gd` | `_ready()` 中按存档恢复 `TranslationServer.set_locale()` | D16 |
| `assets/text/translations.csv` | 新增 `zh_CN` 列，键扩充至 33 条 | D15 / D16 |
| `project.godot` | 注册 `translations.zh_CN.translation`，设置 `locale/fallback="en"` | D16 |

### 4.2 第二轮体验修复（试玩反馈后追加）

| 文件 | 修改内容 | 对应缺陷 |
| --- | --- | --- |
| `scripts/characters/CharacterBody3D.gd` | 修正 `random_spread()` 散布系数（±40° → ±2°）；新增 `hit_count` 命中统计 | D25 / D29 |
| `scripts/characters/target.gd` | `target_kill` 信号回传靶 id，便于关卡清理坐标 | D09 |
| `scripts/global.gd` | 新增 `save_record() / get_record()` 成绩记录读写 | D10 / D29 |
| `scripts/levels/World.gd` | 恢复靶间距检查；`Timer` 替代每帧 `await`；新增 `fit_target_prison()`；全屏/鼠标捕获合并为一步；新增 `_on_timer_timeout()` 结算（击杀 + 命中率 + 历史最佳） | D09 / D12 / D13 / D26 / D29 |
| `scripts/levels/World.tscn` | 暂停面板新增 `Restart` 按钮与连接；`Timer.timeout` 接到 World | D11 |
| `scripts/levels/Pause.gd` | 新增 `_on_restart_pressed()` → `reload_current_scene()`；结算态焦点改给 `Restart` | D11 / D30 |
| `scenes/levels/World.tscn`、`scenes/levels/World2D.tscn` | `Pause` 面板 `process_mode` 2 → 3 | D30 |
| `scripts/global.gd` | 新增 `get/set/apply_display_mode()`、`toggle_fullscreen()`、窗口默认尺寸 1600×900 | D33 |
| `scripts/data_manager.gd` | `_ready` 里最先应用显示模式 | D33 |
| `scripts/ui/Options.gd` / `scenes/ui/Options.tscn` | 新增「显示模式」下拉框 + 提示；`sync_language_selection()` / `sync_display_selection()` | D31 / D33 |
| `scripts/ui/MainScreen.gd` / `scenes/ui/MainScreen.tscn` | 画质滑条加 `QualityRow` + `QualityValue` + 刻度与高对比样式；F 键切换全屏 | D32 / D33 |
| `scripts/levels/World.gd` / `scenes/levels/World.tscn` | 守卫只校验鼠标捕获态；弹窗文案改为「点击以锁定鼠标」 | D33 |
| `assets/text/translations.csv` + `tools/build_translations.gd` | 新增 6 条文案；新增 CSV → `.translation` 编译脚本 | D31 / D33 |
| `scripts/levels/World2D.gd` | 2D 目标尺寸/边距/速度按 1920 基准缩放；失焦自动暂停；结算展示历史最佳；新增重开；结算态忽略 Esc | D27 / D22 / D10 / D11 / D28 |
| `scripts/levels/World2D.tscn` | 暂停面板新增 `RestartButton` 与连接 | D11 |
| `scenes/ui/MainScreen.tscn` | 灵敏度区新增 `Game` / `Sensitivity` 标签 | D24 |
| `assets/text/translations.csv` | 新增 `RESULT_TEXT` `RESULT_SCORE` `Restart` `Game` `Sensitivity` 五键 × 3 语 | D16 |

### 4.3 第三、四轮修复（语言同步 / 显示与窗口 / 滑条）

| 文件 | 修改内容 | 对应缺陷 |
| --- | --- | --- |
| `scripts/ui/Options.gd` | `sync_language_selection()` / `sync_display_selection()` / `sync_window_size_selection()`；缓存 `put_labels` 并在切语言后 `refresh_dynamic_texts()`；切语言后 `reload_current_scene()` | D31 / D35 / D36 |
| `scenes/ui/Options.tscn` | 新增 `Display` / `WindowSize` 下拉框、`DisplayHint` 提示与信号连接 | D33 / D35 |
| `scripts/global.gd` | `WINDOW_SIZES` 四档尺寸；`set_window_size_index()` 在非窗口模式时自动切窗口；窗口按屏幕可用区域收敛并居中 | D35 / D37 |
| `scripts/ui/MainScreen.gd` | `style_quality_slider()` 高对比样式与刻度色；`update_quality_label()`；渲染缩放文案；F 键切换全屏 | D32 / D33 / D34 |
| `scenes/ui/MainScreen.tscn` | **修正 `value_changed` 信号 `from` 路径**（节点移入 `QualityRow` 后失效）；滑条改为 0.5–2.0 / 步长 0.25 / `tick_count = 7` / 宽度 900 | D34 / D38 |
| `assets/text/translations.csv` | 由 33 键扩至 **55 键**（新增 `Display` `Windowed` `Maximized` `Fullscreen` `Window size` `Render scale` `DISPLAY_HINT` `Click to capture the mouse.` `CrosshairColor` `OutlineColor` `TargetColor` 等） | D31 / D33 / D36 |
| `tools/build_translations.gd`（新增） | CSV → `.translation` 编译脚本，改 CSV 后需重跑 | D31 / D36 |

### 4.4 第五轮修复（多语言 / 游戏名本地化 / 首页布局）

| 文件 | 修改内容 | 对应缺陷 |
| --- | --- | --- |
| `assets/text/translations.csv` | 列由 3 扩至 **15**（`en es zh_CN zh_TW zh_HK ja ko fr de pt_BR ru it tr ar vi`），键由 55 扩至 **58**（新增 `GAME_VALORANT` / `GAME_COUNTERSTRIKE` / `GAME_FORTNITE`）；原有 3 列内容一字未改 | D39 / D40 |
| `assets/text/translations.csv.import`、`project.godot` | `dest_files` 与 `locale/translations` 同步登记 15 个 `.translation`；headless `--import` 重新生成 | D39 |
| `scripts/ui/Options.gd` | `LOCALES` 扩至 15；新增 `LOCALE_NAMES`（母语写法）与 `locale_to_index()`（变体匹配：繁体按 TW/HK 细分、`pt` / `de_DE` / `es_419` 等） | D39 |
| `scripts/global.gd` | 新增 `GAME_TR_KEYS` 与 `game_display_name()`，替换原先硬编码的显示名字典 | D40 |
| `scripts/ui/MainScreen.gd` | 游戏下拉框 `set_item_metadata()` 存 key、`get_selected_game_key()` / `save_selected_game_value()` 按 key 存系数；模式按钮 `SIZE_SHRINK_CENTER`；新增 `sync_mode_layout()` 与 `_on_left_column_resized()`；`@onready` 显式声明 `VBoxContainer` 类型 | D40 / D41 / D42 / D43 |
| `tools/build_translations.gd` | 输出语言改为**由 CSV 表头动态决定**，新增语言无需改脚本 | D39 |
| `README.md`、`docs/OpenAimTrainer_使用说明.md` | README 新增完整帮助章节；新增独立使用手册（设置 / 效果 / 玩法 / 排错 / 开发者） | 文档 |

---

## 五、优化路线图

> Phase 1 的稳定性与体验项（D09 / D11 / D12 / D13 / D22 / **D14 / D23 / D20 / D44**）已全部完成，以下为剩余计划。

### Phase 1（✅ 已完成）

1. ✅ **D14 字段名**：`movment` → `movement`，统一 2D / 3D 配置键（`World.gd` 同步改用 `get("movement", false)` 兜底）。
2. ✅ **D23 导出目录**：`FileDialog.current_dir` 改用 `OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)`。
3. ✅ **D20 准星缓存**：`Crosshair` 参数只在 `_ready()` / 设置变更时加载，`_draw()` 仅做懒加载兜底；描边直接用点数组绘制，不再每帧 `new Polygon2D()`。
4. ✅ **D44 数值输入校验**：灵敏度与准星尺寸改走 `Global.parse_number()` / `parse_number_clamped()`，空串 / 非法字符 / 中文全角标点不再静默写 0。

### Phase 2（约 2–3 天，训练闭环）

4. **成绩扩展**：`records` 增加 `played_at[]` 时间序列，支持"近 10 次成绩曲线"与"本轮 vs 最佳"对比。
5. **D17 音效**：命中、结算、UI 点击三类音效 + 音量设置。
6. **D21 2D 准星**：2D 模式复用自定义准星（隐藏系统光标）。

### Phase 3（约 1 周，架构升级）

10. **模式配置 Resource 化**：把 `models2d/3d` 的两个 `Dictionary` 换成自定义 `Resource`（`mode_3d.gd` / `mode_2d.gd`），消除"字符串 Key + 弱类型字典"的取参风险，顺带统一 `movment` → `movement`（D14）。
11. **关卡抽象**：抽 `BaseLevel` 基类统一"刷靶 / 计时 / 结算 / 暂停"四件事，3D 与 2D 各自只实现刷靶与命中判定。
12. **目录整理**（D19）+ 补 2D 靶贴图（D18）+ 主菜单补标签（D24）+ 导出目录改为系统文档目录（D23）。

---

## 六、中文本地化（汉化）方案与落地

### 6.1 原状问题

- `translations.csv` 仅 `en / es` 两列、仅 **4 个键**（`KILLS_ON` + 4 个 3D 模式名）。
- 3 个 2D 模式名、全部菜单/设置/暂停/结算文案**硬编码英文**，无法本地化。
- 无语言切换入口，只能被动跟随系统 locale。

### 6.2 方案设计

采用 **"源文案即 msgid" + Godot 自动翻译** 的策略：

- `Control.text` 等属性在 `auto_translate_mode = AUTO` 下会自动按当前 locale 查表；把 `.tscn` 中的英文原文直接作为键，即可**零改动完成场景文案汉化**。
- 脚本中动态拼接的文案（`Score: 0`、`60s`、`Finished!`）无法自动翻译，统一改为 `tr("KEY") % 变量`，键写入 CSV。
- 动态生成的参数标签（`DotSize` 等）在 `putLabel()` 中用 `tr(put_label.name)` 包裹。
- 模式按钮在 `MainScreen` 中用 `button.text = tr(model)`。

**语言切换**：`Options.tscn` 新增 `Language`（`OptionButton`，Persist 组）→ `TranslationServer.set_locale()` + `DataManager.save_data("locale", …)`；启动时由 `DataManager._ready()` 在 `load_all_data()` 之后恢复，保证自动加载顺序正确（Global 先于 DataManager，故不能在 Global 里读档）。

### 6.3 覆盖范围（58 键 × 15 语言）

> 语言：English · Español · 简体中文 · 繁體中文（台灣）· 繁體中文（香港）· 日本語 · 한국어 · Français · Deutsch · Português (Brasil) · Русский · Italiano · Türkçe · العربية · Tiếng Việt

- 模式名 7 条：`3D_HEAD_LEVEL_V1` / `3D_MULTIPLE_BASIC_TARGETS_V1` / `3D_MULTIPLE_BASIC_TARGETS_MOVEMENT_V1` / `3D_MULTIPLE_MEDIUM_TARGETS_V1` / `2D_GRIDSHOT_V1` / `2D_REFLEX_V1` / `2D_MOVING_TARGETS_V1`
- 主菜单 5 条：`PLAY` `Options` `Quit` `Resolution` `3D`
- 设置页 15 条：`Language` `Crosshair` `Outline` `Crosshair inner` `Dot` `DotSize` `OutlineSize` `CrosshairHeight` `CrosshairWidth` `CrosshairSpace` `Crosshair color` `Outline color` `Target` `Target color` `IMPORT / EXPORT` `Export` `Import` `Back`
- 关卡与结算 9 条：`Resume` `Menu` `Main Menu` `Restart` `Click to capture the mouse.` `Mouse captured is needed.` `KILLS_ON` `SCORE_TEXT`（`Score: %d`）`TIME_LEFT`（`%ds`）`FINISHED` `RESULT_TEXT` `RESULT_SCORE`
- 显示与窗口 6 条：`Display` `Windowed` `Maximized` `Fullscreen` `Window size` `Render scale` `DISPLAY_HINT`
- 参数标签补充 3 条：`CrosshairColor` `OutlineColor` `TargetColor`（修复动态标签显示原始键名）
- 游戏名 3 条（新增）：`GAME_VALORANT` `GAME_COUNTERSTRIKE` `GAME_FORTNITE`（下拉框显示名随语言，内部 key 不变）

### 6.3.1 翻译产物编译

`assets/text/translations.*.translation` 有两种生成方式，**改动 CSV 后必须重跑**，否则界面不会更新：

```powershell
# 推荐：引擎导入器，按 CSV 列自动生成全部 15 个产物
godot --headless --path . --import

# 备选：自写脚本（输出语言由 CSV 表头动态决定）
godot --headless --path . --script res://tools/build_translations.gd
```

脚本支持带引号 / 引号内逗号的 CSV 字段；新增语言列时同步更新 `project.godot → locale/translations` 与 `translations.csv.import` 的 `dest_files`。

### 6.4 验证结果

`godot --headless --path <proj> --import` 成功生成 15 个翻译资源；抽样实测输出：

```
en     Play              Counter-Strike (CS)   Tip: press F to switch between windowed and fullscreen
ja     トレーニング開始   カウンターストライク (CS)  ヒント: F キーでウィンドウと全画面を切り替え
ar     ابدأ التدريب      كاونتر سترايك (CS)   تلميح: اضغط F للتبديل بين النافذة وملء الشاشة
zh_TW  開始訓練           絕對武力 (CS)         提示：按 F 鍵可在視窗 / 全螢幕之間切換
de     Training starten  Counter-Strike (CS)  Tipp: Drücke F, um zwischen Fenster und Vollbild zu wechseln
vi     Bắt đầu luyện tập Counter-Strike (CS)  Mẹo: nhấn F để chuyển giữa cửa sổ và toàn màn hình
```

自写脚本实测：`导出完成：58 条 × 15 语言`；无头启动（`--quit-after 200`）无任何 `ERROR / Parse Error` 输出。

### 6.5 使用方式

设置页（Options）底部 `Language` 下拉框选择 `简体中文` 即时生效并写入存档；未选择时跟随系统语言，缺省回退英文（`locale/fallback="en"`）。

切换语言后的刷新策略（D36）：

1. `refresh_dynamic_texts()` 重译代码生成的文本（`putLabel()` 标签、显示模式提示）；
2. `get_tree().reload_current_scene()` 重建当前场景，让编辑器里的静态文案按 msgid 重新翻译；
3. 下拉框本身由 `sync_language_selection()` 按生效 locale 反查，保证"界面语言 = 下拉框选中项"。

---

## 七、回归验证清单

| # | 步骤 | 预期 |
| --- | --- | --- |
| 1 | 启动进入主菜单 | 显示模式列表与缩略图，无报错 |
| 2 | 切换 3D / 2D 开关 | 列表重建为对应维度模式，按钮文案随语言变化 |
| 3 | 主菜单切换游戏灵敏度下拉 | **停留在主菜单**（原会跳到设置页） |
| 4 | 设置页切换语言为简体中文 | 界面即时汉化；重启后保持中文 |
| 5 | 设置页修改目标颜色 → 进入 2D 模式 | 2D 靶显示为新颜色 |
| 6 | 进入 3D 模式，鼠标左键射击 | 单次点击只生成 1 颗弹道，命中计数正常 |
| 7 | 3D 中按 Esc → Resume | 暂停/恢复正常 |
| 8 | 3D 点击 Menu 返回 | **不再卡死**，正常回到主菜单 |
| 9 | 2D 模式按 Esc 暂停 → 再按 Esc | 正常恢复（原无法恢复） |
| 10 | 2D 模式等待 60 秒结束 | 弹出结算面板显示"得分 ｜ 最佳"，"继续"按钮隐藏 |
| 11 | 3D 模式移动中开枪 | 散布正常，仍可命中（原散布 ±40° 几乎打不中） |
| 12 | 3D 进入关卡 | 只需点击一次弹窗即进入全屏并锁定鼠标 |
| 13 | 3D 60 秒结束 | 结算显示"击杀数 · 模式 ｜ 命中率 ｜ 最佳"，可点 Restart 重开 |
| 14 | 切换窗口（失焦） | 2D 也会自动暂停（原本不会） |
| 15 | 2D 模式靶子大小/移动速度 | 在 4K 视口下按 1920 基准等比放大，手感正常 |
| 16 | 设置页语言框 | 选中项与实际界面语言一致（不再出现"中文界面 + English 选项"） |
| 17 | 设置页切 English | 全界面转英文，无中文残留，下拉框同步为 English |
| 18 | 设置页「显示模式」选窗口 | 立即退出全屏，变为居中悬浮窗口；重启后保持 |
| 19 | 设置页「窗口大小」选 1280×720 | 若当前是全屏则自动切为窗口，并应用该尺寸 |
| 20 | 主菜单按 F 键 | 在全屏 / 窗口之间切换并写入存档（输入框有焦点时不生效） |
| 21 | 主菜单拖动渲染缩放滑条 | 档位为 50/75/100/125/150/175/200%，右侧百分比与渲染分辨率实时更新，3D 画质随之变化 |
| 22 | 设置页语言下拉框 | 共 15 项（母语写法），选中项与实际 locale 一致；选日本語 / العربية 等立即生效 |
| 23 | 主菜单游戏下拉框 | 中文下显示「无畏契约 / 反恐精英 (CS) / 堡垒之夜」；切换语言后换算系数不变（`sensitivity_game_value` 仍在） |
| 24 | 主菜单模式按钮 | 四个按钮等宽、厚度适中；右侧列表总高与左列等高（headless 实测 `left=1248 right=1248`） |
| 25 | 3D ↔ 2D 反复切换 | 列表正确重建（4 / 3 项），无残留行、无脚本报错 |
| 26 | 无头冒烟 `--quit-after 200` | 无 `SCRIPT ERROR` / `Parse Error`（重点防 D43 类型推断问题复发） |

---

## 八、遗留风险提示

1. 本机 Godot 为 **4.7**，而项目声明 **4.5**；本次仅做资源导入与运行，**未用编辑器保存**，因此 `project.godot` 的 `config/features` 仍为 4.5。若日后用 4.7 编辑器打开并保存，项目会被升级且不可逆，建议先备份。
2. 生成的 `assets/text/translations.*.translation` 为导入产物，需在发布/提交时确认 `.gitignore` 策略（当前仓库无 `.git`，无法核对）。
3. 剩余未修项（D14 / D17 / D18 / D19 / D20 / D21 / D23）均为工程规范或素材缺失类，不影响可玩性，已列入 Phase 1–2。
4. **用户存档**：`user://open_aim_trainer.json`（Windows：`%APPDATA%\Godot\app_userdata\Open Aim Trainer\`）。用 `godot --script` 跑验证脚本时 autoload 的 `_ready()` 不会执行，`DataManager` 不读盘，任何 `save_data()` 都会用空字典**覆盖存档**；2026-10-08 20:44 已用无 BOM 的 UTF-8 还原（中文 + 100% 渲染缩放 + 原准星/灵敏度设置）。后续禁止用脚本模式写入用户存档。

---

*报告生成时间：2026-10-08 19:33 · 最后更新：2026-10-08（UTC+8，第五轮：15 语言 / 游戏名本地化 / 首页布局 / 文档补全后） · 分析对象：OpenAimTrainer-main（Godot 4.7 / Apache-2.0）*
*缺陷计数：累计 **46 项**（D01–D46），**39 项已修复**，7 项为工程规范 / 素材类建议*
*配套文档：`OpenAimTrainer_项目分析报告_20261008.md`（说明）、`OpenAimTrainer_优化进度记录_20261008.md`（进度）、`OpenAimTrainer_使用说明.md`（帮助手册）*
