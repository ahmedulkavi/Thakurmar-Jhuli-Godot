extends Node2D
## Riverbank transition, submerged palace scenery, and water encounters.

signal enemy_defeated(at: Vector2, value: int)

const BANK = preload("res://assets/riverbank.png")
const PALACE = preload("res://assets/underwater-kingdom.png")
const WATER_ENEMY = preload("res://scripts/water_enemy.gd")
const WATER_START := ForestPrince.WATER_START_X
const WATER_SURFACE := ForestPrince.WATERLINE_Y
const WORLD_END := 19000.0
const SEABED_Y := 1100.0

var player: ForestPrince
var enemies: Array[CharacterBody2D] = []
var backdrop := Sprite2D.new()
var boss: CharacterBody2D
var gate_collision: CollisionShape2D
var fog_prompt: Label
var time := 0.0

func _ready() -> void:
	name = "UnderwaterKingdom"
	var far_bank := Sprite2D.new()
	far_bank.name = "FarShore"
	far_bank.texture = preload("res://assets/forest-background.png")
	far_bank.centered = false
	far_bank.position = Vector2(8620, -260)
	far_bank.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	far_bank.region_enabled = true
	far_bank.region_rect = Rect2(Vector2.ZERO, Vector2(ForestPrince.DRY_HALL_X - far_bank.position.x, far_bank.texture.get_height()))
	far_bank.scale.y = 1120.0 / far_bank.texture.get_height()
	far_bank.modulate = Color(0.72, 0.84, 0.84)
	far_bank.z_index = -9
	add_child(far_bank)
	backdrop.name = "SubmergedPalace"
	backdrop.texture = PALACE
	backdrop.centered = false
	backdrop.position = Vector2(9150, WATER_SURFACE - 14.0)
	# Anchor the painted surface and floor to the world, independently of swim depth.
	backdrop.scale = Vector2.ONE * (800.0 / PALACE.get_height())
	backdrop.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	backdrop.region_enabled = true
	backdrop.region_rect = Rect2(0, 0, (ForestPrince.DRY_HALL_X - backdrop.position.x) / backdrop.scale.x, PALACE.get_height())
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backdrop.material = _shore_fade(0.13, 0.0, 0.045)
	backdrop.z_index = -8
	add_child(backdrop)
	var bank := Sprite2D.new()
	bank.name = "Riverbank"
	bank.texture = BANK
	bank.centered = false
	bank.position = Vector2(8690, 354)
	bank.scale = Vector2(1390.0 / BANK.get_width(), 350.0 / BANK.get_height())
	bank.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bank.material = _shore_fade(0.22, 0.37, 0.0, 0.22)
	bank.z_index = 0
	add_child(bank)
	var slope := StaticBody2D.new()
	slope.name = "Riverbed"
	slope.add_to_group("landing_stone")
	slope.collision_layer = 1
	slope.collision_mask = 0
	var bank_collision := CollisionPolygon2D.new()
	# The palace painting supplies the seabed visuals; this slope is collision only.
	# Keep the bank level across the forest floor's end so its vertical face stays buried.
	bank_collision.polygon = PackedVector2Array([Vector2(9100, 586), Vector2(9190, 586), Vector2(9300, 600), Vector2(9550, 720), Vector2(9800, 900), Vector2(10000, SEABED_Y), Vector2(ForestPrince.HALL_APPROACH_X, SEABED_Y), Vector2(ForestPrince.DRY_HALL_X, ForestPrince.HALL_FLOOR_Y), Vector2(WORLD_END, ForestPrince.HALL_FLOOR_Y), Vector2(WORLD_END, 1400), Vector2(9100, 1400)])
	slope.add_child(bank_collision)
	add_child(slope)
	var water := Polygon2D.new()
	water.name = "WaterTint"
	water.polygon = PackedVector2Array([Vector2(WATER_START, WATER_SURFACE - 4), Vector2(ForestPrince.DRY_HALL_X, WATER_SURFACE - 4), Vector2(ForestPrince.DRY_HALL_X, 1400), Vector2(WATER_START, 1400)])
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		varying vec2 shore;
		void vertex() { shore = VERTEX; }
		uniform vec2 origin;
		uniform vec2 hall_entrance;
		void fragment() {
			vec2 p = shore - origin;
			float wave = sin(p.x * 0.022 + TIME * 1.4) * 1.6 + sin(p.x * 0.051 - TIME) * 0.7;
			float depth = p.y - wave;
			float foam = exp(-abs(depth) * 0.7) * (0.55 + 0.45 * sin(p.x * 0.038 + TIME));
			float edge = smoothstep(0.0, 165.0, p.x);
			edge *= 1.0 - smoothstep(hall_entrance.x, hall_entrance.y, shore.x);
			COLOR = vec4(mix(vec3(0.04, 0.39, 0.44), vec3(0.65, 0.94, 0.86), foam),
				edge * (0.16 * smoothstep(-1.0, 70.0, depth) + 0.48 * foam));
		}"""
	var water_material := ShaderMaterial.new()
	water_material.shader = shader
	water_material.set_shader_parameter("origin", Vector2(WATER_START, WATER_SURFACE))
	water_material.set_shader_parameter("hall_entrance", Vector2(ForestPrince.HALL_APPROACH_X, ForestPrince.DRY_HALL_X))
	water.material = water_material
	water.z_index = 4
	add_child(water)
	for entry in [["eel", Vector2(10150, 745)], ["sentinel", Vector2(10700, 910)], ["eel", Vector2(11350, 690)], ["sentinel", Vector2(12000, 870)], ["eel", Vector2(12700, 790)], ["sentinel", Vector2(13400, 710)], ["eel", Vector2(14100, 905)], ["naga", Vector2(14680, 820)], ["sentinel", Vector2(15280, 765)], ["naga", Vector2(15980, 870)]]:
		var enemy := CharacterBody2D.new()
		enemy.set_script(WATER_ENEMY)
		enemy.kind = StringName(entry[0])
		enemy.position = entry[1]
		enemy.player = player
		enemy.defeated.connect(func(at: Vector2, value: int) -> void: enemy_defeated.emit(at, value))
		add_child(enemy)
		enemies.append(enemy)

	var hall := Sprite2D.new()
	hall.name = "DryThroneHall"
	hall.texture = preload("res://assets/tidal-throne.png")
	hall.centered = false
	var hall_width := WORLD_END - ForestPrince.HALL_APPROACH_X
	hall.scale = Vector2.ONE * (hall_width / hall.texture.get_width())
	# Feet and fountain bases sit on the tiles, above the painted front fascia.
	hall.position = Vector2(ForestPrince.HALL_APPROACH_X, ForestPrince.HALL_FLOOR_Y - hall.texture.get_height() * hall.scale.y * 0.845)
	hall.material = _shore_fade((ForestPrince.DRY_HALL_X - ForestPrince.HALL_APPROACH_X) / hall_width, 0.0, 0.0)
	hall.z_index = -6
	add_child(hall)
	_build_hall_approach()
	boss = preload("res://scripts/other_prince.gd").new()
	boss.player = player
	boss.position = Vector2(WORLD_END - 620, ForestPrince.HALL_FLOOR_Y)
	add_child(boss)
	_build_fog_gate()
	boss.started.connect(_seal_fog_gate)
	boss.ended.connect(_sync_fog_gate)
	boss.defeated.connect(_sync_fog_gate)
	boss.encounter_reset.connect(_sync_fog_gate)

func _build_fog_gate() -> void:
	var gate := StaticBody2D.new()
	gate.name = "OtherPrinceFogBarrier"
	gate.position = Vector2(boss.ENTRY_X, ForestPrince.HALL_FLOOR_Y - 650.0)
	gate.collision_layer = 1
	gate.collision_mask = 0
	gate_collision = CollisionShape2D.new()
	var wall := RectangleShape2D.new()
	wall.size = Vector2(24, 2600)
	gate_collision.shape = wall
	gate.add_child(gate_collision)
	add_child(gate)
	fog_prompt = Label.new()
	fog_prompt.name = "OtherPrinceFogPrompt"
	fog_prompt.text = "E / RB  TRAVERSE THE FOG"
	fog_prompt.position = Vector2(boss.ENTRY_X - 250, ForestPrince.HALL_FLOOR_Y - 230)
	fog_prompt.size = Vector2(500, 30)
	fog_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fog_prompt.add_theme_font_size_override("font_size", 14)
	fog_prompt.add_theme_color_override("font_color", Color("edf0dc"))
	fog_prompt.add_theme_constant_override("outline_size", 5)
	fog_prompt.add_theme_color_override("font_outline_color", Color("101927"))
	fog_prompt.z_index = 6
	fog_prompt.hide()
	add_child(fog_prompt)

func can_enter() -> bool:
	return not boss.active and boss.health > 0 and player.health > 0 and not player.is_resting and not player.in_water and player.is_on_floor() and player.position.x < boss.ENTRY_X and absf(player.position.x - boss.ENTRY_X) < 85.0

func traverse() -> bool:
	if not can_enter():
		return false
	player.position.x = boss.ENTRY_X + 65.0
	player.velocity = Vector2.ZERO
	boss.begin()
	return true

func _seal_fog_gate() -> void:
	gate_collision.set_deferred("disabled", false)
	fog_prompt.hide()

func _sync_fog_gate() -> void:
	gate_collision.set_deferred("disabled", boss.health <= 0)
	queue_redraw()

func _build_hall_approach() -> void:
	# A submerged stone sill rises into the hall instead of ending at a vertical seam.
	var start := Vector2(ForestPrince.HALL_APPROACH_X, SEABED_Y)
	var end := Vector2(ForestPrince.DRY_HALL_X, ForestPrince.HALL_FLOOR_Y)
	var sill := Polygon2D.new()
	sill.name = "PalaceThreshold"
	sill.texture = preload("res://assets/tidal-throne.png")
	sill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sill.z_index = -5
	# Feather both ends into the seabed and the hall's existing painted tiles.
	# Intermediate vertices keep the central stonework solid while the ends blend.
	sill.polygon = PackedVector2Array([start, start.lerp(end, 0.2), start.lerp(end, 0.8), end, end + Vector2(0, 36), start.lerp(end, 0.8) + Vector2(0, 36), start.lerp(end, 0.2) + Vector2(0, 36), start + Vector2(0, 36)])
	var texture_scale := (WORLD_END - ForestPrince.HALL_APPROACH_X) / sill.texture.get_width()
	var uv := PackedVector2Array()
	for i in range(sill.polygon.size()):
		uv.append(Vector2((sill.polygon[i].x - start.x) / texture_scale, sill.texture.get_height() * (0.845 if i < 4 else 0.88)))
	sill.uv = uv
	sill.vertex_colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color(0.6, 0.6, 0.6, 0), Color(0.6, 0.6, 0.6), Color(0.6, 0.6, 0.6), Color(0.6, 0.6, 0.6, 0)])
	add_child(sill)

func _shore_fade(left: float, right: float, top: float, bottom: float = 0.0) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform vec4 feather;
		void fragment() {
			vec4 edges = vec4(UV.x, 1.0 - UV.x, UV.y, 1.0 - UV.y);
			vec4 alpha = mix(vec4(1.0), smoothstep(vec4(0.0), max(feather, vec4(0.00001)), edges), step(vec4(0.00001), feather));
			COLOR.a *= alpha.x * alpha.y * alpha.z * alpha.w;
		}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("feather", Vector4(left, right, top, bottom))
	return material

func reset_enemies() -> void:
	for child in get_children():
		if child.get_script() == preload("res://scripts/water_bolt.gd"):
			child.queue_free()
	for enemy in enemies:
		enemy.reset_enemy()

func _process(delta: float) -> void:
	time += delta
	fog_prompt.visible = can_enter()
	if player.position.x > 8500:
		queue_redraw()

func _draw() -> void:
	if is_instance_valid(boss) and boss.health > 0:
		# Tall, animated strands seal the dry hall from floor to ceiling.
		for i in range(13):
			var points := PackedVector2Array()
			for j in range(25):
				var y := ForestPrince.HALL_FLOOR_Y - 1100.0 + j * 46.0
				var x: float = boss.ENTRY_X + (i - 6) * 4.0 + sin(time * (0.9 + i * 0.035) + j * 0.38 + i) * 14.0
				points.append(Vector2(x, y))
			draw_polyline(points, Color(0.70, 0.84, 0.88, 0.10 + (i % 3) * 0.025), 9.0, true)
	# A continuous waterline and rising motes bridge the bank and palace art.
	for i in range(55):
		var x := WATER_START + 85.0 + fmod(float(i) * 151.0, ForestPrince.DRY_HALL_X - WATER_START - 150.0)
		var y := WATER_SURFACE + 65.0 + fposmod(float(i * 113) - time * (14.0 + float(i % 5) * 4.0), 760.0)
		var radius := 2.0 + float(i % 4) * 1.1
		var opacity := (0.17 + 0.05 * float(i % 3)) * (1.0 - smoothstep(ForestPrince.HALL_APPROACH_X, ForestPrince.DRY_HALL_X, x))
		draw_arc(Vector2(x + sin(time * 0.7 + i) * 8.0, y), radius, 0, TAU, 12, Color(0.72, 1.0, 0.96, opacity), 1.5, true)
