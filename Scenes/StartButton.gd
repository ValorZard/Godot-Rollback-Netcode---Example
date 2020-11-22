extends Button


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var is_player_two = false
var network_scene = preload("res://Scenes/Stage2DCollisions.tscn").instance()


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _on_StartButton_pressed():
	is_player_two = get_parent().get_node("CheckPlayerPort").pressed
	print("hi!")
	print("Player port 2: " + String(is_player_two))
	network_scene.get_node("InputControl").is_player_two = is_player_two
	get_tree().get_root().add_child(network_scene)
	get_tree().get_root().get_node("Control").visible = false

# func _on_CheckPlayerPort_pressed():
# 	is_player_two = true
# 	print("Connecting from player two")

# func _on_CheckPlayerPort_button_up():
# 	is_player_two = false
# 	print("Connecting from player one")
# 	pass


# func _on_CheckPlayerPort_button_down():
# 	pass # Replace with function body.
