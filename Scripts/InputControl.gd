#By Jon Chau
extends Node

#amount of input delay in frames
var input_delay = 5 
#number of frame states to save in order to implement rollback (max amount of frames able to rollback)
var rollback = 7 
#frame range of duplicate past input packets to send every frame (should be less than rollback)
var dup_send_range = 5

#tracks current game status
enum Game {WAITING, PLAYING, END}
var game = Game.WAITING
var status = "" #for additional status label info

var is_player_two : bool = false

var input_array = [] #array to hold 256 Inputs
var state_queue = [] #queue for Frame_States of past frames (for rollback)
var input_arrival_array = [] #256 boolean array, tracks if networked inputs for a given frame have arrived
var input_viable_request_array = [] #256 boolean array, tracks if local inputs for a given frame are viable to be sent by request
var prev_frame_arrival_array = [] #boolean array to compare input arrivals between current frame and previous frame
var input_array_mutex = Mutex.new()
var input_viable_request_array_mutex = Mutex.new()

var frame_num = 0 #ranges between 0-255 per circular input array cycle (cycle is every 256 frames)

var input_received #boolean to communicate between threads if new inputs have been received
var input_received_mutex = Mutex.new()

var input_thread = null #thread to receive inputs over the network

var UDPPeer = PacketPeerUDP.new()

#---classes---
class Inputs:
	#Indexing [0]: W, [1]: A, [2]: S, [3]: D, [4]: SPACE
	#inputs by local player for a single frame
	var local_input = [false, false, false, false, false] 
	#inputs by a player over network for a single frame
	var net_input = [false, false, false, false, false]
	var encoded_local_input = 0


class Frame_State:
	var local_input #inputs by local player for a single frame
	var net_input #inputs by a player over network for a single frame
	var frame #frame number according to 256 frame cycle number
	var game_state #dictionary holds the values need for tracking a game's state at a given frame. Keys are child names.
	var actual_input #boolean, whether the state contains guessed input (false) or actual input (true) from networked player

	func _init(_local_input : Array, _net_input : Array, _frame : int, _game_state : Dictionary, _actual_input : bool):
		self.local_input = _local_input #Array of booleans
		self.net_input = _net_input #Array of booleans
		self.frame = _frame
		self.game_state = _game_state #Dictionary of dictionaries
		#game_state keys are child names, values are their individual state dictionaries
		#states: Keys are state vars of the children (e.g. x, y), values are the var values  
		self.actual_input = _actual_input


#---functions---
func thr_network_inputs(_userdata): #thread function to read inputs from network
	var result = null
	while(true):
		result = UDPPeer.get_packet() #receive a single packet
		if result:
			match result[0]: #switch statement for header byte
				0: #input received
					if result.size() == 3: #check for complete packet (no bytes lost)
						input_array_mutex.lock()
						if input_arrival_array[result[1]] == false: #if a non-duplicate input arrives for a frame
							input_array[result[1]].net_input = [
									bool(result[2] & 1),
									bool(result[2] & 2),
									bool(result[2] & 4),
									bool(result[2] & 8),
									bool(result[2] & 16)]
							input_arrival_array[result[1]] = true
							input_received_mutex.lock()
							input_received = true
							if game == Game.WAITING:
								game = Game.PLAYING
							input_received_mutex.unlock()
						input_array_mutex.unlock()
				
				1: #request for input received
					if result.size() == 3: #check for complete packet (no bytes lost)
						var frame = result[1]
						input_viable_request_array_mutex.lock()
						while (frame != result[2]): #send inputs for requested frame and newer past frames
							if input_viable_request_array[frame] == false: 
								break #do not send invalid inputs from future frames
							UDPPeer.put_packet(PoolByteArray([0, frame, input_array[frame].encoded_local_input]))
							frame = (frame + 1)%256
						input_viable_request_array_mutex.unlock()
				
				2: #game start
					if result.size() == 2: #check for complete packet (no bytes lost)
						if game == Game.WAITING:
							input_received_mutex.lock()
							input_received = true
							game = Game.PLAYING
							input_received_mutex.unlock()
						elif (result[1] == 0):
							UDPPeer.put_packet(PoolByteArray([2, 1])) #send ready handshake to opponent
				
				3: #game end
					if game == Game.PLAYING:
						input_received_mutex.lock()
						game = Game.END
						input_received_mutex.unlock()
		else:
			UDPPeer.wait()


func _ready():
	#initialize arrays
	for _x in range (0, 256):
		input_array.append(Inputs.new())
		input_arrival_array.append(false)
		input_viable_request_array.append(false)
	
	#initialize state queue
	for _x in range (0, rollback):
		#empty local input, empty net input, frame 0, inital game state, treat initial empty inputs as true, actual inputs
		state_queue.append(Frame_State.new([], [], 0, get_game_state(), true))
	
	for i in range (1, rollback + 100):
		prev_frame_arrival_array.append(true)
		input_arrival_array[-i] = true # for initialization, pretend all "previous" inputs arrived
		
	for i in range (0, input_delay):
		input_arrival_array[i] = true # assume empty inputs at game start input_delay window
		input_viable_request_array[i] = true
		
	input_received = false #network thread will set to true when a networked player is found.
	
	#set up networking thread
	
	# Switch the values of 240 and 241
	# to create a player 2 client
	
	if(is_player_two):
		UDPPeer.listen(241, "*")
		UDPPeer.set_dest_address("::1", 240) #::1 is localhost
		input_thread = Thread.new()
		input_thread.start(self, "thr_network_inputs", null, 2)
	else:
		UDPPeer.listen(240, "*")
		UDPPeer.set_dest_address("::1", 241) #::1 is localhost
		input_thread = Thread.new()
		input_thread.start(self, "thr_network_inputs", null, 2)


func _physics_process(_delta):
	input_received_mutex.lock()
	if (input_received):
		#if the oldest Frame_State in the queue is guessed,
		#but the input_queue Input does not yet contain an actual input for the oldest Frame_State's frame, then DELAY
		if state_queue[0].actual_input == false && input_arrival_array[state_queue[0].frame] == false:
			input_received = false #wait until actual net input is received for guessed oldest Frame_State
			input_received_mutex.unlock()
			UDPPeer.put_packet(PoolByteArray([1, state_queue[0].frame, frame_num])) #send request for needed input
			status = "DELAY: Waiting for net input. frame_num: " + str(frame_num)
		else:
			input_received_mutex.unlock()
			status = ""
			handle_input()
	else:
		input_received_mutex.unlock()
		if (game == Game.WAITING): #search for networked player
			UDPPeer.put_packet(PoolByteArray([2, 0])) #send ready handshake to opponent
		else:#send request for needed inputs for past frames
			UDPPeer.put_packet(PoolByteArray([1, state_queue[0].frame, (frame_num + 1)%256])) #send request for needed input


func handle_input(): #get input, run rollback if necessary, implement inputs
	var pre_game_state = get_game_state()
	var actual_input = true
	var start_rollback = false
	
	var current_input = null
	var current_frame_arrival_array = []

	var local_input = [false, false, false, false, false]
	var encoded_local_input = 0
	
	frame_start_all() #for all children, set their update vars to their current/actual values
	
	#record local inputs
	if Input.is_key_pressed(KEY_W):
		local_input[0] = true
		encoded_local_input += 1
	if Input.is_key_pressed(KEY_A):
		local_input[1] = true
		encoded_local_input += 2
	if Input.is_key_pressed(KEY_S):
		local_input[2] = true
		encoded_local_input +=4
	if Input.is_key_pressed(KEY_D):
		local_input[3] = true
		encoded_local_input += 8
	if Input.is_key_pressed(KEY_SPACE):
		local_input[4] = true
		encoded_local_input += 16
	if Input.is_key_pressed(KEY_ESCAPE):
		game = Game.END
		UDPPeer.put_packet(PoolByteArray([3])) #send game end signal to peer

	input_array_mutex.lock()
	
	input_array[(frame_num + input_delay) % 256].local_input = local_input
	input_array[(frame_num + input_delay) % 256].encoded_local_input = encoded_local_input
	
	#send inputs over network
	for i in dup_send_range + 1: #send inputs for current frame as well as duplicates of past frame inputs
		UDPPeer.put_packet(PoolByteArray([0, (frame_num + input_delay - i) % 256,
				input_array[(frame_num + input_delay - i) % 256].encoded_local_input]))
	
	#get current input arrival boolean values for current frame & old frames eligible for rollback
	for i in range(0, rollback + 1): 
		current_frame_arrival_array.push_front(input_arrival_array[frame_num - i]) #oldest frame in front
	
	input_array_mutex.unlock()
	
	#the input from the current frame can now be sent by request
	input_viable_request_array_mutex.lock()
	input_viable_request_array[(frame_num + input_delay) % 256] = true
	input_viable_request_array_mutex.unlock()
	
	#remove current frame's arrival boolean for rollback condition hash comparison
	var current_frame_arrival = current_frame_arrival_array.pop_back()
	
	#if an input for a past frame has arrived (to fulfill a guess),
	if current_frame_arrival_array.hash() != prev_frame_arrival_array.hash():
		#iterate through all saved states until the state with the guessed input to be replaced by an arrived actual input is found (rollback will begin with that state)
		#then, continue iterating and operating through remaining saved states to continue the resimulation process
		var state_index = 0 #for tracking iterated element's index in state_queue
		for i in state_queue: #index 0 is oldest state
			#if an arrived input is for a past frame,
			if (prev_frame_arrival_array[state_index] == false && current_frame_arrival_array[state_index] == true):
				
				#set net input in the Frame_State from guess to actual input
				input_array_mutex.lock()
				i.net_input = input_array[i.frame].net_input.duplicate() 
				input_array_mutex.unlock()
				i.actual_input = true
				
				#if first rollback iteration, reset update variables for all children to match rollback start state
				if start_rollback == false:
					reset_state_all(i.game_state) 
					start_rollback = true
				
				pre_game_state = get_game_state()
				input_update_all(input_array[i.frame], pre_game_state) #simulate using new true input
				
			#else, continue simulating using currently stored (actual or guessed) inputs
			else:
				if start_rollback == true:
					pre_game_state = get_game_state() #save pre-update game_state value for Frame_State
					input_update_all(input_array[i.frame], pre_game_state) #update game_state using old (guessed or actual) input during rollback resimulation 			
			
			if start_rollback == true:
				i.game_state = pre_game_state #update Frame_States with updated game_state value.
				
			state_index += 1
	
	#reinsert current frame's arrival boolean (for next frame's prev_frame_arrival_array)
	current_frame_arrival_array.push_back(current_frame_arrival)
	#remove oldest frame's arrival boolean (unwanted for next frame's prev_frame_arrival_array)
	current_frame_arrival_array.pop_front() 
	
	current_input = Inputs.new()
	input_array_mutex.lock()
	
	#if the input for the current frame has not been received
	if input_arrival_array[frame_num] == false:
		#implement guess of last input used
		current_input.local_input = input_array[frame_num].local_input.duplicate()
		current_input.net_input = input_array[frame_num - 1].net_input.duplicate() #guessing with previous frame's input
		input_array[frame_num].net_input = input_array[frame_num - 1].net_input.duplicate()
		
		actual_input = false
	else: #else proceed with actual net input
		current_input.local_input = input_array[frame_num].local_input.duplicate()
		current_input.net_input = input_array[frame_num].net_input.duplicate()
	
	input_arrival_array[frame_num - (rollback + 120)] = false #reset input arrival boolean for old frame
	input_array_mutex.unlock()
	
	input_viable_request_array_mutex.lock()
	input_viable_request_array[frame_num - (rollback + 120)] = false #reset viable local input boolean
	input_viable_request_array_mutex.unlock()
	 
	if start_rollback == true:
		pre_game_state = get_game_state()
	
	input_update_all(current_input, pre_game_state) #update with current input
	execute_all() #implement all applied updates/inputs to all child objects
	
	#store current frame state into queue
	state_queue.append(Frame_State.new(current_input.local_input, current_input.net_input, frame_num, pre_game_state, actual_input))
	
	#remove oldest state
	state_queue.pop_front()
	
	prev_frame_arrival_array = current_frame_arrival_array #store current input arrival array for comaparisons in next frame
	frame_num = (frame_num + 1)%256 #increment frame_num


func frame_start_all():
	for child in get_children():
		child.frame_start()


func reset_state_all(game_state : Dictionary):
	for child in get_children():
		child.reset_state(game_state)


func input_update_all(input : Inputs, game_state : Dictionary):
	for child in get_children():
		child.input_update(input, game_state)


func execute_all():
	for child in get_children():
		child.execute()


func get_game_state():
	var state = {}
	for child in get_children():
		state[child.name] = child.get_state()
	return state.duplicate(true) #deep duplicate to copy all nested dictionaries by value instead of by reference
