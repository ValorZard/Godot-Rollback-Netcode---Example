extends Button


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var is_player_two : bool = false
var network_scene = preload("res://Scenes/Stage2DCollisions.tscn").instance()
var address : String = ""

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

	address = get_parent().get_node("AdrLabel/AddressText").text
	var frame_delay : int = int(get_parent().get_node("FrameLabel/FrameEdit").text)
	var rollback_frames : int = int(get_parent().get_node("RollbackLabel/RollbackEdit").text)
	var duplicate_range : int = int(get_parent().get_node("DupRangeLabel/DupRangeEdit").text)
	
	#print(address)
	network_scene.get_node("InputControl").address = address
	
	network_scene.get_node("InputControl").input_delay = frame_delay
	network_scene.get_node("InputControl").rollback = rollback_frames
	network_scene.get_node("InputControl").dup_send_range  = duplicate_range

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
