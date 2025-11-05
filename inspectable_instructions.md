# 1 - object must have child of root node called "FocusMarker" (Node3D) to indicate where the inspect camera should go
# 2 - parts that you can interact with in inspect mode should be on collision layer 6 (Inspectable details)
# 2 - objects that are interactable in inspect mode should have these parts in their script


## Script reqirements:


@export var inspect_fov: float = 40.0  #50 is the default, I used 40 for the lock because it's small. This is optional
@onready var focus_marker: Node3D = $FocusMarker

func _ready():
    # Add to Interactable group so the player can interact with it
    add_to_group("Interactable")

func can_interact() -> bool:
    # only allow interaction when in PLAY mode bc then you can set the interaction to go into inspect mode
    return InspectionManager.current_mode == InspectionManager.Mode.PLAY

func on_interact() -> void:
    if focus_marker and InspectionManager:
        InspectionManager.enter_inspect(self, focus_marker, inspect_fov) #can leave FOV out if you just want the default
        # Mark input as handled to prevent double-processing (it was counting the same click twice)
        get_viewport().set_input_as_handled()

func on_inspect_click() -> void:   
    # whatever you want to happen when clicked in inspect mode
    

