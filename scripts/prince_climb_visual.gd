extends Node2D
## Four distinct upward poses and four downward poses, paced by travel.

const SHEET = preload("res://assets/prince-climb-sheet.png")
# The painted body is roughly 500 pixels tall; match the 122-pixel prince
# while allowing for bent legs and the crown in the climbing poses.
const POSE_SCALE := 0.26
const FEET_BASELINE := 560.0

var art: Sprite2D
var frames: Array[AtlasTexture] = []
var traveled := 0.0
var direction := -1.0
var pose_frame := 0

func _ready() -> void:
	art = Sprite2D.new()
	art.centered = false
	art.scale = Vector2.ONE * POSE_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { if (COLOR.a < 0.04) { discard; } }"
	var material := ShaderMaterial.new()
	material.shader = shader
	art.material = material
	add_child(art)
	var cell := Vector2(SHEET.get_size()) / Vector2(4, 2)
	for i in range(8):
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		var start := (Vector2(i % 4, i / 4) * cell).round()
		var end := (Vector2(i % 4 + 1, i / 4 + 1) * cell).round()
		atlas.region = Rect2(start, end - start)
		atlas.filter_clip = true
		frames.append(atlas)
	hide()

func show_climb(vertical: float, delta: float) -> void:
	if absf(vertical) > 0.1:
		if signf(vertical) != direction:
			traveled = 0.0
		direction = signf(vertical)
		traveled += absf(vertical) * ForestPrince.CLIMB_SPEED * delta
	pose_frame = int(traveled / 22.0) % 4 + (4 if direction > 0.0 else 0)
	art.texture = frames[pose_frame]
	art.offset = Vector2(-frames[pose_frame].region.size.x * 0.5, -FEET_BASELINE)
	show()
