extends State
class_name PlayerMoveState


#------------------------#
@onready var player : Player = owner

var facing : float = 1.0
var flipSpeed : float = 0.2
#------------------------#


func update_physics(_delta : float) -> void:
	var typing : bool = player.get_viewport().gui_get_focus_owner() is LineEdit
	var direction : Vector2 = Vector2.ZERO if player.rooted or player.asleep or player.charting or player.frozen or typing else Input.get_vector("left","right","up","down")
	if direction != Vector2.ZERO:
		player.velocity = player.velocity.move_toward(direction * player.speed * player.boost(&"walkSpeed"), player.acceleration)
	else:
		player.velocity = player.velocity.move_toward(Vector2.ZERO, player.deceleration)
	update_animation(direction)
	handle_flip(direction.x)
	var before : Vector2 = player.global_position
	player.move_and_slide()
	keep_on_ground(before)

# On islands the edge of the land is a wall too: a step that would leave it
# slides along it instead, or doesn't happen.
func keep_on_ground(before : Vector2) -> void:
	var after : Vector2 = player.global_position
	if after == before or player.can_stand(after) or not player.can_stand(before):
		return
	var sideways : Vector2 = Vector2(after.x, before.y)
	var upDown : Vector2 = Vector2(before.x, after.y)
	if player.can_stand(sideways):
		player.global_position = sideways
		player.velocity.y = 0.0
	elif player.can_stand(upDown):
		player.global_position = upDown
		player.velocity.x = 0.0
	else:
		player.global_position = before
		player.velocity = Vector2.ZERO

func handle_flip(directionX : float) -> void:
	if player.rooted:
		facing = player.facing
	elif directionX:
		facing = signf(directionX)
	player.sprite.scale.x = move_toward(player.sprite.scale.x, facing, flipSpeed)

func update_animation(direction : Vector2):
	if direction != Vector2.ZERO:
		if player.animationPlayer.current_animation != "walk":
			player.animationPlayer.play("walk")
	else:
		if player.animationPlayer.current_animation != "idle":
			player.animationPlayer.play("idle")
