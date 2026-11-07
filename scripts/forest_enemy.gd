extends CharacterBody2D
## A forest shade: approaches, telegraphs a lunge, then recovers.

const MAX_HEALTH: int = 3
const SIZE_MULTIPLIER: float = 1.75
const CONTACT_REACH: float = 22.0 + 42.0 * SIZE_MULTIPLIER * 0.5
const SHADE_TEXTURE = preload("res://assets/forest-shade.png")
# Frame the painted silhouette, excluding faint alpha haze at the image edges.
const SHADE_REGION := Rect2(109, 128, 893, 1023)
var player: ForestPrince
var home := Vector2.ZERO
var health: int = MAX_HEALTH
var clock: float = 0.0
var hurt_left: float = 0.0
var attack_left: float = 0.0
var attack_direction: float = 1.0
var recovery_left: float = 0.0
var knockback_left: float = 0.0
var glow: Sprite2D
var art: Sprite2D
var art_scale: float = 1.0

func _ready() -> void:
	home = position
	collision_layer = 4
	collision_mask = 1
	z_index = 2
	add_to_group("combat_targets")
	var shape := CollisionShape2D.new()
	var bounds := RectangleShape2D.new()
	bounds.size = Vector2(42, 58) * SIZE_MULTIPLIER
	shape.position.y = -bounds.size.y * 0.5
	shape.shape = bounds
	add_child(shape)
	glow = Sprite2D.new()
	glow.texture = preload("res://scenes/soft_glow.tres")
	glow.position.y = -38 * SIZE_MULTIPLIER
	glow.scale = Vector2(0.95, 0.9) * SIZE_MULTIPLIER
	glow.modulate = Color(0.44, 0.8, 0.67, 0.3)
	add_child(glow)
	art = Sprite2D.new()
	art.texture = SHADE_TEXTURE
	art.region_enabled = true
	art.region_rect = SHADE_REGION
	art.centered = false
	art.offset = Vector2(-SHADE_REGION.size.x / 2.0, -SHADE_REGION.size.y)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art_scale = 78.0 * SIZE_MULTIPLIER / SHADE_REGION.size.y
	art.scale = Vector2.ONE * art_scale
	add_child(art)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	clock += delta
	hurt_left = maxf(0.0, hurt_left - delta)
	recovery_left = maxf(0.0, recovery_left - delta)
	knockback_left = maxf(0.0, knockback_left - delta)
	velocity.y = minf(velocity.y + 1800.0 * delta, 1000.0)
	var offset := player.global_position - global_position
	if knockback_left > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	elif attack_left > 0.0:
		attack_left = maxf(0.0, attack_left - delta)
		velocity.x = attack_direction * 240.0 if attack_left < 0.18 else 0.0
		if attack_left <= 0.0:
			recovery_left = 0.85
	elif player.health > 0 and absf(offset.x) < 90.0 and absf(offset.y) < 85.0 and recovery_left <= 0.0:
		attack_left = 0.55
		attack_direction = signf(offset.x) if absf(offset.x) > 1.0 else 1.0
		velocity.x = 0.0
	elif player.health > 0 and absf(offset.x) < 320.0 and absf(offset.y) < 150.0 and recovery_left <= 0.0:
		velocity.x = signf(offset.x) * 85.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	move_and_slide()
	if attack_left > 0.0 and attack_left < 0.18 and absf(offset.x) < CONTACT_REACH and absf(offset.y) < 80.0:
		player.take_damage(20, global_position)
	glow.modulate = Color(1.0, 0.42, 0.22, 0.5) if attack_left > 0.18 else Color(0.44, 0.8, 0.67, 0.3)
	art.flip_h = offset.x > 0.0
	art.scale.y = art_scale * (1.0 + sin(clock * 3.5) * 0.025)
	art.modulate = Color(1.6, 1.8, 1.5) if hurt_left > 0.0 else Color(1.3, 0.8, 0.6) if attack_left > 0.18 else Color.WHITE
	queue_redraw()

func take_damage(amount: int, source: Vector2) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	hurt_left = 0.18
	attack_left = 0.0
	recovery_left = 0.45
	knockback_left = 0.22
	var direction := signf(global_position.x - source.x)
	velocity = Vector2((direction if direction else 1.0) * 240.0, -120.0)
	if health == 0:
		set_deferred("collision_layer", 0)
		hide()
	queue_redraw()

func reset_enemy() -> void:
	position = home
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	hurt_left = 0.0
	attack_left = 0.0
	recovery_left = 0.0
	knockback_left = 0.0
	collision_layer = 4
	art.modulate = Color.WHITE
	art.scale = Vector2.ONE * art_scale
	glow.modulate = Color(0.44, 0.8, 0.67, 0.3)
	show()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * SIZE_MULTIPLIER)
	if attack_left > 0.18:
		draw_arc(Vector2(0, -40), 43, -PI * 0.8, PI * 0.3, 24, Color(1.0, 0.65, 0.3, 0.8), 2.0, true)
	if health < MAX_HEALTH:
		draw_rect(Rect2(-24, -92, 48, 5), Color("142522"))
		draw_rect(Rect2(-24, -92, 48.0 * health / MAX_HEALTH, 5), Color("c94b4b"))
