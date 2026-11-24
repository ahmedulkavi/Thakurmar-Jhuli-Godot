extends CharacterBody2D
## Shakchunni's visible upper body is the sword target. Her limbs reach the platforms.

signal health_changed(current: int, maximum: int)
signal phase_changed(phase: StringName)
signal defeated

const MAX_HEALTH := 32
const BASE_DAMAGE := 28
const ATTACK_TEXTURE = preload("res://assets/shakchunni-attack-torso.png")
const ARM_TEXTURE = preload("res://assets/shakchunni-arm.png")
const IDLE_SHEET = preload("res://assets/shakchunni-idle-sheet.png")
const LAUGH_SHEET = preload("res://assets/shakchunni-laugh-sheet.png")
const ARM_REGION := Rect2(18, 129, 2132, 435)
const MOTION_SHADER = preload("res://assets/shakchunni_motion.gdshader")
const HAND_SCALE := 0.135
const WRIST_X := 1240.0
const PALM_X := 1730.0
const LAUGH_TIME := 2.1
const FRENZY_TIME := 8.0
const BLOCK_STUN_TIME := 0.45
const HOVER_MIN_X := 8280.0
const HOVER_MAX_X := 8700.0
const HOVER_HEIGHT := 586.0

var player: ForestPrince
var health := MAX_HEALTH
var active := false
var state: StringName = &"dormant"
var time_left := 0.0
var attack_count := 0
var frenzy_left := 0.0
var arm_target := Vector2.ZERO
var reaching := false
var arm_hit := false
var strike_duration := 0.34
var art: Sprite2D
var previous_art: Sprite2D
var pose_blend := 0.0
var voice: AudioStreamPlayer
var clock := 0.0
var hit_flash := 0.0
var home_position := Vector2.ZERO
var hover_velocity := 0.0
var idle_frames: Array[AtlasTexture] = []
var laugh_frames: Array[AtlasTexture] = []
var pose_frame := 0
var death_tween: Tween
var phase_duration := 1.0
var reach_start := Vector2.ZERO
var recovery_start := Vector2.ZERO
var body_lean := 0.0
var body_shift := Vector2.ZERO
var arm_canvas: Node2D
var arm_mesh := ArrayMesh.new()
var motion_material: ShaderMaterial
var death_arm := false
var death_hand_local := Vector2.ZERO

func _ready() -> void:
	home_position = position
	collision_layer = 4
	collision_mask = 0
	add_to_group("combat_targets")
	z_index = 2
	var hitbox := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(250, 220)
	hitbox.shape = shape
	hitbox.position = Vector2(0, -325)
	add_child(hitbox)
	idle_frames = _make_frames(IDLE_SHEET)
	laugh_frames = _make_frames(LAUGH_SHEET)
	art = Sprite2D.new()
	art.name = "ShakchunniArt"
	motion_material = ShaderMaterial.new()
	motion_material.shader = MOTION_SHADER
	art.material = motion_material
	art.texture = idle_frames[0]
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.position = Vector2(0, -270)
	add_child(art)
	previous_art = Sprite2D.new()
	previous_art.name = "PoseBlend"
	previous_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(previous_art)
	previous_art.hide()
	arm_canvas = Node2D.new()
	arm_canvas.name = "ArticulatedArm"
	add_child(arm_canvas)
	arm_canvas.draw.connect(_draw_arm)
	voice = AudioStreamPlayer.new()
	voice.name = "Laugh"
	voice.stream = _make_laugh()
	voice.volume_db = -4.0
	add_child(voice)
	_reset_visual()

func _make_frames(sheet: Texture2D) -> Array[AtlasTexture]:
	var result: Array[AtlasTexture] = []
	var cell := Vector2(sheet.get_size()) / Vector2(4, 2)
	for i in range(8):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		var start := (Vector2(i % 4, i / 4) * cell).round()
		var end := (Vector2(i % 4 + 1, i / 4 + 1) * cell).round()
		atlas.region = Rect2(start, end - start)
		atlas.filter_clip = true
		result.append(atlas)
	return result

func _update_pose() -> void:
	if not art or state == &"dead":
		return
	var frame_position := 0.0
	var frames := idle_frames
	if state == &"windup" or reaching:
		art.texture = ATTACK_TEXTURE
		pose_frame = 0
	else:
		if state == &"laugh":
			frames = laugh_frames
			frame_position = clampf((LAUGH_TIME - time_left) / LAUGH_TIME, 0.0, 1.0) * 7.0
		elif active:
			# The painted sheet already contains the return to rest: loop it once.
			frame_position = fmod(clock * 3.2, 8.0)
		pose_frame = int(frame_position)
		art.texture = frames[pose_frame]
	var rect := Vector4(0, 0, 1, 1)
	var next_rect := rect
	if art.texture is AtlasTexture:
		var atlas := art.texture as AtlasTexture
		var size := Vector2(atlas.atlas.get_size())
		var r := atlas.region
		rect = Vector4(r.position.x / size.x, r.position.y / size.y, r.size.x / size.x, r.size.y / size.y)
		r = frames[(pose_frame + 1) % frames.size()].region
		next_rect = Vector4(r.position.x / size.x, r.position.y / size.y, r.size.x / size.x, r.size.y / size.y)
	motion_material.set_shader_parameter("frame_rect", rect)
	motion_material.set_shader_parameter("next_rect", next_rect)
	motion_material.set_shader_parameter("frame_mix", smoothstep(0.0, 1.0, fmod(frame_position, 1.0)))
	motion_material.set_shader_parameter("motion_time", clock)
	var laugh_pulse := sin((LAUGH_TIME - time_left) * 22.0) * sin(PI * clampf(1.0 - time_left / LAUGH_TIME, 0.0, 1.0)) if state == &"laugh" else 0.0
	motion_material.set_shader_parameter("laugh", laugh_pulse)
	motion_material.set_shader_parameter("recoil", body_lean * 8.0)
	var base := (620.0 if art.texture == ATTACK_TEXTURE else 560.0) / art.texture.get_height()
	var breath := sin(clock * 1.7)
	art.scale = Vector2(base * (1.0 - breath * 0.003), base * (1.0 + breath * 0.004 + laugh_pulse * 0.004))
	art.rotation = body_lean + sin(clock * 1.1) * 0.008 + laugh_pulse * 0.006
	var attack_offset := Vector2(-20, 25) if art.texture == ATTACK_TEXTURE else Vector2.ZERO
	art.position = Vector2(0, -270.0 + sin(clock * 1.5) * 4.0 + laugh_pulse * 1.5) + attack_offset + body_shift
	if pose_blend > 0.0:
		var previous_offset := Vector2(-20, 25) if previous_art.texture == ATTACK_TEXTURE else Vector2.ZERO
		previous_art.position = art.position - attack_offset + previous_offset
		previous_art.rotation = art.rotation
		previous_art.scale = Vector2.ONE * ((620.0 if previous_art.texture == ATTACK_TEXTURE else 560.0) / previous_art.texture.get_height())
		var blend := smoothstep(0.0, 1.0, pose_blend / 0.18)
		previous_art.modulate = Color(1, 1, 1, blend)
		art.self_modulate.a = 1.0 - blend
		previous_art.show()
	else:
		previous_art.hide()
		art.self_modulate.a = 1.0

func _update_body(delta: float) -> void:
	var progress := _phase_progress()
	var lean := -hover_velocity * 0.0003
	var shift := Vector2.ZERO
	if state == &"windup":
		lean += 0.035 * sin(progress * PI * 0.5)
		shift = Vector2(10, 3) * smoothstep(0.0, 1.0, progress)
	elif state == &"strike":
		lean -= 0.075 * sin(progress * PI)
		shift = Vector2(-18, 5) * sin(progress * PI)
	elif state == &"recover" and reaching:
		lean += 0.025 * sin(progress * PI)
	if hit_flash > 0.0:
		lean += 0.055 * sin(hit_flash / 0.15 * PI)
	body_lean = lerpf(body_lean, lean, 1.0 - exp(-delta * 14.0))
	body_shift = body_shift.lerp(shift, 1.0 - exp(-delta * 12.0))

func _phase_progress() -> float:
	return clampf(1.0 - time_left / maxf(phase_duration, 0.001), 0.0, 1.0)

func begin() -> void:
	if health <= 0:
		return
	active = true
	_set_state(&"waiting", 1.0)
	health_changed.emit(health, MAX_HEALTH)

func reset_boss() -> void:
	if death_tween and death_tween.is_valid():
		death_tween.kill()
	active = false
	death_arm = false
	health = MAX_HEALTH
	position = home_position
	hover_velocity = 0.0
	clock = 0.0
	body_lean = 0.0
	body_shift = Vector2.ZERO
	pose_blend = 0.0
	attack_count = 0
	frenzy_left = 0.0
	arm_hit = false
	hit_flash = 0.0
	voice.stop()
	_set_state(&"dormant", 0.0)
	_reset_visual()
	health_changed.emit(health, MAX_HEALTH)

func _reset_visual() -> void:
	_update_pose()
	art.modulate = Color.WHITE
	art.show()
	queue_redraw()

func _set_state(next: StringName, duration: float) -> void:
	var previous := state
	var was_reaching := reaching
	var old_hand := to_global(_arm_endpoint()) if art else global_position
	if next == &"strike":
		reach_start = old_hand
	elif next == &"recover":
		recovery_start = old_hand
	if art and _pose_family(previous) != _pose_family(next):
		previous_art.texture = art.texture
		pose_blend = 0.18
	state = next
	time_left = duration
	phase_duration = duration
	reaching = next == &"strike" or (next == &"recover" and (previous == &"strike" or was_reaching))
	if next == &"strike":
		strike_duration = duration
	_update_pose()
	phase_changed.emit(state)

func _pose_family(phase: StringName) -> int:
	if phase == &"laugh":
		return 2
	if phase == &"windup" or phase == &"strike" or (phase == &"recover" and reaching):
		return 1
	return 0

func _physics_process(delta: float) -> void:
	if not active or health <= 0:
		return
	clock += delta
	pose_blend = maxf(0.0, pose_blend - delta)
	# Her body and hurtbox travel together, never beyond the island route.
	var desired_x := clampf(player.global_position.x + 250.0 + sin(clock * 0.65) * 55.0, HOVER_MIN_X, HOVER_MAX_X)
	var hover_speed := 74.0 if frenzy_left > 0.0 else 37.0
	var desired_velocity := clampf((desired_x - position.x) * 1.4, -hover_speed, hover_speed)
	hover_velocity = move_toward(hover_velocity, desired_velocity, 110.0 * delta)
	position.x = clampf(position.x + hover_velocity * delta, HOVER_MIN_X, HOVER_MAX_X)
	position.y = HOVER_HEIGHT + sin(clock * 1.25) * 18.0
	hit_flash = maxf(0.0, hit_flash - delta)
	if state != &"laugh":
		frenzy_left = maxf(0.0, frenzy_left - delta)
	time_left -= delta
	_update_body(delta)
	_update_pose()
	art.modulate = Color(1.5, 1.2, 1.35) if hit_flash > 0 else (Color(1.2, 0.8, 1.3) if state == &"laugh" else Color.WHITE)
	if state == &"strike" and not arm_hit and player.health > 0:
		var player_center := player.global_position + Vector2(0, -65)
		var hand := to_global(_arm_endpoint())
		if player_center.distance_to(hand) < 68.0:
			arm_hit = player.take_damage(BASE_DAMAGE, global_position, self)
	if time_left <= 0.0:
		match state:
			&"waiting", &"recover":
				if attack_count >= 3 and frenzy_left <= 0.0:
					attack_count = 0
					_set_state(&"laugh", LAUGH_TIME)
					voice.play()
				else:
					arm_target = player.global_position + Vector2(0, -65)
					arm_hit = false
					_set_state(&"windup", 0.40 if frenzy_left > 0.0 else 0.85)
			&"windup":
				# The marked position is locked, allowing the prince to dodge.
				_set_state(&"strike", 0.24 if frenzy_left > 0.0 else 0.34)
			&"strike":
				attack_count += 1
				_set_state(&"recover", 0.30 if frenzy_left > 0.0 else 0.90)
			&"laugh":
				frenzy_left = FRENZY_TIME
				_set_state(&"recover", 0.2)
	queue_redraw()

func can_counter_from(prince_position: Vector2) -> bool:
	# Compare the prince's sword reach with the boss's upper-body hurtbox.
	var offset := (prince_position + Vector2(0, -62)) - (global_position + Vector2(0, -325))
	return absf(offset.x) <= 241.0 and absf(offset.y) <= 161.0

func stun_from_block() -> void:
	if not active or health <= 0:
		return
	_set_state(&"recover", BLOCK_STUN_TIME)
	arm_hit = true
	queue_redraw()

func take_damage(amount: int, _source: Vector2) -> void:
	if not active or state == &"laugh" or health <= 0 or amount <= 0 or get_tree().paused:
		return
	health = maxi(0, health - amount)
	if health > 0 and amount >= ForestPrince.COUNTER_DAMAGE and state == &"strike":
		_set_state(&"recover", 0.9)
	hit_flash = 0.15
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		death_arm = reaching or state == &"windup"
		death_hand_local = art.transform.affine_inverse() * _arm_endpoint()
		active = false
		voice.stop()
		_set_state(&"dead", 0.0)
		previous_art.hide()
		art.self_modulate.a = 1.0
		# Recoil, collapse, and dissolve before the victory screen appears.
		death_tween = create_tween()
		death_tween.tween_property(art, "rotation", -0.20, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.parallel().tween_property(art, "modulate", Color(1.8, 1.35, 1.5, 1.0), 0.22)
		death_tween.tween_property(art, "rotation", 0.48, 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		death_tween.parallel().tween_property(art, "position", art.position + Vector2(35, 180), 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		death_tween.parallel().tween_property(art, "modulate", Color(0.4, 0.35, 0.42, 0.0), 1.25)
		defeated.emit()
	queue_redraw()

func _process(_delta: float) -> void:
	if state == &"dead" and art.modulate.a > 0.0:
		queue_redraw()

func _draw() -> void:
	if arm_canvas:
		arm_canvas.queue_redraw()
	if not active:
		return
	var target := to_local(arm_target)
	if state == &"windup":
		var pulse := 0.45 + 0.25 * sin(clock * 18.0)
		draw_arc(target, 45.0, 0.0, TAU, 32, Color(0.9, 0.3, 0.6, pulse), 3.0, true)
	elif state == &"laugh":
		draw_arc(Vector2(0, -345), 80.0 + 10.0 * sin(clock * 8), 0, TAU, 40, Color(0.83, 0.5, 0.88, 0.55), 4.0, true)

func _draw_arm() -> void:
	if state == &"dead" and death_arm:
		_draw_reaching_arm(_shoulder_position(), art.transform * death_hand_local)
	elif active and (state == &"windup" or reaching):
		_draw_reaching_arm(_shoulder_position(), _arm_endpoint())

func _shoulder_position() -> Vector2:
	# Socket is inside the painted sleeve, in attack-texture coordinates.
	if art.texture == ATTACK_TEXTURE:
		return art.transform * Vector2(-107, -389)
	return art.position + Vector2(-20, 25) + (Vector2(-107, -389) * (620.0 / ATTACK_TEXTURE.get_height())).rotated(art.rotation)

func _rest_hand() -> Vector2:
	return _shoulder_position() + Vector2(-12, 143).rotated(art.rotation)

func _cocked_hand() -> Vector2:
	return _shoulder_position() + Vector2(-85, 75).rotated(art.rotation)

func _arm_endpoint() -> Vector2:
	var progress := _phase_progress()
	if state == &"windup":
		return _rest_hand().lerp(_cocked_hand(), smoothstep(0.0, 1.0, progress))
	if state == &"strike":
		var t := smoothstep(0.0, 0.72, progress)
		var start := to_local(reach_start)
		var target := to_local(arm_target)
		# Anticipation flows into an arcing reach, with zero velocity at contact.
		return start.lerp(target, t) + Vector2(0, -42.0 * sin(PI * t))
	if state == &"recover" and reaching:
		var t := smoothstep(0.06, 1.0, progress)
		return to_local(recovery_start).lerp(_rest_hand(), t) + Vector2(0, 45.0 * sin(PI * t))
	return _rest_hand()

func _hand_direction(shoulder: Vector2, hand: Vector2) -> Vector2:
	var aim := (hand - shoulder).normalized()
	var stretch := smoothstep(140.0, 340.0, shoulder.distance_to(hand))
	# Wrist rotates into the strike; fingers and bangles never stretch.
	return Vector2(-0.35, 0.94).normalized().slerp(aim, stretch).normalized()

func _draw_reaching_arm(shoulder: Vector2, hand: Vector2) -> void:
	var direction := _hand_direction(shoulder, hand)
	var wrist := hand - direction * ((PALM_X - WRIST_X) * HAND_SCALE)
	var distance := shoulder.distance_to(wrist)
	var control_a := shoulder + Vector2(0, minf(100.0, distance * 0.7)).rotated(art.rotation)
	var control_b := wrist - direction * minf(135.0, distance * 0.38)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var segments := 48
	var half_width := ARM_REGION.size.y * HAND_SCALE * 0.5
	for i in range(segments + 1):
		var t := float(i) / segments
		var center := shoulder.bezier_interpolate(control_a, control_b, wrist, t)
		var tangent := shoulder.bezier_derivative(control_a, control_b, wrist, t).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		# The torso already owns the sleeve. Start with bare skin inside its cuff,
		# feathering the overlap instead of bending a second sleeve over it.
		var source_x := lerpf(430.0, WRIST_X, t)
		var root_blend := smoothstep(0.0, minf(0.28, 18.0 / maxf(distance, 1.0)), t)
		var width := half_width * lerpf(0.72, 1.0, root_blend)
		var opacity := smoothstep(0.0, minf(0.12, 5.0 / maxf(distance, 1.0)), t)
		for side in [-1.0, 1.0]:
			vertices.append(center + normal * width * side)
			uvs.append(Vector2(source_x, ARM_REGION.position.y + (0.0 if side < 0 else ARM_REGION.size.y)) / Vector2(ARM_TEXTURE.get_size()))
			colors.append(Color(1, 1, 1, opacity))
		if i < segments:
			var j := i * 2
			indices.append_array(PackedInt32Array([j, j + 1, j + 2, j + 1, j + 3, j + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	arm_mesh.clear_surfaces()
	arm_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tint := art.modulate if state == &"dead" else Color(1, 1, 1, art.self_modulate.a)
	arm_canvas.draw_mesh(arm_mesh, ARM_TEXTURE, Transform2D.IDENTITY, tint)
	# One rigid wrist/palm/finger patch preserves anatomy at every reach distance.
	arm_canvas.draw_set_transform(wrist, direction.angle(), Vector2.ONE)
	arm_canvas.draw_texture_rect_region(ARM_TEXTURE, Rect2(-0.5, -half_width, (2150.0 - WRIST_X) * HAND_SCALE + 0.5, half_width * 2.0), Rect2(WRIST_X, ARM_REGION.position.y, 2150.0 - WRIST_X, ARM_REGION.size.y), tint)
	arm_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _make_laugh() -> AudioStreamWAV:
	# Uneven cackles, shifting vowel tones and a lower rasp give the ghost a voice.
	var rate := 22050
	var count := int(rate * LAUGH_TIME)
	var raw := PackedFloat32Array()
	raw.resize(count)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var starts := [0.0, 0.24, 0.48, 0.72, 1.02, 1.29, 1.55, 1.79]
	var lengths := [0.19, 0.19, 0.20, 0.25, 0.20, 0.21, 0.20, 0.26]
	var pitches := [270.0, 325.0, 295.0, 385.0, 310.0, 405.0, 355.0, 430.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12493
	var phase := 0.0
	var undertone_phase := 0.0
	var syllable := 0
	for i in range(count):
		var t := float(i) / rate
		if syllable + 1 < starts.size() and t >= starts[syllable + 1]:
			syllable += 1
		var local := t - float(starts[syllable])
		var duration: float = lengths[syllable]
		var progress := clampf(local / duration, 0.0, 1.0)
		var envelope := pow(sin(PI * progress), 0.65) if local < duration else 0.0
		var pitch: float = pitches[syllable] + 65.0 * (1.0 - progress) + 25.0 * sin(t * 29.0) + 11.0 * sin(t * 71.0)
		phase = fmod(phase + TAU * pitch / rate, TAU)
		undertone_phase = fmod(undertone_phase + PI * pitch / rate, TAU)
		var wave := 0.0
		for harmonic in range(1, 15):
			var frequency := pitch * harmonic
			var formant := exp(-pow((frequency - (790.0 + 140.0 * progress)) / 250.0, 2.0))
			formant += 0.7 * exp(-pow((frequency - (1550.0 - 150.0 * progress)) / 340.0, 2.0))
			wave += sin(phase * harmonic) * (0.16 / harmonic + formant * 0.24)
		wave += 0.09 * sin(undertone_phase) + 0.055 * rng.randf_range(-1.0, 1.0)
		raw[i] = tanh(wave * 1.4) * envelope
	# A quiet, short echo adds an eerie tail without extending the invulnerable phase.
	var delay_a := int(rate * 0.095)
	var delay_b := int(rate * 0.19)
	var peak := 0.001
	var mixed := PackedFloat32Array()
	mixed.resize(count)
	for i in range(count):
		var echo := (raw[i - delay_a] * 0.24 if i >= delay_a else 0.0)
		echo += (raw[i - delay_b] * 0.12 if i >= delay_b else 0.0)
		var fade := minf(1.0, float(count - 1 - i) / (rate * 0.08))
		mixed[i] = (raw[i] + echo) * fade
		peak = maxf(peak, absf(mixed[i]))
	for i in range(count):
		samples.encode_s16(i * 2, int(clampf(mixed[i] / peak * 0.78, -1.0, 1.0) * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = samples
	return sound
