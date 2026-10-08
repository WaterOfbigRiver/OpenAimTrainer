extends Node3D

var packed_target = preload("res://scenes/characters/target.tscn")
var location_target = Vector3()
var count_kills = 0
var id_spawn_target = 0

@onready var animation_kill = $Player/Head/AnimationKill
@onready var kill = $Player/Head/Kill
@onready var kills = $Player/Head/Kills
@onready var kills_result = $CanvasLayer/Pause/Buttons/Kills
@onready var full_screen_needed = $CanvasLayer/FullScreenRequest
@onready var captured_needed = $CanvasLayer/MouseCapturedRequested
@onready var player = $Player
@onready var target_prison = $TargetPrison

# 已生成靶子的坐标（用于避免重叠），键为 spawn id
var last_vectors: Dictionary = {}
#@onready var anim_hit = $FPS/Head/Camera3D/AnimationHit

# Called when the node enters the scene tree for the first time.
func _ready():
	full_screen_needed.visible = false
	captured_needed.visible = false
	id_spawn_target = 0
	count_kills = 0
	last_vectors.clear()
	kills_result.set_text(tr("KILLS_ON") % [str(count_kills), tr(str(Global.game_type))])
	
	kill.visible = false

	fit_target_prison()

	# 用常驻 Timer 替代原先“每帧 await 一个 0.5s 定时器”的写法
	var guard := Timer.new()
	guard.name = "FullScreenGuard"
	guard.wait_time = 0.5
	guard.timeout.connect(full_screen_requested)
	add_child(guard)
	guard.start()
	full_screen_requested()

	for x in range(Global.models3d[Global.game_type].number_of_initial_targets):
		spawn_target()


func target_killed(target_id = null):
	if target_id != null:
		last_vectors.erase(target_id)
	messageHit()
	spawn_target()

func randomize_vector():
	randomize()
	var location_x = randf_range(Global.models3d[Global.game_type].spawn_location_x_0, Global.models3d[Global.game_type].spawn_location_x_1)
	var location_y = randf_range(Global.models3d[Global.game_type].spawn_location_y_0, Global.models3d[Global.game_type].spawn_location_y_1)
	var location_z = -25
	return Vector3(location_x, location_y, location_z)

func check_distance():
	var vector_return = randomize_vector()
	var have_distance = true
	# 与场上已有靶子保持最小间距，避免重叠 / 穿模
	var min_distance = Global.models3d[Global.game_type].size * 2.0 + 1.0
	for last_key in last_vectors.keys():
		if last_vectors[last_key].distance_to(vector_return) < min_distance:
			have_distance = false
			break
	return [have_distance, vector_return]

func spawn_target():
	id_spawn_target += 1
	var return_distance_array = check_distance()
	var count_max = 0
	while return_distance_array[0] != true and count_max < 100:
		count_max += 1
		return_distance_array = check_distance()
	var vector_return = return_distance_array[1]
	location_target.x = vector_return.x
	location_target.y = vector_return.y
	location_target.z = vector_return.z
	
	last_vectors[id_spawn_target] = vector_return
	
	var target = packed_target.instantiate()
	# 用 get() 兜底：模式配置缺少 movement 键时按静止靶处理，不再直接索引
	target.init(Global.models3d[Global.game_type].size, id_spawn_target,
			Global.models3d[Global.game_type].get("movement", false))
	target.connect("target_kill", Callable(self, "target_killed"))
	target.set_position(location_target)
	add_child(target)
	
func messageHit():
	count_kills += 1
	kills.set_text((str(count_kills)))
	kills_result.set_text(tr("KILLS_ON") % [str(count_kills), tr(str(Global.game_type))])
	if not animation_kill.is_playing():
		animation_kill.play("kill")
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta):
#	if Input.is_action_pressed("f_pressed"):
#		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
#		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#		is_already_full_screen()

func _on_menu_pressed():
	pass # Replace with function body.

# 窗口 / 最大化 / 全屏都能玩，这里只强制要求“鼠标处于捕获态”
func full_screen_requested():
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if (full_screen_needed.visible == false && get_tree().paused == false):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			full_screen_needed.visible = true
			get_tree().paused = true


func _on_full_screen_needed_pressed():
	# 一次点击完成“应用显示模式 + 捕获鼠标”，不再强制全屏
	Global.apply_display_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	full_screen_needed.visible = false
	captured_needed.visible = false
	get_tree().paused = false
	#var timer = Timer.new()
	#timer.set_wait_time(3)
	#timer.connect("timeout", Callable(self, "full_screen_requested"))


func _on_mouse_captured_needed_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	captured_needed.visible = false
	get_tree().paused = false


# 按当前模式的刷靶范围自动调整靶笼，避免移动靶飞出笼外
func fit_target_prison():
	var cfg = Global.models3d[Global.game_type]
	var min_x = min(cfg.spawn_location_x_0, cfg.spawn_location_x_1)
	var max_x = max(cfg.spawn_location_x_0, cfg.spawn_location_x_1)
	var min_y = min(cfg.spawn_location_y_0, cfg.spawn_location_y_1)
	var max_y = max(cfg.spawn_location_y_0, cfg.spawn_location_y_1)
	var size = Vector3(
			max(max_x - min_x + 8.0, 16.0),
			max(max_y - min_y + 8.0, 16.0),
			12.0)
	target_prison.transform = Transform3D.IDENTITY
	target_prison.transform.origin = Vector3((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, -25.0)
	target_prison.size = size
	for child in target_prison.get_children():
		if child is CSGBox3D:
			child.size = size - Vector3(2.0, 2.0, 2.0)


# 60 秒结束：结算击杀数、命中率与历史最佳
func _on_timer_timeout():
	var accuracy = 0
	if player.shot_count > 0:
		accuracy = int(round(float(player.hit_count) / float(player.shot_count) * 100.0))
	var record = Global.save_record(Global.game_type, count_kills, accuracy)
	kills_result.set_text(tr("RESULT_TEXT") % [
			str(count_kills), tr(str(Global.game_type)), accuracy, str(record["best_score"])])
	#await get_tree().create_timer(1.0).timeout
	#var timer = Timer.new()  # Add a timer to capture the mouse again after a delay
	#timer.set_wait_time(3)
	#timer.connect("timeout", Callable(self, "_recapture_mouse"))
	#add_child(timer)
	#timer.start()
