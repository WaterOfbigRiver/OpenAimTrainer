extends Node


func string_to_vector3d(string_vector: String) -> Vector3:
	var components_str = string_vector.substr(1, string_vector.length() - 2)
	var components = components_str.split(",")

	# Convert each component from string to float
	var x = components[0].to_float()
	var y = components[1].to_float()
	var z = components[2].to_float()

	# Create the Vector3D object
	return Vector3(x, y, z)

func string_to_color(string_vector: String) -> Color:

	var components_str = string_vector.substr(1, string_vector.length() - 2)
	var components = components_str.split(",")

	# Convert each component from string to float
	var r = components[0].to_float()
	var g = components[1].to_float()
	var b = components[2].to_float()
	var a = components[3].to_float()

	# Create the Vector3D object
	return Color(r, g, b, a)

# ---------------------------------------------------------------------------
# 数值输入工具
#   中文输入法很容易打出全角数字/句号（０．５、0。5），直接 float() 会静默
#   得到 0.0 并被写盘，结果就是"视角不动"或"准星消失"。这里统一规范化，
#   解析失败时回退到上一次有效值，而不是归零。
# ---------------------------------------------------------------------------

# 全角数字、中文句号/顿号/逗号、全角空格 → 半角
static func normalize_number_text(text: String) -> String:
	var out := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0xFF10 and code <= 0xFF19:  # ０-９
			code -= 0xFEE0
		elif code == 0xFF0E or code == 0x3002 or code == 0xFF0C or code == 0x3001:
			# ．。，、 一律按小数点处理（0，5 → 0.5）
			code = 0x2E
		elif code == 0x3000:  # 全角空格
			code = 0x20
		out += String.chr(code)
	return out.strip_edges()


# 空串 / 非数字 → 返回 fallback，绝不静默归零
static func parse_number(text: String, fallback: float) -> float:
	var value_text := normalize_number_text(text)
	if value_text.is_empty() or not value_text.is_valid_float():
		return fallback
	return value_text.to_float()


# 在 parse_number 基础上夹取区间，用于灵敏度这类有下限的参数
static func parse_number_clamped(text: String, fallback: float, min_value: float, max_value: float) -> float:
	return clampf(parse_number(text, fallback), min_value, max_value)


#4k
var games_sensitivities: Dictionary = {
	"Valorant": 0.0707589285714285,
	"CounterStrike": 0.0222372497081799,
	"Fortnite": 0.00561534231977053
	}

# games_sensitivities 的 key 同时用于存档换算，不能改；
# 界面显示名放在 translations.csv（GAME_* 键），跟随当前界面语言
const GAME_TR_KEYS: Dictionary = {
	"Valorant": "GAME_VALORANT",
	"CounterStrike": "GAME_COUNTERSTRIKE",
	"Fortnite": "GAME_FORTNITE",
}


# 按界面语言返回游戏显示名
func game_display_name(game_key: String) -> String:
	if not GAME_TR_KEYS.has(game_key):
		return game_key
	return tr(GAME_TR_KEYS[game_key])


var models3d: Dictionary = {
	"3D_HEAD_LEVEL_V1": {
		"spawn_location_x_0": 24,
		"spawn_location_x_1": -24,
		"spawn_location_y_0": 4,
		"spawn_location_y_1": 4,
		"movement": false,
		"size": 0.5,
		"number_of_initial_targets": 1
	},
	"3D_MULTIPLE_BASIC_TARGETS_MOVEMENT_V1": {
		"spawn_location_x_0": 12,
		"spawn_location_x_1": -12,
		"spawn_location_y_0": 4,
		"spawn_location_y_1": 20,
		"movement": true,
		"size": 0.5,
		"number_of_initial_targets": 6
	},
	"3D_MULTIPLE_BASIC_TARGETS_V1": {
		"spawn_location_x_0": 12,
		"spawn_location_x_1": -12,
		"spawn_location_y_0": 4,
		"spawn_location_y_1": 20,
		"movement": false,
		"size": 0.5,
		"number_of_initial_targets": 6
	},
	"3D_MULTIPLE_MEDIUM_TARGETS_V1": {
		"spawn_location_x_0": 11,
		"spawn_location_x_1": -11,
		"spawn_location_y_0": 4,
		"spawn_location_y_1": 15,
		"movement": false,
		"size": 3,
		"number_of_initial_targets": 3
	}
}

var models2d: Dictionary = {
	"2D_GRIDSHOT_V1": {
		"spawn_margin": 100, # Margin from edges
		"size": 60, # Target size in pixels
		"number_of_initial_targets": 3,
		"duration": 60
	},
	"2D_REFLEX_V1": {
		"spawn_margin": 100,
		"size": 40,
		"number_of_initial_targets": 1,
		"duration": 60
	},
	"2D_MOVING_TARGETS_V1": {
		"spawn_margin": 100,
		"size": 40,
		"number_of_initial_targets": 5,
		"duration": 60,
		"movement": true
	}
}


var game_type = ""

# ---------------------------------------------------------------------------
# 显示模式：0 窗口 / 2 最大化 / 3 全屏（对应 DisplayServer.WindowMode）
# ---------------------------------------------------------------------------
const DISPLAY_WINDOWED := 0
const DISPLAY_MAXIMIZED := 2
const DISPLAY_FULLSCREEN := 3
const DEFAULT_DISPLAY_MODE := DISPLAY_FULLSCREEN

# 窗口模式下可选的窗口尺寸（会按屏幕可用区域自动收敛）
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DEFAULT_WINDOW_SIZE_INDEX := 1

func get_display_mode() -> int:
	var mode = DataManager.get_data("display_mode")
	if mode == null:
		return DEFAULT_DISPLAY_MODE
	return int(mode)

func set_display_mode(mode: int) -> void:
	DataManager.save_data("display_mode", mode)
	apply_display_mode()

func apply_display_mode() -> void:
	if OS.has_feature("web"):
		return
	var mode := get_display_mode()
	DisplayServer.window_set_mode(mode)
	if mode == DISPLAY_WINDOWED:
		var screen_id := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(screen_id)
		var screen_pos := DisplayServer.screen_get_position(screen_id)
		var size := WINDOW_SIZES[get_window_size_index()]
		# 不超过屏幕可用区域，避免窗口被任务栏挡住或超出显示器
		size.x = mini(size.x, maxi(screen_size.x - 80, 640))
		size.y = mini(size.y, maxi(screen_size.y - 140, 400))
		DisplayServer.window_set_size(size)
		var window_size := DisplayServer.window_get_size()
		DisplayServer.window_set_position(screen_pos + (screen_size - window_size) / 2)

func get_window_size_index() -> int:
	var index = DataManager.get_data("window_size")
	if index == null:
		return DEFAULT_WINDOW_SIZE_INDEX
	return clamp(int(index), 0, WINDOW_SIZES.size() - 1)

func set_window_size_index(index: int) -> void:
	DataManager.save_data("window_size", index)
	# 选了具体尺寸就说明要“悬浮窗口”，自动从全屏 / 最大化切回窗口模式
	if get_display_mode() != DISPLAY_WINDOWED:
		DataManager.save_data("display_mode", DISPLAY_WINDOWED)
	apply_display_mode()

# 返回切换后的显示模式（0 窗口 / 3 全屏）
func toggle_fullscreen() -> int:
	var is_fullscreen := DisplayServer.window_get_mode() == DISPLAY_FULLSCREEN
	var next_mode := DISPLAY_WINDOWED if is_fullscreen else DISPLAY_FULLSCREEN
	set_display_mode(next_mode)
	return next_mode


# ---------------------------------------------------------------------------
# 训练成绩记录（写入 DataManager 的 "records" 键）
# 结构：{ "模式名": { "best_score": int, "best_accuracy": int } }
# ---------------------------------------------------------------------------
func _empty_record() -> Dictionary:
	return {"best_score": 0, "best_accuracy": 0}


func get_record(mode: String) -> Dictionary:
	var records = DataManager.get_data("records")
	if records != null and records.has(mode):
		return records[mode]
	return _empty_record()


func save_record(mode: String, score: int, accuracy: int) -> Dictionary:
	var records = DataManager.get_data("records")
	if records == null:
		records = {}
	var record = records.get(mode, _empty_record())
	if score > record["best_score"]:
		record["best_score"] = score
	if accuracy > record["best_accuracy"]:
		record["best_accuracy"] = accuracy
	records[mode] = record
	DataManager.save_data("records", records)
	return record
