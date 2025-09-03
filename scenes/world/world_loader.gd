extends RefCounted
class_name WorldLoader

func load_world(tiles_path: String, biomes_path: String, world_path: String) -> GameWorld:
	var tiles_json: Dictionary = _load_json(tiles_path)
	var biomes_json: Dictionary = _load_json(biomes_path)
	var world_json: Dictionary = _load_json(world_path)

	_require(tiles_json != null, "Failed to load tiles.json")
	_require(biomes_json != null, "Failed to load biomes.json")
	_require(world_json != null, "Failed to load world.json")

	var tiles_map: Dictionary = _build_tiles(tiles_json)
	var game_world: GameWorld = GameWorld.new(
		world_json["name"],
		int(world_json.get("seed", 0))
	)

	var biomes_array: Array = world_json["biomes"]
	for biome_ref in biomes_array:
		if biome_ref.get("active", true) == false:
			continue  # Skip inactive biomes

		var biome_key: String = biome_ref["biome"]
		var biome_def: Dictionary = biomes_json[biome_key]
		var biome: WorldBiome = _build_biome(biome_def, tiles_map)

		var noise: Dictionary = biome_ref.get("noise_params", {})
		var weight: float = float(biome_ref.get("weight", 1.0))

		game_world.add_biome(
			biome,
			weight,
			float(noise.get("scale", 40.0)),
			int(noise.get("octaves", 3)),
			float(noise.get("persistence", 0.5)),
			float(noise.get("lacunarity", 2.0)),
			float(noise.get("freq_x", 1.0)),
			float(noise.get("freq_y", 1.0))
		)

	return game_world



func _build_tiles(tiles_json: Dictionary) -> Dictionary:
	var tiles_map: Dictionary = {}
	for name: String in tiles_json.keys():
		var def: Dictionary = tiles_json[name]
		var coords: Array = def["atlas_coords"]
		var atlas_coords: Vector2i = Vector2i(coords[0], coords[1])

		var tile: LayerTile = LayerTile.new(
			name,
			atlas_coords,
			int(def["src_id"]),
			int(def.get("alt_id", 0)),
			def.get("categories", [])
		)
		tiles_map[name] = tile
	return tiles_map


func _build_biome(def: Dictionary, tiles_map: Dictionary) -> WorldBiome:
	print("Building biome: %s" % def["name"])
	var layers_dict: Dictionary = {}

	for layer_name: String in def["layers"].keys():
		var layer_definition: Dictionary = def["layers"][layer_name]

		# Validate layer type
		var key_upper := layer_name.to_upper()
		var layer_type_variant = BiomeLayer.LayerType.get(key_upper)
		_require(layer_type_variant != null, "Invalid layer type '%s' in biome '%s'" % [layer_name, def["name"]])
		var layer_type: int = int(layer_type_variant)

		# Build biome layer
		var density: float = float(layer_definition["density"])
		var layer: BiomeLayer = BiomeLayer.new(layer_type, density)

		for t: Dictionary in layer_definition["tiles"]:
			var tile_name: String = t["name"]
			_require(tiles_map.has(tile_name), "Tile '%s' not found in tiles.json" % tile_name)
			var tile: LayerTile = tiles_map[tile_name]
			var weight: float = float(t["weight"])
			layer.add_tile(tile, weight, 1.0) # no per-tile density, fixed at 1.0

		# Use weight if defined, else default to 1.0
		var layer_weight: float = float(layer_definition.get("weight", 1.0))
		layers_dict[layer_type] = {"layer": layer, "weight": layer_weight}
		

	return WorldBiome.new(
		def["name"],
		load(def["biome_tileset"]) as TileSet,
		float(def.get("biome_density", 1.0)),
		layers_dict,
		def.get("weather", "clear"),
		int(def.get("temperature", 0)),
		def.get("ambient_sounds", []),
		_hex_to_color(def.get("sky_color", "#FFFFFF")),
		_hex_to_color(def.get("fog_color", "#FFFFFF")),
		def.get("notes", "")
	)



func _load_json(path: String) -> Dictionary:
	_require(FileAccess.file_exists(path), "JSON file not found: %s" % path)
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	_require(parsed != null, "Failed parsing JSON: %s" % path)
	return parsed

func _hex_to_color(hex: String) -> Color:
	return Color.from_string(hex, Color.WHITE)

func _require(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		assert(false, msg)
