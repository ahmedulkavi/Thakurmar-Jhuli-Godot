extends Node2D
## Brief silver, copper and blue energy bloom on an actual stance change.

const DURATION := 0.65
const COLORS := [Color("dceaff"), Color("dc9565"), Color("488fff")]
var time_left := 0.0

func _ready() -> void:
	z_index = -1
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow
	hide()

func burst() -> void:
	time_left = DURATION
	show()
	queue_redraw()

func clear() -> void:
	time_left = 0.0
	hide()
	queue_redraw()

func _process(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left = maxf(0.0, time_left - delta)
	visible = time_left > 0.0
	queue_redraw()

func _draw() -> void:
	if time_left <= 0.0:
		return
	var progress := 1.0 - time_left / DURATION
	var fade := sin(PI * pow(progress, 0.65))
	for band in range(3):
		var color: Color = COLORS[band]
		# Soft nested halos frame the body without tinting the painted sprite.
		draw_set_transform(Vector2(0, -64), 0.0, Vector2(0.65, 1.12))
		for layer in range(4):
			var haze := color
			haze.a = fade * 0.035
			draw_circle(Vector2.ZERO, 46.0 + band * 8.0 + layer * 5.0 + progress * 20.0, haze)
		draw_set_transform(Vector2(0, -6), 0.0, Vector2(1.0, 0.30))
		color.a = fade * 0.65
		draw_arc(Vector2.ZERO, 29.0 + progress * 77.0 + band * 10.0, 0, TAU, 64, color, 2.0, true)
		draw_set_transform(Vector2.ZERO)
		# Three spirals of rising metal-colored sparks accompany the blue bloom.
		for spark in range(7):
			var phase := spark * TAU / 7.0 + band * TAU / 3.0 + progress * 3.6
			var radius := 27.0 + progress * 37.0
			var at := Vector2(cos(phase) * radius, -12.0 - spark * 15.0 - progress * 32.0 + sin(phase) * 11.0)
			var size := 1.5 + fade * 1.3
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -size * 2), at + Vector2(size, 0), at + Vector2(0, size * 2), at + Vector2(-size, 0)]), color)
