extends RefCounted
class_name WorldSlope

var id: int
static var next_id: int = 1

var name: String
var tile_set: TileSet
var tile_set_src_id: int
var width: int
var ground: AssetGroup
var assets: Dictionary = {}     # { name: { "group": AssetGroup, "weight": float } }
var notes: String
var weight: float

# --- Walker state ---
var start_cell: Vector2i
var current_cell: Vector2i
var rng: RandomNumberGenerator
var steps_taken := 0
var max_length := 200
var branch_chance := 0.15   # default, can be overridden

# --- Collected cells ---
var cells: Array[Vector2i] = []
var edge_cells: Array[Vector2i] = []

func _init(
		name: String,
		tile_set: TileSet,
		tile_set_src_id: int,
		length: int,
		width: int,
		ground: AssetGroup,
		assets: Dictionary = {},   # { name: { "group": AssetGroup, "weight": float } }
		notes: String = "",
		weight: float = 1.0,
		branch_chance: float = 0.15
	) -> void:
	self.id = next_id
	next_id += 1

	self.name = name
	self.tile_set = tile_set
	self.tile_set_src_id = tile_set_src_id
	self.max_length = max(1, length)
	self.width = max(1, width)
	self.ground = ground
	self.assets = assets.duplicate(true)
	self.notes = notes
	self.weight = weight
	self.branch_chance = branch_chance

func set_start_cell(cell: Vector2i) -> void:
	start_cell = cell
	current_cell = cell
	rng = RandomNumberGenerator.new()
	rng.seed = int(cell.x * 73856093 + cell.y * 19349663 + id)

func step_forward() -> Variant:
	if steps_taken >= max_length:
		return null

	var roll = rng.randf()
	if roll < 0.2:
		current_cell += Vector2i(-1, 1)
	elif roll < 0.4:
		current_cell += Vector2i(1, 1)
	else:
		current_cell += Vector2i(0, 1)

	steps_taken += 1
	return current_cell

func is_finished() -> bool:
	return steps_taken >= max_length

func should_branch() -> bool:
	return rng.randf() < branch_chance

func get_branch_cell() -> Vector2i:
	return current_cell

func add_cell(c: Vector2i): cells.append(c)
func add_edge(c: Vector2i): edge_cells.append(c)

func get_ground_asset(rng: RandomNumberGenerator) -> WorldAsset:
	return ground.get_random_asset(rng) if ground != null else null

func get_random_asset(rng: RandomNumberGenerator) -> WorldAsset:
	var candidates: Array = []
	var total_weight := 0.0
	for entry in assets.values():
		candidates.append(entry)
		total_weight += float(entry["weight"])

	if total_weight <= 0.0:
		return null

	var choice_point := rng.randf() * total_weight
	var running_total := 0.0
	var selected_group: AssetGroup = null
	for entry in candidates:
		running_total += float(entry["weight"])
		if choice_point < running_total:
			selected_group = entry["group"]
			break

	return selected_group.get_random_asset(rng) if selected_group != null else null

func duplicate() -> WorldSlope:
	var copy := WorldSlope.new(
		name,
		tile_set,
		tile_set_src_id,
		max_length,
		width,
		ground,
		assets,
		notes,
		weight,
		branch_chance
	)
	return copy
