extends Control

var packed_target = preload("res://scenes/characters/Target2D.tscn")

# 项目以 3840×2160 为布局基准，2D 目标的像素尺寸若直接使用会在高分屏上过小。
# 这里以 1920 宽为手感基准做等比放大。
const REFERENCE_WIDTH = 1920.0

var score = 0
var time_left = 0
var game_active = false

@onready var container = $TargetContainer
@onready var lbl_score = $HUD/Score
@onready var lbl_timer = $HUD/Timer
@onready var hud = $HUD
@onready var pause_menu = $CanvasLayer/Pause

func _ready():
	# Setup initial game state
	score = 0
	var config = Global.models2d[Global.game_type]
	time_left = config["duration"]
	game_active = true
	
	lbl_score.text = tr("SCORE_TEXT") % score
	lbl_timer.text = tr("TIME_LEFT") % time_left
	
	# Spawn initial targets
	for i in range(config["number_of_initial_targets"]):
		spawn_target()
		
	$GameTimer.start()

# 注意：暂停输入由场景中的 PauseInput 节点（process_mode = ALWAYS）转发，
# 因为 get_tree().paused = true 后本节点的 _input 不会再被调用，导致 Esc 无法恢复。
func toggle_pause():
	# 结算面板显示期间不再响应暂停切换，避免把已结束的回合又“恢复”
	if !game_active and pause_menu.visible:
		return
	var new_state = !get_tree().paused
	get_tree().paused = new_state
	pause_menu.visible = new_state

# 与 3D 保持一致：窗口失焦时自动暂停，避免切窗丢时间
func _notification(what):
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT and game_active:
		if !get_tree().paused:
			toggle_pause()

func spawn_target():
	if !game_active: return
	
	var config = Global.models2d[Global.game_type]

	# Get available area
	var viewport_size = get_viewport_rect().size
	var ui_scale = max(viewport_size.x / REFERENCE_WIDTH, 1.0)
	var margin = float(config["spawn_margin"]) * ui_scale
	var t_size = float(config["size"]) * ui_scale

	var max_x = viewport_size.x - margin - t_size
	var max_y = viewport_size.y - margin - t_size
	var min_x = margin
	var min_y = margin
	
	var random_x = randf_range(min_x, max_x)
	var random_y = randf_range(min_y, max_y)
	
	var t = packed_target.instantiate()

	var movement = config.get("movement", false)
	t.init(t_size, 0, movement) # ID not strictly used yet
	t.set_target_size(t_size)
	if movement:
		t.velocity *= ui_scale
	t.position = Vector2(random_x, random_y)
	t.connect("target_kill", Callable(self, "_on_target_killed"))
	container.add_child(t)

func _on_target_killed():
	if !game_active: return
	score += 1
	lbl_score.text = tr("SCORE_TEXT") % score
	# Spawn replacement
	spawn_target()

func _on_game_timer_timeout():
	time_left -= 1
	lbl_timer.text = tr("TIME_LEFT") % time_left
	
	if time_left <= 0:
		end_game()

func end_game():
	game_active = false
	$GameTimer.stop()
	lbl_timer.text = tr("FINISHED")

	# 结算：暂停场景树（停住剩余靶子的运动），复用暂停面板展示本轮得分与历史最佳，
	# 并隐藏“继续”按钮（本轮已结束）
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	var record = Global.save_record(Global.game_type, score, 0)
	var result_score = pause_menu.get_node("VBoxContainer/Score")
	result_score.text = tr("RESULT_SCORE") % [score, record["best_score"]]
	result_score.visible = true
	pause_menu.get_node("VBoxContainer/ResumeButton").visible = false
	pause_menu.visible = true

func _on_menu_pressed():
	get_tree().paused = false # Unpause before leaving
	get_tree().change_scene_to_file("res://scenes/ui/MainScreen.tscn")

func _on_resume_pressed():
	toggle_pause()

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()
