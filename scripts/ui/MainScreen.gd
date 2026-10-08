extends Control

@onready var game = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/HBoxContainer/Game
@onready var resolution_label := $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/ResolutionLabel
@onready var gamelist: VBoxContainer = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer2
@onready var left_column: VBoxContainer = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer
@onready var quality_row := $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/QualityRow
@onready var slider_quality := $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/QualityRow/QualitySlider
@onready var quality_value := $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/QualityRow/QualityValue
@onready var sensitivity := $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/HBoxContainer/Sensitivity
@onready var exit_button = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/Quit
@onready var check_button = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/CheckButton
@onready var sensitivity_container = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/HBoxContainer
@onready var options_button = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/Options


const ModePreview3D = preload("res://scenes/ui/ModePreview3D.tscn")
const ModePreview2D = preload("res://scenes/ui/ModePreview2D.tscn")
const UIStyle = preload("res://scripts/ui/ui_style.gd")

# 灵敏度取值范围：0 会让视角完全不动（看起来像卡死），因此设下限；
# 上限只用来拦住"手滑多打几个 0"这类误输入
const MIN_SENSITIVITY := 0.001
const MAX_SENSITIVITY := 1000.0
const DEFAULT_SENSITIVITY := 1.0

# 右侧模式列表是“单选选中”：3D / 2D 各自记住当前选中项，
# 启动时默认选中第一个；点「开始训练」才进入对应关卡
var selected_mode_3d := ""
var selected_mode_2d := ""
var _mode_buttons_3d: Array[Button] = []
var _mode_buttons_2d: Array[Button] = []


# Called when the node enters the scene tree for the first time.
func _ready():
	check_button.toggled.connect(_on_check_button_toggled)
	# 左列高度变化（字体异步加载、语言切换）时自动重新对齐右侧模式列表
	left_column.resized.connect(_on_left_column_resized)
	
	if OS.has_feature("web"):
		slider_quality.visible = false
		resolution_label.visible = false
		exit_button.visible = false
	else:
		# 按设置里保存的显示模式启动（窗口 / 最大化 / 全屏），不再强制全屏
		Global.apply_display_mode()

	style_quality_slider()

	AddGamesSensitivities()
	# 注意：存档值为 0 时也要生效，因此统一用 != null 判断（不能用真值判断）
	if DataManager.get_data("resolution") != null:
		slider_quality.value = DataManager.get_data("resolution")
	update_quality_label(slider_quality.value)
	if DataManager.get_data("sensitivity") != null:
		# 兜底：历史上非法输入会被存成 0（视角完全不动），这里恢复成默认值
		var saved_sensitivity := float(DataManager.get_data("sensitivity"))
		if saved_sensitivity <= 0.0:
			saved_sensitivity = DEFAULT_SENSITIVITY
			DataManager.save_data("sensitivity", saved_sensitivity)
		sensitivity.text = str(saved_sensitivity)
	if DataManager.get_data("sensitivity_game") != null:
		game.selected = DataManager.get_data("sensitivity_game")
	elif game.item_count > 0:
		game.selected = 0
		DataManager.save_data("sensitivity_game", 0)
		save_selected_game_value()
	# 首次运行：把输入框里的默认灵敏度落盘，避免 UI 显示值与实际手感不一致
	if DataManager.get_data("sensitivity") == null:
		DataManager.save_data("sensitivity",
				Global.parse_number_clamped(sensitivity.text, DEFAULT_SENSITIVITY,
						MIN_SENSITIVITY, MAX_SENSITIVITY))
	AddGames()
	
	if DataManager.get_data("is_3d_mode") != null:
		check_button.button_pressed = DataManager.get_data("is_3d_mode")
		
	# 2D 模式会隐藏渲染缩放 / 灵敏度 / 设置等行，左列随之收窄，
	# 「开始训练」「退出」会被压短；这里固定左列最小宽度与 3D 布局一致
	# （3840 设计基准下 3D 左列实测约 1240），保证两种模式下左列按钮等长
	left_column.custom_minimum_size.x = 1250.0

	# Initialize visibility
	update_ui_visibility(check_button.button_pressed)
		
	get_viewport().size_changed.connect(self.update_resolution_label)
	update_resolution_label()

	# 与设置页保持一致：按钮/输入框显式加底色与描边，悬停用高对比蓝
	UIStyle.apply_controls(self)

#func _process(_delta):
#	if Input.is_action_pressed("f_pressed"):
#		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func AddGamesSensitivities():
	for sens in Global.games_sensitivities:
		# 显示名跟随语言，内部 key 存到 metadata，避免换算系数查不到
		game.add_item(Global.game_display_name(sens))
		game.set_item_metadata(game.item_count - 1, sens)


# 取下拉框当前项的内部 key（换算表的原始键名）
func get_selected_game_key() -> String:
	var key = game.get_item_metadata(game.get_selected_id())
	if key == null:
		key = Global.games_sensitivities.keys()[game.get_selected_id()]
	return key


# 按内部 key 重新计算并保存当前游戏的换算系数
func save_selected_game_value() -> void:
	if game.get_selected_id() < 0:
		return
	DataManager.save_data("sensitivity_game_value",
			Global.games_sensitivities.get(get_selected_game_key()))


func AddGames():
	# Clear existing children first (important when switching back from 2D)
	for child in gamelist.get_children():
		child.queue_free()
		
	var mode_buttons: Array[Button] = []
	for model in Global.models3d:
		var hboxc = HBoxContainer.new()
		var button = Button.new()
		button.theme = load("res://assets/themes/theme.tres")
		button.text = tr(model)
		button.name = model
		# 模式按钮是“单选选中”：点击只切换高亮，点「开始训练」才进关卡
		button.toggle_mode = true
		button.pressed.connect(_on_mode_button_pressed.bind(button, true))
		


		var preview = ModePreview3D.instantiate()
		preview.setup_scene(model, Global.models3d[model])

		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(300, 300) 
		wrapper.add_child(preview)

		# 按钮不再随预览容器(300px)拉伸成厚框：垂直居中，厚度减半
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size = Vector2(0, 150)

		hboxc.add_child(wrapper)
		hboxc.add_child(button)
		gamelist.add_child(hboxc)
		mode_buttons.append(button)

	_mode_buttons_3d = mode_buttons
	if selected_mode_3d.is_empty() or not Global.models3d.has(selected_mode_3d):
		selected_mode_3d = Global.models3d.keys()[0]
	_apply_mode_selection(mode_buttons, selected_mode_3d)

	# 按钮是动态创建的，切换 3D/2D 重建后必须重新套高对比样式，
	# 否则选中态（按下态）几乎看不出来
	UIStyle.apply_controls(gamelist)

	# 等布局稳定后统一按钮宽度，并让右侧列表总高对齐左侧控制列
	sync_mode_layout.call_deferred(mode_buttons)


# 模式按钮单选：点击只更新选中态（按下态高亮），不进入关卡
func _on_mode_button_pressed(button: Button, is_3d: bool) -> void:
	var buttons: Array[Button] = _mode_buttons_3d if is_3d else _mode_buttons_2d
	if is_3d:
		selected_mode_3d = String(button.name)
	else:
		selected_mode_2d = String(button.name)
	_apply_mode_selection(buttons, String(button.name))


# 让列表中只有 mode_name 对应的按钮处于按下（选中）态
func _apply_mode_selection(buttons: Array[Button], mode_name: String) -> void:
	for b in buttons:
		if is_instance_valid(b):
			b.set_pressed_no_signal(b.name == mode_name)


# 依赖真实布局的宽度统一与左右列高度对齐统一放到这里（等一帧后再算）。
# 字体（尤其 CJK 回退字体）异步加载会让左列高度变化，
# 因此监听 left_column.resized 自动重算，保证两边始终等高。
var _last_mode_buttons: Array[Button] = []
# 跨 3D / 2D 两组模式按钮统一的尺寸：两组各自取最宽/最高者生效，
# 保证切换 3D↔2D 时按钮长宽完全一致（右边列对齐）
var _unified_button_size := Vector2.ZERO
var _sync_retries := 0


func sync_mode_layout(buttons: Array[Button]) -> void:
	_last_mode_buttons = buttons
	await get_tree().process_frame
	var rows := gamelist.get_children()
	var target := left_column.size.y
	if rows.is_empty() or target <= 0.0:
		# 布局尚未就绪（首帧左列还没有尺寸）：下一帧重试而不是放弃，
		# 否则宽度统一永远不会执行（按钮恢复成各自文字的自然宽度、长短不一）
		_sync_retries += 1
		if _sync_retries < 30:
			sync_mode_layout.call_deferred(buttons)
		return
	_sync_retries = 0

	# 宽度：用主题探测按钮测量 3D + 2D 全部模式名的自然宽度，取最宽者 ×1.1。
	# 两组共用同一基准，保证冷启动直接进 2D / 3D、或运行时互相切换，
	# 按钮宽度都完全一致（不随当前显示的是哪组文字变长变短）。
	# 探测按钮必须挂进场景树（隐藏），否则拿不到项目主题的字体回退，测出来会偏窄
	var probe := Button.new()
	probe.theme = load("res://assets/themes/theme.tres")
	UIStyle.apply_controls(probe)  # 与真实按钮同款 stylebox（含左右 40px 边距），宽度才一致
	probe.visible = false
	gamelist.add_child(probe)
	var width := 0.0
	for mode_name: String in Global.models3d.keys() + Global.models2d.keys():
		probe.text = tr(mode_name)
		width = maxf(width, probe.get_combined_minimum_size().x)
	probe.queue_free()
	width = maxf(width * 1.1, _unified_button_size.x)

	# 高度：右侧行总高 ≈ 左侧控制列高度；按钮几乎撑满行高（上下各留 12px）。
	# 行高下限 300（= 预览完整尺寸）：2D 模式会隐藏左列的灵敏度 / 设置 /
	# 渲染缩放等行，左列变矮；若跟着左列把行高压到 300 以下，
	# 预览会被裁剪、按钮挤成一条，观感与 3D 不一致。
	# 按钮高度同样与另一组（3D/2D）取大者统一
	var sep := float(gamelist.get_theme_constant("separation"))
	var row_h := maxf(300.0, (target - sep * (rows.size() - 1)) / float(rows.size()))
	var button_h := maxf(clampf(row_h - 24.0, 120.0, row_h), _unified_button_size.y)
	_unified_button_size = Vector2(width, button_h)

	for row in rows:
		if row.get_child_count() < 2:
			continue
		var wrapper := row.get_child(0) as Control
		var button := row.get_child(1) as Button
		if wrapper:
			wrapper.custom_minimum_size = Vector2(300, row_h)
		if button:
			button.custom_minimum_size = Vector2(width, button_h)


# 左列高度变化（语言切换 / 字体加载完成）时重新对齐右侧
func _on_left_column_resized() -> void:
	if not _last_mode_buttons.is_empty():
		sync_mode_layout.call_deferred(_last_mode_buttons)

func startTraining(type):
	if !OS.has_feature("web"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Global.game_type = type
	get_tree().change_scene_to_file("res://scenes/levels/World.tscn")


func update_resolution_label() -> void:
	var viewport_render_size = get_viewport().size * get_viewport().scaling_3d_scale
	# 这个滑条改的是 3D 渲染缩放（画质/性能），不是窗口大小
	resolution_label.text = "%s：%d × %d (%d%%)" \
			% [tr("Render scale"), viewport_render_size.x, viewport_render_size.y,
			round(get_viewport().scaling_3d_scale * 100)]


# 「开始训练」进入当前选中的模式；模式列表启动时已默认选中第一个，
# 因此任何时候点击都有明确目标（不再随机抽取）
func _on_play_pressed():
	if check_button.button_pressed:
		startTraining(selected_mode_3d)
	else:
		startTraining2D(selected_mode_2d)


func _on_quality_slider_value_changed(value: float) -> void:
	get_viewport().scaling_3d_scale = value
	update_resolution_label()
	update_quality_label(value)
	DataManager.save_data("resolution", value)


func update_quality_label(value: float) -> void:
	if quality_value == null:
		return
	quality_value.text = "%d%%" % round(value * 100)


# 默认主题的滑条在 4K 缩放下几乎看不清，这里显式指定高对比样式
func style_quality_slider() -> void:
	if slider_quality == null:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.13, 0.13, 0.16, 1.0)
	track.set_border_width_all(4)
	track.border_color = Color(0.55, 0.55, 0.6, 1.0)
	track.set_corner_radius_all(16)
	track.content_margin_top = 34
	track.content_margin_bottom = 34
	slider_quality.add_theme_stylebox_override("slider", track)
	# 刻度线用 font_color 绘制，调亮一点让刻度看得清
	slider_quality.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92, 1.0))

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.0, 0.64, 0.95, 1.0)
	fill.set_corner_radius_all(16)
	fill.content_margin_top = 34
	fill.content_margin_bottom = 34
	slider_quality.add_theme_stylebox_override("grabber_area", fill)
	slider_quality.add_theme_stylebox_override("grabber_area_highlight", fill)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	grabber.set_corner_radius_all(14)
	grabber.content_margin_left = 30
	grabber.content_margin_right = 30
	grabber.content_margin_top = 54
	grabber.content_margin_bottom = 54
	slider_quality.add_theme_stylebox_override("grabber", grabber)

	var grabber_highlight := StyleBoxFlat.new()
	grabber_highlight.bg_color = Color(0.4, 0.87, 1.0, 1.0)
	grabber_highlight.set_corner_radius_all(14)
	grabber_highlight.content_margin_left = 30
	grabber_highlight.content_margin_right = 30
	grabber_highlight.content_margin_top = 54
	grabber_highlight.content_margin_bottom = 54
	slider_quality.add_theme_stylebox_override("grabber_highlight", grabber_highlight)


func _on_quit_pressed():
	get_tree().quit()


func _on_options_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/Options.tscn")


func _on_sensitivity_text_changed(new_text):
	DataManager.save_data("sensitivity_game", game.get_selected_id())
	save_selected_game_value()
	# 空串 / 非数字（含中文全角标点）时保留上一次有效值，不再静默写成 0
	var previous = DataManager.get_data("sensitivity")
	if previous == null:
		previous = DEFAULT_SENSITIVITY
	DataManager.save_data("sensitivity",
			Global.parse_number_clamped(new_text, float(previous), MIN_SENSITIVITY, MAX_SENSITIVITY))


func _on_game_item_selected(index):
	DataManager.save_data("sensitivity_game", index)
	save_selected_game_value()


func _on_check_button_toggled(toggled_on):
	# Toggle between 2D and 3D
	# Assuming button text is "3D" or similar, we can change it to "2D" when off
	# But actually the button text is static "3D" and checked=true means 3D.
	
	DataManager.save_data("is_3d_mode", toggled_on) # Save state
	update_ui_visibility(toggled_on)
	
	if toggled_on:
		Global.game_type = "" # Reset or keep last?
		AddGames()
	else:
		Global.game_type = ""
		AddGames2D()

func AddGames2D():
	# Clear existing children first
	for child in gamelist.get_children():
		child.queue_free()
		
	var mode_buttons: Array[Button] = []
	for model in Global.models2d:
		var hboxc = HBoxContainer.new()
		var button = Button.new()
		button.theme = load("res://assets/themes/theme.tres")
		button.text = tr(model)
		button.name = model
		button.toggle_mode = true
		button.pressed.connect(_on_mode_button_pressed.bind(button, false))

		var preview = ModePreview2D.instantiate()
		preview.setup_scene(model, Global.models2d[model])

		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(300, 300) 
		wrapper.add_child(preview)

		# 与 3D 模式按钮保持一致：垂直居中，厚度减半
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size = Vector2(0, 150)

		hboxc.add_child(wrapper)
		hboxc.add_child(button)
		gamelist.add_child(hboxc)
		mode_buttons.append(button)

	_mode_buttons_2d = mode_buttons
	if selected_mode_2d.is_empty() or not Global.models2d.has(selected_mode_2d):
		selected_mode_2d = Global.models2d.keys()[0]
	_apply_mode_selection(mode_buttons, selected_mode_2d)

	# 与 3D 保持一致：重建后重新套高对比样式，保证选中态可见
	UIStyle.apply_controls(gamelist)

	# 与 3D 保持一致：等布局稳定后统一宽度并对齐左右列高度
	sync_mode_layout.call_deferred(mode_buttons)

func startTraining2D(type):
	Global.game_type = type
	get_tree().change_scene_to_file("res://scenes/levels/World2D.tscn")

func update_ui_visibility(is_3d: bool):
	if sensitivity_container:
		sensitivity_container.visible = is_3d
	if options_button:
		options_button.visible = is_3d
	
	if !OS.has_feature("web"):
		quality_row.visible = is_3d
		resolution_label.visible = is_3d


# F 键在窗口 / 全屏之间切换（输入框获得焦点时不拦截按键）
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("f_pressed"):
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return
	Global.toggle_fullscreen()
