extends Sprite2D

# Reference to the parent object (assumed to be a rotating Node2D or similar)
@onready var parent_object = get_parent() as Node2D

func _process(delta):
    if parent_object:
        # Negate the parent's rotation, so the sprite remains upright
        rotation = -parent_object.rotation
