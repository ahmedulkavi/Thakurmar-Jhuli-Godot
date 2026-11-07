extends CharacterBody2D
## A hovering enemy that warns, commits to a dive, then returns to its roost.

const MAX_HEALTH := 2
const DAMAGE := 15
const SIGHT_RANGE := 270.0
const DIVE_SPEED := 340.0
const BAT_TEXTURE = preload("res://assets/forest-bat.png")
const BAT_WINGS = preload("res://shaders/bat_wings.gdshader")

var player: ForestPrince
var home := Vector2.ZERO
var health := MAX_HEALTH
var state: StringName = &"patrol"
var state_left := 0.0
var clock := 0.0
var facing := -1.0
var dive_direction := Vector2.ZERO
var dive_hit := false
var hurt_left := 0.0
var death_left := 0.0
var art: Sprite2D
var glow: Sprite2D
var wing_material: ShaderMaterial

func _ready() -> void:
	home = position
	collision_layer = 4
	collision_mask = 1
	z_index = 2
	add_to_group("combat_targets")
	var collision := CollisionShape2D.new()
	var body := RectangleShape2D.new()
	body.size = Vector2(64, 40)
	collision.position.y = -25
	collision.shape = body
	add_child(collision)
	glow = Sprite2D.new()
	glow.texture = preload("res://scenes/soft_glow.tres")
	glow.position.y = -25
	glow.scale = Vector2(0.7, 0.5)
	glow.modulate = Color(0.38, 0.85, 0.78, 0.22)
	add_child(glow)
	art = Sprite2D.new()
	art.texture = BAT_TEXTURE
	art.position.y = -25
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	wing_material = ShaderMaterial.new()
	wing_material.shader = BAT_WINGS
	art.material = wing_material
	add_child(art)
	_update_art()

func _physics_process(delta: float) -> void:
	clock += delta
	hurt_left = maxf(0.0, hurt_left - delta)
	if health <= 0:
		death_left = maxf(0.0, death_left - delta)
		art.modulate.a = death_left / 0.4
		glow.modulate.a = 0.22 * death_left / 0.4
		if death_left <= 0.0:
			hide()
		return
	state_left = maxf(0.0, state_left - delta)
	var target := player.global_position + Vector2(0, -60)
	var center := global_position + Vector2(0, -25)
	match state:
		&"hurt":
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if state_left <= 0.0:
				state = &"return"
		&"windup":
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if state_left <= 0.0:
				dive_direction = (target - center).normalized()
				state = &"dive"
				state_left = 0.65
				dive_hit = false
		&"dive":
			velocity = dive_direction * DIVE_SPEED
			if not dive_hit and center.distance_to(target) < 48.0 and _has_line_of_sight(center, target):
				dive_hit = player.take_damage(DAMAGE, global_position)
			if state_left <= 0.0 or dive_hit:
				state = &"return"
				state_left = 0.8
		_:
			var destination := home + Vector2(sin(clock * 1.3) * 55.0, sin(clock * 2.2) * 12.0) if state == &"patrol" else home
			var displacement := destination - global_position
			velocity = displacement.limit_length(100.0) * 2.0
			if state == &"return" and displacement.length() < 20.0 and state_left <= 0.0:
				state = &"patrol"
			if state == &"patrol" and player.health > 0 and center.distance_to(target) < SIGHT_RANGE and _has_line_of_sight(center, target):
				state = &"windup"
				state_left = 0.4
				facing = signf(target.x - center.x) if absf(target.x - center.x) > 1.0 else facing
	if absf(velocity.x) > 5.0 and state != &"windup":
		facing = signf(velocity.x)
	move_and_slide()
	if state == &"dive" and get_slide_collision_count() > 0:
		state = &"return"
		state_left = 0.8
	_update_art()
	queue_redraw()

func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _update_art() -> void:
	var size_scale := 110.0 / float(BAT_TEXTURE.get_width())
	art.scale = Vector2.ONE * size_scale
	wing_material.set_shader_parameter("wing_motion", sin(clock * 13.0))
	art.flip_h = facing > 0.0
	art.rotation = clampf(velocity.y / 1800.0, -0.16, 0.16)
	art.modulate = Color(1.8, 1.6, 1.4) if hurt_left > 0.0 else Color.WHITE
	glow.modulate = Color(1.0, 0.46, 0.24, 0.38) if state == &"windup" else Color(0.38, 0.85, 0.78, 0.22)

func take_damage(amount: int, source: Vector2) -> void:
	if health <= 0 or amount <= 0 or get_tree().paused:
		return
	health = maxi(0, health - amount)
	hurt_left = 0.18
	state = &"hurt"
	state_left = 0.3
	velocity = (global_position - source).normalized() * 180.0
	if health == 0:
		state = &"dead"
		death_left = 0.4
		velocity = Vector2.ZERO
		set_deferred("collision_layer", 0)
	queue_redraw()

func reset_enemy() -> void:
	position = home
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	state = &"patrol"
	state_left = 0.0
	clock = 0.0
	facing = -1.0
	dive_direction = Vector2.ZERO
	dive_hit = false
	hurt_left = 0.0
	death_left = 0.0
	collision_layer = 4
	show()
	_update_art()
	queue_redraw()

func _draw() -> void:
	if health > 0 and health < MAX_HEALTH:
		draw_rect(Rect2(-24, -60, 48, 4), Color("192e27"))
		draw_rect(Rect2(-24, -60, 48.0 * health / MAX_HEALTH, 4), Color("c94b4b"))
