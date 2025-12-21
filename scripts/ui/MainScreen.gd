extends Control

@onready var game = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/HBoxContainer/Game
@onready var resolution_label := $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/ResolutionLabel
@onready var gamelist := $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer2
@onready var slider_quality := $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/QualitySlider
@onready var sensitivity := $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/HBoxContainer/Sensitivity
@onready var exit_button = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/Quit
@onready var check_button = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/CheckButton
@onready var sensitivity_container = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/HBoxContainer
@onready var options_button = $MarginContainer/ScrollContainer/HBoxContainer/VBoxContainer/Options


const ModePreview3D = preload("res://scenes/ui/ModePreview3D.tscn")
const ModePreview2D = preload("res://scenes/ui/ModePreview2D.tscn")


# Called when the node enters the scene tree for the first time.
func _ready():
	check_button.toggled.connect(_on_check_button_toggled)
	
	if OS.has_feature("web"):
		slider_quality.visible = false
		resolution_label.visible = false
		exit_button.visible = false
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	AddGamesSensitivities()
	if DataManager.get_data("resolution"):
		slider_quality.value = DataManager.get_data("resolution")
	if DataManager.get_data("sensitivity"):
		sensitivity.text = str(DataManager.get_data("sensitivity"))
	if DataManager.get_data("sensitivity_game"):
		game.selected = DataManager.get_data("sensitivity_game")
	AddGames()
	
	if DataManager.get_data("is_3d_mode") != null:
		check_button.button_pressed = DataManager.get_data("is_3d_mode")
		
	# Initialize visibility
	update_ui_visibility(check_button.button_pressed)
		
	get_viewport().size_changed.connect(self.update_resolution_label)
	update_resolution_label()

#func _process(_delta):
#	if Input.is_action_pressed("f_pressed"):
#		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func AddGamesSensitivities():
	for sens in Global.games_sensitivities:
		game.add_item(sens)


func AddGames():
	# Clear existing children first (important when switching back from 2D)
	for child in gamelist.get_children():
		child.queue_free()
		
	for model in Global.models3d:
		var hboxc = HBoxContainer.new()
		var button = Button.new()
		button.theme = load("res://assets/themes/theme.tres")
		button.text = model
		button.name = model
		button.pressed.connect(startTraining.bind(button.name))
		


		var preview = ModePreview3D.instantiate()
		preview.setup_scene(model, Global.models3d[model])

		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(300, 300) 
		wrapper.add_child(preview)


		hboxc.add_child(wrapper)
		hboxc.add_child(button)
		gamelist.add_child(hboxc)

func startTraining(type):
	if !OS.has_feature("web"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Global.game_type = type
	get_tree().change_scene_to_file("res://scenes/levels/World.tscn")


func update_resolution_label() -> void:
	var viewport_render_size = get_viewport().size * get_viewport().scaling_3d_scale
	resolution_label.text = "%d × %d (%d%%)" \
			% [viewport_render_size.x, viewport_render_size.y, round(get_viewport().scaling_3d_scale * 100)]


func _on_play_pressed():
	if check_button.button_pressed:
		var keys = []
		for key in Global.models3d.keys():
			keys.push_back(key)
		
		var random_index = randi() % keys.size()
		var value = keys[random_index]
		startTraining(value)
	else:
		var keys = []
		for key in Global.models2d.keys():
			keys.push_back(key)
			
		var random_index = randi() % keys.size()
		var value = keys[random_index]
		startTraining2D(value)


func _on_quality_slider_value_changed(value: float) -> void:
	get_viewport().scaling_3d_scale = value
	update_resolution_label()
	DataManager.save_data("resolution", value)


func _on_quit_pressed():
	get_tree().quit()


func _on_options_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/Options.tscn")


func _on_sensitivity_text_changed(new_text):
	DataManager.save_data("sensitivity_game", game.get_selected_id())
	DataManager.save_data("sensitivity_game_value", Global.games_sensitivities.get(game.get_item_text(game.get_selected_id())))
	DataManager.save_data("sensitivity", float(new_text))


func _on_game_item_selected(index):
	DataManager.save_data("sensitivity_game", index)
	DataManager.save_data("sensitivity_game_value", Global.games_sensitivities.get(game.get_item_text(index)))


	get_tree().change_scene_to_file("res://scenes/ui/Options.tscn")


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
		
	for model in Global.models2d:
		var hboxc = HBoxContainer.new()
		var button = Button.new()
		button.theme = load("res://assets/themes/theme.tres")
		button.text = model
		button.name = model
		button.pressed.connect(startTraining2D.bind(button.name))

		var preview = ModePreview2D.instantiate()
		preview.setup_scene(model, Global.models2d[model])

		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(300, 300) 
		wrapper.add_child(preview)

		hboxc.add_child(wrapper)
		hboxc.add_child(button)
		gamelist.add_child(hboxc)

func startTraining2D(type):
	Global.game_type = type
	get_tree().change_scene_to_file("res://scenes/levels/World2D.tscn")

func update_ui_visibility(is_3d: bool):
	if sensitivity_container:
		sensitivity_container.visible = is_3d
	if options_button:
		options_button.visible = is_3d
	
	if !OS.has_feature("web"):
		slider_quality.visible = is_3d
		resolution_label.visible = is_3d
