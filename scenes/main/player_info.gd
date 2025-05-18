extends Label

func _process(delta):
    # Update the speed text
    text = "Speed: " + str(int(Globals.player_speed)) + "\nDirection: " + str(int(Globals.player_direction))
