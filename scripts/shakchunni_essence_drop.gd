extends Area2D
## The boss's unique essence remains in the arena until the prince claims it.

signal collected

const ICON = preload("res://assets/essence-of-shakchunni.png")
var time := 0.0
var claimed := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	shape.shape = circle
	add_child(shape)
	var art := Sprite2D.new()
	art.name = "Art"
	art.texture = ICON
	art.scale = Vector2.ONE * (78.0 / ICON.get_height())
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(art)
	var glow := Sprite2D.new()
	glow.texture = preload("res://scenes/soft_glow.tres")
	glow.scale = Vector2.ONE * 1.6
	glow.modulate = Color(0.25, 0.95, 0.48, 0.45)
	glow.z_index = -1
	add_child(glow)
	body_entered.connect(_claim)

func _process(delta: float) -> void:
	time += delta
	$Art.position.y = sin(time * 2.6) * 5.0
	for body in get_overlapping_bodies():
		_claim(body)

func _claim(body: Node2D) -> void:
	if claimed or not body is ForestPrince or body.health <= 0:
		return
	claimed = true
	collected.emit()
	queue_free()
