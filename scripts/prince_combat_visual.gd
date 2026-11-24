extends Node2D
## Registered armed movement and combat; every sword is painted into its hand.

const SHEET = preload("res://assets/prince-combat-sheet.png")
const LOCOMOTION_SHEET = preload("res://assets/prince-armed-locomotion.png")
const RUN_SHEET = preload("res://assets/prince-armed-run-v2.png")
const STEEL_SHEET = preload("res://assets/prince-steel-combat.png")
const STEEL_LOCOMOTION_SHEET = preload("res://assets/prince-steel-locomotion.png")
const STEEL_WALK_SHEET = preload("res://assets/prince-steel-walk.png")
const HUNTER_SHEET = preload("res://assets/prince-hunter-sheet.png")
const ROYAL_SWIM_SHEET = preload("res://assets/prince-royal-swim.png")
const STEEL_SWIM_SHEET = preload("res://assets/prince-steel-swim.png")
const HUNTER_SWIM_SHEET = preload("res://assets/prince-hunter-swim.png")
const SWORD_SWIM_SHEET = preload("res://assets/prince-sword-swim.png")
const SWORD_SWIM_STROKE := [0, 0, 1, 1, 2, 2, 1, 1]
const RUN_POSE_SCALE: float = 122.0 / 383.0
const RUN_ORIGIN := Vector2(254.0, 423.0)
const FRAME_TIMES: Array[float] = [0.045, 0.045, 0.035, 0.03, 0.04, 0.045, 0.065, 0.095]
const POSE_SCALE: float = 0.44
const BASELINE: float = 304.0
const GRIPS: Array[Vector2] = [
	Vector2(149, 170), Vector2(78, 73), Vector2(216, 33), Vector2(246, 197),
	Vector2(244, 216), Vector2(198, 248), Vector2(167, 192), Vector2(149, 170),
	Vector2(149, 170), Vector2(67, 163), Vector2(211, 143), Vector2(246, 138),
	Vector2(206, 137), Vector2(104, 188), Vector2(149, 177), Vector2(149, 170)]
const TIPS: Array[Vector2] = [
	Vector2(250, 132), Vector2(175, 10), Vector2(286, 7), Vector2(300, 246),
	Vector2(309, 277), Vector2(275, 274), Vector2(247, 118), Vector2(250, 132),
	Vector2(250, 132), Vector2(161, 167), Vector2(308, 123), Vector2(308, 130),
	Vector2(307, 137), Vector2(238, 151), Vector2(246, 133), Vector2(250, 132)]

var art: Sprite2D
var frames: Array[AtlasTexture] = []
var locomotion_frames: Array[AtlasTexture] = []
var run_frames: Array[AtlasTexture] = []
var royal_frames: Array[AtlasTexture] = []
var royal_locomotion_frames: Array[AtlasTexture] = []
var royal_run_frames: Array[AtlasTexture] = []
var steel_frames: Array[AtlasTexture] = []
var steel_locomotion_frames: Array[AtlasTexture] = []
var steel_walk_frames: Array[AtlasTexture] = []
var steel_equipped := false
var hunter_equipped := false
var hunter_frames: Array[AtlasTexture] = []
var royal_swim_frames: Array[AtlasTexture] = []
var steel_swim_frames: Array[AtlasTexture] = []
var hunter_swim_frames: Array[AtlasTexture] = []
var sword_swim_frames: Array[AtlasTexture] = []
var pose_frame: int = 0
var pose_set: StringName = &"combat"
var locomotion_frame: int = 0
var stride_distance: float = 0.0
var facing: float = 1.0
var breath_clock: float = 0.0
var stroke_phase := 0.0
var swim_speed := 0.0
var swim_weapon: StringName
var swim_grip := Vector2.ZERO
var weapon_progress := 0.0
var traces: Array[Dictionary] = []
var impacts: Array[Dictionary] = []

func _ready() -> void:
	art = Sprite2D.new()
	art.centered = false
	art.scale = Vector2.ONE * POSE_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Generated alpha can contain faint color haze outside the painted sprite.
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { if (COLOR.a < 0.035) { discard; } }"
	var clean_alpha := ShaderMaterial.new()
	clean_alpha.shader = shader
	art.material = clean_alpha
	add_child(art)
	royal_frames = _atlas_frames(SHEET)
	royal_locomotion_frames = _atlas_frames(LOCOMOTION_SHEET)
	royal_run_frames = _atlas_frames(RUN_SHEET, 2)
	steel_frames = _atlas_frames(STEEL_SHEET)
	steel_locomotion_frames = _atlas_frames(STEEL_LOCOMOTION_SHEET)
	steel_walk_frames = _atlas_frames(STEEL_WALK_SHEET, 2)
	hunter_frames = _atlas_frames(HUNTER_SHEET)
	royal_swim_frames = _atlas_frames(ROYAL_SWIM_SHEET, 2)
	steel_swim_frames = _atlas_frames(STEEL_SWIM_SHEET, 2)
	hunter_swim_frames = _atlas_frames(HUNTER_SWIM_SHEET, 2)
	sword_swim_frames = _atlas_frames(SWORD_SWIM_SHEET)
	frames = royal_frames
	locomotion_frames = royal_locomotion_frames
	run_frames = royal_run_frames
	hide()

func _atlas_frames(sheet: Texture2D, rows: int = 4) -> Array[AtlasTexture]:
	var result: Array[AtlasTexture] = []
	var cell := Vector2(sheet.get_size()) / Vector2(4.0, rows)
	for i in range(4 * rows):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		var start := (Vector2(i % 4, i / 4) * cell).round()
		var end := (Vector2(i % 4 + 1, i / 4 + 1) * cell).round()
		atlas.region = Rect2(start, end - start)
		atlas.filter_clip = true
		result.append(atlas)
	return result

func set_steel(enabled: bool) -> void:
	if enabled == steel_equipped:
		return
	steel_equipped = enabled
	frames = steel_frames if enabled else royal_frames
	locomotion_frames = steel_locomotion_frames if enabled else royal_locomotion_frames
	run_frames = steel_walk_frames if enabled else royal_run_frames

func set_hunter(enabled: bool) -> void:
	hunter_equipped = enabled
	if enabled:
		frames = hunter_frames
	elif steel_equipped:
		frames = steel_frames
	else:
		frames = royal_frames

func show_hunter(action: StringName, progress: float, direction: float, tint: Color, state: StringName, moving: bool) -> void:
	var index := 0
	if action == &"fire":
		index = mini(3, int(progress * 4.0))
	elif action == &"roll":
		index = 4 + mini(3, int(progress * 4.0))
	elif state == &"run" or moving:
		index = 8 + int(stride_distance / 50.0) % 4
	elif state == &"rise":
		index = 13
	elif state == &"fall":
		index = 14
	elif state == &"land":
		index = 15
	else:
		index = 12
	_set_frame(index, direction, tint)

# Leading hand in each painted swim frame, relative to its center at swim scale.
const HUNTER_SWIM_GRIPS := [Vector2(59,0), Vector2(59,2), Vector2(59,6), Vector2(60,8), Vector2(59,1), Vector2(60,4), Vector2(57,7), Vector2(59,8)]

func show_swim(stance: StringName, direction: float, swim_velocity: Vector2, tint: Color, entry: float, sword_equipped: bool, weapon: StringName, progress: float) -> void:
	var swim_frames := hunter_swim_frames if stance == &"hunter" else steel_swim_frames if stance == &"steel" else royal_swim_frames
	swim_speed = swim_velocity.length()
	swim_weapon = weapon
	weapon_progress = progress
	var index := int(stroke_phase) % 8
	var holding_sword := sword_equipped and stance != &"hunter"
	var pitch := 0.0
	var reach := 0.0
	if weapon == &"bow":
		# The arrow releases on input. Brace, recoil, then float forward again.
		var recoil := smoothstep(0.0, 0.22, progress) * (1.0 - smoothstep(0.22, 1.0, progress))
		reach = -8.0 * recoil
		pitch = -0.12 * recoil
		index = 2 if progress < 0.42 else 3
		swim_grip = HUNTER_SWIM_GRIPS[index]
	elif weapon != &"":
		var thrust := weapon == &"thrust"
		var contact := 0.225 if thrust else 0.3125
		var coil := smoothstep(0.0, contact * 0.75, progress) * (1.0 - smoothstep(contact * 0.75, contact + 0.1, progress))
		var drive := smoothstep(contact * 0.75, 0.49, progress) * (1.0 - smoothstep(0.55, 1.0, progress))
		reach = -5.0 * coil + (13.0 if thrust else 7.0) * drive
		pitch = -0.16 * coil + (0.04 if thrust else 0.22) * drive
		# Move from guard through the raised blade into contact and follow-through.
		index = 5 if progress < contact else 6
		if not thrust and progress >= 0.48:
			index = 7
		if progress >= 0.83:
			index = 4
	elif holding_sword:
		index = SWORD_SWIM_STROKE[index]
	if holding_sword:
		swim_frames = sword_swim_frames
		if stance == &"steel":
			index += 8
	var frame: AtlasTexture = swim_frames[index]
	pose_set = &"swim"
	pose_frame = index
	facing = direction
	art.texture = frame
	art.offset = -frame.region.size * 0.5
	art.position = Vector2(direction * reach, -65.0 + sin(breath_clock * 2.5) * 1.5)
	art.scale = Vector2.ONE * (0.43 if holding_sword else 0.30)
	art.flip_h = direction < 0.0
	art.rotation = lerpf(-0.94, clampf(swim_velocity.y / 670.0, -0.34, 0.34), smoothstep(0.0, 1.0, entry)) * direction
	art.rotation += pitch * direction
	art.modulate = tint
	art.show()
	show()

func tick(delta: float, horizontal_speed: float = 0.0) -> void:
	breath_clock += delta
	if pose_set == &"swim":
		stroke_phase = fmod(stroke_phase + delta * (1.3 + swim_speed / 55.0), 8.0)
	if (pose_set == &"locomotion" and locomotion_frame < 8) or hunter_equipped:
		# Eight poses per 200 px travelled: feet follow speed, not a free clock.
		stride_distance = fmod(stride_distance + absf(horizontal_speed) * delta, 200.0)
	for trace in traces:
		trace.age += delta
	for impact in impacts:
		impact.age += delta
	traces = traces.filter(func(trace: Dictionary) -> bool: return trace.age < 0.085)
	impacts = impacts.filter(func(impact: Dictionary) -> bool: return impact.age < 0.16)
	queue_redraw()

func show_pose(kind: StringName, elapsed: float, direction: float, tint: Color, striking: bool) -> void:
	var index := 0
	var remaining := elapsed
	while index < FRAME_TIMES.size() - 1 and remaining >= FRAME_TIMES[index]:
		remaining -= FRAME_TIMES[index]
		index += 1
	_set_frame(index + (8 if kind == &"thrust" else 0), direction, tint)
	if striking:
		var blade := blade_segment()
		traces.append({"grip": to_global(blade[0]), "tip": to_global(blade[1]), "age": 0.0})

func show_guard(kind: StringName, direction: float, tint: Color) -> void:
	_set_frame(15 if kind == &"thrust" else 7, direction, tint)
	# The sprite origin is at the soles, keeping feet planted while breathing.
	art.scale.y = POSE_SCALE * (1.0 + sin(breath_clock * 2.4) * 0.009)

func show_steel_guard(direction: float, tint: Color, horizontal_speed: float) -> void:
	if absf(horizontal_speed) > 15.0:
		show_locomotion(&"run", direction, tint, 0.0, 0.0, 0.0)
	else:
		show_guard(&"slash", direction, tint)

func _set_frame(index: int, direction: float, tint: Color) -> void:
	pose_set = &"combat"
	pose_frame = index
	facing = direction
	art.texture = frames[index]
	art.position = Vector2.ZERO
	art.offset = Vector2(-frames[index].region.size.x / 2.0, -BASELINE)
	art.flip_h = direction < 0.0
	art.scale = Vector2.ONE * POSE_SCALE
	art.rotation = 0.0
	art.modulate = tint
	art.show()
	show()
	queue_redraw()

func show_locomotion(state: StringName, direction: float, tint: Color, vertical_speed: float, landing_left: float, knockback_left: float) -> void:
	var index := 13
	if knockback_left > 0.0:
		index = 14 if knockback_left > 0.09 else 15
	elif state == &"run":
		index = int(stride_distance / 25.0) % 8
	elif state == &"rise":
		index = 8 if vertical_speed < -300.0 else 9
	elif state == &"fall":
		index = 10 if vertical_speed < 350.0 else 11
	elif state == &"land":
		index = 12 if landing_left > 0.09 else 13
	pose_set = &"locomotion"
	art.position = Vector2.ZERO
	locomotion_frame = index
	facing = direction
	if index < 8:
		art.texture = run_frames[index]
		# Register at the hips and soles so the arm pumps around a stable body.
		var origin_x := RUN_ORIGIN.x if direction > 0.0 else run_frames[index].region.size.x - RUN_ORIGIN.x
		art.offset = Vector2(-origin_x, -RUN_ORIGIN.y)
		art.scale = Vector2.ONE * RUN_POSE_SCALE
	else:
		art.texture = locomotion_frames[index]
		# Aerial frames retain their tucked feet above the shared ground line.
		var baseline := 307.0 if index < 12 else 300.0
		art.offset = Vector2(-locomotion_frames[index].region.size.x / 2.0, -baseline)
		art.scale = Vector2.ONE * POSE_SCALE
	art.flip_h = direction < 0.0
	art.rotation = 0.0
	art.modulate = tint
	art.show()
	show()

func blade_segment() -> PackedVector2Array:
	var origin := Vector2(frames[pose_frame].region.size.x / 2.0, BASELINE)
	var grip := (GRIPS[pose_frame] - origin) * POSE_SCALE
	var tip := (TIPS[pose_frame] - origin) * POSE_SCALE
	grip.x *= facing
	tip.x *= facing
	return PackedVector2Array([grip, tip])

func add_impact(at: Vector2) -> void:
	impacts.append({"at": at, "age": 0.0})

func hide_pose() -> void:
	art.hide()
	visible = not traces.is_empty() or not impacts.is_empty()

func reset_pose() -> void:
	traces.clear()
	impacts.clear()
	pose_frame = 0
	pose_set = &"combat"
	locomotion_frame = 0
	stride_distance = 0.0
	breath_clock = 0.0
	stroke_phase = 0.0
	hide()
	queue_redraw()

func _draw_swim_bow() -> void:
	# Work in facing-local space so the off hand, weapon and wake turn together.
	draw_set_transform(art.position, art.rotation, Vector2(facing, 1))
	var hand := swim_grip
	var p := weapon_progress
	var string_offset := 11.0 * (1.0 - smoothstep(0.0, 0.17, p)) + 2.0 * sin(p * 28.0) * exp(-6.0 * p)
	var upper := hand + Vector2(-12, -21)
	var lower := hand + Vector2(-12, 21)
	draw_polyline(PackedVector2Array([upper, hand + Vector2(-2, -12), hand, hand + Vector2(-2, 12), lower]), Color("ce995a"), 3.0, true)
	draw_polyline(PackedVector2Array([upper, hand - Vector2(12 + string_offset, 0), lower]), Color("e8dec2"), 1.3, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	if pose_set == &"swim" and art.visible and swim_weapon == &"bow":
		_draw_swim_bow()
	for i in range(1, traces.size()):
		var fade: float = 1.0 - traces[i - 1].age / 0.085
		var tip := to_local(traces[i].tip)
		var previous := to_local(traces[i - 1].tip)
		if tip.distance_to(previous) > 0.5:
			draw_line(previous, tip, Color(0.77, 1.0, 0.91, fade * 0.5), 3.0 * fade + 0.5, true)
	for impact in impacts:
		var progress: float = impact.age / 0.16
		var center := to_local(impact.at)
		for i in range(6):
			var ray := Vector2.from_angle(i * TAU / 6.0 + 0.35)
			draw_line(center + ray * (3 + progress * 12), center + ray * (8 + progress * 24), Color(1.0, 0.88, 0.58, 1.0 - progress), 2.0 * (1.0 - progress) + 0.5, true)
