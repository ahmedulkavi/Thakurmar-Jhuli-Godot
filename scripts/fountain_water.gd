extends Node2D
## Small moving highlights follow the painted spout and pool.

var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	# Narrow, staggered highlights travel down the existing turquoise stream.
	for i in range(5):
		var x := -2.7 + float(i) * 1.4
		var phase := fposmod(elapsed * (22.0 + i * 2.2) + i * 7.3, 28.0)
		var y := -104.0 + phase
		var end_y := minf(y + 3.5 + float(i % 2), -74.0)
		draw_line(Vector2(x, y), Vector2(x + 0.5, end_y), Color(0.68, 1.0, 0.97, 0.44), 0.8, true)
	# Low, elliptical ripples spread out where the stream meets the water.
	for i in range(2):
		var progress := fposmod(elapsed * 0.48 + float(i) * 0.5, 1.0)
		var radius := 2.0 + progress * 16.0
		var points := PackedVector2Array()
		for j in range(33):
			var angle := TAU * float(j) / 32.0
			points.append(Vector2(cos(angle) * radius, -73.0 + sin(angle) * radius * 0.20))
		draw_polyline(points, Color(0.68, 1.0, 0.94, (1.0 - progress) * 0.48), 0.8, true)
