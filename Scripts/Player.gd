class_name Player
extends KinematicBody2D

onready var colExtents = $Collider.shape.get_extents() # Assuming rect shaped
onready var colMask = Rect2(position - colExtents, colExtents * 2)
onready var lblCount = $Count

export var enemy: bool = false

const SPEED: int = 7
var count: int = -1 # Testing value
var vCount: int = count

# Just to set a unique color
func _ready() -> void:
	if enemy: $Skin.color = Color.red
	else: $Skin.color = Color.blue

# Reset object state to that in a given game_state, executed once per rollback 
func reset_state(game_state : Dictionary) -> void:
	# Check if this object exists within the checked game_state
	if not game_state.has(name):
	#	free() # Delete from memory
		return
	
	position.x = game_state[name].x
	position.y = game_state[name].y
	vCount = game_state[name].count
	colMask = game_state[name].colMask

func frame_start() -> void:
	# Set update vars to current values
	vCount = count
	update_collision_mask()

func input_update(input: Session.InputDef, game_state : Dictionary) -> void:
	# Calculate movement on input
	var motion = Vector2(0, 0)
	for object in game_state:
		if object != name and colMask.intersects(game_state[object].colMask):
			vCount += 1
	
	if not enemy: # Is a Player
		if Session.IsDir(input.Player, Session.InputType.U): motion.y -= SPEED
		if Session.IsDir(input.Player, Session.InputType.L): motion.x -= SPEED
		if Session.IsDir(input.Player, Session.InputType.R): motion.x += SPEED
		if Session.IsDir(input.Player, Session.InputType.D): motion.y += SPEED
		if Session.IsDir(input.Player, Session.InputType.SEL): vCount /= 2
	else:  # Reverse enemy input (simulate mirrored screen)
		if Session.IsDir(input.Enemy, Session.InputType.U): motion.y += SPEED
		if Session.IsDir(input.Enemy, Session.InputType.L): motion.x += SPEED
		if Session.IsDir(input.Enemy, Session.InputType.R): motion.x -= SPEED
		if Session.IsDir(input.Enemy, Session.InputType.D): motion.y -= SPEED
		if Session.IsDir(input.Enemy, Session.InputType.SEL): vCount /= 2
	
	# move_and_collide for "solid" stationary objects
	var collision = move_and_collide(motion)
	if collision:
		motion = motion.slide(collision.normal)
		move_and_collide(motion)
	
	update_collision_mask()

func execute() -> void:
	# Execute calculated state of object for current frame
	count = vCount
	lblCount.text = str(count)

func get_state() -> Dictionary:
	# Return dict of state variables to be stored in Frame_States
	return {'x': position.x, 'y': position.y, 'count': vCount, 'colMask': colMask}

func update_collision_mask() -> void:
	colMask = Rect2(position - colExtents, colExtents * 2)
