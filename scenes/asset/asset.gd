extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    sprite.z_index = Globals.get_z_index(self, -10)