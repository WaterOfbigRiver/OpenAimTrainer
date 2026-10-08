extends Node

const file_name = "open_aim_trainer.json"
const file_path = "user://" + file_name

var game_data = {}

func _ready():
	# 首次运行（无文件）或存档损坏时保留默认设置；损坏的存档先备份，
	# 避免后续任意一次保存把它直接覆盖掉
	if not load_all_data():
		backup_file(file_path)
	# 恢复用户选择的界面语言（缺省则跟随系统 locale）
	var locale = get_data("locale")
	if locale != null and locale != "":
		TranslationServer.set_locale(locale)
	# 尽早恢复显示模式，避免窗口模式下启动时先闪一下全屏
	Global.apply_display_mode()

# 把文本解析成设置字典；解析失败或结果不是 Dictionary 时返回 null，
# 由调用方决定是拒绝应用还是回退默认（绝不能用空字典顶替，否则会清空设置）
func parse_game_data(string_json: String):
	if string_json == null or string_json.strip_edges().is_empty():
		return null
	var json = JSON.new()
	if json.parse(string_json) != OK:
		return null
	if json.data == null or not (json.data is Dictionary):
		return null
	return json.data


# 导入：只有解析成功才真正替换内存中的设置
func load_all_data_from_param(string_json) -> bool:
	var result = parse_game_data(string_json)
	if result == null:
		push_warning("导入内容不是合法的设置 JSON，已忽略，现有设置保持不变")
		return false
	game_data = result
	return true


func save_all_data_to_file_web():
	var json = JSON.stringify(game_data)
	JavaScriptBridge.download_buffer(json.to_utf8_buffer(),"open_aim_trainer.json")

# 统一写盘入口：打开失败（路径不存在 / 无权限）时不再崩溃，返回 false
func write_all_data(file_directory: String) -> bool:
	var file = FileAccess.open(file_directory, FileAccess.WRITE)
	if file == null:
		push_error("设置写入失败：无法打开文件 %s（本次修改只在内存中生效）" % file_directory)
		return false
	file.store_line(JSON.stringify(game_data))
	file.close()
	return true

func save_data(key, value, file_directory = file_path) -> bool:
	game_data[key] = value
	return write_all_data(file_directory)

func save_all_data(file_directory = file_path) -> bool:
	return write_all_data(file_directory)
	
func get_data(key):
	var result = null
	if game_data != null:
		result = game_data.get(key)
	return result

# 返回是否成功读取。失败（文件不存在 / 内容损坏）时保留现有 game_data，
# 绝不用空字典覆盖，避免设置被静默清空
func load_all_data(file_directory = file_path) -> bool:
	var file = FileAccess.open(file_directory, FileAccess.READ)
	if file == null:
		print("File not found: %s" % file_directory)
		return false
	var text = file.get_as_text()
	file.close()

	var result = parse_game_data(text)
	if result == null:
		push_warning("存档内容不是合法 JSON，已保留现有设置：%s" % file_directory)
		return false
	game_data = result
	return true

# 存档损坏时先备份原文件，避免下次任意保存把损坏内容直接覆盖掉
func backup_file(file_directory: String) -> void:
	var backup = file_directory + ".bak"
	if FileAccess.file_exists(backup):
		return
	var source = FileAccess.open(file_directory, FileAccess.READ)
	if source == null:
		return
	var text = source.get_as_text()
	source.close()
	var target = FileAccess.open(backup, FileAccess.WRITE)
	if target == null:
		return
	target.store_string(text)
	target.close()
	print("已把损坏的存档备份为：%s" % backup)
