class_name ForestPrince
extends CharacterBody2D
## Feet are the origin. Physics matches the original 1280 x 720 game.

signal health_changed(current: int, maximum: int)
signal sword_equipped
signal died

const MAX_HEALTH: int = 100
const SWING_DURATION: float = 0.40
const ATTACK_COOLDOWN: float = 0.44
const SLASH_ACTIVE_START: float = 0.125
const THRUST_ACTIVE_START: float = 0.09
const ACTIVE_END: float = 0.24
const COMBAT_VISUAL = preload("res://scripts/prince_combat_visual.gd")

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
var health: int = MAX_HEALTH
var has_sword: bool = false
var invulnerable_left: float = 0.0
var knockback_left: float = 0.0
var swing_left: float = 0.0
var cooldown_left: float = 0.0
var swing_targets: Array[int] = []
var combat_visual: Node2D
var attack_kind: StringName = &"slash"
var next_attack_kind: StringName = &"slash"
var chain_left: float = 0.0
var attack_buffer_left: float = 0.0
var hitstop_left: float = 0.0

func _ready() -> void:
	combat_visual = Node2D.new()
	combat_visual.set_script(COMBAT_VISUAL)
	add_child(combat_visual)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	knockback_left = maxf(0.0, knockback_left - delta)
	var combat_delta := maxf(0.0, delta - hitstop_left)
	hitstop_left = maxf(0.0, hitstop_left - delta)
	cooldown_left = maxf(0.0, cooldown_left - combat_delta)
	swing_left = maxf(0.0, swing_left - combat_delta)
	chain_left = maxf(0.0, chain_left - combat_delta)
	attack_buffer_left = maxf(0.0, attack_buffer_left - delta)
	combat_visual.tick(delta, velocity.x)
	var grounded := is_on_floor() and is_zero_approx(slide_direction)
	coyote_left = coyote_time if grounded else maxf(0.0, coyote_left - delta)
	buffer_left = maxf(0.0, buffer_left - delta)
	landing_left = maxf(0.0, landing_left - delta)
	if Input.is_action_just_pressed("jump"):
		buffer_left = jump_buffer
	var direction := Input.get_axis("move_left", "move_right")
	if knockback_left <= 0.0:
		var movement_scale := 0.35 if swing_left > 0.0 and grounded else 1.0
		velocity.x = move_toward(velocity.x, direction * speed * movement_scale, (acceleration if direction else drag) * delta)
		if _is_striking() and grounded:
			velocity.x = facing * (100.0 if attack_kind == &"thrust" else 45.0) + direction * 60.0
		if hitstop_left > 0.0 and grounded:
			velocity.x = 0.0
	if not is_zero_approx(slide_direction):
		velocity.x = slide_direction * maxf(absf(velocity.x), rock_slide_speed)
	if absf(direction) > 0.01 and swing_left <= 0.0:
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
	if Input.is_action_just_pressed("attack"):
		if not attack() and has_sword and cooldown_left <= 0.14:
			attack_buffer_left = 0.18
	if attack_buffer_left > 0.0 and cooldown_left <= 0.0 and swing_left <= 0.0:
		attack()
	if _is_striking() and hitstop_left <= 0.0:
		_hit_sword_targets()
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
	_update_combat_visuals()
	$Shadow.visible = landed

func equip_sword() -> void:
	if has_sword or health <= 0:
		return
	has_sword = true
	_update_combat_visuals()
	sword_equipped.emit()

func attack() -> bool:
	if not has_sword or health <= 0 or cooldown_left > 0.0 or swing_left > 0.0 or get_tree().paused:
		return false
	attack_kind = next_attack_kind if chain_left > 0.0 else &"slash"
	next_attack_kind = &"thrust" if attack_kind == &"slash" else &"slash"
	chain_left = 0.9
	attack_buffer_left = 0.0
	swing_left = SWING_DURATION
	cooldown_left = ATTACK_COOLDOWN
	swing_targets.clear()
	return true

func _is_striking() -> bool:
	var elapsed := SWING_DURATION - swing_left
	var starts := THRUST_ACTIVE_START if attack_kind == &"thrust" else SLASH_ACTIVE_START
	return swing_left > 0.0 and elapsed >= starts and elapsed < ACTIVE_END

func _hit_sword_targets() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 54) if attack_kind == &"thrust" else Vector2(94, 102)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(facing * 66.0, -62.0))
	query.collision_mask = 4
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var target := hit.collider as Node2D
		if not target or not target.is_in_group("combat_targets") or target.get_instance_id() in swing_targets:
			continue
		var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -62), target.global_position + Vector2(0, -35), 1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		swing_targets.append(target.get_instance_id())
		target.take_damage(1, global_position)
		hitstop_left = 0.035
		combat_visual.add_impact(target.global_position + Vector2(0, -42))

func take_damage(amount: int, source: Vector2) -> bool:
	if health <= 0 or invulnerable_left > 0.0 or amount <= 0 or get_tree().paused:
		return false
	health = maxi(0, health - amount)
	invulnerable_left = 1.0
	knockback_left = 0.18
	# A hit breaks the action instead of leaving a rigid attack pose on recoil.
	swing_left = 0.0
	attack_buffer_left = 0.0
	hitstop_left = 0.0
	chain_left = 0.0
	var direction := signf(global_position.x - source.x)
	velocity = Vector2((direction if direction else -facing) * 260.0, -180.0)
	health_changed.emit(health, MAX_HEALTH)
	_update_combat_visuals()
	if health == 0:
		velocity = Vector2.ZERO
		swing_left = 0.0
		animation.modulate = Color("ad8275")
		combat_visual.art.modulate = Color("ad8275")
		animation.pause()
		died.emit()
	return true

func _update_combat_visuals() -> void:
	var tint := Color(1.0, 0.65, 0.5, 0.55) if invulnerable_left > 0.0 and fmod(invulnerable_left, 0.16) > 0.08 else Color.WHITE
	animation.modulate = tint
	var guarding := has_sword and is_on_floor() and absf(velocity.x) < 15.0 and landing_left <= 0.0 and knockback_left <= 0.0
	if has_sword:
		animation.hide()
		if swing_left > 0.0:
			combat_visual.show_pose(attack_kind, SWING_DURATION - swing_left, facing, tint, _is_striking() and hitstop_left <= 0.0)
		elif guarding:
			combat_visual.show_guard(attack_kind, facing, tint)
		else:
			combat_visual.show_locomotion(animation.animation, facing, tint, velocity.y, landing_left, knockback_left)
		return
	combat_visual.hide_pose()
	animation.show()

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
	health = MAX_HEALTH
	has_sword = false
	invulnerable_left = 0.0
	knockback_left = 0.0
	swing_left = 0.0
	cooldown_left = 0.0
	attack_kind = &"slash"
	next_attack_kind = &"slash"
	chain_left = 0.0
	attack_buffer_left = 0.0
	hitstop_left = 0.0
	combat_visual.reset_pose()
	swing_targets.clear()
	animation.modulate = Color.WHITE
	animation.show()
	animation.flip_h = false
	animation.play(&"idle")
	health_changed.emit(health, MAX_HEALTH)
