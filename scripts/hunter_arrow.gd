extends Node2D
## Fast physical projectile; the ray covers each step to prevent tunneling.

const SPEED := 980.0
const REACH := 1000.0
const REFLECTED_DAMAGE := 14
var direction := 1.0
var owner_prince: ForestPrince
var underwater := false
var travelled := 0.0
var reflected_by: CharacterBody2D

func _ready() -> void:
	z_index = 6
	queue_redraw()

func _physics_process(delta: float) -> void:
	var step := Vector2(direction * SPEED * delta, 0)
	var reflected := is_instance_valid(reflected_by)
	if reflected and (reflected_by.health <= 0 or not reflected_by.active):
		queue_free()
		return
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 3 if reflected else 5)
	query.exclude = [reflected_by.get_rid()] if reflected else [owner_prince.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var target := hit.collider as Node2D
		if reflected and target == owner_prince:
			owner_prince.take_damage(REFLECTED_DAMAGE, reflected_by.global_position, reflected_by)
		elif not reflected and target and target.is_in_group("combat_targets"):
			if target.has_method("try_reflect_arrow") and target.try_reflect_arrow(global_position):
				reflected_by = target
				direction = -direction
				global_position.x += direction * 8.0
				travelled = 0.0
				queue_redraw()
				return
			var before: int = target.health
			target.take_damage(before if owner_prince.god_mode else 1, owner_prince.global_position)
			if target.health < before:
				owner_prince.sound_requested.emit(&"hit")
		queue_free()
		return
	position += step
	travelled += step.length()
	if travelled >= REACH:
		queue_free()

func _draw() -> void:
	if underwater:
		draw_line(Vector2(-direction * 42, 1), Vector2(-direction * 12, 0), Color(0.67, 0.98, 1, 0.46), 2.5, true)
	var head := Vector2(direction * 12.0, 0)
	draw_line(Vector2(-direction * 12.0, 0), head, Color("9c682f"), 3.0, true)
	draw_colored_polygon(PackedVector2Array([head + Vector2(direction * 6.0, 0), head + Vector2(-direction * 3.0, -4), head + Vector2(-direction * 3.0, 4)]), Color("d6e9c4"))
	draw_line(Vector2(-direction * 11.0, 0), Vector2(-direction * 17.0, -5), Color("60b985"), 2.0, true)
	draw_line(Vector2(-direction * 11.0, 0), Vector2(-direction * 17.0, 5), Color("60b985"), 2.0, true)
