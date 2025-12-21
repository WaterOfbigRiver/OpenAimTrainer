extends TextureButton

signal target_kill

var id = 0
var velocity = Vector2.ZERO
var parent_rect: Rect2


func init(size_px, _id, movement = false):
	id = _id
	
	if movement:
		# Random velocity
		var speed = 200.0
		velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * speed
		set_process(true)
	else:
		set_process(false)
	# Assuming a default white circle texture is available or we use a rounded box
	# For simplicity, we'll load a standard texture or creating one on the fly isn't easy in GDScript without setup
	# Let's use the logo or a simple placeholder resource if available, or just set a min size and color.
	# But TextureButton needs a texture. 
	# We can use the same texture as 3D if it's a png, or just a color rect child.
	
	# Actually, easier to extend Control or specific node if we don't have a texture handy.
	# But let's assume we can use "res://assets/images/texture_08.png" from World.tscn or similar.
	pass

func _ready():
	connect("pressed", Callable(self, "_on_pressed"))
	# Initialize parent rect if possible, otherwise will be updated in process
	if get_parent() is Control:
		parent_rect = get_parent().get_rect()
	elif get_parent() is SubViewport: # Direct child of SubViewport? unlikely but checking
		parent_rect = get_parent().get_visible_rect()
		
func _process(delta):
	if velocity != Vector2.ZERO:
		position += velocity * delta
		
		# Bounce logic
		# We need to know boundaries. Use parent control size.
		var bound_rect = Rect2()
		if get_parent() is Control:
			bound_rect = get_parent().get_rect() # This might be relative to parent's parent if anchors used
			# Actually for Control children, we care about the parent's size
			bound_rect.size = get_parent().size
			bound_rect.position = Vector2.ZERO # Local coordinates
			
		elif get_parent() is SubViewportContainer:
			# Not typical structure for TargetContainer but for preview maybe
			bound_rect.size = get_parent().size 
		else:
			# Fallback to viewport
			bound_rect = get_viewport_rect()
			
		# Check collisions with boundaries
		# Account for size
		if position.x <= 0:
			velocity.x = abs(velocity.x)
		elif position.x + size.x >= bound_rect.size.x:
			velocity.x = -abs(velocity.x)
			
		if position.y <= 0:
			velocity.y = abs(velocity.y)
		elif position.y + size.y >= bound_rect.size.y:
			velocity.y = -abs(velocity.y)
	
func set_target_size(size_px):
	custom_minimum_size = Vector2(size_px, size_px)
	size = Vector2(size_px, size_px)
	
	# If we use a simple ColorRect as visual rep if texture is missing/complex
	if texture_normal == null:
		var viz = ColorRect.new()
		viz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		viz.set_anchors_preset(Control.PRESET_FULL_RECT)
		viz.color = Color.WHITE # Use white to be neutral or allow modulation
		add_child(viz)

func _on_pressed():
	emit_signal("target_kill")
	queue_free()
