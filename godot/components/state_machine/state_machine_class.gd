extends Node
class_name StateMachine


#------------------------#
@export var initialState : State

var currentState : State
#------------------------#

func _ready() -> void:
	initialize_states()

func initialize_states() -> void:
	for c in get_children():
		c.stateMachine = self
	change_state(initialState)

func change_state(newState : State) -> void:
	if currentState:
		currentState.exit()
	currentState = newState
	currentState.enter()

func _process(delta: float) -> void:
	if currentState:
		currentState.update_process(delta)

func _physics_process(delta: float) -> void:
	if currentState:
		currentState.update_physics(delta)

func _input(event: InputEvent) -> void:
	if currentState:
		currentState.update_input(event)
