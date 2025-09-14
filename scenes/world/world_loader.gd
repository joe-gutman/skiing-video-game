extends RefCounted
class_name WorldLoader

func load_world(assets_path: String, biomes_path: String, world_path: String, slopes_path: String = "") -> GameWorld:
	var assets_json: Dictionary = _load_json(assets_path)
	var biomes_json: Dictionary = _load_json(biomes_path)
	var world_json: Dictionary = _load_json(world_path)

	_require(assets_json != null, "Failed to load assets.json")
	_require(biomes_json != null, "Failed to load biomes.json")
	_require(world_json != null, "Failed to load world.json")

	var assets_map: Dictionary = _load_assets(assets_json)
	var game_world: GameWorld = GameWorld.new(
		world_json["name"],
		int(world_json.get("seed", 0))
	)

	# Load biomes
	var biomes_array: Array = world_json.get("biomes", [])
	for biome_ref in biomes_array:
		if biome_ref.get("active", true) == false:
			continue
		var biome_key: String = biome_ref["biome"]
		var biome_def: Dictionary = biomes_json[biome_key]
		var biome: WorldBiome = _load_biomes(biome_def, assets_map)

		var noise: Dictionary = biome_ref.get("noise_params", {})
		var weight: float = float(biome_ref.get("weight", 1.0))

		game_world.add_biome(
			biome,
			weight,
			float(noise.get("scale", 40.0)),
			int(noise.get("octaves", 3)),
			float(noise.get("persistence", 0.5)),
			float(noise.get("lacunarity", 2.0)),
			float(biome_def.get("width", 1.0)),
			float(biome_def.get("length", 1.0))
		)

	# Load slopes
	var slopes_json: Dictionary = {}
	if slopes_path != "":
		slopes_json = _load_json(slopes_path)
		_require(slopes_json != null, "Failed to load slopes.json")
	else:
		slopes_json = world_json.get("slopes", {})

	for slope_key in slopes_json.keys():
		var slope_def: Dictionary = slopes_json[slope_key]
		var slope: WorldSlope = _load_slopes(slope_def, assets_map)
		game_world.add_slope(slope)

	return game_world


func _load_assets(assets_json: Dictionary) -> Dictionary:
	var assets_map: Dictionary = {}
	for name: String in assets_json.keys():
		var def: Dictionary = assets_json[name]
		var asset: WorldAsset = WorldAsset.new(name, def)
		assets_map[name] = asset
	return assets_map


func _load_biomes(def: Dictionary, assets_map: Dictionary) -> WorldBiome:
	print("Building biome: %s" % def["name"])

	# Ground
	_require(def.has("ground"), "Biome '%s' missing ground definition" % def["name"])
	var ground_def: Dictionary = def["ground"]
	var ground_group: AssetGroup = _build_group("ground", ground_def, assets_map)

	# Assets
	var biome_assets: Dictionary = {}
	if def.has("assets"):
		for asset_group_name: String in def["assets"].keys():
			var asset_group_def: Dictionary = def["assets"][asset_group_name]
			var group: AssetGroup = _build_group(asset_group_name, asset_group_def, assets_map)
			biome_assets[asset_group_name] = {
				"group": group,
				"weight": float(asset_group_def.get("weight", 1.0))
			}

	return WorldBiome.new(
		def["name"],
		load(def["tile_set"]) as TileSet,
		float(def.get("density", 1.0)),
		float(def.get("width", 1.0)),
		float(def.get("length", 1.0)),
		ground_group,
		biome_assets,
		def.get("weather", "clear"),
		int(def.get("temperature", 0)),
		def.get("ambient_sounds", []),
		_hex_to_color(def.get("sky_color", "#FFFFFF")),
		_hex_to_color(def.get("fog_color", "#FFFFFF")),
		def.get("notes", "")
	)


func _load_slopes(def: Dictionary, assets_map: Dictionary) -> WorldSlope:
	# Ground (slopes always need ground)
	_require(def.has("ground"), "Slope '%s' missing ground definition" % def.get("name", "Unnamed"))
	var ground_def: Dictionary = def["ground"]
	var ground: AssetGroup = _build_group("ground", ground_def, assets_map)

	# Assets
	var slope_assets: Dictionary = {}
	if def.has("assets"):
		for asset_group_name: String in def["assets"].keys():
			var asset_group_def: Dictionary = def["assets"][asset_group_name]
			var group: AssetGroup = _build_group(asset_group_name, asset_group_def, assets_map)
			slope_assets[asset_group_name] = {
				"group": group,
				"weight": float(asset_group_def.get("weight", 1.0))
			}

	return WorldSlope.new(
		def.get("name", "Unnamed Slope"),
		load(def["tile_set"]) as TileSet,
		int(def["src_id"]),
		int(def.get("width", 1)),
		int(def.get("length", 100)),
		ground,
		slope_assets,
		def.get("notes", ""),
		float(def.get("weight", 1.0)),
		float(def.get("branch_chance", 0.15))  # <- allow override
	)


func _build_group(name: String, def: Dictionary, assets_map: Dictionary) -> AssetGroup:
	var density: float = float(def.get("density", 1.0))
	var weight: float = float(def.get("weight", 1.0))
	var group: AssetGroup = AssetGroup.new(name, density, weight)

	for a: Dictionary in def.get("assets", []):
		var asset_name: String = a["name"]
		_require(assets_map.has(asset_name), "Asset '%s' not found in assets.json" % asset_name)
		var asset: WorldAsset = assets_map[asset_name]
		var a_weight: float = float(a.get("weight", 1.0))
		group.add_asset(asset, a_weight)

	return group


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
