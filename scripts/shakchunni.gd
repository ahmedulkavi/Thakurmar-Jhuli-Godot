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
const LAUGH_TIME := 2.1
const FRENZY_TIME := 8.0
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
	art.texture = idle_frames[0]
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.position = Vector2(0, -270)
	add_child(art)
	previous_art = Sprite2D.new()
	previous_art.name = "PoseBlend"
	previous_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(previous_art)
	previous_art.hide()
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
	if not art:
		return
	if state == &"windup" or reaching:
		art.texture = ATTACK_TEXTURE
		pose_frame = 0
	elif state == &"laugh":
		pose_frame = clampi(int((LAUGH_TIME - time_left) / LAUGH_TIME * laugh_frames.size()), 0, laugh_frames.size() - 1)
		art.texture = laugh_frames[pose_frame]
	elif active:
		var step := int(clock * 5.0) % 14
		pose_frame = step if step < idle_frames.size() else 14 - step
		art.texture = idle_frames[pose_frame]
	else:
		pose_frame = 0
		art.texture = idle_frames[0]
	var base := (620.0 if art.texture == ATTACK_TEXTURE else 560.0) / art.texture.get_height()
	var breath := sin(clock * 1.7)
	var tremble := sin((LAUGH_TIME - time_left) * 15.0) if state == &"laugh" else 0.0
	var lunge := 0.03 if state == &"strike" else (0.015 if state == &"windup" else 0.0)
	art.scale = Vector2(base * (1.0 - breath * 0.008), base * (1.0 + breath * 0.008 + tremble * 0.012))
	art.rotation = -lunge + sin(clock * 1.1) * 0.012 + tremble * 0.012
	var attack_offset := Vector2(-20, 25) if art.texture == ATTACK_TEXTURE else Vector2.ZERO
	art.position = Vector2(tremble * 2.0, -270.0 + sin(clock * 1.5) * 7.0) + attack_offset
	if pose_blend > 0.0:
		var previous_offset := Vector2(-20, 25) if previous_art.texture == ATTACK_TEXTURE else Vector2.ZERO
		previous_art.position = art.position - attack_offset + previous_offset
		previous_art.rotation = art.rotation
		previous_art.scale = Vector2.ONE * ((620.0 if previous_art.texture == ATTACK_TEXTURE else 560.0) / previous_art.texture.get_height())
		previous_art.modulate = Color(1, 1, 1, pose_blend / 0.18)
		previous_art.show()
	else:
		previous_art.hide()

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
	health = MAX_HEALTH
	position = home_position
	hover_velocity = 0.0
	clock = 0.0
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
	if art and _pose_family(previous) != _pose_family(next):
		previous_art.texture = art.texture
		pose_blend = 0.18
	state = next
	time_left = duration
	reaching = next == &"strike" or (next == &"recover" and previous == &"strike")
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

func take_damage(amount: int, _source: Vector2) -> void:
	if not active or state == &"laugh" or health <= 0 or amount <= 0 or get_tree().paused:
		return
	health = maxi(0, health - amount)
	if health > 0 and amount >= ForestPrince.COUNTER_DAMAGE and state == &"strike":
		_set_state(&"recover", 0.9)
	hit_flash = 0.15
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		active = false
		voice.stop()
		_set_state(&"dead", 0.0)
		previous_art.hide()
		# Recoil, collapse, and dissolve before the victory screen appears.
		death_tween = create_tween()
		death_tween.tween_property(art, "rotation", -0.20, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.parallel().tween_property(art, "modulate", Color(1.8, 1.35, 1.5, 1.0), 0.22)
		death_tween.tween_property(art, "rotation", 0.48, 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		death_tween.parallel().tween_property(art, "position", art.position + Vector2(35, 180), 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		death_tween.parallel().tween_property(art, "modulate", Color(0.4, 0.35, 0.42, 0.0), 1.25)
		defeated.emit()
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var shoulder := Vector2(-66, -435)
	var target := to_local(arm_target)
	if state == &"windup":
		var pulse := 0.45 + 0.25 * sin(clock * 18.0)
		draw_arc(target, 45.0, 0.0, TAU, 32, Color(0.9, 0.3, 0.6, pulse), 3.0, true)
	if state == &"windup" or reaching:
		_draw_reaching_arm(shoulder, _arm_endpoint())
	elif state == &"laugh":
		draw_arc(Vector2(0, -345), 80.0 + 10.0 * sin(clock * 8), 0, TAU, 40, Color(0.83, 0.5, 0.88, 0.55), 4.0, true)

func _arm_endpoint() -> Vector2:
	var shoulder := Vector2(-66, -435)
	var target := to_local(arm_target)
	if state == &"windup":
		return shoulder + Vector2(-110, 100) + Vector2(sin(clock * 12.0) * 12.0, cos(clock * 9.0) * 10.0)
	var extension := 0.0
	if state == &"strike":
		var progress := clampf(1.0 - time_left / strike_duration, 0.0, 1.0)
		# A quick whip followed by a brief held reach gives the hand a readable impact.
		extension = 0.12 + 0.88 * (1.0 - pow(1.0 - minf(progress / 0.72, 1.0), 3.0))
	elif state == &"recover":
		var duration := 0.30 if frenzy_left > 0.0 else 0.90
		var progress := clampf(1.0 - time_left / duration, 0.0, 1.0)
		extension = 1.0 - pow(progress, 1.8)
	return shoulder.lerp(target, extension)

func _draw_reaching_arm(shoulder: Vector2, hand: Vector2) -> void:
	var direction := hand - shoulder
	if direction.length() < 20.0:
		return
	var normal := Vector2(-direction.y, direction.x).normalized()
	var bend := minf(165.0, direction.length() * 0.29) * (0.9 + 0.1 * sin(clock * 9.0))
	if state == &"windup":
		bend = 65.0
	var control := (shoulder + hand) * 0.5 + normal * bend
	var segments := 26
	for i in range(segments):
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a := shoulder * pow(1.0 - t0, 2.0) + control * (2.0 * t0 * (1.0 - t0)) + hand * t0 * t0
		var b := shoulder * pow(1.0 - t1, 2.0) + control * (2.0 * t1 * (1.0 - t1)) + hand * t1 * t1
		var tangent := b - a
		var source_x := ARM_REGION.position.x + ARM_REGION.size.x * t0
		var source_w := ARM_REGION.size.x / segments + 2.0
		draw_set_transform(a, tangent.angle(), Vector2.ONE)
		draw_texture_rect_region(ARM_TEXTURE, Rect2(0, -45.0, tangent.length() + 2.0, 90.0), Rect2(source_x, ARM_REGION.position.y, source_w, ARM_REGION.size.y))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
