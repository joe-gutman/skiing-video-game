extends RefCounted
class_name GameWorld

var name: String
var biomes: Dictionary   # { biome_name: { "biome": WorldBiome, "noise": FastNoiseLite, "weight": float }, ... }
var rng: RandomNumberGenerator
var seed: int

var biome_axis_radians := 0.0          # 0 = rows run vertical (downhill). Try PI/18 for slight tilt.
var freq_x := 0.5           # faster variation across X => narrower rows
var freq_y := 1.0 / 10          # slower variation along Y => longer rows

var warp_amp := 100.0                   # set ~6.0 to add subtle wiggle, 0.0 = off
var warp_noise := FastNoiseLite.new()  # optional warp field

func _init(name: String, seed: int = 0) -> void:
	self.name = name
	self.seed = seed
	self.biomes = {}
	rng = RandomNumberGenerator.new()

	# init warp noise
	warp_noise.seed = int(rng.seed) ^ 0x5a5a
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp_noise.frequency = 1.0 / 800.0

	if seed == 0:
		rng.randomize()
		self.seed = rng.seed  # store whatever random seed we got
	else:
		rng.seed = seed

func _sample_anisotropic(noise: FastNoiseLite, cell: Vector2i, freq_x: float, freq_y: float) -> float:
	var x := float(cell.x) * freq_x
	var y := float(cell.y) * freq_y

	# optional domain warp for wobbly edges
	if warp_amp > 0.0:
		var wx := warp_noise.get_noise_2d(x, y)
		var wy := warp_noise.get_noise_2d(x + 1234.0, y - 987.0)
		x += wx * warp_amp
		y += wy * warp_amp

	return (noise.get_noise_2d(x, y) + 1.0) * 0.5

func add_biome(
		biome: WorldBiome,
		weight: float = 1.0,
		scale: float = 1.0,
		octaves: int = 1,
		persistence: float = 0.5,
		lacunarity: float = 2.0,
		freq_x: float = 1.0,
		freq_y: float = 1.0
	) -> void:
	if not (biome is WorldBiome):
		push_error("Biome must be a WorldBiome type but got %s." % typeof(biome))
		return

	if self.biomes.has(biome.name):
		push_error("Biome with name '%s' already exists." % biome.name)
		return

	var noise := _make_noise(scale, octaves, persistence, lacunarity)

	self.biomes[biome.name] = {
		"biome": biome,
		"noise": noise,
		"weight": weight,
		"scale": scale,
		"octaves": octaves,
		"persistence": persistence,
		"lacunarity": lacunarity,
		"freq_x": freq_x,
		"freq_y": freq_y
	}


func add_biomes(biomes_list: Array) -> void:
	for biome in biomes_list:
		add_biome(biome)

func get_biome(biome_name: String) -> WorldBiome:
	var biome_data = self.biomes.get(biome_name, null)
	if biome_data:
		return biome_data["biome"]
	return null

func get_biomes() -> Array:
	var biome_array: Array = []
	for biome_data in self.biomes.values():
		biome_array.append(biome_data["biome"])
	return biome_array

func get_biome_at(cell: Vector2i) -> WorldBiome:
	var best_biome: WorldBiome = null
	var best_score := -1.0
	var i := 0
	for biome_data in biomes.values():
		var noise: FastNoiseLite = biome_data["noise"]
		var global_weight: float = biome_data["weight"]

		# Apply offset so each biome sees a different slice
		var offset := Vector2i(
			int(cell.x * freq_x + i * 1000.0),
			int(cell.y * freq_y + i * 2000.0)
		)
		var fx = biome_data.get("freq_x", 1.0)
		var fy = biome_data.get("freq_y", 1.0)
		var n := _sample_anisotropic(noise, cell + offset, fx, fy)

		var score := n * global_weight
		if score > best_score:
			best_score = score
			best_biome = biome_data["biome"]

		i += 1
	return best_biome

func get_biome_by_weight(cell: Vector2i) -> WorldBiome:
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = int(rng.seed + cell.x * 73856093 + cell.y * 19349663)

	var total_weight: float = 0.0
	var biome_weights: Array = []

	# Instead of noise, just use biome weight directly
	for biome_data in biomes.values():
		var weight: float = biome_data["weight"]
		if weight > 0.0:
			biome_weights.append([biome_data["biome"], weight])
			total_weight += weight

	if total_weight <= 0.0:
		return null  # no biome here

	var choice_point: float = local_rng.randf() * total_weight
	var running_total: float = 0.0

	for item in biome_weights:
		running_total += item[1]
		if choice_point < running_total:
			return item[0]

	return null

func _make_noise(
		scale: float = 1.0,
		octaves: int = 1,
		persistence: float = 0.5,
		lacunarity: float = 2.0
	) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.seed
	noise.frequency = 1.0 / scale
	noise.fractal_octaves = octaves
	noise.fractal_gain = persistence
	noise.fractal_lacunarity = lacunarity
	return noise

func _normalize_noise(noise: FastNoiseLite, cell: Vector2i) -> float:
	var raw_value: float = noise.get_noise_2d(cell.x, cell.y)  # -1..1
	return (raw_value + 1.0) * 0.5  # 0..1

func update_biome_noise(
		biome: WorldBiome,
		scale: float = -1.0,
		octaves: int = -1,
		persistence: float = -1.0,
		lacunarity: float = -1.0
	) -> void:
	if not (biome is WorldBiome):
		push_error("Biome must be a WorldBiome type but got %s." % typeof(biome))
		return
	
	var biome_data: Dictionary = self.biomes.get(biome.name, null)
	if not biome_data:
		push_error("Biome '%s' not found in world." % biome.name)
		return
	
	# Use stored params as fallback
	var new_scale      = (scale       >= 0.0) if scale       else biome_data["scale"]
	var new_octaves    = (octaves     >= 0)   if octaves     else biome_data["octaves"]
	var new_persistence= (persistence >= 0.0) if persistence else biome_data["persistence"]
	var new_lacunarity = (lacunarity  >= 0.0) if lacunarity  else biome_data["lacunarity"]

	# Rebuild noise
	biome_data["noise"] = _make_noise(new_scale, new_octaves, new_persistence, new_lacunarity)

	# Update stored params
	biome_data["scale"]       = new_scale
	biome_data["octaves"]     = new_octaves
	biome_data["persistence"] = new_persistence
	biome_data["lacunarity"]  = new_lacunarity
