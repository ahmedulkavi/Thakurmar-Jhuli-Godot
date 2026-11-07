class_name ForestLadder
extends Node2D
## A vine-bound ladder that only appears after every forest bat is defeated.

const TOP_Y := 20.0
const BOTTOM_Y := 330.0
const RUNG_SPACING := 24.0
# The climber's origin is at his feet. Rails must extend above the landing
# so his hands remain supported until he steps onto the upper deck.
const HANDRAIL_HEIGHT := 150.0
const REVEAL_DURATION := 0.8
const SMOKE_DURATION := 1.25

var active := false
var reveal_elapsed := 0.0

func ready_for_climb() -> bool:
	return active and reveal_elapsed >= REVEAL_DURATION

func rail_top() -> float:
	var growth := clampf(reveal_elapsed / REVEAL_DURATION, 0.0, 1.0)
	return lerpf(BOTTOM_Y - TOP_Y, -HANDRAIL_HEIGHT, growth)

func unlock() -> void:
	active = true
	reveal_elapsed = 0.0
	show()
	set_process(true)
	queue_redraw()

func reset_ladder() -> void:
	active = false
	reveal_elapsed = 0.0
	hide()
	set_process(false)
	queue_redraw()

func _ready() -> void:
	z_index = 0
	var prompt := Label.new()
	prompt.text = "W / UP  CLIMB     S / DOWN  DESCEND"
	prompt.position = Vector2(-125, BOTTOM_Y - TOP_Y - 95)
	prompt.size = Vector2(250, 22)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 11)
	prompt.add_theme_color_override("font_color", Color("e8d9a6"))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.add_theme_color_override("font_outline_color", Color("122d2d"))
	add_child(prompt)
	hide()
	set_process(false)

func _process(delta: float) -> void:
	reveal_elapsed += delta
	queue_redraw()
	if reveal_elapsed >= SMOKE_DURATION:
		set_process(false)

func _draw() -> void:
	if not active:
		return
	var height := BOTTOM_Y - TOP_Y
	var visible_top := rail_top()
	# Dark underpainting and mossy highlights give the rails some depth.
	for side in [-1.0, 1.0]:
		var rail := PackedVector2Array()
		for i in range(25):
			var y := lerpf(visible_top, height, i / 24.0)
			rail.append(Vector2(side * 21.0 + sin(y * 0.052 + side) * 2.5, y))
		draw_polyline(rail, Color("182821"), 12.0, true)
		draw_polyline(rail, Color("66472d"), 7.0, true)
		draw_polyline(rail, Color("829269"), 1.4, true)
	# A rung at deck level supports the final step; above it are handrails.
	for i in range(0, int(height / RUNG_SPACING)):
		var y := i * RUNG_SPACING
		if y < visible_top:
			continue
		draw_line(Vector2(-21, y + 2), Vector2(21, y + 2), Color("1b2d23"), 9.0, true)
		draw_line(Vector2(-21, y), Vector2(21, y), Color("8a6440"), 6.0, true)
		draw_line(Vector2(-18, y - 2), Vector2(18, y - 2), Color("bb9c67"), 1.5, true)
	if reveal_elapsed < SMOKE_DURATION:
		var fade := 1.0 - reveal_elapsed / SMOKE_DURATION
		var smoke_y := visible_top
		for i in range(18):
			var drift := reveal_elapsed * (24.0 + float(i % 5) * 8.0)
			var x := sin(float(i) * 2.4) * (18.0 + drift) + cos(float(i) * 0.7) * 17.0
			var y := smoke_y + sin(float(i) * 1.8) * 21.0 - drift * 0.45
			var radius := 13.0 + float(i % 4) * 5.0 + drift * 0.12
			draw_circle(Vector2(x, y), radius, Color(0.29, 0.44, 0.43, 0.32 * fade), true, -1.0, true)
			draw_circle(Vector2(x, y), radius * 0.55, Color(0.83, 0.85, 0.69, 0.25 * fade), true, -1.0, true)
		for i in range(9):
			var angle := float(i) * TAU / 9.0 + 0.17
			var distance := 28.0 + reveal_elapsed * 90.0 + float(i % 3) * 10.0
			var point := Vector2(cos(angle), sin(angle)) * distance + Vector2(0, smoke_y)
			var shine := Color(0.73, 1.0, 0.82, fade * 0.75)
			draw_line(point + Vector2(-4, 0), point + Vector2(4, 0), shine, 1.5, true)
			draw_line(point + Vector2(0, -4), point + Vector2(0, 4), shine, 1.5, true)
		var flash := maxf(0.0, 1.0 - reveal_elapsed * 2.2)
		draw_arc(Vector2(0, height - 10), 42.0 + reveal_elapsed * 65.0, 0.0, TAU, 32, Color(0.66, 1.0, 0.76, flash * 0.6), 3.0, true)
