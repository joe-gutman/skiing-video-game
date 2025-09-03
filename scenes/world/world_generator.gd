extends Node2D

@export var prop_template: PackedScene
@export var ground: TileMapLayer	  # drag your Ground TileMap node here
@export var props: Node2D			 # drag your Props container here
@export var jitter_amount: int = 5

var rng := RandomNumberGenerator.new()
var loader: WorldLoader
var world: GameWorld
var viewport: Viewport
var camera: Camera2D

var spawned_props: Dictionary = {}  # cell -> prop instance
var visited_cells: Dictionary = {}  # cell -> true


@export var inbound_padding: int = 2
@export var outbound_padding: int = 6

func _ready():
	rng.randomize()
	viewport = get_viewport()
	camera = viewport.get_camera_2d()

	loader = WorldLoader.new()
	world = loader.load_world(
		"res://scenes/world/data/tiles.json",
		"res://scenes/world/data/biomes.json",
		"res://scenes/world/data/world.json"
	)

func get_cell_rng(cell: Vector2i, seed: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(seed + cell.x * 73856093 + cell.y * 19349663)
	return r


func get_biome_at(cell: Vector2i) -> WorldBiome:
	return world.get_biome_at(cell)

func place_ground(cell: Vector2i):

	var biome := get_biome_at(cell)
	if biome == null:
		return

	var ground_layer: BiomeLayer = biome.get_layer(BiomeLayer.LayerType.GROUND)
	if ground_layer == null:
		return

	var pick_rng := get_cell_rng(cell, 42)
	var tile: LayerTile = ground_layer.get_random_tile(pick_rng)
	if tile == null:
		return

	ground.tile_set = biome.biome_tileset
	ground.set_cell(cell, tile.src_id, tile.atlas_coords, tile.alt_id)


func place_prop(cell: Vector2i):
	print("Placing prop at cell: ", cell)

	var biome := get_biome_at(cell)
	if biome == null: return

	var cell_rng := get_cell_rng(cell, 0)
	var prop_tile: LayerTile = biome.get_random_prop(cell_rng)
	if prop_tile == null: return

	if prop_template == null:
		push_error("prop_template not set!")
		return

	var prop_instance: Node2D = prop_template.instantiate()
	prop_instance.z_index = Globals.get_z_index(prop_instance)
	var sprite := prop_instance.get_node_or_null("Sprite2D") as Sprite2D

	if sprite:
		var tile_source := biome.biome_tileset.get_source(prop_tile.src_id)
		var tile_data: TileData = tile_source.get_tile_data(prop_tile.atlas_coords, 0)

		# --- Sprite setup ---
		sprite.texture = tile_source.texture
		sprite.region_enabled = true
		sprite.region_rect = tile_source.get_tile_texture_region(prop_tile.atlas_coords)
		sprite.centered = false
		var sprite_size = sprite.region_rect.size
		sprite.offset = Vector2(-sprite_size.x * 0.5, -sprite_size.y)

		# Offset the whole prop so its origin is bottom-center
		var base_pos = ground.map_to_local(cell)

		# Add per-cell random jitter
		var jitter_rng = get_cell_rng(cell, 1234)
		var jitter = Vector2(
			jitter_rng.randi_range(-jitter_amount, jitter_amount),
			jitter_rng.randi_range(-jitter_amount, jitter_amount)
		)

		prop_instance.position = base_pos + jitter

		build_collision(biome, cell, prop_tile, prop_instance, sprite)

		props.add_child(prop_instance)  # add it to your scene
		spawned_props[cell] = prop_instance



func build_collision(biome: WorldBiome, cell: Vector2i, tile: LayerTile, prop_instance: Node2D, sprite: Sprite2D) -> void:
	var tile_source := biome.biome_tileset.get_source(tile.src_id) as TileSetAtlasSource
	if tile_source == null: return
	var tile_data: TileData = tile_source.get_tile_data(tile.atlas_coords, 0)
	if tile_data == null: return

	for i in range(tile_data.get_collision_polygons_count(0)):
		var poly_points := tile_data.get_collision_polygon_points(0, i)
		if poly_points.is_empty(): continue

		var shape_node := CollisionPolygon2D.new()
		shape_node.polygon = poly_points
		for n in range(shape_node.polygon.size()):
			#offset to bottom-center origin
			shape_node.polygon[n] -= Vector2(0, tile_data.texture_origin.y) + Vector2(0, 8)
		prop_instance.add_child(shape_node)

func clear_cell(cell: Vector2i):
	if not visited_cells.has(cell):
		return

	ground.set_cell(cell, -1)

	if spawned_props.has(cell):
		var prop = spawned_props[cell]
		if is_instance_valid(prop):
			prop.get_parent().remove_child(prop)
			prop.queue_free()
		spawned_props.erase(cell)

	visited_cells.erase(cell)


func get_tile_bounds(center_pos: Vector2, tile_padding: int = 0) -> Rect2i:
	# Use max_zoom_out instead of current camera.zoom
	var world_size: Vector2 = get_viewport().get_visible_rect().size * Globals.max_zoom
	var half_size: Vector2 = world_size * 0.5
	var top_left_world := center_pos - half_size
	var bottom_right_world := center_pos + half_size

	var tile_tl := ground.local_to_map(ground.to_local(top_left_world))
	var tile_br := ground.local_to_map(ground.to_local(bottom_right_world)) + Vector2i(1, 1)

	tile_tl -= Vector2i(tile_padding, tile_padding)
	tile_br += Vector2i(tile_padding, tile_padding)

	return Rect2i(tile_tl, tile_br - tile_tl)

func _process(delta: float) -> void:
	var viewport_pos := camera.get_screen_center_position()
	var inbounds := get_tile_bounds(viewport_pos, inbound_padding)
	var outbounds := get_tile_bounds(viewport_pos, outbound_padding + inbound_padding)

	for x in range(outbounds.position.x, outbounds.end.x):
		for y in range(outbounds.position.y, outbounds.end.y):
			var cell := Vector2i(x, y)
			if inbounds.has_point(cell):
				# Only place once per cell until cleared
				if not visited_cells.has(cell):
					place_ground(cell)
					place_prop(cell)
					visited_cells[cell] = true
			else:
				clear_cell(cell)
