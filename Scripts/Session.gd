extends Node

######################################
######################################
###
###        Session Handlers
###
##############################
##############################

# Debug elements/variables
var IsLocal : bool = false
var IsPlayerOne : bool = false

# Subscene where players are stored
onready var lblDetails: Label = get_tree().root.get_node("Game/Gui/Details")
onready var objects = get_tree().root.get_node("Game/Arena/Objects")


# Modifiable settings
var InputDelay : int = 1 # Amount of input delay in frames
var Rollback : int = 20 # Frame history (Max-Rollback length)
var DupSendRange :int = 16 # Input history to resend (in frames) from past frames

# Tracks current game status
enum StatusType { WAITING, PLAYING, END, MENU }
var Status = StatusType.MENU

# Input Trackers
var bufHistory = [] # 256 boolean array, tracks the input history
var StateQueue = [] # Queue for Frame_States of past frames (for Rollback)
var InputReceived = [] # 256 boolean array, tracks if networked inputs for a given frame have arrived
var InputCanRequest = [] # 256 boolean array, tracks if local inputs for a given frame are viable to be sent by request
var InputsHandled = [] # Bool array to compare input arrivals between current frame and previous frame

var CurFrame : int = 0 # Ranges between 0-255 per circular input array cycle (cycle is every 256 frames)

######################################
### Input Definitions
##############################

enum InputType { U, D, L, R, SEL }

func SetDir(value: int, dir: int) -> int:
	return value | (1 << dir)

func IsDir(value: int, dir: int) -> bool:
	return value & (1 << dir) != 0

class InputDef: # Single frame of input from both sides
	var Player: int
	var Enemy: int

class FrameStateDef:
	var State: Dictionary # Dictionary holds the values need for tracking a game's state at a given frame. Keys are child names.
	var Frame: int # Frame number according to 256 frame cycle number
	var Player: int = 0
	var Enemy: int = 0
	var Predicted: bool = true # If networked input has not been received yet

	# State keys are child names, values are their individual state dictionaries
	# states: Keys are state vars of the children (e.g. x, y), values are the var values  
	func _init(state : Dictionary, frame : int, player : int, enemy : int, predicted : bool):
		self.State = state # Dictionary of dictionaries
		self.Frame = frame
		self.Player = player
		self.Enemy = enemy
		self.Predicted = predicted

######################################
### Core Functions
##############################

func _notification(what):
	if (what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST):
		Send_GameEnd()
		get_tree().quit()
		
func ready():
	# Disable auto-close from game window
	get_tree().set_auto_accept_quit(false)
	
	# Initialize arrays
	for _i in range (0, 256):
		bufHistory.append(InputDef.new())
		InputReceived.append(false)
		InputCanRequest.append(false)
	
	# Initialize state queue
	for _i in range (0, Rollback):
		# Empty local input, empty net input, frame 0, inital game state, treat initial empty inputs as true, actual inputs
		StateQueue.append(FrameStateDef.new(get_game_state(), 0, 0, 0, true))
	
	for i in range (1, Rollback + 100):
		InputsHandled.append(true)
		InputReceived[-i] = true # For initialization, pretend all "previous" inputs arrived
	
	for i in range (0, InputDelay):
		InputReceived[i] = true # Assume empty inputs at game start InputDelay window
		InputCanRequest[i] = true
	
	NetReceived = false # Network thread will set to true when a networked player is found
	
	###########################
	## Network Initialization
	############
	
	peer.set_broadcast_enabled(true)
	upnp.discover()
	upnp.add_port_mapping(Port)
	
	# Connecting to end-user
	if IsLocal:
		# When testing locally, we have to make the clients listen on different ports
		if IsPlayerOne:
			peer.listen(5000, "*")
			peer.set_dest_address(Address, 5001)
		else:
			peer.listen(5001, "*")
			peer.set_dest_address(Address, 5000)
	else:
		peer.listen(Port, "*")
		peer.set_dest_address(Address, Port)
	
	# Link function pointers to packet headers
	BindPacketList()
	
	# Fire receiving thread
	NetThread = Thread.new()
	NetThread.start(self, "_receive_data", null, 2)

func _physics_process(_delta):
	if Status == StatusType.MENU: return
	
	NetMutex.lock()
	if (NetReceived):
		# If the oldest FrameState in the queue is guessed,
		# but the input_queue Input does not yet contain an actual
		# input for the oldest FrameState's Frame, then DELAY
		if StateQueue[0].Predicted and not InputReceived[StateQueue[0].Frame]:
			NetReceived = false # Wait until actual net input is received for guessed oldest FrameState
			NetMutex.unlock()
			Send_InputRequest(CurFrame) # Send request for needed input
			lblDetails.text = "DELAY: Waiting for net input. CurFrame: " + str(CurFrame)
		else:
			NetMutex.unlock()
			lblDetails.text = ""
			handle_input()
	else:
		NetMutex.unlock()
		if (Status == StatusType.WAITING): # Search for networked player
			Send_GameStart(StatusType.WAITING) # Send ready handshake to opponent
		else: # Send request for needed inputs for past frames
			Send_InputRequest((CurFrame + 1) % 256) # Send request for needed input

func handle_input(): # Get input, Rollback if necessary, implement inputs
	var pre_game_state = get_game_state()
	var predicted: bool = false
	var start_rollback: bool = false
	
	var current_input = null
	var current_frame_arrival_array = []

	var myInput: int = 0
	
	frame_start_all() # For all children, set their update vars to their current/actual values
	
	# Record local inputs
	if Input.is_action_pressed("ui_up"): myInput = SetDir(myInput, InputType.U)
	if Input.is_action_pressed("ui_down"): myInput = SetDir(myInput, InputType.D)
	if Input.is_action_pressed("ui_left"): myInput = SetDir(myInput, InputType.L)
	if Input.is_action_pressed("ui_right"): myInput = SetDir(myInput, InputType.R)
	if Input.is_action_just_pressed("ui_select"): myInput = SetDir(myInput, InputType.SEL)
	if Input.is_action_just_pressed("ui_end"):
		Send_GameEnd()
		Status = StatusType.END
		return

	InputMutex.lock()
	
	bufHistory[(CurFrame + InputDelay) % 256].Player = myInput
	
	# Send inputs over network
	for i in Rollback:
		var offset = (CurFrame + InputDelay - i) % 256
		Send_ReceiveInput(offset, bufHistory[offset].Player)
	
	# Get current input arrival boolean values for current frame & old frames eligible for Rollback
	for i in range(0, Rollback + 1): 
		current_frame_arrival_array.push_front(InputReceived[CurFrame - i]) # Oldest frame in front
	
	InputMutex.unlock()
	
	# The input from the current frame can now be sent by request
	RequestMutex.lock()
	InputCanRequest[(CurFrame + InputDelay) % 256] = true
	RequestMutex.unlock()
	
	# Remove current frame's arrival boolean for Rollback condition hash comparison
	var current_frame_arrival = current_frame_arrival_array.pop_back()
	
	# If an input for a past frame has arrived (to fulfill a guess),
	if current_frame_arrival_array.hash() != InputsHandled.hash():
		# Iterate through all saved states until the state with the guessed input 
		# to be replaced by an arrived actual input is found (Rollback will begin with that state)
		# then, continue iterating and operating through remaining saved
		# states to continue the resimulation process
		var state_index = 0 # For tracking iterated element's index in StateQueue
		for i in StateQueue: # Index 0 is oldest state
			# If an arrived input is for a past frame,
			if (InputsHandled[state_index] == false && current_frame_arrival_array[state_index] == true):
				
				# Set net input in the FrameState from guess to actual input
				InputMutex.lock()
				i.Enemy = bufHistory[i.Frame].Enemy 
				InputMutex.unlock()
				i.Predicted = false
				
				# If first Rollback iteration, reset update variables for all children to match Rollback start state
				if start_rollback == false:
					reset_state_all(i.State) 
					start_rollback = true
				
				pre_game_state = get_game_state()
				input_update_all(bufHistory[i.Frame], pre_game_state) # Simulate using new true input
				
			# Continue simulating using currently stored inputs
			else:
				if start_rollback == true:
					pre_game_state = get_game_state() # Save pre-update state value for FrameState
					input_update_all(bufHistory[i.Frame], pre_game_state) # Update state using previous input during Rollback resimulation
			
			if start_rollback == true:
				i.State = pre_game_state # Update FrameState with updated state value.
				
			state_index += 1
	
	# Reinsert current frame's arrival boolean (for next frame's InputsHandled)
	current_frame_arrival_array.push_back(current_frame_arrival)
	# Remove oldest frame's arrival boolean (unwanted for next frame's InputsHandled)
	current_frame_arrival_array.pop_front() 
	
	current_input = InputDef.new()
	InputMutex.lock()
	
	# If the input for the current frame has not been received
	if InputReceived[CurFrame] == false:
		# Implement guess of last input used
		current_input.Player = bufHistory[CurFrame].Player
		current_input.Enemy = bufHistory[CurFrame - 1].Enemy # Guessing with previous frame's input
		bufHistory[CurFrame].Enemy = bufHistory[CurFrame - 1].Enemy
		
		predicted = true
	else: # Proceed with actual net input
		current_input.Player = bufHistory[CurFrame].Player
		current_input.Enemy = bufHistory[CurFrame].Enemy
	
	InputReceived[CurFrame - (Rollback + 120)] = false # Reset input arrival boolean for old frame
	InputMutex.unlock()
	
	RequestMutex.lock()
	InputCanRequest[CurFrame - (Rollback + 120)] = false # Reset viable local input boolean
	RequestMutex.unlock()
	 
	if start_rollback == true:
		pre_game_state = get_game_state()
	
	input_update_all(current_input, pre_game_state) # Update with current input
	execute_all() # Implement all applied updates/inputs to all child objects
	
	# Store current frame state into queue
	StateQueue.append(FrameStateDef.new(pre_game_state, CurFrame, current_input.Player, current_input.Enemy, predicted))
	
	# Remove oldest state
	StateQueue.pop_front()
	
	InputsHandled = current_frame_arrival_array # Store current input arrival array for comaparisons in next frame
	CurFrame = (CurFrame + 1)%256 # Increment CurFrame

func frame_start_all():
	for child in objects.get_children():
		child.frame_start()

func reset_state_all(state : Dictionary):
	for child in objects.get_children():
		child.reset_state(state)

func input_update_all(input : InputDef, state : Dictionary):
	for child in objects.get_children():
		child.input_update(input, state)

func execute_all():
	for child in objects.get_children():
		child.execute()

func get_game_state():
	var state = {}
	for child in objects.get_children():
		state[child.name] = child.get_state()
	return state.duplicate(true)


######################################
######################################
###
###        Network Handlers
###
##############################
##############################

enum PacketType {
	RECEIVE_INPUT,
	INPUT_REQUESTED,
	GAME_START,
	GAME_END
}

# Thread Handling
var InputMutex = Mutex.new()
var RequestMutex = Mutex.new()
var NetMutex = Mutex.new()
var NetThread = null # Thread to receive inputs over the network
var NetReceived: bool # Semephore communicate between threads if new inputs have been received

var Address: String = "127.0.0.1"
var Port: int = 5678

######################################
### Function Pointers
##############################

var Packets = {}
class PacketDef:
	signal function(data)
	
	func _emit(data) -> void:
		emit_signal("function", data)

######################################
### Network Loop
##############################

var upnp = UPNP.new()
var peer = PacketPeerUDP.new()
func _receive_data(_userdata):
	var data = null
	
	while(true):
		data = peer.get_packet() # Receive a single packet
		if data: Packets[data[0]]._emit(data) # Handle Packet
		else: peer.wait() # Wait for data to come in

######################################
### Function Pointer Binder
##############################

func BindPacketList():
	# Receive Input
	var tmp = PacketDef.new()
	tmp.connect("function", self, "HandlePacket_ReceiveInput")
	Packets[PacketType.RECEIVE_INPUT] = tmp
	
	# Input Requested
	tmp = PacketDef.new()
	tmp.connect("function", self, "HandlePacket_InputRequested")
	Packets[PacketType.INPUT_REQUESTED] = tmp
	
	# Game Starting
	tmp = PacketDef.new()
	tmp.connect("function", self, "HandlePacket_GameStart")
	Packets[PacketType.GAME_START] = tmp
	
	# Game Ending
	tmp = PacketDef.new()
	tmp.connect("function", self, "HandlePacket_GameEnd")
	Packets[PacketType.GAME_END] = tmp

######################################
### Function Pointed Handlers
##############################

func HandlePacket_ReceiveInput(data) -> void:
	# Confirm packet-size integrity
	if data.size() != 3: return
	
	InputMutex.lock()
	if InputReceived[data[1]] == false: # If a non-duplicate input arrives for a frame
		bufHistory[data[1]].Enemy = data[2]
		InputReceived[data[1]] = true
		NetMutex.lock()
		NetReceived = true
		if Status == StatusType.WAITING:
			Status = StatusType.PLAYING
		NetMutex.unlock()
	InputMutex.unlock()

func HandlePacket_InputRequested(data) -> void:
	# Confirm packet-size integrity
	if data.size() != 3: return
	
	var frame = data[1]
	RequestMutex.lock()
	while (frame != data[2]): # Send inputs for requested frame and newer past frames
		if InputCanRequest[frame] == false: 
			break # Do not send invalid inputs from future frames
		Send_ReceiveInput(frame, bufHistory[frame].Player)
		frame = (frame + 1)%256
	RequestMutex.unlock()

func HandlePacket_GameStart(data) -> void:
	# Confirm packet-size integrity
	if data.size() != 2: return
	
	if Status == StatusType.WAITING:
		NetMutex.lock()
		Status = StatusType.PLAYING
		NetReceived = true
		NetMutex.unlock()
		
	elif (data[1] == StatusType.WAITING):
		Send_GameStart(StatusType.PLAYING)

func HandlePacket_GameEnd(data) -> void:
	# Close the port
	upnp.delete_port_mapping(Port)
	
	if Status != StatusType.PLAYING: return
	
	NetMutex.lock()
	Status = StatusType.END
	NetMutex.unlock()

######################################
### Send Packets
##############################

func Send_ReceiveInput(frame: int, input: int) -> void:
	peer.put_packet(
		PoolByteArray([
			PacketType.RECEIVE_INPUT,
			frame,
			input
		])
	)

func Send_InputRequest(frame: int) -> void:
	peer.put_packet(
		PoolByteArray([
			PacketType.INPUT_REQUESTED,
			StateQueue[0].Frame,
			frame
		])
	)

func Send_GameStart(status: int) -> void:
	peer.put_packet(
		PoolByteArray([
			PacketType.GAME_START,
			status
		])
	)

func Send_GameEnd() -> void:
	peer.put_packet(
		PoolByteArray([
			PacketType.GAME_END
		])
	)
