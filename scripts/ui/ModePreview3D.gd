extends SubViewportContainer

@onready var sub_viewport = $SubViewport
@onready var world_3d = $SubViewport/World3D
@onready var camera = $SubViewport/World3D/Camera3D

# Preload the target scene
var target_scene = preload("res://scenes/characters/target.tscn")

func setup_scene(mode_name: String, mode_data: Dictionary):
	# Manual retrieval if @onready vars are not yet set
	var world_node = world_3d
	if world_node == null:
		world_node = get_node("SubViewport/World3D")

	# Ensure walls exist
	if not world_node.has_node("Walls"):
		create_walls(world_node)

	# Clear existing targets
	for child in world_node.get_children():
		if child.has_method("init"): # Targets should have init method
			child.queue_free()

	# Create representative targets
	# Use a fixed seed or consistent pattern for previews if possible, but random is okay
	
	var num_targets = min(mode_data.get("number_of_initial_targets", 3), 5) # Cap visual targets
	
	for i in range(num_targets):
		var target = target_scene.instantiate()
		
		# Position logic (simplified from World.gd)
		var x_range_0 = mode_data.get("spawn_location_x_0", 10)
		var x_range_1 = mode_data.get("spawn_location_x_1", -10)
		var y_range_0 = mode_data.get("spawn_location_y_0", 4)
		var y_range_1 = mode_data.get("spawn_location_y_1", 10)
		
		# Use simplified random or fixed distribution for preview
		# We need to scale down the range significantly to fit in potential view if ranges are large
		# Or pull camera back. Let's scale the random positions to be within a "safe" preview box.
		
		var preview_scale = 0.5 # Shrink the world for the preview box
		
		var x = lerp(float(x_range_0), float(x_range_1), float(i) / max(1, num_targets - 1)) * preview_scale
		var y = lerp(float(y_range_0), float(y_range_1), float(i) / max(1, num_targets - 1)) * preview_scale
		
		# Center Y better if it's high up
		y -= 4.0 * preview_scale # Offset typical height to center? Or just let camera handle it.
		# Actually, let's just clamp X/Y so they are always visible?
		# FOV 75 at Z 25 sees width ~38. 
		# If ranges are -24 to 24, that's 48 width -> clipped.
		
		# Let's map the range to a visibly pleasing area (-10 to 10)
		var t = float(i) / max(1, num_targets - 1)
		var visual_x_range_0 = 10
		var visual_x_range_1 = -10
		
		# If the original mode has spread, we show spread. If it's a single point, we show center.
		if x_range_0 == x_range_1:
			x = 0
		else:
			x = lerp(float(visual_x_range_0), float(visual_x_range_1), t)
			
		var visual_y_range_0 = 2
		var visual_y_range_1 = 8
		if y_range_0 == y_range_1:
			y = 0
		else:
			y = lerp(float(visual_y_range_0), float(visual_y_range_1), t)
		
		# CLAMP POSITIONS TO BE INSIDE WALLS
		# Walls are at extent=8, with thickness=2. Internal space is approx -7 to 7.
		# Safe zone: -6 to 6
		x = clampf(x, -6.0, 6.0)
		y = clampf(y, -6.0, 6.0)
		
		# Add some noise if it's the same
		if num_targets > 1:
			x += (i % 2) * 2 - 1 
		
		var z = -25.0
		
		target.position = Vector3(x, y, z)
		
		# Initialize target (size, id, movement)
		# We don't need movement for preview, usually
		var size = mode_data.get("size", 1.0)
		
		# Enforce minimum size for visibility in preview
		# Small targets (like 0.5) are too hard to see in the small viewport
		size = max(size, 2.0) 
		
		# Enable movement if the mode has it
		var movement = mode_data.get("movment", false)
		target.init(size, i, movement) 
		
		# FORCE Z VELOCITY TO 0 for preview stability
		# and Ensure X/Y velocity isn't too crazy high
		var current_vel = target.get("lavelocitat")
		if current_vel:
			target.set("lavelocitat", Vector3(current_vel.x, current_vel.y, 0))
		
		# Ensure target is visible layer? (Default should be fine) 
		
		world_node.add_child(target)

func create_walls(parent):
	var walls_node = Node3D.new()
	walls_node.name = "Walls"
	parent.add_child(walls_node)
	
	# Define box bounds (approximate based on spawn range)
	# Spawn range was roughly -10 to 10 scaled by 0.5 (so -5 to 5)
	# Spawning at Z = -25. Let's make a box centered there.
	var center = Vector3(0, 0, -25)
	var extent = 8.0 # Increased from 6.0 to give more room for large targets
	var thickness = 2.0 # Thicker walls to prevent tunneling
	
	# Create 6 walls (Top, Bottom, Left, Right, Front, Back)
	var wall_configs = [
		{"pos": center + Vector3(0, extent, 0), "size": Vector3(extent*2, thickness, extent*2)}, # Top
		{"pos": center + Vector3(0, -extent, 0), "size": Vector3(extent*2, thickness, extent*2)}, # Bottom
		{"pos": center + Vector3(-extent, 0, 0), "size": Vector3(thickness, extent*2, extent*2)}, # Left
		{"pos": center + Vector3(extent, 0, 0), "size": Vector3(thickness, extent*2, extent*2)}, # Right
		{"pos": center + Vector3(0, 0, extent), "size": Vector3(extent*2, extent*2, thickness)}, # Front
		{"pos": center + Vector3(0, 0, -extent), "size": Vector3(extent*2, extent*2, thickness)}  # Back
	]
	
	for config in wall_configs:
		var static_body = StaticBody3D.new()
		static_body.position = config.pos
		
		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = config.size
		col_shape.shape = box
		
		static_body.add_child(col_shape)
		walls_node.add_child(static_body)
