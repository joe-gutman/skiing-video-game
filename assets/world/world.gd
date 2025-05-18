extends Node2D

@onready var ground = get_node("Ground")  

func _process(delta):
	ground.position = Globals.player.position
