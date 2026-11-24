extends Node2D
## Painted hand animation with flexible blades anchored to each moving hilt.

const SHEET_PATH := "res://assets/other-prince-urumi-motion.png"
const FRAME_ORIGIN := Vector2(156.75, 310)
const POSE_SCALE := 125.0 / 300.0
const BLADE_LENGTH := 390.0
const BLADE_SEGMENTS := 64
# Blade-emitting silver caps in each frame, in cell-local source pixels.
# Calibrated against the animation atlas, not the character's stationary torso.
const HILTS := [
	[Vector2(242, 146), Vector2(160, 160)],
	[Vector2(257, 98), Vector2(167, 112)],
	[Vector2(224, 51), Vector2(158, 91)],
	[Vector2(164, 24), Vector2(151, 98)],
	[Vector2(166, 26), Vector2(185, 80)],
	[Vector2(204, 23), Vector2(185, 141)],
	[Vector2(293, 66), Vector2(79, 123)],
	[Vector2(274, 154), Vector2(67, 127)],
	[Vector2(267, 173), Vector2(86, 131)],
	[Vector2(256, 84), Vector2(160, 127)],
	[Vector2(276, 70), Vector2(147, 116)],
	[Vector2(288, 62), Vector2(141, 103)],
	[Vector2(251, 60), Vector2(162, 92)],
	[Vector2(220, 77), Vector2(167, 91)],
	[Vector2(222, 110), Vector2(161, 124)],
	[Vector2(248, 146), Vector2(161, 150)]]
const HILT_AXES := [
	[Vector2(0.7, -0.7), Vector2(1, 0)],
	[Vector2(0.3, -1), Vector2(0.7, -0.7)],
	[Vector2(-0.3, -1), Vector2(0.7, -0.7)],
	[Vector2(0.5, 0.8), Vector2(-1, -0.4)],
	[Vector2(0.6, 0.7), Vector2(-0.8, -0.6)],
	[Vector2(0.7, 0.7), Vector2(-0.8, -0.6)],
	[Vector2(0.3, -1), Vector2(-0.2, -1)],
	[Vector2(0.8, -0.5), Vector2(-0.2, -1)],
	[Vector2(0.8, -0.5), Vector2(1, 0)],
	[Vector2(-0.3, -1), Vector2(0.8, -0.5)],
	[Vector2(-0.6, -0.8), Vector2(0.7, -0.7)],
	[Vector2(0.2, -1), Vector2(0.7, -0.7)],
	[Vector2(-0.2, -1), Vector2(0.7, -0.7)],
	[Vector2(-0.6, -0.8), Vector2(0.7, -0.7)],
	[Vector2(0.3, -1), Vector2(0.7, -0.7)],
	[Vector2(0.8, -0.5), Vector2(1, 0)]]

var art := Sprite2D.new()
var frames: Array[AtlasTexture] = []
var pose_frame := 0
var phase: StringName = &"windup"
var progress := 0.0
var facing := 1.0
var blades: Array[PackedVector2Array] = []
var trails: Array[Dictionary] = []

func _ready() -> void:
	var sheet: Texture2D = load(SHEET_PATH)
	var cell := sheet.get_size() / 4.0
	for index in range(16):
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		var start := (Vector2(index % 4, index / 4) * cell).round()
		var end := (Vector2(index % 4 + 1, index / 4 + 1) * cell).round()
		frame.region = Rect2(start, end - start)
		frame.filter_clip = true
		frames.append(frame)
	art.centered = false
	art.offset = -FRAME_ORIGIN
	art.scale = Vector2.ONE * POSE_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var clean := ShaderMaterial.new()
	clean.shader = preload("res://shaders/other_prince.gdshader")
	art.material = clean
	add_child(art)
	show_phase(&"windup", 0.0, 1.0)
	hide()

func reset_pose() -> void:
	trails.clear()
	blades.clear()
	pose_frame = 0
	phase = &"windup"
	progress = 0.0
	hide()
	queue_redraw()

func show_phase(next_phase: StringName, fraction: float, direction: float) -> void:
	phase = next_phase
	progress = clampf(fraction, 0.0, 1.0)
	facing = direction
	match phase:
		&"windup":
			pose_frame = mini(3, int(progress * 4.0))
		&"sweep":
			pose_frame = 4 + mini(7, int(progress * 8.0))
		&"recover":
			pose_frame = 12 + mini(3, int(progress * 4.0))
	art.texture = frames[pose_frame]
	art.flip_h = facing < 0.0
	# Mirroring is about the feet origin, including the authored hilt anchors.
	art.offset.x = -FRAME_ORIGIN.x if facing > 0.0 else FRAME_ORIGIN.x - frames[pose_frame].region.size.x
	blades.clear()
	for blade in range(2):
		blades.append(_build_ribbon(blade))
	show()
	queue_redraw()

func tick(delta: float) -> void:
	for trail in trails:
		trail.age += delta
	trails = trails.filter(func(trail: Dictionary) -> bool: return trail.age < 0.08)
	if visible and phase == &"sweep":
		for blade in blades:
			trails.append({"points": blade, "age": 0.0})
	queue_redraw()

func grip(blade: int) -> Vector2:
	var at: Vector2 = (HILTS[pose_frame][blade] - FRAME_ORIGIN) * POSE_SCALE
	at.x *= facing
	return at

func ribbon(blade: int) -> PackedVector2Array:
	return blades[blade] if blade < blades.size() else PackedVector2Array()

func is_striking() -> bool:
	return visible and phase == &"sweep" and progress >= 0.10 and progress < 0.90

func _build_ribbon(blade: int) -> PackedVector2Array:
	var root := grip(blade)
	root.x *= facing
	var spin := progress * TAU + blade * PI
	var angle := spin
	var extension := 0.0
	var turns := 1.7
	if phase == &"windup":
		turns = lerpf(1.8, 1.45, progress)
		angle = -PI * 0.5 - progress * TAU + blade * 0.65
	elif phase == &"sweep":
		extension = sin(PI * progress)
		turns = lerpf(1.45, 0.02, extension)
		angle = lerpf(-1.35, 1.15, progress) + blade * 0.20 - turns * 0.9
	else:
		turns = lerpf(1.45, 1.8, progress)
		angle = PI * 0.5 + spin
	# Keep the strip's length constant. It coils into circular loops near the
	# rotating hand, then unfurls during the committed sweep instead of growing.
	var axis: Vector2 = HILT_AXES[pose_frame][blade]
	var points := PackedVector2Array()
	var p := root
	points.append(Vector2(p.x * facing, p.y))
	for index in range(1, BLADE_SEGMENTS + 1):
		var t := (index - 0.5) / BLADE_SEGMENTS
		var tangent := lerp_angle(axis.angle(), angle, smoothstep(0.0, 0.12, t))
		tangent += turns * TAU * t
		tangent += sin(spin - t * TAU) * t * 0.15 * (1.0 - extension)
		p += Vector2.from_angle(tangent) * (BLADE_LENGTH / BLADE_SEGMENTS)
		points.append(Vector2(p.x * facing, p.y))
	return points

func _draw() -> void:
	for trail in trails:
		var fade := (1.0 - float(trail.age) / 0.08) * 0.12
		draw_polyline(trail.points, Color(0.57, 0.40, 0.88, fade), 4.0, true)
	for points in blades:
		draw_polyline(points, Color(0.29, 0.13, 0.48, 0.32), 6.0, true)
		draw_polyline(points, Color("34253e"), 3.2, true)
		draw_polyline(points, Color("d8c9ec"), 1.4, true)
