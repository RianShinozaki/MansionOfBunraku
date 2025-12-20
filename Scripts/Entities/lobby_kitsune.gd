class_name LobbyKitsune

extends AnimatableBody3D

@export var dialogue_data: DialogueData

var body_sprite: Sprite3D
var head_sprite: Sprite3D
var trigger_area: Area3D

var dialogue_triggered: bool = false
var is_visible_now: bool = false
var dialogue_completed: bool = false

func _ready() -> void:
	print("=== Lobby Kitsune _ready() START ===")
	
	# Find child nodes
	body_sprite = get_node_or_null("Body")
	if body_sprite:
		head_sprite = body_sprite.get_node_or_null("Head")
		print("Lobby Kitsune: Body and Head sprites found")
	else:
		print("ERROR: Body sprite not found!")
	
	# Find trigger area
	trigger_area = get_node_or_null("TriggerArea")
	if trigger_area:
		print("Lobby Kitsune: TriggerArea found, connecting signal...")
		trigger_area.body_entered.connect(_on_trigger_area_entered)
		print("Lobby Kitsune: Trigger area signal connected successfully")
		print("  - Monitoring: ", trigger_area.monitoring)
		print("  - Monitorable: ", trigger_area.monitorable)
		print("  - Collision Layer: ", trigger_area.collision_layer)
		print("  - Collision Mask: ", trigger_area.collision_mask)
	else:
		print("ERROR: Lobby Kitsune - TriggerArea node not found!")
		print("  Available children: ")
		for child in get_children():
			print("    - ", child.name, " (", child.get_class(), ")")
	
	# Start hidden
	visible = false
	print("Lobby Kitsune: Set to hidden")
	
	# Check if clock has already been activated
	if GameManager.instance:
		print("Lobby Kitsune: clock_activated_once = ", GameManager.instance.clock_activated_once)
		if GameManager.instance.clock_activated_once:
			_show_kitsune()
	else:
		print("ERROR: Lobby Kitsune - GameManager not found!")
	
	print("=== Lobby Kitsune _ready() END ===")

func _process(_delta: float) -> void:
	if not GameManager.instance:
		return
	
	# Only show when clock is activated AND in past timeline AND not completed dialogue
	var should_be_visible = (GameManager.instance.clock_activated_once and 
	                          GameManager.instance.is_past_time and 
	                          not dialogue_completed)
	
	# Show/hide based on timeline state
	if should_be_visible and not is_visible_now:
		_show_kitsune()
	elif not should_be_visible and is_visible_now:
		_hide_kitsune()
	
	# Reset dialogue trigger when switching back to past (allows repeated encounters)
	if GameManager.instance.is_past_time and not dialogue_completed:
		dialogue_triggered = false
	
	# Switch frames based on current inspection mode
	if visible:
		if InspectionManager.current_mode == InspectionManager.Mode.DIALOGUE:
			set_dialogue_mode()
		else:
			set_normal_mode()

func _show_kitsune() -> void:
	"""Make the kitsune visible once time travel clock has been activated"""
	visible = true
	is_visible_now = true
	print("Lobby Kitsune: Now visible after clock activation")
	print("  - TriggerArea status: ", "FOUND" if trigger_area else "NOT FOUND")
	if trigger_area:
		print("  - TriggerArea monitoring: ", trigger_area.monitoring)
		print("  - TriggerArea collision_mask: ", trigger_area.collision_mask)
		print("  - TriggerArea global position: ", trigger_area.global_position)

func _hide_kitsune() -> void:
	"""Hide the kitsune when switching to present timeline"""
	visible = false
	is_visible_now = false
	print("Lobby Kitsune: Hidden (switched to present timeline)")

func set_normal_mode() -> void:
	"""Display normal appearance (frames 0 and 1)"""
	if head_sprite:
		head_sprite.frame = 0
	if body_sprite:
		body_sprite.frame = 1

func set_dialogue_mode() -> void:
	"""Display dialogue appearance (frames 2 and 3)"""
	if head_sprite:
		head_sprite.frame = 2
	if body_sprite:
		body_sprite.frame = 3

func _on_trigger_area_entered(body: Node3D) -> void:
	"""Triggered when player walks through the area"""
	print("Lobby Kitsune: Trigger area entered by: ", body.name)
	print("  - is_visible_now: ", is_visible_now)
	print("  - dialogue_triggered: ", dialogue_triggered)
	print("  - is in Player group: ", body.is_in_group("Player"))
	
	# Only trigger if kitsune is visible and dialogue hasn't been triggered yet
	if not is_visible_now or dialogue_triggered:
		print("  - Skipping: kitsune not visible or dialogue already triggered")
		return
	
	# Check if it's the player
	if body.is_in_group("Player") or body.name == "Player":
		print("  - Player detected! Triggering dialogue")
		_trigger_warning_dialogue()
	else:
		print("  - Not the player, ignoring")

func _trigger_warning_dialogue() -> void:
	"""Start the warning dialogue"""
	if dialogue_triggered:
		return
	
	dialogue_triggered = true
	print("Lobby Kitsune: Triggering warning dialogue")
	
	if dialogue_data:
		var _dialogue_box: DialogueBox = DialogueBox.instance
		_dialogue_box.data = dialogue_data
		_dialogue_box.start("lobby_warning")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		InspectionManager.current_mode = InspectionManager.Mode.DIALOGUE
		
		await _dialogue_box.dialogue_ended
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		InspectionManager.current_mode = InspectionManager.Mode.PLAY
		
		if Player.instance:
			Player.instance.active = true
		
		print("Lobby Kitsune: Dialogue complete, marking as permanently completed")
		# Mark dialogue as permanently completed
		dialogue_completed = true
		# Disappear after dialogue
		queue_free()
