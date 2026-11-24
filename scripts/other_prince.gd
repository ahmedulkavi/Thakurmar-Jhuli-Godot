extends CharacterBody2D

signal started
signal ended
signal defeated
signal encounter_reset
signal health_changed(current: int, maximum: int)
signal stance_changed(title: String)

const MAX_HEALTH := 30
const ENTRY_X := 17500.0
const SWEEP_TIME := 0.64
const URUMI_WINDUP := 0.72
const URUMI_RECOVERY := 1.1
const COUNTER_CHANCE := 0.70
const REACTIVE_GUARD_TIME := 0.48
const COUNTER_REACH := 180.0
var counter_rng := RandomNumberGenerator.new()
var player: ForestPrince
var health := MAX_HEALTH
var active := false
var state: StringName = &"approach"
var left := 0.0
var facing := -1.0
var beat := 0
var hit := false
var home: Vector2
var visual := preload("res://scripts/prince_combat_visual.gd").new()
var palette := ShaderMaterial.new()
var urumi := preload("res://scripts/urumi_visual.gd").new()
var stance_index := 0
var stance_aura := preload("res://scripts/other_prince_aura.gd").new()

func _ready() -> void:
	name = "TheOtherPrince"
	home = position
	collision_mask = 1
	z_index = 3
	add_to_group("combat_targets")
	player.sword_attack_started.connect(_on_player_sword_attack)
	var box := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 23
	shape.height = 115
	box.shape = shape
	box.position.y = -57
	add_child(box)
	add_child(visual)
	_configure_stance_art()
	add_child(stance_aura)
	palette.shader = preload("res://shaders/other_prince.gdshader")
	visual.art.material = palette
	add_child(urumi)
	reset_boss()

func reset_boss() -> void:
	if active:
		ended.emit()
	active = false
	health = MAX_HEALTH
	collision_layer = 0
	position = home
	velocity = Vector2.ZERO
	facing = -1
	beat = 0
	left = 0
	hit = false
	state = &"approach"
	stance_index = 0
	stance_aura.clear()
	visual.set_steel(false)
	visual.show_guard(&"slash", facing, Color.WHITE)
	urumi.reset_pose()
	show()
	queue_redraw()
	encounter_reset.emit()

func _physics_process(delta: float) -> void:
	if health <= 0 or player.health <= 0:
		return
	if not active:
		if player.position.x < ENTRY_X or player.in_water or player.is_resting:
			return
		begin()
	left = maxf(0, left - delta)
	visual.tick(delta, velocity.x)
	urumi.tick(delta)
	var dx := player.position.x - position.x
	velocity.x = 0
	match state:
		&"approach":
			facing = -1 if dx < 0 else 1
			var reach := 380.0 if beat == 3 else 95.0
			if is_on_floor() and player.position.y < position.y - 90:
				velocity.y = player.jump_velocity
			if absf(dx) > reach or absf(player.position.y - position.y) > 90:
				velocity.x = facing * minf(player.speed, absf(dx) * 5)
				var motion := &"run" if is_on_floor() else (&"rise" if velocity.y < 0 else &"fall")
				visual.show_locomotion(motion, facing, Color.WHITE, velocity.y, 0, 0)
			else:
				_begin_beat()
		&"prepare":
			if left <= 0:
				state = &"swing"
				left = ForestPrince.SWING_DURATION
		&"swing", &"riposte":
			var kind := &"slash" if beat == 0 and state != &"riposte" else &"thrust"
			var elapsed := ForestPrince.SWING_DURATION - left
			var start := ForestPrince.SLASH_ACTIVE_START if kind == &"slash" else ForestPrince.THRUST_ACTIVE_START
			var striking := elapsed >= start and elapsed < ForestPrince.ACTIVE_END
			visual.show_pose(kind, elapsed, facing, Color.WHITE, striking)
			if striking:
				velocity.x = facing * (100 if kind == &"thrust" else 45)
				if not hit and dx * facing >= -15 and dx * facing <= 120 and absf(player.position.y - position.y) < (105 if kind == &"slash" else 82):
					hit = true
					player.take_damage(22 if state == &"riposte" else 14, position, self)
			if left <= 0:
				_recover(0.12 if beat == 0 else 0.68)
		&"guard":
			if left <= 0:
				_recover(0.7)
		&"summon":
			urumi.show_phase(&"windup", 1.0 - left / URUMI_WINDUP, facing)
			if left <= 0:
				state = &"whip"
				left = SWEEP_TIME
				urumi.show_phase(&"sweep", 0.0, facing)
		&"whip":
			urumi.show_phase(&"sweep", 1.0 - left / SWEEP_TIME, facing)
			for blade in range(2):
				var points := _ribbon(blade)
				var target := to_local(player.global_position) + Vector2(0, -61)
				for i in range(1, points.size()):
					if urumi.is_striking() and not hit and Geometry2D.get_closest_point_to_segment(target, points[i-1], points[i]).distance_to(target) < 35:
						hit = true
						player.take_damage(20, position, self)
			if left <= 0:
				_recover(URUMI_RECOVERY)
		&"recover":
			if urumi.visible:
				urumi.show_phase(&"recover", 1.0 - left / URUMI_RECOVERY, facing)
			if left <= 0:
				beat = (beat + 1) % 4
				state = &"approach"
				_set_stance(beat)
	velocity.y = minf(1000, velocity.y + 1800 * delta)
	move_and_slide()
	queue_redraw()

func begin() -> void:
	if active or health <= 0 or player.health <= 0:
		return
	active = true
	collision_layer = 4
	started.emit()
	stance_changed.emit("Royal stance")

func _set_stance(index: int) -> void:
	var next_stance := 0 if index < 2 else index
	if next_stance != stance_index:
		stance_aura.burst()
	stance_index = next_stance
	visual.set_steel(index == 2)
	urumi.reset_pose()
	visual.show_guard(&"slash", facing, Color.WHITE)
	stance_changed.emit(["Royal stance", "Royal stance", "Copper steel stance", "Twin urumi"][index])

func _configure_stance_art() -> void:
	# Boss-only sheets retain the player's frame registration and natural skin.
	visual.royal_frames = visual._atlas_frames(load("res://assets/other-prince-royal-combat.png"))
	visual.royal_locomotion_frames = visual._atlas_frames(load("res://assets/other-prince-royal-locomotion.png"))
	visual.royal_run_frames = visual._atlas_frames(load("res://assets/other-prince-royal-run.png"), 2)
	visual.steel_frames = visual._atlas_frames(load("res://assets/other-prince-steel-combat.png"))
	visual.steel_locomotion_frames = visual._atlas_frames(load("res://assets/other-prince-steel-locomotion.png"))
	visual.steel_walk_frames = visual._atlas_frames(load("res://assets/other-prince-steel-run.png"), 2)
	visual.frames = visual.royal_frames
	visual.locomotion_frames = visual.royal_locomotion_frames
	visual.run_frames = visual.royal_run_frames

func _begin_beat() -> void:
	hit = false
	match beat:
		0, 1:
			state = &"prepare"
			left = 0.36 if beat == 0 else 0.12
			visual.show_pose(&"slash" if beat == 0 else &"thrust", 0.06, facing, Color.WHITE, false)
		2:
			state = &"guard"
			left = 0.9
			visual.show_steel_guard(facing, Color.WHITE, 0)
		3:
			state = &"summon"
			left = URUMI_WINDUP
			visual.hide()
			urumi.reset_pose()
			urumi.show_phase(&"windup", 0.0, facing)

func _recover(duration: float) -> void:
	state = &"recover"
	left = duration
	if urumi.visible:
		urumi.show_phase(&"recover", 0.0, facing)

func _on_player_sword_attack() -> void:
	var offset := global_position - player.global_position
	if absf(offset.x) > COUNTER_REACH or absf(offset.y) > 110.0 or offset.x * player.facing < 0:
		return
	_try_reactive_guard(player.global_position)

func _try_reactive_guard(source: Vector2) -> bool:
	if not active or health <= 0 or player.health <= 0 or get_tree().paused:
		return false
	# A committed counter or urumi sweep still gives the player an opening.
	if state in [&"riposte", &"whip"]:
		return false
	if state == &"guard":
		return (source.x - global_position.x) * facing >= 0
	# Called once per sword swing or arrow impact, never rerolled each frame.
	if counter_rng.randf() >= COUNTER_CHANCE:
		return false
	facing = -1.0 if source.x < global_position.x else 1.0
	_set_stance(2)
	state = &"guard"
	left = REACTIVE_GUARD_TIME
	velocity.x = 0.0
	hit = false
	visual.show_steel_guard(facing, Color.WHITE, 0.0)
	queue_redraw()
	return true

func try_reflect_arrow(source: Vector2) -> bool:
	if not _try_reactive_guard(source):
		return false
	player.sound_requested.emit(&"counter")
	visual.add_impact(global_position + Vector2(facing * 28.0, -75.0))
	return true

func take_damage(amount: int, source: Vector2) -> void:
	if not active or health <= 0 or amount <= 0:
		return
	if state == &"guard" and (source.x - position.x) * facing >= 0:
		state = &"riposte"
		left = ForestPrince.SWING_DURATION
		hit = false
		player.sound_requested.emit(&"counter")
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		stance_aura.clear()
		urumi.reset_pose()
		active = false
		collision_layer = 0
		hide()
		ended.emit()
		defeated.emit()

func can_counter_from(at: Vector2) -> bool:
	return position.distance_to(at) < 145

func stun_from_block() -> void:
	_recover(0.9)

func _ribbon(blade: int) -> PackedVector2Array:
	return urumi.ribbon(blade)

func _draw() -> void:
	if state == &"guard":
		draw_arc(Vector2(facing * 12, -68), 53, -PI/2 if facing > 0 else PI/2, PI/2 if facing > 0 else 1.5*PI, 26, Color("#e9a879"), 3, true)
