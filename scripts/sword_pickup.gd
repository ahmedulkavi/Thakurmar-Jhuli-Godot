extends Area2D

const SWORD_VISUAL = preload("res://scripts/sword_visual.gd")
var collected: bool = false
var elapsed: float = 0.0
var blade: Node2D
var glow: Sprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 3
	var shape := CollisionShape2D.new()
	var bounds := RectangleShape2D.new()
	bounds.size = Vector2(48, 90)
	shape.shape = bounds
	shape.position.y = -28
	add_child(shape)
	glow = Sprite2D.new()
	glow.texture = preload("res://scenes/soft_glow.tres")
	glow.position.y = -30
	glow.scale = Vector2(1.3, 1.6)
	glow.modulate = Color(0.55, 1.0, 0.81, 0.45)
	add_child(glow)
	blade = Node2D.new()
	blade.set_script(SWORD_VISUAL)
	blade.aura = true
	add_child(blade)
	var label := Label.new()
	label.text = "FOREST BLADE"
	label.position = Vector2(-75, -SWORD_VISUAL.BLADE_LENGTH - 42.0)
	label.size.x = 150
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("e8e7bf"))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color("122d2d"))
	add_child(label)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	elapsed += delta
	blade.position.y = sin(elapsed * 2.5) * 4.0
	glow.modulate.a = 0.36 + sin(elapsed * 3.0) * 0.1

func _on_body_entered(body: Node2D) -> void:
	if not collected and body is ForestPrince and body.health > 0:
		collected = true
		body.equip_sword()
		hide()

func reset_pickup() -> void:
	collected = false
	elapsed = 0.0
	show()
