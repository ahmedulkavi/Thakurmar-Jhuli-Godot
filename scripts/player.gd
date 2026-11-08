class_name ForestPrince
extends CharacterBody2D
## Feet are the origin. Physics matches the original 1280 x 720 game.

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal magic_changed(current: float, maximum: float)
signal sword_equipped
signal amulet_equipped
signal healing_completed(amount: int)
signal died
signal stance_changed(stance: StringName)
signal sound_requested(cue: StringName)

const STEEL_DEFENSE := 75
const COUNTER_WINDOW := 0.28
const COUNTER_DAMAGE := 4
const MAX_HEALTH: int = 100
const MAX_STAMINA: float = 100.0
const MAX_MAGIC: float = 100.0
const ATTACK_STAMINA_COST: float = 15.0
const MAGIC_PER_HIT: float = 20.0
const HEAL_MAGIC_COST: float = 40.0
const HEAL_AMOUNT: int = 30
const HEAL_CHANNEL_TIME: float = 0.9
const STAMINA_REGEN_RATE: float = 35.0
const STAMINA_REGEN_DELAY: float = 0.50
const STAMINA_EXHAUSTION_DELAY: float = 0.65
const SWING_DURATION: float = 0.40
const ATTACK_COOLDOWN: float = 0.44
const SLASH_ACTIVE_START: float = 0.125
const THRUST_ACTIVE_START: float = 0.09
const ACTIVE_END: float = 0.24
const COMBAT_VISUAL = preload("res://scripts/prince_combat_visual.gd")
const CLIMB_VISUAL = preload("res://scripts/prince_climb_visual.gd")
const CLIMB_SPEED: float = 180.0
const STEEL_UNARMED_SHEET = preload("res://assets/prince-steel-unarmed.png")

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
var stance: StringName = &"royal"
var defense: int = 0
var counter_window_left := 0.0
var counter_attack := false
var stance_flash_left := 0.0
var god_mode: bool = false
var health: int = MAX_HEALTH
var stamina: float = MAX_STAMINA
var magic: float = 0.0
var stamina_regen_left: float = 0.0
var has_sword: bool = false
var has_amulet: bool = false
var is_healing: bool = false
var is_resting: bool = false
var rest_art: Sprite2D
var rest_elapsed := 0.0
var rest_base_scale := 1.0
var healing_elapsed: float = 0.0
var heal_flash_left: float = 0.0
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
var climb_ladder: ForestLadder
var is_climbing: bool = false
var climb_visual: Node2D
var royal_unarmed: SpriteFrames
var steel_unarmed: SpriteFrames

func _ready() -> void:
	combat_visual = Node2D.new()
	combat_visual.set_script(COMBAT_VISUAL)
	add_child(combat_visual)
	royal_unarmed = animation.sprite_frames
	steel_unarmed = royal_unarmed.duplicate(true)
	for animation_name in steel_unarmed.get_animation_names():
		for i in range(steel_unarmed.get_frame_count(animation_name)):
			var old_frame := steel_unarmed.get_frame_texture(animation_name, i) as AtlasTexture
			var index := int(old_frame.region.position.x / 160.0)
			var start := roundi(index * 2172.0 / 14.0)
			var end := roundi((index + 1) * 2172.0 / 14.0)
			var new_frame := AtlasTexture.new()
			new_frame.atlas = STEEL_UNARMED_SHEET
			new_frame.region = Rect2(start, 288, end - start, 160)
			new_frame.filter_clip = true
			steel_unarmed.set_frame(animation_name, i, new_frame, steel_unarmed.get_frame_duration(animation_name, i))
	climb_visual = Node2D.new()
	climb_visual.set_script(CLIMB_VISUAL)
	add_child(climb_visual)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if is_resting:
		velocity = Vector2.ZERO
		rest_elapsed += delta
		var breath := sin(rest_elapsed * 1.6)
		rest_art.scale = Vector2(rest_base_scale * (1.0 - 0.004 * breath), rest_base_scale * (1.0 + 0.016 * breath))
		rest_art.position.y = -68.0 - breath * 0.55
		rest_art.rotation = sin(rest_elapsed * 0.8) * 0.012
		return
	counter_window_left = maxf(0.0, counter_window_left - delta)
	stance_flash_left = maxf(0.0, stance_flash_left - delta)
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	knockback_left = maxf(0.0, knockback_left - delta)
	var combat_delta := maxf(0.0, delta - hitstop_left)
	hitstop_left = maxf(0.0, hitstop_left - delta)
	cooldown_left = maxf(0.0, cooldown_left - combat_delta)
	swing_left = maxf(0.0, swing_left - combat_delta)
	chain_left = maxf(0.0, chain_left - combat_delta)
	attack_buffer_left = maxf(0.0, attack_buffer_left - delta)
	_regenerate_stamina(delta)
	heal_flash_left = maxf(0.0, heal_flash_left - delta)
	queue_redraw()
	combat_visual.tick(delta, velocity.x * (0.6 if stance == &"steel" else 1.0))
	if _process_healing(delta):
		return
	if _process_climbing(delta):
		return
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
		if not attack() and stance == &"royal" and has_sword and cooldown_left <= 0.14 and stamina > 0.0:
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
		sound_requested.emit(_landing_sound())
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

func _landing_sound() -> StringName:
	# Use the floor contact rather than a wall the prince may touch at the same time.
	for i in range(get_slide_collision_count()):
		var contact := get_slide_collision(i)
		if contact.get_normal().dot(Vector2.UP) < 0.7:
			continue
		var surface := contact.get_collider() as Node
		if surface:
			if surface.is_in_group("landing_grass"):
				return &"land_grass"
			if surface.is_in_group("landing_wood"):
				return &"land_wood"
			if surface.is_in_group("landing_stone"):
				return &"land_stone"
	return &"land"

func equip_sword(show_unlock: bool = false) -> void:
	if has_sword or health <= 0:
		return
	has_sword = true
	_update_combat_visuals()
	if show_unlock:
		sword_equipped.emit()

func equip_amulet() -> void:
	if has_amulet or health <= 0:
		return
	has_amulet = true
	_set_magic(0.0, true)
	amulet_equipped.emit()

func set_stance(next: StringName, animate: bool = true) -> void:
	if next == stance or next not in [&"royal", &"steel"]:
		return
	stance = next
	var current_animation := animation.animation
	var current_frame := animation.frame
	var progress := animation.frame_progress
	animation.sprite_frames = steel_unarmed if stance == &"steel" else royal_unarmed
	animation.play(current_animation)
	animation.set_frame_and_progress(current_frame, progress)
	combat_visual.set_steel(stance == &"steel")
	climb_visual.frames = climb_visual.steel_frames if stance == &"steel" else climb_visual.royal_frames
	defense = STEEL_DEFENSE if stance == &"steel" else 0
	counter_window_left = 0.0
	counter_attack = false
	swing_left = 0.0
	attack_buffer_left = 0.0
	chain_left = 0.0
	stance_flash_left = 0.6 if animate else 0.0
	stance_changed.emit(stance)
	if animate:
		sound_requested.emit(&"stance")
	_update_combat_visuals()
	queue_redraw()

func attack() -> bool:
	if not has_sword or health <= 0 or get_tree().paused or is_climbing or is_healing or is_resting:
		return false
	if stance == &"steel":
		if cooldown_left > 0.0 or swing_left > 0.0 or stamina <= 0.0:
			return false
		counter_window_left = COUNTER_WINDOW
		cooldown_left = 0.4
		sound_requested.emit(&"stance")
		return true
	if stamina <= 0.0:
		# Repeated inputs cannot postpone recovery while the prince is exhausted.
		attack_buffer_left = 0.0
		return false
	if cooldown_left > 0.0 or swing_left > 0.0:
		return false
	var overdrawn := stamina < ATTACK_STAMINA_COST
	_set_stamina(stamina - ATTACK_STAMINA_COST)
	stamina_regen_left = STAMINA_EXHAUSTION_DELAY if overdrawn else STAMINA_REGEN_DELAY
	attack_kind = next_attack_kind if chain_left > 0.0 else &"slash"
	next_attack_kind = &"thrust" if attack_kind == &"slash" else &"slash"
	chain_left = 0.9
	attack_buffer_left = 0.0
	swing_left = SWING_DURATION
	cooldown_left = ATTACK_COOLDOWN
	swing_targets.clear()
	sound_requested.emit(&"swing")
	return true

func _set_stamina(value: float) -> void:
	var next := clampf(value, 0.0, MAX_STAMINA)
	if stamina != next:
		stamina = next
		stamina_changed.emit(stamina, MAX_STAMINA)

func _regenerate_stamina(delta: float) -> void:
	# Only the part of this physics step after the recovery delay can refill.
	var recovery_delta := maxf(0.0, delta - stamina_regen_left)
	stamina_regen_left = maxf(0.0, stamina_regen_left - delta)
	if recovery_delta > 0.0 and swing_left <= 0.0 and stamina < MAX_STAMINA:
		_set_stamina(stamina + STAMINA_REGEN_RATE * recovery_delta)

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
		var health_before: int = target.get("health")
		target.take_damage(health_before if god_mode else (COUNTER_DAMAGE if counter_attack else 1), global_position)
		if int(target.get("health")) < health_before:
			_add_magic(MAGIC_PER_HIT)
			sound_requested.emit(&"hit")
		hitstop_left = 0.035
		combat_visual.add_impact(target.global_position + Vector2(0, -42))

func take_damage(amount: int, source: Vector2, attacker: Node2D = null) -> bool:
	if health <= 0 or is_resting or invulnerable_left > 0.0 or amount <= 0 or get_tree().paused:
		return false
	if stance == &"steel" and counter_window_left > 0.0 and is_instance_valid(attacker) and attacker.is_in_group("combat_targets") and attacker.health > 0:
		counter_window_left = 0.0
		counter_attack = true
		facing = signf(attacker.global_position.x - global_position.x) if absf(attacker.global_position.x - global_position.x) > 1.0 else facing
		attack_kind = &"thrust"
		swing_left = SWING_DURATION
		cooldown_left = ATTACK_COOLDOWN
		swing_targets.clear()
		swing_targets.append(attacker.get_instance_id())
		attacker.take_damage(attacker.health if god_mode else COUNTER_DAMAGE, global_position)
		_add_magic(MAGIC_PER_HIT)
		combat_visual.add_impact(attacker.global_position + Vector2(0, -42))
		stance_flash_left = 0.35
		sound_requested.emit(&"counter")
		return true
	if god_mode:
		return false
	counter_window_left = 0.0
	var reduced_damage := maxi(1, ceili(amount * (100.0 - defense) / 100.0))
	health = maxi(0, health - reduced_damage)
	sound_requested.emit(&"hurt")
	_cancel_healing()
	_stop_climbing()
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
	if is_healing:
		tint = Color(0.68, 0.92, 1.0)
	animation.modulate = tint
	if is_healing:
		if has_sword:
			animation.hide()
			combat_visual.show_guard(attack_kind, facing, tint)
		else:
			combat_visual.hide_pose()
			animation.show()
			animation.play(&"idle")
		return
	var guarding := has_sword and is_on_floor() and absf(velocity.x) < 15.0 and landing_left <= 0.0 and knockback_left <= 0.0
	if has_sword:
		animation.hide()
		if swing_left > 0.0:
			combat_visual.show_pose(attack_kind, SWING_DURATION - swing_left, facing, tint, _is_striking() and hitstop_left <= 0.0)
		elif stance == &"steel" and is_on_floor() and knockback_left <= 0.0:
			combat_visual.show_steel_guard(facing, tint, velocity.x)
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
	stop_resting()
	_stop_climbing()
	set_stance(&"royal", false)
	position = start
	velocity = Vector2.ZERO
	coyote_left = 0.0
	buffer_left = 0.0
	landing_left = 0.0
	facing = 1.0
	slide_direction = 0.0
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	magic = 0.0
	stamina_regen_left = 0.0
	has_sword = false
	has_amulet = false
	is_healing = false
	healing_elapsed = 0.0
	heal_flash_left = 0.0
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
	stamina_changed.emit(stamina, MAX_STAMINA)
	magic_changed.emit(magic, MAX_MAGIC)
	queue_redraw()

func begin_resting(at: Vector2, texture: Texture2D) -> void:
	_cancel_healing()
	_stop_climbing()
	position = at
	velocity = Vector2.ZERO
	swing_left = 0.0
	attack_buffer_left = 0.0
	knockback_left = 0.0
	invulnerable_left = 0.0
	stamina = MAX_STAMINA
	stamina_regen_left = 0.0
	stamina_changed.emit(stamina, MAX_STAMINA)
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)
	is_resting = true
	animation.hide()
	combat_visual.hide_pose()
	$Shadow.hide()
	if rest_art == null:
		rest_art = Sprite2D.new()
		rest_art.name = "RestingArt"
		rest_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(rest_art)
	rest_art.texture = texture
	var bounds := texture.get_image().get_used_rect()
	rest_art.region_enabled = true
	rest_art.region_rect = bounds
	rest_base_scale = 96.0 / float(bounds.size.y)
	rest_elapsed = 0.0
	rest_art.scale = Vector2.ONE * rest_base_scale
	rest_art.rotation = 0.0
	# The pose's hips meet the fountain rim while the feet hang in front.
	rest_art.position = Vector2(0, -68)
	rest_art.show()

func stop_resting() -> void:
	if not is_resting:
		return
	is_resting = false
	if rest_art:
		rest_art.hide()
	if animation:
		animation.play(&"idle")
		_update_combat_visuals()

func recover_at_checkpoint(at: Vector2) -> void:
	var sword := has_sword
	var amulet := has_amulet
	var saved_magic := magic
	var saved_stance := stance
	reset_to(at)
	has_sword = sword
	has_amulet = amulet
	set_stance(saved_stance, false)
	_set_magic(saved_magic, true)
	_update_combat_visuals()

func _set_magic(value: float, force_emit: bool = false) -> void:
	var next := clampf(value, 0.0, MAX_MAGIC)
	if magic != next or force_emit:
		magic = next
		magic_changed.emit(magic, MAX_MAGIC)

func _add_magic(amount: float) -> void:
	if has_amulet and amount > 0.0:
		_set_magic(magic + amount)

func _process_healing(delta: float) -> bool:
	if is_healing:
		if not Input.is_action_pressed("heal") or not is_on_floor() or magic < HEAL_MAGIC_COST or health >= MAX_HEALTH:
			_cancel_healing()
			return false
		velocity = Vector2.ZERO
		healing_elapsed += delta
		_update_combat_visuals()
		if healing_elapsed >= HEAL_CHANNEL_TIME:
			_set_magic(magic - HEAL_MAGIC_COST)
			var before := health
			health = mini(MAX_HEALTH, health + HEAL_AMOUNT)
			health_changed.emit(health, MAX_HEALTH)
			healing_completed.emit(health - before)
			sound_requested.emit(&"heal")
			heal_flash_left = 0.55
			is_healing = false
			healing_elapsed = 0.0
			_update_combat_visuals()
		return true
	if Input.is_action_pressed("heal") and has_amulet and health < MAX_HEALTH and magic >= HEAL_MAGIC_COST and is_on_floor() and swing_left <= 0.0 and knockback_left <= 0.0 and not is_climbing:
		is_healing = true
		healing_elapsed = 0.0
		velocity = Vector2.ZERO
		_update_combat_visuals()
		return true
	return false

func _cancel_healing() -> void:
	if not is_healing:
		return
	is_healing = false
	healing_elapsed = 0.0
	_update_combat_visuals()
	queue_redraw()

func _draw() -> void:
	if stance_flash_left > 0.0:
		var light := Color(0.72, 0.87, 1.0) if stance == &"steel" else Color(1.0, 0.77, 0.28)
		var progress := 1.0 - stance_flash_left / 0.6
		light.a = clampf(stance_flash_left / 0.6, 0.0, 1.0) * 0.85
		draw_arc(Vector2(0, -65), 25.0 + 50.0 * progress, 0, TAU, 40, light, 4.0, true)
		for i in range(8):
			var ray := Vector2.from_angle(i * TAU / 8.0 + progress)
			draw_line(Vector2(0, -65) + ray * 25.0, Vector2(0, -65) + ray * (40.0 + 45.0 * progress), light, 2.0, true)
	if not is_healing and heal_flash_left <= 0.0:
		return
	var center := Vector2(0, -62)
	var progress := healing_elapsed / HEAL_CHANNEL_TIME if is_healing else 1.0
	var alpha := 0.85 if is_healing else heal_flash_left / 0.55
	draw_arc(center, 34.0 + progress * 9.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(0.35, 0.85, 1.0, alpha), 4.0, true)
	draw_arc(center, 48.0 + progress * 5.0, PI * 0.5, PI * 0.5 - TAU * progress, 40, Color(0.68, 0.96, 1.0, alpha * 0.55), 2.0, true)
	for i in range(6):
		var angle := float(i) * TAU / 6.0 + progress * 2.0
		var mote := center + Vector2(cos(angle), sin(angle)) * (28.0 + float(i % 2) * 17.0)
		draw_circle(mote, 2.5 + progress * 1.5, Color(0.63, 0.94, 1.0, alpha))

func _process_climbing(delta: float) -> bool:
	if climb_ladder == null or not climb_ladder.ready_for_climb():
		if is_climbing:
			_stop_climbing()
		return false
	var vertical := Input.get_axis("move_up", "move_down")
	if is_climbing:
		if Input.is_action_just_pressed("jump"):
			_stop_climbing()
			velocity.y = jump_velocity
			buffer_left = 0.0
			return false
	elif absf(vertical) > 0.1 and absf(global_position.x - climb_ladder.global_position.x) < 32.0 and position.y >= ForestLadder.TOP_Y - 4.0 and position.y <= ForestLadder.BOTTOM_Y + 4.0 and ((vertical < 0.0 and position.y > ForestLadder.TOP_Y + 4.0) or (vertical > 0.0 and position.y < ForestLadder.BOTTOM_Y - 4.0)):
		is_climbing = true
		collision_mask = 1
		velocity = Vector2.ZERO
		swing_left = 0.0
		attack_buffer_left = 0.0
	else:
		return false
	position.x = move_toward(position.x, climb_ladder.position.x, 600.0 * delta)
	position.y = clampf(position.y + vertical * CLIMB_SPEED * delta, ForestLadder.TOP_Y, ForestLadder.BOTTOM_Y)
	velocity = Vector2.ZERO
	coyote_left = 0.0
	buffer_left = 0.0
	if (vertical < -0.1 and position.y <= ForestLadder.TOP_Y) or (vertical > 0.1 and position.y >= ForestLadder.BOTTOM_Y):
		# Start just above the one-way platform so normal physics can land on it.
		position.y -= 1.0
		_stop_climbing()
		animation.play(&"idle")
		_update_combat_visuals()
		return true
	animation.hide()
	combat_visual.hide_pose()
	climb_visual.show_climb(vertical, delta)
	$Shadow.hide()
	return true

func _stop_climbing() -> void:
	is_climbing = false
	collision_mask = 9
	if climb_visual:
		climb_visual.hide()
