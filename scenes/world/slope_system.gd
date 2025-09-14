extends RefCounted
class_name SlopeSystem

var world: GameWorld
var ground: TileMapLayer
var props_root: Node2D
var prop_template: PackedScene
var slope_root: WorldSlope
var slope_cells: Dictionary = {}
var slope_edge_cells: Dictionary = {}
var slope_instances: Array = []

var slope_width := 5

func _init(world: GameWorld, ground: TileMapLayer, props_root: Node2D = null, prop_template: PackedScene = null):
	self.world = world
	self.ground = ground
	self.props_root = props_root
	self.prop_template = prop_template

	self.set_root()

func set_root():
	# new slope based on global player position
	var start_cell: Vector2i = ground.local_to_map(Globals.player_camera.get_global_position())
	var slope = world.get_random_slope(_rng_for(start_cell))
	slope_root = slope.duplicate() as WorldSlope
	slope_root.set_start_cell(start_cell)
	if slope_root:
		slope_instances.append(slope_root)
		_register_cell(slope_root, start_cell)
		paint_cell(start_cell)
	return slope_root


func step_slopes(outbounds: Rect2i) -> bool:
	var keep_walking := false
	for slope in slope_instances:
		if slope.is_finished():
			continue
		var cell: Vector2i = slope.step_forward()
		if cell == null:
			continue
		_register_cell(slope, cell)
		if outbounds.has_point(cell):
			keep_walking = true
	return keep_walking

func branch_slopes():
	var new_slopes: Array = []
	for slope in slope_instances:
		if slope.should_branch():
			var branch_start: Vector2i = slope.get_branch_cell()
			var new_slope: WorldSlope = start_slope(branch_start)
			if new_slope:
				new_slopes.append(new_slope)
	for s in new_slopes:
		slope_instances.append(s)

func has_slope(cell: Vector2i) -> bool:
	return slope_cells.has(cell)

func is_edge(cell: Vector2i) -> bool:
	return slope_edge_cells.has(cell)

func paint_cell(cell: Vector2i):
	var slope: WorldSlope = slope_cells[cell]
	var rng := _rng_for(slope.start_cell)
	var tile: WorldTile = slope.get_ground_tile(rng)
	if tile:
		ground.tile_set = slope.tile_set
		ground.set_cell(cell, tile.src_id, tile.atlas_coords, tile.alt_id)

func _rng_for(cell: Vector2i) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(cell.x * 73856093 + cell.y * 19349663 + world.seed)
	return r
