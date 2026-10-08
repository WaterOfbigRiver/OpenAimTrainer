extends RefCounted

# 用法（不用 class_name，避免无头/导出时全局类缓存未刷新导致解析失败）：
#   const UIStyle = preload("res://scripts/ui/ui_style.gd")
#   UIStyle.apply_controls(self)

# ---------------------------------------------------------------------------
# 统一的控件外观
# 项目自带主题里 Button/LineEdit 的 normal 是纯黑、hover 是近黑（0.0987），
# 在黑色背景上完全看不出“这是个按钮/输入框”，容易被当成纯文本。
# 这里用高对比 StyleBoxFlat 显式给出：底色 + 描边 + 悬停/按下/聚焦态。
# ---------------------------------------------------------------------------

const BG_PANEL := Color(0.15, 0.16, 0.20, 1.0)      # 按钮常态底色
const BG_INPUT := Color(0.07, 0.08, 0.10, 1.0)      # 输入框底色（比面板更深，形成“凹槽”）
const BG_HOVER := Color(0.20, 0.45, 0.70, 1.0)      # 悬停：明显偏蓝
const BG_PRESSED := Color(0.10, 0.30, 0.52, 1.0)    # 按下 / 勾选
const BG_INPUT_FOCUS := Color(0.11, 0.14, 0.18, 1.0)
const BORDER := Color(0.62, 0.67, 0.76, 1.0)
const BORDER_INPUT := Color(0.75, 0.79, 0.88, 1.0)
const ACCENT := Color(0.40, 0.82, 1.0, 1.0)
const TEXT := Color(0.96, 0.98, 1.0, 1.0)
const TEXT_DIM := Color(0.55, 0.58, 0.64, 1.0)


static func make_box(bg: Color, border: Color, border_width: int, radius: int,
		margin_x: int, margin_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(border_width)
	box.border_color = border
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box


# 递归给整棵子树里的按钮 / 下拉框 / 开关 / 输入框套样式
static func apply_controls(root: Node) -> void:
	if root == null:
		return
	_apply_one(root)
	for child in root.get_children():
		# 弹窗内部保持系统样式，避免改出奇怪的对话框
		if child is FileDialog or child is Popup:
			continue
		apply_controls(child)


static func _apply_one(node: Node) -> void:
	if node is HSlider or node is VSlider:
		return

	if node is LineEdit:
		# 输入框：深底 + 亮边框 + 蓝色光标，明确“可编辑”
		node.add_theme_stylebox_override("normal",
				make_box(BG_INPUT, BORDER_INPUT, 6, 14, 28, 20))
		node.add_theme_stylebox_override("focus",
				make_box(BG_INPUT_FOCUS, ACCENT, 8, 14, 28, 20))
		node.add_theme_stylebox_override("read_only",
				make_box(BG_INPUT, BORDER_INPUT.darkened(0.35), 6, 14, 28, 20))
		node.add_theme_color_override("font_color", TEXT)
		node.add_theme_color_override("font_placeholder_color", TEXT_DIM)
		node.add_theme_color_override("caret_color", ACCENT)
		node.add_theme_color_override("selection_color", BG_HOVER)
		return

	if node is Button or node is OptionButton or node is CheckButton:
		node.add_theme_stylebox_override("normal",
				make_box(BG_PANEL, BORDER, 5, 16, 40, 22))
		node.add_theme_stylebox_override("hover",
				make_box(BG_HOVER, ACCENT, 7, 16, 40, 22))
		node.add_theme_stylebox_override("pressed",
				make_box(BG_PRESSED, ACCENT, 7, 16, 40, 22))
		node.add_theme_stylebox_override("focus",
				make_box(BG_PANEL, ACCENT, 8, 16, 40, 22))
		node.add_theme_color_override("font_color", TEXT)
		node.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		node.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		node.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))

		if node is CheckButton:
			# 勾选（开）与未勾选（关）用不同底色区分
			node.add_theme_stylebox_override("hover_pressed",
					make_box(BG_HOVER.lightened(0.12), ACCENT, 7, 16, 40, 22))
			node.add_theme_stylebox_override("disabled",
					make_box(BG_PANEL.darkened(0.4), BORDER.darkened(0.4), 5, 16, 40, 22))

		if node is OptionButton:
			# 下拉列表：悬停项与选中项也要看得清
			_style_popup(node)


static func _style_popup(option: OptionButton) -> void:
	var popup := option.get_popup()
	if popup == null:
		return
	popup.add_theme_stylebox_override("panel",
			make_box(Color(0.10, 0.12, 0.16, 1.0), BORDER, 5, 16, 20, 20))
	popup.add_theme_stylebox_override("hover",
			make_box(BG_HOVER, ACCENT, 4, 10, 20, 14))
	popup.add_theme_stylebox_override("selected",
			make_box(BG_PRESSED, ACCENT, 4, 10, 20, 14))
	popup.add_theme_color_override("font_color", TEXT)
	popup.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	popup.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
