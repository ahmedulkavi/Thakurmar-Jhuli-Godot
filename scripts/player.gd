class_name ForestPrince
extends CharacterBody2D
## Feet are the origin. Physics matches the original 1280 x 720 game.

@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var drag: float = 2400.0
@export var gravity: float = 1800.0
@export var jump_velocity: float = -720.0
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12
@export var rock_slide_speed: float = 180.0

@onready var animation: AnimatedSprite2D = $Animation
var coyote_left: float = 0.0
var buffer_left: float = 0.0
var landing_left: float = 0.0
var facing: float = 1.0
var slide_direction: float = 0.0

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor() and is_zero_approx(slide_direction)
	coyote_left = coyote_time if grounded else maxf(0.0, coyote_left - delta)
	buffer_left = maxf(0.0, buffer_left - delta)
	landing_left = maxf(0.0, landing_left - delta)
	if Input.is_action_just_pressed("jump"):
		buffer_left = jump_buffer
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, direction * speed, (acceleration if direction else drag) * delta)
	if not is_zero_approx(slide_direction):
		velocity.x = slide_direction * maxf(absf(velocity.x), rock_slide_speed)
	if absf(direction) > 0.01:
		facing = signf(direction)
		animation.flip_h = facing < 0.0
	velocity.y = minf(velocity.y + gravity * delta, 1000.0)
	if buffer_left > 0.0 and coyote_left > 0.0:
		velocity.y = jump_velocity
		buffer_left = 0.0
		coyote_left = 0.0
		landing_left = 0.0
	if Input.is_action_just_released("jump") and velocity.y < -260.0:
		velocity.y = -260.0
	move_and_slide()
	slide_direction = _rock_slide_direction()
	var landed := is_on_floor() and is_zero_approx(slide_direction)
	if not is_zero_approx(slide_direction):
		# A rectangular character can balance on a polygon's tip. Force a slide
		# off this obstacle, and never grant grounded jumps or landing animation.
		coyote_left = 0.0
		landing_left = 0.0
	if landed and not grounded:
		landing_left = 0.18
	var next_animation: StringName = &"idle"
	if not landed:
		next_animation = &"rise" if velocity.y < 0.0 else &"fall"
	elif landing_left > 0.0:
		next_animation = &"land"
	elif absf(velocity.x) > 15.0:
		next_animation = &"run"
	if animation.animation != next_animation:
		animation.play(next_animation)
	$Shadow.visible = landed

func _rock_slide_direction() -> float:
	for i in range(get_slide_collision_count()):
		var contact := get_slide_collision(i)
		var obstacle := contact.get_collider() as Node2D
		if obstacle and obstacle.is_in_group("slippery_obstacles") and contact.get_normal().y < -0.01 and position.y < obstacle.global_position.y - 1.0:
			var offset := global_position.x - obstacle.global_position.x
			return signf(offset) if absf(offset) > 1.0 else facing
	return 0.0

func reset_to(start: Vector2) -> void:
	position = start
	velocity = Vector2.ZERO
	coyote_left = 0.0
	buffer_left = 0.0
	landing_left = 0.0
	facing = 1.0
	slide_direction = 0.0
	animation.flip_h = false
	animation.play(&"idle")
