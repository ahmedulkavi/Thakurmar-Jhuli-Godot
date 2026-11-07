extends CharacterBody2D
## A single collectible coin carries the defeated enemy's Essence value.

signal collected(amount: int)

const COIN_TEXTURE = preload("res://scenes/essence_coin.tres")
const PICKUP_DELAY := 0.35
const GRAVITY := 1800.0

var amount := 0
var age := 0.0
var claimed := false
var coin_art: Sprite2D
var aura: Sprite2D
var pickup_area: Area2D
var art_scale := 1.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 9
	z_index = 3
	velocity = Vector2(0, -140)
	var collider := CollisionShape2D.new()
	var body := CircleShape2D.new()
	body.radius = 7.0
	collider.position.y = -7.0
	collider.shape = body
	add_child(collider)
	pickup_area = Area2D.new()
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 2
	pickup_area.position.y = -20.0
	var pickup_shape := CollisionShape2D.new()
	var reach := CircleShape2D.new()
	reach.radius = 28.0
	pickup_shape.shape = reach
	pickup_area.add_child(pickup_shape)
	add_child(pickup_area)
	pickup_area.body_entered.connect(_on_body_entered)
	aura = Sprite2D.new()
	aura.texture = preload("res://scenes/soft_glow.tres")
	aura.position.y = -22.0
	aura.scale = Vector2(0.95, 0.95)
	aura.modulate = Color(0.66, 0.88, 1.0, 0.45)
	add_child(aura)
	coin_art = Sprite2D.new()
	coin_art.name = "CoinArt"
	coin_art.texture = COIN_TEXTURE
	coin_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art_scale = 40.0 / float(COIN_TEXTURE.get_width())
	coin_art.scale = Vector2.ONE * art_scale
	coin_art.position.y = -22.0
	add_child(coin_art)
	var value_label := Label.new()
	value_label.text = "+%d" % amount
	value_label.position = Vector2(-35, -57)
	value_label.size = Vector2(70, 20)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color("e9f8ff"))
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.add_theme_color_override("font_outline_color", Color("122d3b"))
	add_child(value_label)

func _physics_process(delta: float) -> void:
	if claimed:
		return
	age += delta
	velocity.y = minf(velocity.y + GRAVITY * delta, 850.0)
	move_and_slide()
	# Compress and mirror the face for a readable coin rotation in 2D.
	var turn := cos(age * 4.2)
	coin_art.scale.x = art_scale * (0.14 + 0.86 * absf(turn))
	coin_art.flip_h = turn < 0.0
	coin_art.position.y = -22.0 + sin(age * 3.0) * 2.5
	aura.position.y = coin_art.position.y
	aura.modulate.a = 0.35 + 0.10 * sin(age * 2.4)
	if age >= PICKUP_DELAY:
		for body in pickup_area.get_overlapping_bodies():
			_on_body_entered(body)
			if claimed:
				break

func _on_body_entered(body: Node2D) -> void:
	if claimed or age < PICKUP_DELAY or not body is ForestPrince or body.health <= 0 or body.is_resting:
		return
	claimed = true
	collected.emit(amount)
	queue_free()
