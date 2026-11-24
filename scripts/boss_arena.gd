extends Node2D
## Fog gate, encounter lifetime, and a one-way staircase of floating islands.

signal encounter_started
signal encounter_reset
signal boss_defeated

const FOG_X := 7060.0
const ENTRANCE_BLEND_RADIUS := 300.0
const BOSS_X := 8510.0
const ARENA_END := 9200.0
const BACKGROUND = preload("res://assets/shakchunni-arena.png")
const ISLAND = preload("res://assets/floating-amulet-island.png")
const BOSS_SCRIPT = preload("res://scripts/shakchunni.gd")

var player: ForestPrince
var boss: CharacterBody2D
var gate: StaticBody2D
var gate_collision: CollisionShape2D
var exit_collision: CollisionShape2D
var prompt: Label
var active := false
var beaten := false
var clock := 0.0
var victory_delay := -1.0
var islands: Array[StaticBody2D] = []

func _ready() -> void:
	name = "ShakchunniArena"
	var background := Sprite2D.new()
	background.name = "DarkForest"
	background.texture = BACKGROUND
	background.centered = false
	var backdrop_start := FOG_X - ENTRANCE_BLEND_RADIUS
	background.position = Vector2(backdrop_start, -260)
	background.scale = Vector2((ARENA_END - backdrop_start) / BACKGROUND.get_width(), 980.0 / BACKGROUND.get_height())
	var edge_shader := Shader.new()
	edge_shader.code = """
		shader_type canvas_item;
		varying float world_x;
		void vertex() { world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x; }
		uniform float bank_end;
		uniform vec2 entrance;
		void fragment() {
			float fade_in = smoothstep(entrance.x, entrance.y, world_x);
			float fade_out = 1.0 - smoothstep(bank_end - 420.0, bank_end, world_x);
			COLOR.a *= fade_in * fade_out;
		}
		"""
	var edge_material := ShaderMaterial.new()
	edge_material.shader = edge_shader
	edge_material.set_shader_parameter("bank_end", ARENA_END)
	edge_material.set_shader_parameter("entrance", Vector2(backdrop_start, FOG_X + ENTRANCE_BLEND_RADIUS))
	background.material = edge_material
	background.z_index = -6 # Behind the walkable forest floor, above the parallax trees.
	add_child(background)
	var darkness := Polygon2D.new()
	darkness.name = "ArenaDarkness"
	darkness.polygon = PackedVector2Array([Vector2(backdrop_start, -260), Vector2(ARENA_END, -260), Vector2(ARENA_END, 720), Vector2(backdrop_start, 720)])
	darkness.color = Color(0.012, 0.025, 0.04, 0.48)
	darkness.material = edge_material
	darkness.z_index = -1
	add_child(darkness)
	for pos in [Vector2(7280, 505), Vector2(7460, 415), Vector2(7640, 325), Vector2(7820, 415), Vector2(7990, 325), Vector2(8160, 235), Vector2(8370, 315), Vector2(8620, 410)]:
		_make_island(pos)
	boss = CharacterBody2D.new()
	boss.name = "Shakchunni"
	boss.set_script(BOSS_SCRIPT)
	boss.position = Vector2(BOSS_X, 586)
	boss.player = player
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	gate = StaticBody2D.new()
	gate.name = "FogBarrier"
	gate.position = Vector2(FOG_X, 200)
	gate.collision_layer = 1
	gate.collision_mask = 0
	gate_collision = CollisionShape2D.new()
	var wall := RectangleShape2D.new()
	wall.size = Vector2(24, 1300)
	gate_collision.shape = wall
	gate.add_child(gate_collision)
	add_child(gate)
	var exit_gate := StaticBody2D.new()
	exit_gate.name = "RiverExitBarrier"
	exit_gate.position = Vector2(ARENA_END, 400)
	exit_gate.collision_layer = 1
	exit_gate.collision_mask = 0
	exit_collision = CollisionShape2D.new()
	var exit_wall := RectangleShape2D.new()
	exit_wall.size = Vector2(24, 1300)
	exit_collision.shape = exit_wall
	exit_gate.add_child(exit_collision)
	add_child(exit_gate)
	prompt = Label.new()
	prompt.text = "E / RB  TRAVERSE THE FOG"
	prompt.position = Vector2(FOG_X - 250, 355)
	prompt.size = Vector2(500, 30)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color("edf0dc"))
	prompt.add_theme_constant_override("outline_size", 5)
	prompt.add_theme_color_override("font_outline_color", Color("101927"))
	prompt.hide()
	add_child(prompt)
	z_index = 3

func _process(delta: float) -> void:
	clock += delta
	prompt.visible = can_enter()
	if victory_delay >= 0.0:
		victory_delay -= delta
		if victory_delay < 0.0:
			boss_defeated.emit()
	queue_redraw()

func can_enter() -> bool:
	return not active and not beaten and player.health > 0 and not player.is_resting and player.is_on_floor() and absf(player.global_position.x - FOG_X) < 85.0 and player.global_position.x < FOG_X

func traverse() -> bool:
	if not can_enter():
		return false
	active = true
	player.position = Vector2(FOG_X + 65.0, player.position.y)
	player.velocity = Vector2.ZERO
	boss.begin()
	encounter_started.emit()
	return true

func reset_encounter() -> void:
	active = false
	beaten = false
	victory_delay = -1.0
	gate_collision.set_deferred("disabled", false)
	exit_collision.set_deferred("disabled", false)
	boss.reset_boss()
	encounter_reset.emit()

func _on_boss_defeated() -> void:
	active = false
	beaten = true
	gate_collision.set_deferred("disabled", true)
	exit_collision.set_deferred("disabled", true)
	victory_delay = 1.6

func _make_island(at: Vector2) -> void:
	var island := StaticBody2D.new()
	island.add_to_group("landing_grass")
	island.name = "FloatingIsland%d" % islands.size()
	island.position = at
	island.collision_layer = 8
	island.collision_mask = 0
	var factor := 220.0 / ISLAND.get_width()
	var origin := Vector2(-110, -7)
	var deck := Rect2(origin + Vector2(70, 270) * factor, Vector2(1570, 70) * factor)
	var hitbox := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = deck.size
	hitbox.shape = shape
	hitbox.position = deck.get_center()
	hitbox.one_way_collision = true
	island.add_child(hitbox)
	var art := Sprite2D.new()
	art.texture = ISLAND
	art.centered = false
	art.position = origin
	art.scale = Vector2.ONE * factor
	art.modulate = Color(0.65, 0.72, 0.72)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	island.add_child(art)
	add_child(island)
	islands.append(island)

func _draw() -> void:
	if beaten:
		return
	# Multiple translucent strands move independently behind the solid barrier.
	for i in range(13):
		var points := PackedVector2Array()
		for j in range(22):
			var y := -260.0 + j * 46.0
			var x := FOG_X + (i - 6) * 4.0 + sin(clock * (0.9 + i * 0.035) + j * 0.38 + i) * 14.0
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.70, 0.78, 0.83, 0.08 + (i % 3) * 0.025), 9.0, true)
