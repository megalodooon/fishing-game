extends State
class_name PlayerMoveState


#------------------------#
@onready var player : Player = owner

var facing : float = 1.0
var flipSpeed : float = 0.2
#------------------------#


func update_physics(_delta : float) -> void:
	var direction : Vector2 = Input.get_vector("left","right","up","down")
	if direction != Vector2.ZERO:
		player.velocity = player.velocity.move_toward(direction * player.speed, player.acceleration)
	else:
		player.velocity = player.velocity.move_toward(Vector2.ZERO, player.deceleration)
	update_animation(direction)
	handle_flip(direction.x)
	player.move_and_slide()


func handle_flip(directionX : float) -> void:
	if directionX:
		facing = signf(directionX)
	player.sprite.scale.x = move_toward(player.sprite.scale.x, facing, flipSpeed)

func update_animation(direction : Vector2):
	if direction != Vector2.ZERO:
		if player.animationPlayer.current_animation != "walk":
			player.animationPlayer.play("walk")
	else:
		if player.animationPlayer.current_animation != "idle":
			player.animationPlayer.play("idle")
