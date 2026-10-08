extends Control


#Code needed on export Header web:
#<script>
#function getFile(callback) {
#		window.input = document.createElement('input');
#		input.type = 'file';
#		input.onchange = e => {
#			var file = e.target.files[0];
#			var reader = new FileReader();
#			reader.readAsText(file, 'UFT-8');
#			reader.onload = readerEvent => {
#				callback(readerEvent.target.result);
#			}
#		}
#	}
#</script>

signal refresh_crosshair

@onready var columns = $ScrollContainer/MarginContainer/HBoxContainer
@onready var left_column = $ScrollContainer/MarginContainer/HBoxContainer/VBoxContainer
@onready var right_column = $ScrollContainer/MarginContainer/HBoxContainer/VBoxContainer2
# 注意：场景里有两个名为 Crosshair 的节点（预览控件 + 开关），这里必须写完整路径取预览控件
@onready var crosshair = $ScrollContainer/MarginContainer/HBoxContainer/VBoxContainer/CrosshairBox/Control/Crosshair
@onready var file_export = $ScrollContainer/MarginContainer/HBoxContainer/VBoxContainer2/ExportFileDialog
@onready var file_import = $ScrollContainer/MarginContainer/HBoxContainer/VBoxContainer2/ImportFileDialog
@onready var language = $ScrollContainer/MarginContainer/HBoxContainer/VBoxContainer2/RowLanguage/Language
@onready var display = $ScrollContainer/MarginContainer/HBoxContainer/VBoxContainer2/RowDisplay/Display
@onready var display_hint = $ScrollContainer/MarginContainer/HBoxContainer/VBoxContainer2/DisplayHint
@onready var window_size_option = $ScrollContainer/MarginContainer/HBoxContainer/VBoxContainer2/RowWindowSize/WindowSize

# putLabel 动态生成的 Label，切换语言后需要手动刷新
var put_labels := {}

# 颜色项右侧的十六进制值标签（键为对应的 ColorPickerButton）
var color_value_labels := {}

var fileImportCallback = null

# 语言切换下拉框的显示顺序必须与 LOCALES 一一对应
const LOCALES: Array[String] = ["en", "es", "zh_CN", "zh_TW", "zh_HK", "ja", "ko", "fr", "de",
		"pt_BR", "ru", "it", "tr", "ar", "vi"]

# 下拉框里的母語寫法，順序同樣要與 LOCALES 一一對應
const LOCALE_NAMES: Array[String] = ["English", "Español", "简体中文", "繁體中文（台灣）", "繁體中文（香港）",
		"日本語", "한국어", "Français", "Deutsch", "Português (Brasil)", "Русский", "Italiano", "Türkçe",
		"العربية", "Tiếng Việt"]

# 显示模式下拉框的显示顺序必须与 DISPLAY_MODES 一一对应
# 0 窗口 / 2 最大化 / 3 全屏（对应 DisplayServer.WindowMode）
const DISPLAY_MODES := [0, 2, 3]

const UIStyle = preload("res://scripts/ui/ui_style.gd")

# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.has_feature("web"):
		fileImportCallback = JavaScriptBridge.create_callback(Callable(self, "file_parser"))
		var window = JavaScriptBridge.get_interface("window")
		window.getFile(fileImportCallback)
	file_export.visible = false
	file_import.visible = false
	if language:
		for language_name in LOCALE_NAMES:
			language.add_item(language_name)
	if display:
		display.add_item(tr("Windowed"))
		display.add_item(tr("Maximized"))
		display.add_item(tr("Fullscreen"))
	if display_hint:
		display_hint.text = tr("DISPLAY_HINT")
	if window_size_option:
		for size in Global.WINDOW_SIZES:
			window_size_option.add_item("%d × %d" % [size.x, size.y])
	loadSaved()
	# 语言 / 显示模式 / 窗口大小保存的不是索引，需要单独同步下拉框的选中项
	sync_language_selection()
	sync_display_selection()
	sync_window_size_selection()
	
	var all_put_labels = get_tree().get_nodes_in_group("PutLabel")
	for put_label in all_put_labels:
		putLabel(put_label)
	# 全部控件就位后再统一外观：按钮/输入框要有明显的底色与描边，
	# 悬停、按下、勾选态用高对比蓝色，避免被当成纯文本
	UIStyle.apply_controls($ScrollContainer)
	style_option_texts()
	compact_color_buttons()

func putLabel(put_label):
	var label = Label.new()
	var hbox = HBoxContainer.new()
	label.text = tr(put_label.name) + ': '
	# 固定项名列宽，让各行的“值”左对齐成一列
	label.custom_minimum_size = Vector2(640, 0)
	label.size_flags_horizontal = 0
	put_labels[put_label] = label
	hbox.add_theme_constant_override("separation", 40)
	hbox.add_child(label)
	var parent = put_label.get_parent()
	var index = put_label.get_index()
	parent.remove_child(put_label)
	put_label.size_flags_horizontal = 3
	hbox.add_child(put_label)
	parent.add_child(hbox)
	parent.move_child(hbox, index)

func loadSaved():
	var all_persist_groups = get_tree().get_nodes_in_group("Persist")
	for persist_group in all_persist_groups:
		match persist_group.get_class():
			"CheckButton":
				if DataManager.get_data(persist_group.name) != null:
					persist_group.set_pressed(DataManager.get_data(persist_group.name))
			"LineEdit":
				if DataManager.get_data(persist_group.name) != null:
					persist_group.text = str((DataManager.get_data(persist_group.name)))
			"ColorPickerButton":
				if DataManager.get_data(persist_group.name) != null:
					persist_group.color = Global.string_to_color(DataManager.get_data(persist_group.name)) 
			"OptionButton":
				# Language / Display 保存的是 locale 字符串与显示模式枚举，不是索引，跳过通用读取
				if persist_group.name == "Language" or persist_group.name == "Display" or persist_group.name == "WindowSize":
					continue
				if DataManager.get_data(persist_group.name) != null:
					persist_group.selected = int(DataManager.get_data(persist_group.name))
			_:
				print("Not loaded")

# 语言下拉框要跟随当前生效的 locale，否则会出现“界面是中文、下拉框显示 English”
func sync_language_selection() -> void:
	if language == null or language.item_count == 0:
		return
	var current_locale := TranslationServer.get_locale()
	var index := locale_to_index(current_locale)
	# 首次运行把系统自动识别出的语言落盘，保证显示与存档一致
	if DataManager.get_data("locale") == null:
		DataManager.save_data("locale", LOCALES[index])
	language.selected = index


# 把任意 locale（含 zh_TW / pt / de_DE 等变体）映射到 LOCALES 的索引，
# 找不到就回退到英文，避免界面 language 与下拉框不同步
func locale_to_index(locale: String) -> int:
	var index := LOCALES.find(locale)
	if index >= 0:
		return index
	var lower := locale.to_lower()
	if lower.begins_with("zh"):
		# 繁體按地區細分：台灣 / 香港澳門，其餘統一用簡體
		if lower.find("tw") >= 0 or lower.find("hant") >= 0:
			return LOCALES.find("zh_TW")
		if lower.find("hk") >= 0 or lower.find("mo") >= 0:
			return LOCALES.find("zh_HK")
		return LOCALES.find("zh_CN")
	for i in LOCALES.size():
		if lower.begins_with(LOCALES[i].substr(0, 2).to_lower()):
			return i
	return 0

func sync_display_selection() -> void:
	if display == null or display.item_count == 0:
		return
	var index := DISPLAY_MODES.find(Global.get_display_mode())
	display.selected = max(index, 0)

func sync_window_size_selection() -> void:
	if window_size_option == null or window_size_option.item_count == 0:
		return
	window_size_option.selected = Global.get_window_size_index()

# 切换语言后刷新所有代码里生成的文本（这些不会被引擎自动重译）
func refresh_dynamic_texts() -> void:
	for put_label in put_labels:
		put_labels[put_label].text = tr(put_label.name) + ': '
	if display_hint:
		display_hint.text = tr("DISPLAY_HINT")


# ---------------------------------------------------------------------------
# 排版：把“参数项名”（灰、小）与“参数值”（白、大）在视觉上区分开
#   分组标题（CROSSHAIR / TARGET / IMPORT EXPORT）→ 淡蓝、较大
#   参数项名（语言 / 显示模式 / 点大小 …）        → 灰、较小
#   参数值（简体中文 / 窗口 / 6 …）               → 亮白、正常大小
# ---------------------------------------------------------------------------
const COLOR_GROUP := Color(0.45, 0.80, 1.0, 1.0)
const COLOR_LABEL := Color(0.64, 0.68, 0.76, 1.0)
const COLOR_VALUE := Color(0.96, 0.98, 1.0, 1.0)
const GROUP_TITLES := ["LabelCrosshair", "LabelTarget", "ImportExport"]
const HINT_NAMES := ["DisplayHint"]

func style_option_texts() -> void:
	var base := float(get_theme_default_font_size())
	if base <= 0.0:
		base = 64.0
	_apply_text_style($ScrollContainer, base)


func _apply_text_style(node: Node, base: float) -> void:
	for child in node.get_children():
		if child is Label:
			# 场景里的静态文案（分组标题、行内项名）显式翻译一次，
			# 不依赖引擎的自动翻译，切换语言后也能立刻生效
			child.text = tr(child.text)
			if child.name in HINT_NAMES:
				child.add_theme_font_size_override("font_size", int(base * 0.62))
				child.add_theme_color_override("font_color", COLOR_LABEL)
			elif child.name in GROUP_TITLES:
				child.add_theme_font_size_override("font_size", int(base * 0.95))
				child.add_theme_color_override("font_color", COLOR_GROUP)
			else:
				# putLabel 生成的项名 / 场景里行内写死的项名（LabelLanguage 等）
				child.add_theme_font_size_override("font_size", int(base * 0.72))
				child.add_theme_color_override("font_color", COLOR_LABEL)
		elif child is LineEdit or child is OptionButton or child is ColorPickerButton \
				or child is CheckButton or child is Button:
			child.add_theme_font_size_override("font_size", int(base * 0.86))
			child.add_theme_color_override("font_color", COLOR_VALUE)
		if child.get_child_count() > 0:
			_apply_text_style(child, base)


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/MainScreen.tscn")


func _on_crosshair_toggled(button_pressed):
	DataManager.save_data("Crosshair", button_pressed)
	emit_signal("refresh_crosshair")


func _on_outline_toggled(button_pressed):
	DataManager.save_data("Outline", button_pressed)
	emit_signal("refresh_crosshair")


func _on_crosshair_inner_toggled(button_pressed):
	DataManager.save_data("CrosshairInner", button_pressed)
	emit_signal("refresh_crosshair")


func _on_dot_toggled(button_pressed):
	DataManager.save_data("Dot", button_pressed)
	emit_signal("refresh_crosshair")


# 数值项统一入口：空串 / 非数字（含中文全角标点）时保留上一次有效值，
# 不再像之前那样 float() 得到 0 并写盘（准星会整块消失）
func save_numeric_option(key: String, new_text: String, default_value: float) -> void:
	var previous = DataManager.get_data(key)
	if previous == null:
		previous = default_value
	DataManager.save_data(key, Global.parse_number(new_text, float(previous)))
	emit_signal("refresh_crosshair")


func _on_dot_size_text_changed(new_text):
	save_numeric_option("DotSize", new_text, 6.0)


func _on_outline_size_text_changed(new_text):
	save_numeric_option("OutlineSize", new_text, 2.0)


func _on_crosshair_height_text_changed(new_text):
	save_numeric_option("CrosshairHeight", new_text, 4.0)


func _on_crosshair_width_text_changed(new_text):
	save_numeric_option("CrosshairWidth", new_text, 12.0)


func _on_crosshair_space_text_changed(new_text):
	save_numeric_option("CrosshairSpace", new_text, 5.0)


func _on_crosshair_color_color_changed(color):
	DataManager.save_data("CrosshairColor", str(color))
	update_color_value("CrosshairColor")
	emit_signal("refresh_crosshair")

func _on_outline_color_color_changed(color):
	DataManager.save_data("OutlineColor", str(color))
	update_color_value("OutlineColor")
	emit_signal("refresh_crosshair")

func _on_target_color_color_changed(color):
	DataManager.save_data("TargetColor", str(color))
	update_color_value("TargetColor")
	emit_signal("refresh_crosshair")


# 颜色项：只保留一个小色块，后面跟十六进制值，不再拉成长条
func compact_color_buttons() -> void:
	var base := float(get_theme_default_font_size())
	if base <= 0.0:
		base = 64.0
	color_value_labels.clear()
	for node in get_tree().get_nodes_in_group("PutLabel"):
		if not (node is ColorPickerButton):
			continue
		node.text = ""
		node.custom_minimum_size = Vector2(260, 0)
		node.size_flags_horizontal = 0
		var value := Label.new()
		value.name = "ColorValue"
		value.custom_minimum_size = Vector2(560, 0)
		value.text = "#" + node.color.to_html(false)
		value.add_theme_font_size_override("font_size", int(base * 0.86))
		value.add_theme_color_override("font_color", COLOR_VALUE)
		node.get_parent().add_child(value)
		color_value_labels[node] = value


func update_color_value(key: String) -> void:
	for node in color_value_labels:
		if node.name == key:
			color_value_labels[node].text = "#" + node.color.to_html(false)


func file_parser(args):
	# 解析失败时 DataManager 会保留现有设置，这里只在成功时落盘
	if DataManager.load_all_data_from_param(args[0]):
		DataManager.save_all_data()

# 导入 / 导出对话框的默认目录。以前写死 "/"，在 Windows 上会落在盘符根目录，
# 用户要一路翻找才能存下配置文件
func default_save_dir() -> String:
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if dir.is_empty():
		dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://")
	return dir


func _on_export_pressed():
	if OS.has_feature("web"):
		DataManager.save_all_data_to_file_web()
	else:
		file_export.current_dir = default_save_dir()
		file_export.visible = true



func _on_import_pressed():
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		window.input.click()
	else:
		file_import.current_dir = default_save_dir()
		file_import.visible = true


func _on_export_file_dialog_file_selected(path):
	DataManager.save_all_data(path)


func _on_import_file_dialog_file_selected(path):
	# 只有读取成功才落盘：否则会把空设置写进 user://，导致设置与成绩全部丢失
	if DataManager.load_all_data(path):
		DataManager.save_all_data()


func _on_language_item_selected(index: int) -> void:
	if index < 0 or index >= LOCALES.size():
		return
	var locale = LOCALES[index]
	TranslationServer.set_locale(locale)
	DataManager.save_data("locale", locale)
	# 先让引擎重新翻译场景里自动翻译的文本，再刷新代码生成的文本；
	# 最后重载当前场景，确保所有编辑器里的静态文案都换成新语言
	refresh_dynamic_texts()
	if get_tree().current_scene != null:
		get_tree().reload_current_scene()


func _on_display_item_selected(index: int) -> void:
	if index < 0 or index >= DISPLAY_MODES.size():
		return
	Global.set_display_mode(DISPLAY_MODES[index])


func _on_window_size_item_selected(index: int) -> void:
	if index < 0 or index >= Global.WINDOW_SIZES.size():
		return
	Global.set_window_size_index(index)
