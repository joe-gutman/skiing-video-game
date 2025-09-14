extends RefCounted
class_name GameWorld

# Biome noise control:
var biome_rot := 0.0
var biome_width := 0.5 
var biome_length := 1.0 / 10

# Noise distortion:
var warp_amp := 100.0
var warp_noise := FastNoiseLite.new()

var slope_frequency: float = .1

var name: String
var biomes: Dictionary
var slopes: Dictionary
var slope_instances: Array
var rng: RandomNumberGenerator
var seed: int


func _init(name: String, seed: int = 0) -> void:
	self.name = name
	self.seed = seed
	self.biomes = {}
	self.slopes = {}
	self.slope_instances = []
	rng = RandomNumberGenerator.new()

	# init warp noise
	warp_noise.seed = int(rng.seed) ^ 0x5a5a
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp_noise.frequency = 1.0 / 800.0

	if seed == 0:
		rng.randomize()
		self.seed = rng.seed
	else:
		rng.seed = seed

func _sample_anisotropic(noise: FastNoiseLite, cell: Vector2i, biome_width: float, biome_length: float) -> float:
	var x := float(cell.x) * biome_width
	var y := float(cell.y) * biome_length

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
		width: float = 1.0,
		length: float = 1.0
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
		"width": width,
		"length": length,
		"scale": scale,
		"octaves": octaves,
		"persistence": persistence,
		"lacunarity": lacunarity
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
		var biome: WorldBiome = biome_data["biome"]

		# Use biome specific width & length for offset and noise sampling
		var w := biome.width
		var l := biome.length

		var offset := Vector2i(
			int(cell.x * w + i * 1000.0),
			int(cell.y * l + i * 2000.0)
		)
		
		var n := _sample_anisotropic(noise, cell + offset, w, l)
		
		var score := n * global_weight
		if score > best_score:
			best_score = score
			best_biome = biome
		
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
	
@export var biome_blend_threshold: float = 0.1  # how "soft" borders are

func get_biome_blended(cell: Vector2i) -> WorldBiome:
	var scores: Array = []
	var i := 0

	for biome_data in biomes.values():
		var weight: float = float(biome_data["weight"])
		if weight <= 0.0:
			continue

		var noise: FastNoiseLite = biome_data["noise"]
		var biome: WorldBiome = biome_data["biome"]
		var w: float = biome.width
		var l: float = biome.length

		var offset := Vector2i(
			int(cell.x * w + i * 1000.0),
			int(cell.y * l + i * 2000.0)
		)

		var n := _sample_anisotropic(noise, cell + offset, w, l)
		var score: float = n * weight
		scores.append([biome, score])
		i += 1

	if scores.is_empty():
		return null

	# Sort descending
	scores.sort_custom(func(a, b): return a[1] > b[1])

	var first = scores[0]
	if scores.size() == 1:
		return first[0]

	var second = scores[1]
	var diff: float = first[1] - second[1]

	# If they’re nearly equal, soften winner’s hold
	if diff < biome_blend_threshold:
		# shrink the winner’s "edge" chance
		var chance := diff / biome_blend_threshold
		if rng.randf() > chance:
			return second[0]

	return first[0]



func add_slope(slope: WorldSlope) -> void:
	if not (slope is WorldSlope):
		push_error("Slope must be a WorldSlope type but got %s." % typeof(slope))
		return

	if self.slopes.has(slope.name):
		push_error("Slope with name '%s' already exists." % slope.name)
		return

	self.slopes[slope.name] = slope

func get_slope(slope_name: String) -> WorldSlope:
	if self.slopes.has(slope_name):
		return self.slopes[slope_name]
	return null

func get_random_slope() -> WorldSlope:
	var total_weight := 0.0
	for slope_def in slopes.values():
		total_weight += slope_def.weight

	if total_weight <= 0.0:
		return null

	var roll := rng.randf() * total_weight
	for slope_def in slopes.values():
		roll -= slope_def.weight
		if roll <= 0.0:
			return slope_def
	return null

func get_slopes() -> Array:
	return self.slopes.values()

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
