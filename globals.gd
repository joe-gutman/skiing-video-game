extends Node

# Player-related
var player: RigidBody2D
var player_height: int = 0
var player_position: Vector2 = Vector2.ZERO
var player_speed: float = 0.0
var player_direction: float = 0.0
var player_normal: Vector2 = Vector2.ZERO
var player_camera: Camera2D

# World-related	
var world_scale: Vector2 = Vector2(2.5, 2.5)
var ground: TileMapLayer
var viewport_bounds: Rect2i = Rect2i() 	# in tile coordinates
var padding: int = 2 					# extra padding around viewport bounds for loading

# Camera-related zoom state
var current_zoom: float = 0.75
var min_zoom: float = 0.1
var max_zoom: float = 1.25
var zoom_step: float = 0.05

const MAX_Z_INDEX = 4096


func _ready() -> void:
	player_camera = get_node_or_null("/root/Playfield/Control/ColorRect/SubViewport/Player/Camera2D")
	player = get_node_or_null("/root/Playfield/Control/ColorRect/SubViewport/Player")
	set_zoom(current_zoom) # safe initial zoom


func _process(_delta: float) -> void:
	if player:
		player_position = player.global_position

	# keep player_direction within 0–360
	if player_direction < 0:
		player_direction += 360
	elif player_direction >= 360:
		player_direction -= 360

	# update bounds every frame (or throttle if needed)
	update_viewport_bounds()

func set_ground(tilemap: TileMapLayer) -> void:
	ground = tilemap
	update_viewport_bounds()


func get_z_index(element: Node2D, modifier: int = 0) -> int:
	return int(fposmod(element.global_position.y + modifier, MAX_Z_INDEX))


func set_zoom(zoom_value: float) -> void:
	current_zoom = clamp(zoom_value, min_zoom, max_zoom)
	if player_camera:
		var godot_zoom = 1.0 / current_zoom
		player_camera.zoom = Vector2(godot_zoom, godot_zoom)

func zoom_in() -> void:
	set_zoom(current_zoom - zoom_step)

func zoom_out() -> void:
	set_zoom(current_zoom + zoom_step)


func update_viewport_bounds() -> void:
	if not ground or not player_camera:
		return

	var visible_world_size: Vector2 = get_viewport().get_visible_rect().size * max_zoom
	var half_size: Vector2 = visible_world_size * 0.5
	var center_pos: Vector2 = player_camera.global_position

	var top_left = center_pos - half_size
	var bottom_right = center_pos + half_size

	var tile_tl: Vector2i = ground.local_to_map(ground.to_local(top_left)) - Vector2i(padding, padding)
	var tile_br: Vector2i = ground.local_to_map(ground.to_local(bottom_right)) + Vector2i(1 + padding, 1 + padding)

	viewport_bounds = Rect2i(tile_tl, tile_br - tile_tl)


func is_tile_inbounds(cell: Vector2i) -> bool:
	return viewport_bounds.has_point(cell)
