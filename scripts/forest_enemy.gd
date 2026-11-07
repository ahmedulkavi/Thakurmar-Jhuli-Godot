extends CharacterBody2D
## Terrain-aware pursuit with committed, readable jumps and melee attacks.

const MAX_HEALTH: int = 4
const ATTACK_DAMAGE: int = 25
const ATTACK_WINDUP: float = 0.24
const ATTACK_ACTIVE_TIME: float = 0.14
const ATTACK_RECOVERY: float = 0.60
const ATTACK_LUNGE_SPEED: float = 280.0
const SIZE_MULTIPLIER: float = 1.75
const CONTACT_REACH: float = 22.0 + 42.0 * SIZE_MULTIPLIER * 0.5
const BODY_SIZE := Vector2(42, 58) * SIZE_MULTIPLIER
const GRAVITY: float = 1800.0
const CHASE_SPEED: float = 130.0
const RETURN_SPEED: float = 85.0
const JUMP_SPEED: float = 300.0
const JUMP_VELOCITY: float = -780.0
const AGGRO_RANGE: float = 360.0
const LOSE_RANGE: float = 720.0
const MEMORY_DURATION: float = 4.0
const DEATH_DURATION: float = 0.4
const VISUAL = preload("res://scripts/forest_enemy_visual.gd")
var player: ForestPrince
var home := Vector2.ZERO
var health: int = MAX_HEALTH
var clock: float = 0.0
var hurt_left: float = 0.0
var attack_left: float = 0.0
var attack_direction: float = 1.0
var recovery_left: float = 0.0
var knockback_left: float = 0.0
var glow: Sprite2D
var art: Sprite2D
var visual: Node2D
var state: StringName = &"idle"
var state_elapsed: float = 0.0
var facing: float = -1.0
var aggroed: bool = false
var memory_left: float = 0.0
var jump_windup_left: float = 0.0
var jump_cooldown_left: float = 0.0
var jump_direction: float = 1.0
var jumping: bool = false
var landing_left: float = 0.0
var death_left: float = 0.0
var attack_has_hit: bool = false
var jumps_performed: int = 0

func _ready() -> void:
	home = position
	collision_layer = 4
	collision_mask = 1
	z_index = 2
	floor_snap_length = 6.0
	add_to_group("combat_targets")
	var shape := CollisionShape2D.new()
	var bounds := RectangleShape2D.new()
	bounds.size = BODY_SIZE
	shape.position.y = -bounds.size.y * 0.5
	shape.shape = bounds
	add_child(shape)
	glow = Sprite2D.new()
	glow.texture = preload("res://scenes/soft_glow.tres")
	glow.position.y = -38 * SIZE_MULTIPLIER
	glow.scale = Vector2(0.95, 0.9) * SIZE_MULTIPLIER
	glow.modulate = Color(0.44, 0.8, 0.67, 0.3)
	add_child(glow)
	visual = Node2D.new()
	visual.set_script(VISUAL)
	visual.height = 78.0 * SIZE_MULTIPLIER
	visual.windup_duration = ATTACK_WINDUP
	visual.lunge_duration = ATTACK_ACTIVE_TIME
	add_child(visual)
	art = visual.art
	visual.reset_visual()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	clock += delta
	state_elapsed += delta
	hurt_left = maxf(0.0, hurt_left - delta)
	recovery_left = maxf(0.0, recovery_left - delta)
	knockback_left = maxf(0.0, knockback_left - delta)
	jump_cooldown_left = maxf(0.0, jump_cooldown_left - delta)
	landing_left = maxf(0.0, landing_left - delta)
	_update_awareness(delta)
	var grounded := is_on_floor()
	velocity.y = minf(velocity.y + GRAVITY * delta, 1000.0)
	if knockback_left > 0.0:
		_set_state(&"hurt")
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	elif jump_windup_left > 0.0:
		_set_state(&"jump_windup")
		jump_windup_left = maxf(0.0, jump_windup_left - delta)
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
		if jump_windup_left <= 0.0 and grounded:
			velocity = Vector2(jump_direction * JUMP_SPEED, JUMP_VELOCITY)
			jumping = true
			jump_cooldown_left = 0.75
			jumps_performed += 1
			_set_state(&"airborne")
	elif attack_left > 0.0:
		attack_left = maxf(0.0, attack_left - delta)
		_set_state(&"lunge" if attack_left < ATTACK_ACTIVE_TIME else &"windup")
		velocity.x = attack_direction * ATTACK_LUNGE_SPEED if state == &"lunge" else 0.0
		if attack_left <= 0.0:
			recovery_left = ATTACK_RECOVERY
			_set_state(&"recover")
	elif not grounded:
		_set_state(&"airborne")
		var intent := jump_direction if jumping else _navigation_direction()
		var air_speed := JUMP_SPEED if jumping else CHASE_SPEED
		velocity.x = move_toward(velocity.x, intent * air_speed, 650.0 * delta)
	elif landing_left > 0.0:
		_set_state(&"land")
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	elif recovery_left > 0.0:
		_set_state(&"recover")
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
	else:
		_navigate(delta)
	var fall_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not grounded:
		if jumping or fall_speed > 220.0:
			landing_left = 0.12
			_set_state(&"land")
		jumping = false
	var offset := player.global_position - global_position
	if state == &"lunge" and not attack_has_hit and offset.x * attack_direction > -10.0 and absf(offset.x) < CONTACT_REACH and offset.y > -BODY_SIZE.y and offset.y < 122.0 and _has_attack_line():
		attack_has_hit = player.take_damage(ATTACK_DAMAGE, global_position)
	queue_redraw()

func _set_state(next: StringName) -> void:
	if state != next:
		state = next
		state_elapsed = 0.0

func _update_awareness(delta: float) -> void:
	if player.health <= 0:
		aggroed = false
		memory_left = 0.0
		return
	var offset := player.global_position - global_position
	var notice_range := LOSE_RANGE if aggroed else AGGRO_RANGE
	if absf(offset.x) < notice_range and absf(offset.y) < 220.0 and _has_sight():
		aggroed = true
		memory_left = MEMORY_DURATION
	elif aggroed:
		memory_left = maxf(0.0, memory_left - delta)
		if memory_left <= 0.0 or absf(offset.x) > LOSE_RANGE:
			aggroed = false

func _has_sight() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -BODY_SIZE.y * 0.9), player.global_position + Vector2(0, -70), 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _has_attack_line() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -BODY_SIZE.y * 0.6), player.global_position + Vector2(0, -60), 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _navigation_direction() -> float:
	var target_x := player.global_position.x if aggroed else home.x
	var distance := target_x - global_position.x
	return signf(distance) if absf(distance) > (4.0 if aggroed else 1.0) else 0.0

func _navigate(delta: float) -> void:
	var direction := _navigation_direction()
	var offset := player.global_position - global_position
	if not is_zero_approx(direction):
		facing = direction
	if aggroed and absf(offset.x) < 90.0 and absf(offset.y) < 85.0 and _has_attack_line():
		attack_direction = signf(offset.x) if absf(offset.x) > 1.0 else facing
		facing = attack_direction
		attack_has_hit = false
		attack_left = ATTACK_WINDUP + ATTACK_ACTIVE_TIME
		velocity.x = 0.0
		_set_state(&"windup")
	elif not is_zero_approx(direction) and jump_cooldown_left <= 0.0 and _needs_jump(direction):
		jump_direction = direction
		jump_windup_left = 0.12
		velocity.x = 0.0
		_set_state(&"jump_windup")
	elif aggroed or absf(global_position.x - home.x) > 1.0:
		_set_state(&"chase" if aggroed else &"return")
		var target_speed := CHASE_SPEED if aggroed else minf(RETURN_SPEED, absf(global_position.x - home.x) * 8.0)
		velocity.x = move_toward(velocity.x, direction * target_speed, 850.0 * delta)
	else:
		velocity.x = 0.0
		_set_state(&"idle")

func _needs_jump(direction: float) -> bool:
	var ahead := direction * (BODY_SIZE.x * 0.5 + 48.0)
	var low := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -12), global_position + Vector2(ahead, -12), 1)
	var obstruction := get_world_2d().direct_space_state.intersect_ray(low)
	if obstruction.is_empty():
		return false
	# A tall wall or low ceiling is not a viable jump. Physics still resolves
	# the actual arc, including landing on or dropping off a raised platform.
	var high := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -170), global_position + Vector2(ahead, -170), 1)
	if not get_world_2d().direct_space_state.intersect_ray(high).is_empty():
		return false
	return not test_move(global_transform, Vector2(0, -170))

func _process(delta: float) -> void:
	if health <= 0:
		death_left = maxf(0.0, death_left - delta)
		if death_left <= 0.0:
			hide()
			return
	var pose := state
	if state == &"airborne":
		pose = &"rise" if velocity.y < 0.0 else &"fall"
	var tint := Color(1.55, 1.7, 1.45) if hurt_left > 0.0 else Color(1.25, 0.8, 0.6) if state == &"windup" else Color.WHITE
	if health <= 0:
		tint = Color(0.7, 1.0, 0.85, death_left / DEATH_DURATION)
	visual.animate_pose(pose, state_elapsed, facing, tint, velocity.x, delta)
	glow.modulate = Color(1.0, 0.42, 0.22, 0.5) if state == &"windup" else Color(0.44, 0.8, 0.67, 0.3 if aggroed else 0.18)
	if health <= 0:
		glow.modulate.a *= death_left / DEATH_DURATION
	queue_redraw()

func take_damage(amount: int, source: Vector2) -> void:
	if health <= 0 or amount <= 0 or get_tree().paused:
		return
	health = maxi(0, health - amount)
	hurt_left = 0.18
	attack_left = 0.0
	attack_has_hit = false
	jump_windup_left = 0.0
	jumping = false
	aggroed = true
	memory_left = MEMORY_DURATION
	recovery_left = 0.45
	knockback_left = 0.22
	var direction := signf(global_position.x - source.x)
	velocity = Vector2((direction if direction else 1.0) * 240.0, -120.0)
	_set_state(&"hurt")
	if health == 0:
		velocity = Vector2.ZERO
		aggroed = false
		death_left = DEATH_DURATION
		_set_state(&"dead")
		set_deferred("collision_layer", 0)
	queue_redraw()

func reset_enemy() -> void:
	position = home
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	hurt_left = 0.0
	attack_left = 0.0
	recovery_left = 0.0
	knockback_left = 0.0
	state = &"idle"
	state_elapsed = 0.0
	facing = -1.0
	aggroed = false
	memory_left = 0.0
	jump_windup_left = 0.0
	jump_cooldown_left = 0.0
	jumping = false
	jump_direction = 1.0
	landing_left = 0.0
	death_left = 0.0
	attack_has_hit = false
	jumps_performed = 0
	clock = 0.0
	collision_layer = 4
	visual.reset_visual()
	glow.modulate = Color(0.44, 0.8, 0.67, 0.3)
	show()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * SIZE_MULTIPLIER)
	if state == &"windup":
		draw_arc(Vector2(0, -40), 43, -PI * 0.8, PI * 0.3, 24, Color(1.0, 0.65, 0.3, 0.8), 2.0, true)
	if health > 0 and health < MAX_HEALTH:
		draw_rect(Rect2(-24, -92, 48, 5), Color("142522"))
		draw_rect(Rect2(-24, -92, 48.0 * health / MAX_HEALTH, 5), Color("c94b4b"))
