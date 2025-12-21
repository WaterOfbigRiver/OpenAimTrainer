extends Control

var packed_target = preload("res://scenes/characters/Target2D.tscn")
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
	
	lbl_score.text = "Score: 0"
	lbl_timer.text = str(time_left) + "s"
	
	# Spawn initial targets
	for i in range(config["number_of_initial_targets"]):
		spawn_target()
		
	$GameTimer.start()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	var new_state = !get_tree().paused
	get_tree().paused = new_state
	pause_menu.visible = new_state
	
	if new_state:
		# Paused
		pass
	else:
		# Resumed
		pass

func _process(delta):
	pass

func spawn_target():
	if !game_active: return
	
	var config = Global.models2d[Global.game_type]
	var margin = config["spawn_margin"]
	var t_size = config["size"]
	
	# Get available area
	var viewport_size = get_viewport_rect().size
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
	t.position = Vector2(random_x, random_y)
	t.connect("target_kill", Callable(self, "_on_target_killed"))
	container.add_child(t)

func _on_target_killed():
	if !game_active: return
	score += 1
	lbl_score.text = "Score: " + str(score)
	# Spawn replacement
	spawn_target()

func _on_game_timer_timeout():
	time_left -= 1
	lbl_timer.text = str(time_left) + "s"
	
	if time_left <= 0:
		end_game()

func end_game():
	game_active = false
	$GameTimer.stop()
	# Show results / pause menu similar to 3D world
	# For now, just show mouse and maybe a simple game over overlay or reuse pause
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Reuse pause menu if compatible or show custom
	# pause_menu.show_results(score) # If we adapt existing pause logic
	# For simplicity, let's just go back to menu after a short delay or show a "Finished" label
	lbl_timer.text = "Finished!"
	
	# Simulate reusing the pause menu mechanics for "Menu" button
	# if pause_menu:
	#	pause_menu.visible = true
	#	# Might need to inject score into it

func _on_menu_pressed():
	get_tree().paused = false # Unpause before leaving
	get_tree().change_scene_to_file("res://scenes/ui/MainScreen.tscn")

func _on_resume_pressed():
	toggle_pause()
