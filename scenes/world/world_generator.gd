extends Node2D
class_name WorldGenerator

@export var player: RigidBody2D
@export var player_camera: Camera2D
@export var ground: TileMapLayer
@export var assets_container: Node2D             # container for spawned assets
@export var asset_template: PackedScene     # used for sprite-type assets

@export var inbound_padding: int = 2
@export var outbound_padding: int = 6
@export var jitter_amount: int = 5

var rng := RandomNumberGenerator.new()
var world: GameWorld
var visited_cells: Array = []
var biome_cells: Dictionary = {}
var spawned_assets: Dictionary = {}   # cell -> Node2D instance
var viewport: Viewport
var last_tile_pos: Vector2i
var last_bounds: Rect2i

func _ready():
	Globals.set_ground(ground)
	rng.randomize()
	viewport = get_viewport()

	var loader := WorldLoader.new()
	world = loader.load_world(
		"res://scenes/world/data/assets.json",
		"res://scenes/world/data/biomes.json",
		"res://scenes/world/data/world.json"
	)

	_update_cells(Rect2i(), Globals.viewport_bounds)

func _process(_delta: float) -> void:
	if not Globals.ground or not Globals.player:
		return

	var current_tile = Globals.ground.local_to_map(Globals.player.global_position)
	if current_tile != last_tile_pos:
		Globals.update_viewport_bounds()
		_update_cells(last_bounds, Globals.viewport_bounds)
		last_bounds = Globals.viewport_bounds
		last_tile_pos = current_tile


func _update_cells(old_bounds: Rect2i, new_bounds: Rect2i) -> void:
	# First-time setup
	if old_bounds.size == Vector2i.ZERO:
		for x in range(new_bounds.position.x, new_bounds.end.x):
			for y in range(new_bounds.position.y, new_bounds.end.y):
				var cell = Vector2i(x, y)
				_build_cell(cell)
				visited_cells.append(cell)
		return

	# Remove old cells
	for x in range(old_bounds.position.x, old_bounds.end.x):
		for y in range(old_bounds.position.y, old_bounds.end.y):
			var cell = Vector2i(x, y)
			if not new_bounds.has_point(cell) and visited_cells.has(cell):
				_clear_cell(cell)
				visited_cells.erase(cell)

	# Add new cells
	for x in range(new_bounds.position.x, new_bounds.end.x):
		for y in range(new_bounds.position.y, new_bounds.end.y):
			var cell = Vector2i(x, y)
			if not old_bounds.has_point(cell) and not visited_cells.has(cell):
				_build_cell(cell)
				visited_cells.append(cell)

func _build_cell(cell: Vector2i):
	var biome := world.get_biome_blended(cell)
	if biome == null:
		return
	biome_cells[cell] = biome

	var rng := _rng_for(cell, 42)
	var ground_asset: WorldAsset = biome.get_ground_asset(rng)
	if ground_asset and ground_asset.type == "sprite":
		# paint ground directly into tilemap
		ground.tile_set = biome.tile_set
		ground.set_cell(cell, ground_asset.src_id, ground_asset.atlas_coords, ground_asset.alt_id)

	# place a prop/asset (trees, bushes, decorations, etc.)
	_place_asset(cell, biome)

func _clear_cell(cell: Vector2i):
	if biome_cells.has(cell):
		ground.set_cell(cell, -1)
		biome_cells.erase(cell)

	if spawned_assets.has(cell):
		var asset = spawned_assets[cell]
		if is_instance_valid(asset):
			asset.queue_free()
		spawned_assets.erase(cell)

func _place_asset(cell: Vector2i, biome: WorldBiome):
	var rng := _rng_for(cell, 0)
	var asset: WorldAsset = biome.get_random_asset(rng)
	if asset == null:
		return

	match asset.type:
		"sprite":
			print("Placing asset '%s' at cell %s" % [asset.name, cell])
			var instance: StaticBody2D = asset_template.instantiate()
			instance.z_index = Globals.get_z_index(instance)

			var sprite := instance.get_node_or_null("Sprite2D") as Sprite2D
			if sprite:
				var src := biome.tile_set.get_source(asset.src_id) as TileSetAtlasSource
				sprite.texture = src.texture
				sprite.region_enabled = true
				sprite.region_rect = src.get_tile_texture_region(asset.atlas_coords)
				sprite.centered = false

				var size = sprite.region_rect.size
				sprite.offset = Vector2(-size.x * 0.5, -size.y)

			var base_pos = ground.map_to_local(cell)
			var jitter_rng = _rng_for(cell, 1234)
			var jitter = Vector2(
				jitter_rng.randi_range(-jitter_amount, jitter_amount),
				jitter_rng.randi_range(-jitter_amount, jitter_amount)
			)
			instance.position = base_pos + jitter

			assets_container.add_child(instance)
			spawned_assets[cell] = instance

		"scene":
			if asset.scene:
				var instance: Node2D = asset.scene.instantiate()
				instance.z_index = Globals.get_z_index(instance)
				instance.position = ground.map_to_local(cell)
				assets_container.add_child(instance)
				spawned_assets[cell] = instance

func _rng_for(cell: Vector2i, seed: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(seed + cell.x * 73856093 + cell.y * 19349663)
	return r
