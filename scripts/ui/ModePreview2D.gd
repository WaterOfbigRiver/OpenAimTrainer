extends SubViewportContainer

@onready var container = $SubViewport/Container

var target_scene = preload("res://scenes/characters/Target2D.tscn")

func setup_scene(mode_name: String, mode_data: Dictionary):
	var container_node = container
	if container_node == null:
		container_node = get_node("SubViewport/Container")

	# Clear existing targets
	for child in container_node.get_children():
		child.queue_free()
		
	var num_targets = min(mode_data.get("number_of_initial_targets", 3), 5)
	
	# Our viewport size is fixed at 300x300
	var viewport_size = Vector2(300, 300)
	
	# Reference "screen" size for scaling (e.g. 1920x1080 or just generic 1000)
	var reference_size = 1000.0 
	var scale_factor = viewport_size.x / reference_size
	
	for i in range(num_targets):
		var t = target_scene.instantiate()
		var original_size = mode_data.get("size", 40)
		var original_margin = mode_data.get("spawn_margin", 50)
		
		# Scale down for preview
		# But keep targets visible enough
		var scaled_size = max(original_size * scale_factor, 20.0) 
		var scaled_margin = max(original_margin * scale_factor, 10.0)
		
		var max_x = viewport_size.x - scaled_margin - scaled_size
		var max_y = viewport_size.y - scaled_margin - scaled_size
		var min_x = scaled_margin
		var min_y = scaled_margin
		
		# Simple random position
		var random_x = randf_range(min_x, max_x)
		var random_y = randf_range(min_y, max_y)
		
		var movement = mode_data.get("movement", false)
		t.init(scaled_size, i, movement)
		t.set_target_size(scaled_size) # CRITICAL: init() does not set size in Target2D!
		t.position = Vector2(random_x, random_y)
		
		# Disable interactions if necessary (Target2D might have inputs)
		if t.has_node("Button"):
			t.get_node("Button").mouse_filter = Control.MOUSE_FILTER_IGNORE
			
		container_node.add_child(t)
