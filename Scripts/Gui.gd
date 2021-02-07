class_name Gui
extends Node

onready var lblStatus: Label = $Status

# Track changes, otherwise do nothing (Saves performance on modifying values)
onready var curStatus: int = Session.StatusType.MENU

func _physics_process(delta: float) -> void:
	# Check if anything has changed
	if curStatus == Session.Status: return
	
	# Set status message once
	curStatus = Session.Status
	match curStatus:
		Session.StatusType.WAITING: lblStatus.text = "WAITING FOR CONNECTION TO PEER"
		Session.StatusType.PLAYING: lblStatus.text = "CONNECTED TO PEER"
		Session.StatusType.END: lblStatus.text = "THE GAME HAS ENDED. DISCONNECTED FROM PEER"
		Session.StatusType.MENU: pass

func _on_play_pressed() -> void:
	var address: String = $Menu/Align/Grid/txtAddress.text
	var frameDelay: int = int($Menu/Align/Grid/txtFrameDelay.text)
	var rollbackFrames: int = int($Menu/Align/Grid/txtRollback.text)
	var duplicateRange: int = int($Menu/Align/Grid/txtDupRange.text)
	
	Session.Address = address
	Session.InputDelay = frameDelay
	Session.Rollback = rollbackFrames
	Session.DupSendRange = duplicateRange
	Session.ready()
	
	# Set state to a valid game state
	Session.Status = Session.StatusType.WAITING
	
	$Menu.visible = false
