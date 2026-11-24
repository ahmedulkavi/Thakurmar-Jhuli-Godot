extends CharacterBody2D
## Eels telegraph and dash; coral sentinels hold ground and cast water bolts.

signal defeated(at: Vector2, value: int)

const EEL = preload("res://assets/gloom-eel.png")
const SENTINEL = preload("res://assets/coral-sentinel.png")
const WATER_BOLT = preload("res://scripts/water_bolt.gd")
const MOTION_SHADER = preload("res://shaders/water_enemy_motion.gdshader")

var kind: StringName = &"eel"
var player: ForestPrince
var home := Vector2.ZERO
var health := 3
var state: StringName = &"patrol"
var clock := 0.0
var state_left := 0.0
var attack_cooldown := 0.0
var contact_cooldown := 0.0
var volley_count := 0
var hold_tick := 0.0
var hurt_left := 0.0
var dash_direction := Vector2.LEFT
var art: Sprite2D
var motion_material: ShaderMaterial
var motion_phase := 0.0
var swim_blend := 0.0
var tension_blend := 0.0
var burst_blend := 0.0

func _ready() -> void:
	home = position
	collision_layer = 4
	collision_mask = 0
	z_index = 3
	add_to_group("combat_targets")
	var hitbox := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 30.0 if kind == &"eel" else 42.0
	shape.height = 112.0 if kind == &"eel" else 100.0
	hitbox.rotation = PI * 0.5
	hitbox.shape = shape
	add_child(hitbox)
	art = Sprite2D.new()
	art.name = "Art"
	art.texture = EEL if kind == &"eel" else SENTINEL
	if kind == &"naga":
		art.texture = preload("res://assets/palace-naga.png")
	art.scale = Vector2.ONE * ((155.0 if kind == &"eel" else 215.0) / float(art.texture.get_width()))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	motion_material = ShaderMaterial.new()
	motion_material.shader = MOTION_SHADER
	motion_material.set_shader_parameter("species", 0 if kind == &"eel" else (2 if kind == &"naga" else 1))
	art.material = motion_material
	add_child(art)
	var aura := Sprite2D.new()
	aura.texture = preload("res://scenes/soft_glow.tres")
	aura.scale = Vector2(1.3, 0.75)
	aura.modulate = Color(0.24, 0.81, 0.86, 0.18)
	aura.z_index = -1
	add_child(aura)
	reset_enemy()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	clock += delta
	state_left = maxf(0.0, state_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	hurt_left = maxf(0.0, hurt_left - delta)
	var offset := player.global_position + Vector2(0, -60) - global_position
	var alert := player.in_water and player.health > 0 and absf(offset.x) < 530.0 and absf(offset.y) < 470.0
	if kind == &"eel":
		_update_eel(delta, offset, alert)
	elif kind == &"naga":
		_update_naga(delta, offset, alert)
	else:
		_update_sentinel(delta, offset, alert)
	move_and_slide()
	position.x = clampf(position.x, home.x - 550.0, home.x + 550.0)
	position.y = clampf(position.y, 600.0, 1040.0)
	art.flip_h = offset.x > 0 if alert and state != &"dash" else velocity.x > 10.0
	if state == &"dash" and contact_cooldown <= 0.0 and global_position.distance_to(player.global_position + Vector2(0, -55)) < 70.0:
		if player.take_damage(16, global_position, self):
			contact_cooldown = 1.0
			state = &"recover"
			state_left = 0.45
	queue_redraw()

func _process(delta: float) -> void:
	if health > 0:
		_animate_body(delta)

func _animate_body(delta: float) -> void:
	# Blend effort rather than restarting a loop at every AI state change.
	var blend := 1.0 - exp(-delta * 8.0)
	swim_blend = lerpf(swim_blend, clampf(velocity.length() / 160.0, 0.0, 1.0), blend)
	tension_blend = lerpf(tension_blend, 1.0 if state in [&"windup", &"hold"] else 0.0, blend)
	burst_blend = lerpf(burst_blend, 1.0 if state in [&"dash", &"lunge"] else 0.0, blend)
	var resting_rate := 2.5 if kind == &"naga" else 3.2
	motion_phase += delta * (resting_rate + swim_blend * 4.0 + burst_blend * 3.0)
	motion_material.set_shader_parameter("motion_phase", motion_phase)
	motion_material.set_shader_parameter("swim", swim_blend)
	motion_material.set_shader_parameter("tension", tension_blend)
	motion_material.set_shader_parameter("burst", burst_blend)
	art.position.y = sin(motion_phase * 0.5) * (1.3 if kind == &"eel" else 2.0)
	art.rotation = sin(motion_phase * 0.5) * 0.018 + clampf(velocity.y / 1100.0, -0.2, 0.2)
	art.modulate = Color(1.45, 1.8, 1.8) if hurt_left > 0.0 else Color.WHITE

func _update_eel(delta: float, offset: Vector2, alert: bool) -> void:
	match state:
		&"windup":
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			if state_left <= 0.0:
				state = &"dash"
				state_left = 0.50
		&"dash":
			velocity = dash_direction * 460.0
			if state_left <= 0.0:
				state = &"recover"
				state_left = 0.75
		&"recover":
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if state_left <= 0.0:
				state = &"patrol"
		_:
			var target := home + Vector2(sin(clock * 1.1) * 145.0, sin(clock * 1.7) * 42.0)
			velocity = velocity.move_toward((target - position).limit_length(120.0), 450.0 * delta)
			if alert and attack_cooldown <= 0.0:
				state = &"windup"
				state_left = 0.38
				attack_cooldown = 2.3
				dash_direction = offset.normalized() if offset.length() > 1.0 else Vector2.LEFT

func _update_sentinel(delta: float, offset: Vector2, alert: bool) -> void:
	match state:
		&"windup":
			velocity = Vector2.ZERO
			if state_left <= 0:
				if volley_count % 2 == 0:
					for angle in [-0.19, 0.0, 0.19]:
						var bolt := WATER_BOLT.new()
						bolt.position = position
						bolt.direction = dash_direction.rotated(angle)
						bolt.attacker = self
						get_parent().add_child(bolt)
					state = &"recover"
					state_left = 0.65
				else:
					state = &"dash"
					state_left = 0.8
				volley_count += 1
		&"dash":
			velocity = dash_direction * 540.0
			if state_left <= 0:
				state = &"recover"
				state_left = 0.65
		&"recover":
			velocity = velocity.move_toward(Vector2.ZERO, 1100.0 * delta)
			if state_left <= 0:
				state = &"patrol"
		_:
			var target := offset if alert else home - position + Vector2(0, sin(clock) * 30)
			velocity = velocity.move_toward(target.limit_length(105), 340 * delta)
			if alert and attack_cooldown <= 0:
				dash_direction = offset.normalized()
				state = &"windup"
				state_left = 0.5
				attack_cooldown = 2.6

func _update_naga(delta: float, offset: Vector2, alert: bool) -> void:
	match state:
		&"hold":
			velocity = Vector2.ZERO
			hold_tick -= delta
			if player.held_by != self or state_left <= 0 or player.health <= 0:
				_release_hold()
				state = &"recover"
				state_left = 1.2
			elif hold_tick <= 0:
				player.take_damage(5, global_position)
				player.velocity = Vector2.ZERO
				hold_tick = 1.05
		&"windup":
			velocity = Vector2.ZERO
			if state_left <= 0:
				state = &"lunge"
				state_left = 0.42
		&"lunge":
			velocity = dash_direction * 420.0
			if offset.length() < 67 and player.try_grab(self):
				position = player.position + Vector2(-22 if offset.x > 0 else 22, -58)
				velocity = Vector2.ZERO
				state = &"hold"
				state_left = 2.85
				hold_tick = 0.28
			elif state_left <= 0:
				state = &"recover"
				state_left = 1.0
		&"recover":
			velocity = velocity.move_toward(Vector2.ZERO, 1000 * delta)
			if state_left <= 0:
				state = &"patrol"
		_:
			var target := offset if alert else home - position + Vector2(0, sin(clock) * 35)
			velocity = velocity.move_toward(target.limit_length(145), 420 * delta)
			if alert and offset.length() < 155 and attack_cooldown <= 0:
				dash_direction = offset.normalized()
				state = &"windup"
				state_left = 0.48
				attack_cooldown = 3.0

func _release_hold() -> void:
	if player.held_by == self:
		player.held_by = null

func take_damage(amount: int, _source: Vector2) -> void:
	if health <= 0 or amount <= 0 or get_tree().paused:
		return
	health = maxi(0, health - amount)
	hurt_left = 0.18
	if health == 0:
		_release_hold()
		velocity = Vector2.ZERO
		collision_layer = 0
		hide()
		defeated.emit(global_position, 35 if kind == &"eel" else 50)

func reset_enemy() -> void:
	_release_hold()
	volley_count = 0
	position = home
	velocity = Vector2.ZERO
	health = 3 if kind == &"eel" else 5
	state = &"patrol"
	state_left = 0.0
	attack_cooldown = 0.3 if kind == &"sentinel" else 0.7
	contact_cooldown = 0.0
	hurt_left = 0.0
	clock = 0.0
	# A stable home-based phase keeps groups from swimming in lockstep.
	motion_phase = fposmod(home.x * 0.071 + home.y * 0.037, TAU)
	swim_blend = 0.0
	tension_blend = 0.0
	burst_blend = 0.0
	_animate_body(0.0)
	collision_layer = 4
	show()

func _draw() -> void:
	if state == &"windup":
		var pulse := 0.35 + 0.25 * sin(clock * 24.0)
		draw_arc(Vector2.ZERO, 58.0, 0, TAU, 28, Color(0.68, 1.0, 0.95, pulse), 3.0, true)
	if state == &"hold":
		var center := to_local(player.global_position) + Vector2(0, -60)
		for i in range(3):
			var points := PackedVector2Array()
			for j in range(25):
				var a := PI * j / 24.0
				points.append(center + Vector2(cos(a) * (39 - i * 4), sin(a) * 9 + i * 12 - 14))
			draw_polyline(points, Color("#164b46"), 10, true)
			draw_polyline(points, Color("#c5a74c"), 2, true)
