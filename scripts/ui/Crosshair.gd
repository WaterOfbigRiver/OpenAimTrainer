extends Control




var global_color = Color(0, 255, 255, 1)
var global_outline_color = Color(0,0,0)

var enable_crosshair = true
var enable_outline = true
var crosshair_inner_enable = true
var dot_enable = false

#var global_crosshair_height = DataManager.get_options("heigh", "float")
#var global_crosshair_width = DataManager.get_options("width", "float")

var dot_size = 6
var global_outline_width = 2
var global_crosshair_height = 4
var global_crosshair_width = 12
var global_crosshair_space = 5



# 准星参数是否已从存档读入。_draw() 每帧都会被调用，
# 参数只在 _ready() / 设置变更时重载，不能放在 _draw() 里每帧读存档。
var _loaded := false

var dot_crosshair = []


var left_inner_crosshair = []
var top_inner_crosshair = []
var right_inner_crosshair = []
var bottom_inner_crosshair = []

func _ready():
	loadSave()
	_loaded = true

func loadSave():
	if DataManager.get_data("Crosshair") != null:
		enable_crosshair = DataManager.get_data("Crosshair")
	if DataManager.get_data("Outline") != null:
		enable_outline = DataManager.get_data("Outline")
	if DataManager.get_data("CrosshairInner") != null:
		crosshair_inner_enable = DataManager.get_data("CrosshairInner")
	if DataManager.get_data("Dot") != null:
		dot_enable = DataManager.get_data("Dot")
	if DataManager.get_data("DotSize") != null:
		dot_size = DataManager.get_data("DotSize")
	if DataManager.get_data("OutlineSize") != null:
		global_outline_width = DataManager.get_data("OutlineSize")
	if DataManager.get_data("CrosshairHeight") != null:
		global_crosshair_height = DataManager.get_data("CrosshairHeight")
	if DataManager.get_data("CrosshairWidth") != null:
		global_crosshair_width = DataManager.get_data("CrosshairWidth")
	if DataManager.get_data("CrosshairSpace") != null:
		global_crosshair_space = DataManager.get_data("CrosshairSpace")
	if DataManager.get_data("CrosshairColor") != null:
		global_color = Global.string_to_color(DataManager.get_data("CrosshairColor"))
	if DataManager.get_data("OutlineColor") != null:
		global_outline_color = Global.string_to_color(DataManager.get_data("OutlineColor"))
	rebuild_polygons()

# 只在参数变化时重建顶点数组，_draw() 里直接用现成的数组
func rebuild_polygons():
	dot_crosshair = [
		Vector2(-dot_size,-dot_size), #top left
		Vector2(dot_size,-dot_size), #top right
		Vector2(dot_size,dot_size), #bottom right
		Vector2(-dot_size,dot_size) #bottom left
	]
	left_inner_crosshair = [
		Vector2(-global_crosshair_width-global_crosshair_space,-global_crosshair_height),  #top left
		Vector2(0-global_crosshair_space,-global_crosshair_height),#top right
		Vector2(0-global_crosshair_space,global_crosshair_height), #bottom right
		Vector2(-global_crosshair_width-global_crosshair_space,global_crosshair_height) #bottom left
	]
	top_inner_crosshair = [
		Vector2(-global_crosshair_height,-global_crosshair_width-global_crosshair_space),  #top left
		Vector2(global_crosshair_height,-global_crosshair_width-global_crosshair_space),#top right
		Vector2(global_crosshair_height,-global_crosshair_space), #bottom right
		Vector2(-global_crosshair_height,-global_crosshair_space) #bottom left
	]
	right_inner_crosshair = [
		Vector2(0+global_crosshair_space,-global_crosshair_height),  #top left
		Vector2(global_crosshair_width+global_crosshair_space,-global_crosshair_height),#top right
		Vector2(global_crosshair_width+global_crosshair_space,global_crosshair_height),#bottom right
		Vector2(0+global_crosshair_space,global_crosshair_height) #bottom left
	]
	bottom_inner_crosshair = [
		Vector2(-global_crosshair_height, global_crosshair_space),  #top left
		Vector2(global_crosshair_height,global_crosshair_space),#top right
		Vector2(global_crosshair_height,global_crosshair_space+global_crosshair_width), #bottom right
		Vector2(-global_crosshair_height,global_crosshair_space+global_crosshair_width) #bottom left
	]


func redraw(_value):
	queue_redraw()

func _draw():
	if not _loaded:
		loadSave()
		_loaded = true
	if dot_enable and enable_crosshair:
		polygonDrawer(dot_crosshair, global_color, global_outline_width, global_outline_color)
	
	if crosshair_inner_enable and enable_crosshair:
		polygonDrawer(left_inner_crosshair, global_color, global_outline_width, global_outline_color)
		polygonDrawer(top_inner_crosshair, global_color, global_outline_width, global_outline_color)
		polygonDrawer(right_inner_crosshair, global_color, global_outline_width, global_outline_color)
		polygonDrawer(bottom_inner_crosshair, global_color, global_outline_width, global_outline_color)

# 直接按点数组绘制描边，不再为了取顶点而每帧 new 一个 Polygon2D 节点
func polygonDrawer(polygon_points, color, outline_width, outline_color):
	var points := PackedVector2Array(polygon_points)
	draw_polygon(points, PackedColorArray([color]))
	outlinePolygonDrawer(points, outline_width, outline_color)

func outlinePolygonDrawer(points, outline_width, outline_color):
	if not enable_outline:
		return
	for i in range(1, points.size()):
		draw_line(points[i - 1], points[i], outline_color, outline_width)
	draw_line(points[points.size() - 1], points[0], outline_color, outline_width)


func _on_options_refresh_crosshair():
	loadSave()
	queue_redraw()
