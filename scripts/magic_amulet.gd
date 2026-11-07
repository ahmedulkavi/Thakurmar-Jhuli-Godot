class_name MagicAmulet
extends Area2D
## Floating healing amulet collected on the upper island.

const AMULET_TEXTURE = preload("res://assets/healing-amulet.png")

var collected := false
var elapsed := 0.0
var art: Sprite2D
var glow: Sprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 4
	var shape := CollisionShape2D.new()
	var bounds := RectangleShape2D.new()
	bounds.size = Vector2(72, 104)
	shape.shape = bounds
	shape.position.y = -48
	add_child(shape)
	glow = Sprite2D.new()
	glow.texture = preload("res://scenes/soft_glow.tres")
	glow.position.y = -62
	glow.scale = Vector2(1.8, 1.8)
	glow.modulate = Color(0.26, 0.77, 1.0, 0.38)
	add_child(glow)
	art = Sprite2D.new()
	art.texture = AMULET_TEXTURE
	art.position.y = -62
	art.scale = Vector2.ONE * (74.0 / float(AMULET_TEXTURE.get_width()))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(art)
	var label := Label.new()
	label.text = "HEALING AMULET"
	label.position = Vector2(-90, -124)
	label.size = Vector2(180, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("bdefff"))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color("102526"))
	add_child(label)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	elapsed += delta
	var bob := sin(elapsed * 2.3) * 5.0
	art.position.y = -62.0 + bob
	art.rotation = sin(elapsed * 1.2) * 0.045
	glow.position.y = -62.0 + bob
	glow.modulate.a = 0.32 + sin(elapsed * 3.1) * 0.1

func _on_body_entered(body: Node2D) -> void:
	if collected or not body is ForestPrince or body.health <= 0:
		return
	collected = true
	body.equip_amulet()
	hide()

func reset_pickup() -> void:
	collected = false
	elapsed = 0.0
	show()
