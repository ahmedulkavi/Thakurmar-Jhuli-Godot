extends Node2D
## Glowing pickup blade, sized to match the prince's painted armed sprites.

# The painted combat guard has a 47.5 px grip-to-tip length. Apply that same
# uniform size to the original 69 px drawing, including its hilt and guard.
const BLADE_LENGTH: float = 47.5
const DRAW_SCALE: float = BLADE_LENGTH / 69.0

@export var aura: bool = false

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * DRAW_SCALE)
	if aura:
		for i in range(5, 0, -1):
			draw_line(Vector2(0, -8), Vector2(0, -65), Color(0.5, 1.0, 0.88, 0.035), i * 9.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -13), Vector2(-5, -56), Vector2(0, -69), Vector2(5, -56), Vector2(6, -13), Vector2(0, -8)]), Color("89c8ca"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -66), Vector2(4, -55), Vector2(4, -14), Vector2(0, -10)]), Color("e4fff3"))
	draw_line(Vector2(0, -15), Vector2(0, -55), Color("faffdf"), 1.5, true)
	draw_line(Vector2(-14, -9), Vector2(14, -9), Color("413f31"), 7.0, true)
	draw_line(Vector2(-14, -11), Vector2(0, -8), Color("e4c67d"), 4.0, true)
	draw_line(Vector2(0, -8), Vector2(14, -11), Color("e4c67d"), 4.0, true)
	draw_line(Vector2.ZERO, Vector2(0, 12), Color("4b3934"), 7.0, true)
	for y in range(0, 12, 4):
		draw_line(Vector2(-3, y), Vector2(3, y + 2), Color("b39562"), 1.0, true)
	draw_circle(Vector2(0, 15), 4.5, Color("e4c67d"))
	draw_circle(Vector2(0, -9), 3.0, Color("b7ffe2"))
