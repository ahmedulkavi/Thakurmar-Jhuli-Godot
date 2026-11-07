extends Node2D
## Quiet drifting leaves in the middle parallax layer, away from gameplay.

const LEAF_COUNT := 20
const LOOP_WIDTH := 2900.0
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	for i in range(LEAF_COUNT):
		var seed := float(i)
		var x := fposmod(seed * 673.0 + elapsed * (6.0 + fmod(seed, 4.0)) + sin(elapsed * 0.7 + seed) * 18.0, LOOP_WIDTH)
		var y := fposmod(seed * 131.0 + elapsed * (4.0 + fmod(seed, 3.0)), 590.0) - 175.0
		var angle := sin(elapsed * 1.1 + seed * 2.3) * 0.8 + seed
		var size := 2.0 + fmod(seed, 3.0) * 0.5
		var color := Color(0.61, 0.76, 0.55, 0.32) if i % 3 else Color(0.80, 0.76, 0.48, 0.28)
		draw_set_transform(Vector2(x, y), angle, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-size, 0), Vector2(0, -size * 0.45), Vector2(size, 0), Vector2(0, size * 0.45)]), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
