# OpenAimTrainer 优化进度记录

| 项目 | 内容 |
| --- | --- |
| 文档名称 | OpenAimTrainer 缺陷修复 / 汉化 / 体验优化进度记录 |
| 开始时间 | 2026-10-08 19:33（UTC+8，中国标准时间） |
| 最后更新 | 2026-10-08（UTC+8，第五轮完成后） |
| 工作时段 | 2026-10-08 19:33 – 20:45（S0–S5）＋ 同日追加 S6–S8 |
| 验证环境 | Godot v4.7.stable.win64（`K:\Godot_v4.7-stable_win64\Godot.exe`）、Windows、headless 冒烟 + 实际试玩 |
| 当前状态 | **可玩**：P0 阻断项全部清除，本地化 **15 语 × 58 键**，游戏名随语言显示，首页左右两列等高对齐，3D / 2D 均有结算与成绩记录 |
| 缺陷计数 | 累计定位 **46 项**（D01–D46）；**39 项已修复**；**7 项为工程规范 / 素材类建议**（D14 / D17 / D18 / D19 / D20 / D21 / D23） |
| 关联文档 | `OpenAimTrainer_使用说明.md`（帮助手册）、`OpenAimTrainer_项目分析报告_20261008.md`、`OpenAimTrainer_缺陷排查与优化评估报告_20261008.md`、`OpenAimTrainer_模块架构报告_20261008.md` |

---

## 一、阶段进度总览

| 阶段 | 时间（2026-10-08） | 触发来源 | 主要内容 | 状态 |
| --- | --- | --- | --- | --- |
| **S0 项目分析** | 19:33 | 用户：分析项目出报告 | 通读 14 个 `.gd` + 9 个 `.tscn`，输出架构 / 模块 / 功能 / 玩法报告 | ✅ 完成 |
| **S1 第一轮修复** | ~19:40 – 20:05 | 静态审计 + 无头冒烟 | P0 阻断 4 项、手感与数据 8 项、工程规范 12 项（D01–D24）；落地简体中文（33 键 × 3 语） | ✅ 完成 |
| **S2 第二轮修复** | ~20:05 – 20:20 | 用户试玩反馈："不好用" | 弹道散布 ±40°→±2°、全屏二次弹窗合并、2D 靶 4K 缩放、2D 结算、成绩记录、结算重开（D25–D30） | ✅ 完成 |
| **S3 第三轮修复** | ~20:20 – 20:35 | 用户反馈：语言显示不一致 / 滑条看不清 / 全屏不可选 | 语言下拉同步、滑条样式与刻度实时百分比、显示模式（窗口 / 最大化 / 全屏）+ F 键、窗口大小、切换语言后重载场景（D31–D36） | ✅ 完成 |
| **S4 第四轮优化** | ~20:35 – 20:42 | 用户反馈：滑条无效 / 汉化残留 | 修复被移动节点弄断的 `value_changed` 信号；滑条改 7 档；选窗口尺寸自动切窗口模式（D34–D38） | ✅ 完成 |
| **S5 文档更新** | 20:45 | 用户：更新说明 / 评估 / 进度文档 | 同步三份文档至当前代码状态 | ✅ 完成 |
| **S6 多语言扩容** | 同日追加 | 用户：语言扩到 15 种 | CSV 扩至 15 列 × 58 键；`LOCALES` / `LOCALE_NAMES` / `locale_to_index()`；`project.godot` 与 `.import` 登记 15 个产物；headless `--import` 重新生成（D39） | ✅ 完成 |
| **S7 游戏名本地化 + 首页布局** | 同日追加 | 用户：游戏名看不懂 / 按钮太厚 / 左右不等高 | `GAME_TR_KEYS` + `game_display_name()`（metadata 保 key）；按钮 `SIZE_SHRINK_CENTER`；`sync_mode_layout()` 等宽 + 按左列高度均分行高（D40 / D41 / D42） | ✅ 完成 |
| **S8 修复回归 + 文档补全** | 同日追加 | 用户：改完首页失效 / 更新全部文档 | `@onready` 显式 `VBoxContainer` 类型修复 `Parse Error`（D43）；`build_translations.gd` 改为按 CSV 表头动态输出；README 新增帮助章节 + 新增 `docs/OpenAimTrainer_使用说明.md`；四份旧文档同步 | ✅ 完成 |
| **S9 输入校验 + 存档健壮性 + 模式选中** | 10-09 | 用户：数值输错被归 0 / 导入会丢设置 / 模式按钮点了直接进游戏 | `parse_number()` 归一化与回退（D44）；`parse_game_data()` + `write_all_data()` 判空 + `.bak` 备份（D45 / D46）；模式按钮改单选选中（默认第一个），「开始训练」进入选中模式 | ✅ 完成 |
| **S10 2D 主菜单与 3D 观感对齐** | 10-09 | 用户：2D 下按钮无选中高亮 / 排版被压扁 / 按钮长短不一 / 左列按钮变短 | 重建列表后重新套 `UIStyle`（D47）；行高下限 300 + 2D 预览深色背景（D48）；跨 3D/2D 统一按钮宽度 + 布局未就绪重试（D49）；左列固定最小宽 1250（D50）；设置页「返回」移到视口右下角、宽度缩至 1/4 | ✅ 完成 |

---

## 二、逐轮明细

### S1 · 第一轮：可用性与汉化（D01–D24）

| 时间 | 动作 | 产出 |
| --- | --- | --- |
| 19:40 | 定位 4 项 P0（退出卡死 / 2D 暂停不可恢复 / 下拉误跳转 / 射击双路触发） | D01–D04 修复 |
| 19:50 | 修复手感与数据正确性问题（2D 结算、灵敏度显示不一致、索引 0 不恢复、2D 目标色、靶重叠、成绩落盘） | D05–D12 修复 |
| 19:55 | 工程规范项处理（每帧 `await` 定时器、2D 失焦暂停、灵敏度区标签） | D13 / D22 / D24 修复 |
| 20:00 | 新增 `zh_CN` 列与运行期语言切换；`project.godot` 注册三语资源 | 33 键 × 3 语 |
| 20:05 | 无头冒烟 + 三语 `tr()` 验证 | 零 `ERROR / Parse Error` |

### S2 · 第二轮：试玩反馈（D25–D30）

| 时间 | 反馈 | 处理 |
| --- | --- | --- |
| 20:05 | 移动中开枪几乎打不中 | 散布系数按速度归一化，±40° → ±2°（D25） |
| 20:08 | 进 3D 要连点两次弹窗 | 全屏 + 捕获鼠标合并为一次点击（D26） |
| 20:12 | 2D 靶在 4K 下太小、移动靶几乎不动 | 尺寸 / 边距 / 速度按 1920 基准等比缩放（D27） |
| 20:15 | 2D 结算后按 Esc 会"继续"已结束的回合 | 结算态忽略暂停切换（D28） |
| 20:18 | 3D 结算看不到命中率 | 新增 `hit_count`，展示命中率与历史最佳（D29） |
| 20:20 | 结算面板按钮点了没反应 | `Pause` 面板 `process_mode` → 3，2D `end_game()` 同步暂停场景树（D30） |

### S3 · 第三轮：国际化与显示设置（D31–D36）

| 时间 | 反馈 | 处理 |
| --- | --- | --- |
| 20:22 | 界面是中文、语言框却显示 English | `sync_language_selection()` 按生效 locale 反查索引（D31） |
| 20:25 | 画质滑条看不清、没有刻度 | 高对比 `StyleBoxFlat` + `tick_count` + 实时百分比（D32） |
| 20:30 | 没有窗口模式、只能全屏 | 显示模式下拉（窗口 / 最大化 / 全屏）+ `DataManager._ready` 最早应用 + **F 键**切换；关卡守卫改为只校验鼠标捕获（D33） |
| 20:33 | 想调屏幕 / 窗口大小没有入口 | 新增「窗口大小」下拉框（1280×720 / 1600×900 / 1920×1080 / 2560×1440）（D35） |
| 20:35 | 切成 English 仍有中文残留 | 切换语言后刷新动态文本并重载当前场景；补齐 `CrosshairColor` / `OutlineColor` / `TargetColor` 缺失键（D36） |

### S4 · 第四轮：窗口与滑条收尾（D34 / D37 / D38）

| 时间 | 反馈 | 处理 |
| --- | --- | --- |
| 20:36 | 画质滑条拖了没效果 | 上一轮把 `QualitySlider` 移进 `QualityRow` 后信号 `from` 路径失效 → 修正连接路径；标签改为「渲染缩放：W × H (N%)」（D34） |
| 20:39 | 选了屏幕尺寸还是全屏 | `set_window_size_index()` 在非窗口模式时自动切为窗口并立即应用（D37） |
| 20:42 | 滑条太长、档位太细 | 宽度 1400 → 900；范围 0.25–2.0 / 步长 0.05 → **0.5–2.0 / 步长 0.25（7 档）**，`tick_count = 7`（D38） |

### S6 · 第五轮之一：多语言扩容（D39）

| 反馈 | 处理 |
| --- | --- |
| 语言只有 3 种，要扩到 15 种（含简体 + 两种繁体、日韩法德葡西俄等） | CSV 由 3 列扩至 15 列（`en es zh_CN zh_TW zh_HK ja ko fr de pt_BR ru it tr ar vi`），键由 55 增至 58（新增 `GAME_*`）；`Options.LOCALES` 同步扩列并新增 `LOCALE_NAMES`（母语写法） |
| 系统语言变体（如 `zh-Hant-TW`、`pt`）如何匹配 | 新增 `locale_to_index()`：繁体按 TW/HK/MO 细分，其余中文归简体，再按两字母前缀匹配其他语言，都不中则回退英文 |
| 翻译产物没有生成 | `translations.csv.import` 的 `dest_files` 与 `project.godot → locale/translations` 同步登记 15 项；`godot --headless --path . --import` 重新生成 15 个 `.translation` |
| 编译脚本写死 3 种语言 | `tools/build_translations.gd` 改为**由 CSV 表头动态决定输出语言**（实测 `导出完成：58 条 × 15 语言`） |

### S7 · 第五轮之二：游戏名本地化与首页布局（D40 / D41 / D42）

| 反馈 | 处理 |
| --- | --- |
| 游戏下拉框只有英文名，不熟悉 | 新增 `Global.GAME_TR_KEYS` + `game_display_name()`（走 `tr()`，键为 CSV 的 `GAME_*`）；建项时 `set_item_metadata()` 存原始 key，系数一律按 metadata 查（`get_selected_game_key()` / `save_selected_game_value()`），旧存档不受影响 |
| 3D 模式按钮太厚（被预览容器拉伸） | 按钮改 `SIZE_SHRINK_CENTER` + 固定高度（先减半至 150），2D 同步 |
| 四个按钮长短不一 | `sync_mode_layout()`：`await process_frame` 后按最宽文字统一宽度（×1.1） |
| 左右两列不等高 | 行高改为按**左列实际高度**均分，按钮几乎撑满行高（上下各 12px）；监听 `left_column.resized` 自动重算（应对字体异步加载导致的高度变化） |

### S8 · 第五轮之三：回归修复与文档补全（D43）

| 反馈 | 处理 |
| --- | --- |
| 改完首页整个失效 | 定位到 `Parse Error: Cannot infer the type`（`@onready` 用 `:=` 被推断为 `Node`，`.size.y` / `get_theme_constant()` 返回 `Variant`）→ 显式声明 `VBoxContainer` 类型；无头冒烟确认零报错 |
| 更新所有文档并补帮助文档 | README 重写（新增「帮助文档」章节：设置方法 / 效果 / 7 种玩法 / 快捷键 / 排错）；新增 `docs/OpenAimTrainer_使用说明.md`；项目分析 / 缺陷评估 / 模块架构 / 进度记录四份文档同步至当前代码 |

---

### S9 · 第六轮：输入校验、存档健壮性与模式选中交互（D44–D46）

| 时间 | 反馈 | 处理 |
| --- | --- | --- |
| 10-09 | 灵敏度 / 准星尺寸输错（空串、全角标点）会静默存 0 | `Global.parse_number()` / `parse_number_clamped()` 归一化 + 回退上一次有效值；存档为 0 时启动自动恢复默认（D44） |
| 10-09 | 导入损坏 JSON 会清空并覆盖存档；写盘失败直接崩溃 | `parse_game_data()` 校验，失败保留设置；`write_all_data()` 判空；损坏存档备份为 `.bak`（D45 / D46） |
| 10-09 | 模式按钮点击直接进游戏，「开始训练」形同虚设 | 模式按钮改单选选中（`toggle_mode`，默认选中第一个，3D/2D 各自记忆），「开始训练」进入当前选中模式 |

## 三、累计改动文件清单

| 文件 | 变更类型 | 说明 |
| --- | --- | --- |
| `scripts/global.gd` | 修改 | 成绩记录 `save_record()/get_record()`；显示模式 `get/set/apply_display_mode()`、`toggle_fullscreen()`；窗口尺寸表 `WINDOW_SIZES` |
| `scripts/data_manager.gd` | 修改 | `_ready()` 恢复 locale → `TranslationServer.set_locale()`；最早应用显示模式 |
| `scripts/characters/CharacterBody3D.gd` | 修改 | 删除射击线程（改为 `_physics_process()` 单路）；散布 ±2°；新增 `hit_count` |
| `scripts/characters/target.gd` | 修改 | `target_kill` 回传靶 id，便于清理坐标 |
| `scripts/characters/Target2D.gd` | 修改 | 应用 `TargetColor`；4K 尺寸缩放 |
| `scripts/levels/World.gd` | 修改 | 靶间距检查、常驻 `Timer`、`fit_target_prison()`、结算（命中率 / 最佳）、守卫只校验鼠标捕获 |
| `scripts/levels/World2D.gd` | 修改 | 结算面板 + 历史最佳 + 重开；失焦暂停；结算态忽略 Esc；4K 参数缩放；结算暂停场景树 |
| `scripts/levels/Pause.gd` | 修改 | 新增 `_on_restart_pressed()`；结算态焦点改给 `Restart` |
| `scripts/levels/PauseInput.gd` | **新增** | `process_mode = ALWAYS` 的常驻输入节点，解决 2D 暂停后无法用键盘恢复 |
| `scripts/ui/MainScreen.gd` | 修改 | 去掉误跳转；`!= null` 存档判断；画质滑条样式 / 档位 / 实时百分比；**F 键**切换全屏 |
| `scripts/ui/Options.gd` | 修改 | 语言 / 显示模式 / 窗口大小三个下拉框与同步函数；`putLabel()` 汉化与切换语言后刷新 |
| `scenes/ui/MainScreen.tscn` | 修改 | 新增 `Game` / `Sensitivity` 标签；`QualityRow` + `QualityValue`；修正滑条信号连接路径 |
| `scenes/ui/Options.tscn` | 修改 | 新增 `Language` / `Display` / `WindowSize` 下拉框、提示标签与信号连接 |
| `scenes/levels/World.tscn` | 修改 | 结算面板新增 `Restart`；`Pause` 面板 `process_mode` → 3；弹窗文案改为「点击以锁定鼠标」 |
| `scenes/levels/World2D.tscn` | 修改 | 新增 `PauseInput`、`Score`、`RestartButton`；`Pause` 面板 `process_mode` → 3 |
| `assets/text/translations.csv` | 修改 | 由 4 键 × 2 语 → 55 键 × 3 语 → **58 键 × 15 语** |
| `assets/text/translations.*.translation` | 重新生成 | 由引擎导入器（`--import`）或 `tools/build_translations.gd` 编译，现有 15 个 |
| `assets/text/translations.csv.import` | 修改 | `dest_files` 登记 15 个产物 |
| `tools/build_translations.gd` | **新增 / 修改** | CSV → `.translation` 编译脚本；输出语言改为由 CSV 表头动态决定 |
| `scripts/global.gd` | 修改 | 新增 `GAME_TR_KEYS` + `game_display_name()`（游戏显示名随语言） |
| `scripts/ui/MainScreen.gd` | 修改 | 游戏下拉框 metadata 保 key；模式按钮厚度 / 等宽；`sync_mode_layout()` + `_on_left_column_resized()`；`@onready` 显式类型；模式按钮改单选选中（`_on_mode_button_pressed()` / `_apply_mode_selection()`），「开始训练」进入选中模式 |
| `scripts/ui/Options.gd` | 修改 | `LOCALES` 15 项 + `LOCALE_NAMES` + `locale_to_index()` |
| `project.godot` | 修改 | 注册 15 个翻译资源；`locale/fallback="en"` |
| `README.md` | 修改 | 新增「帮助文档」章节（设置 / 效果 / 玩法 / 快捷键 / 排错）+ 目录与构建说明同步 |
| `docs/OpenAimTrainer_使用说明.md` | **新增** | 完整帮助手册（9 章：上手、界面、设置、玩法、结算、快捷键、存档排错、开发者） |

---

## 四、验证记录

| 时间 | 验证方式 | 结果 |
| --- | --- | --- |
| 20:05 | `godot --headless --path <proj> --quit-after 200` | 无 `ERROR / Parse Error` |
| 20:05 | 三语 `tr()` 打印 | `en / es / zh_CN` 均正确 |
| 20:20 | 3D / 2D 关卡场景实例化冒烟 | 均 `OK`，无脚本错误 |
| 20:34 | 语言下拉同步验证 | `language.selected = 2 → 简体中文`（修复前为 0 / English） |
| 20:38 | 滑条生效验证 | 拖动 → `scaling_3d_scale = 0.5`，标签 `渲染缩放：W × H (50%)` |
| 20:40 | 窗口大小联动验证 | 选 1280×720 → `display_mode` 由 3（全屏）自动置 0（窗口） |
| 20:42 | 滑条档位验证 | `min=0.5 max=2.0 step=0.25 ticks=7 宽度=900`，拖到 1.25 → 125% 生效 |
| 全程 | 实际试玩（3D 60s / 2D 60s） | 可正常结算、重开、返回主菜单 |
| S6 | 15 语 `tr()` 抽样打印（en / ja / ar / zh_TW / de / vi） | 全部正确输出对应语言文案 |
| S6 | `build_translations.gd` 重跑 | `导出完成：58 条 × 15 语言`，15 个 `.translation` 均可被加载 |
| S7 | 布局采样脚本（第 5 / 15 / 40 帧） | `left=1248 right=1248`，按钮等宽、上下边缘各留 12px |
| S7 | 3D ↔ 2D 反复切换 | 列表正确重建（4 / 3 项），无残留行、无脚本报错 |
| S8 | `godot --headless --path . --quit-after 200` | 无 `SCRIPT ERROR` / `Parse Error`（D43 修复复核） |
| S9 | 静态断言脚本（19 项）+ `MainScreen` / `Options` / `World` 三场景 `--headless --quit-after` | 19/19 PASS，三场景均无 `SCRIPT ERROR` / `Parse Error`（D14 / D20 / D23 / D44 修复复核） |
| S10 | `DataManager` 解析 / 导入健壮性断言（17 项）+ 主场景 `--headless --quit-after 120` | 17/17 PASS（含"损坏导入保留设置"），主场景无报错（D45 / D46 修复复核） |
| S11 | `MainScreen` / `Options` / `World` / `World2D` 四场景 `--headless --quit-after` + Godot Movie Maker 实际渲染帧 | 四场景均无 `SCRIPT ERROR` / `Parse Error`；渲染帧确认 2D 与 3D 左列按钮等长、模式按钮等宽等高、预览完整、设置页「返回」位于右下角（D47–D50 复核） |

---

## 五、待办（按优先级）

| 优先级 | 项 | 内容 | 计划 |
| --- | --- | --- | --- |
| P1 | D14 | ✅ 配置字段名 `movment` → `movement`，统一 2D / 3D（`World.gd` 加 `get()` 兜底） | 已完成 2026-10-08 |
| P1 | D23 | ✅ 导入/导出 `FileDialog.current_dir` 改用 `default_save_dir()`（系统文档目录） | 已完成 2026-10-08 |
| P1 | D20 | ✅ `Crosshair` 参数缓存 + 去掉每帧 `new Polygon2D()` | 已完成 2026-10-08 |
| P1 | D44 | ✅ 灵敏度 / 准星尺寸输入校验，非法输入不再写 0 | 已完成 2026-10-08 |
| P1 | D45 | ✅ 导入 / 读取损坏 JSON 不再清空覆盖存档（失败保留设置；损坏时备份 `.bak`） | 已完成 2026-10-09 |
| P1 | D46 | ✅ `save_data` / `save_all_data` 写盘失败不再崩溃（判空 + 返回 false） | 已完成 2026-10-09 |
| P1 | D47 | ✅ 2D 模式按钮样式 / 选中态与 3D 一致（重建后重新套 `UIStyle`） | 已完成 2026-10-09 |
| P1 | D48 | ✅ 2D 列表行高不再被压扁（下限 300）+ 2D 预览加深色背景 | 已完成 2026-10-09 |
| P1 | D49 | ✅ 模式按钮宽度统一（3D 组内 + 2D/3D 跨维度），布局未就绪时重试 | 已完成 2026-10-09 |
| P1 | D50 | ✅ 2D 左列按钮不再被压短（左列固定最小宽 1250） | 已完成 2026-10-09 |
| P2 | — | ✅ 设置页「返回」移至视口右下角，宽度缩至 1/4 | 已完成 2026-10-09 |
| P2 | D17 | 命中 / 结算 / UI 音效 + 音量设置 | Phase 2（约 2–3 天） |
| P2 | D21 | 2D 模式准星与灵敏度 | Phase 2 |
| P2 | — | 成绩扩展：时间序列、近 10 次曲线、本轮 vs 最佳 | Phase 2 |
| P3 | D18 / D19 | 2D 靶贴图、目录整理 | Phase 3（约 1 周） |
| P3 | — | 模式配置 Resource 化、抽 `BaseLevel` 基类 | Phase 3 |
| P3 | — | 阿拉伯语等 RTL 语言的布局镜像（`MainScreen` / `Options`） | Phase 3 |

---

## 六、风险与注意事项

1. **引擎版本**：本机 Godot 为 4.7，项目声明 4.5；全程未用编辑器保存，`config/features` 仍为 4.5。用 4.7 编辑器保存会不可逆升级，需先备份。
2. **存档文件**：`user://open_aim_trainer.json`（Windows 下为 `%APPDATA%\Godot\app_userdata\Open Aim Trainer\`）。
   - 教训：用 `godot --script` 跑验证脚本时 **autoload 的 `_ready()` 不会执行**，`DataManager` 从不读盘，任何 `save_data()` 都会用空字典覆盖存档。
   - 已处理：2026-10-08 20:44 用无 BOM 的 UTF-8 还原为 `locale=zh_CN`、`resolution=1.0`，准星与灵敏度按原值保留。
   - 后续：验证脚本禁止再写用户存档；确需运行时，请在脚本内先手动调用 `load_all_data()`。
3. **翻译产物**：`assets/text/translations.*.translation` 为生成物，改 CSV 后必须重新编译（推荐 `godot --headless --path . --import`，或 `--script res://tools/build_translations.gd`）；新增语言列时同时更新 `project.godot → locale/translations` 与 `translations.csv.import` 的 `dest_files`。
4. **Web 端**：显示模式 / 窗口大小 / 画质滑条在 Web 下自动隐藏或不生效（浏览器限制），属预期行为。

---

*进度记录生成时间：2026-10-08 20:45（UTC+8） · 最后更新：2026-10-08（S6–S8：15 语言 / 游戏名本地化 / 首页布局 / 文档补全后）*
*下次更新请新建带日期的同名文档，或在本文追加"修订记录"*
