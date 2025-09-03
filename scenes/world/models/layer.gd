extends RefCounted
class_name BiomeLayer

var layer_type: int
var layer_density: float
var tiles: Dictionary  # { tile_name: { "tile": LayerTile, "weight": float, "density": float }, ... }

enum LayerType {
	GROUND,        # terrain tiles
	TREES,         # tall vegetation (blocking vision/movement)
	BUSHES,        # small shrubs / bushes
	GRASS,         # small ground clutter
	ROCKS,         # rocks, boulders
	DECORATIONS,   # misc props (snowmen, fences, bones, etc.)
	BUILDINGS      # houses, ruins, walls
}

func _init(
		layer_type: int,
		layer_density: float = 1.0
	) -> void:
	self.layer_type = layer_type
	self.layer_density = layer_density
	self.tiles = {}

func get_layer_type() -> int:
	return self.layer_type

func add_tile(
		tile: LayerTile,
		weight: float,
		density: float
	) -> void:
	if not (tile is LayerTile):
		push_error("Tile must be a LayerTile type but got %s." % typeof(tile))
		return

	if tiles.has(tile.name):
		push_error("Tile with name '%s' already exists." % tile.name)
		return

	if weight < 0.0:
		push_error("Weight for %s cannot be negative" % tile.name)
		return

	if density < 0.0 or density > 1.0:
		push_error("Density for %s must be between 0.0 and 1.0" % tile.name)
		return

	# Store validated entry
	tiles[tile.name] = {
		"tile": tile,
		"weight": weight,
		"density": density
	}

func add_tiles(tile_list: Array) -> void:
	for entry in tile_list:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("Each entry in add_tiles must be a dictionary {tile: LayerTile, weight: float, density: float}")
			continue

		if not entry.has("tile") or not (entry["tile"] is LayerTile):
			push_error("Tile entry missing valid 'tile'")
			continue

		if not entry.has("weight") or typeof(entry["weight"]) != TYPE_FLOAT:
			push_error("Tile entry for %s missing valid 'weight'" % str(entry.get("tile")))
			continue

		if not entry.has("density") or typeof(entry["density"]) != TYPE_FLOAT:
			push_error("Tile entry for %s missing valid 'density'" % str(entry.get("tile")))
			continue

		add_tile(entry["tile"], entry["weight"], entry["density"])

func get_random_tile(rng: RandomNumberGenerator) -> LayerTile:
	# Step 1: Density check (probability of placing *anything*)
	# Squaring or cubing the density value makes low numbers much sparser without having to write smaller numbers like 0.01
	if rng.randf() > pow(self.layer_density, 3):
		return null

	# Step 2: Pick from the tile list
	var total_weight := 0.0
	for tile_data in self.tiles.values():
		total_weight += tile_data["weight"]

	var choice_point := rng.randf() * total_weight
	var running_total := 0.0
	for tile_data in self.tiles.values():
		running_total += tile_data["weight"]
		if choice_point < running_total:
			return tile_data["tile"]

	return null
