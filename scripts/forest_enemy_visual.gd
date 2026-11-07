extends Node2D
## Painted poses share a foot origin; motion and combat have distinct silhouettes.

const SHEET = preload("res://assets/forest-shade-animations.png")
const BASELINES: Array[float] = [290, 289, 289, 285, 278, 280, 280, 277, 270, 271, 271, 271, 273, 273, 273, 272]
@export var height: float = 136.5
var art: Sprite2D
var frames: Array[AtlasTexture] = []
var pose_frame: int = 0
var distance_walked: float = 0.0
var clock: float = 0.0
var pose_scale: float = 1.0

func _ready() -> void:
	pose_scale = height / 270.0
	art = Sprite2D.new()
	art.centered = false
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { if (COLOR.a < 0.045) { discard; } }"
	var pose_material := ShaderMaterial.new()
	pose_material.shader = shader
	art.material = pose_material
	add_child(art)
	var cell := Vector2(SHEET.get_size()) / 4.0
	for i in range(16):
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		var start := (Vector2(i % 4, i / 4) * cell).round()
		var end := (Vector2(i % 4 + 1, i / 4 + 1) * cell).round()
		atlas.region = Rect2(start, end - start)
		atlas.filter_clip = true
		frames.append(atlas)

func animate_pose(pose: StringName, elapsed: float, direction: float, tint: Color, horizontal_speed: float, delta: float) -> void:
	clock += delta
	var index := 0
	match pose:
		&"chase", &"return":
			distance_walked = fmod(distance_walked + absf(horizontal_speed) * delta, 88.0)
			index = 1 + int(distance_walked / 22.0) % 4
		&"windup":
			index = 5 if elapsed < 0.18 else 6
		&"lunge":
			index = 7 if elapsed < 0.09 else 8
		&"recover":
			index = 9
		&"jump_windup":
			index = 10
		&"rise":
			index = 11
		&"fall":
			index = 12
		&"land":
			index = 13
		&"hurt":
			index = 14
		&"dead":
			index = 15
	pose_frame = index
	art.texture = frames[index]
	var origin_x := 165.0 if direction > 0.0 else frames[index].region.size.x - 165.0
	art.offset = Vector2(-origin_x, -BASELINES[index])
	art.flip_h = direction < 0.0
	art.scale = Vector2.ONE * pose_scale
	if pose == &"idle":
		art.scale.y *= 1.0 + sin(clock * 2.8) * 0.012
	art.modulate = tint

func reset_visual() -> void:
	clock = 0.0
	distance_walked = 0.0
	animate_pose(&"idle", 0.0, -1.0, Color.WHITE, 0.0, 0.0)
