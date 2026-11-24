extends Node2D
## Coral sentinel's slow, visible water pulse.

const SPEED := 310.0
var direction := Vector2.LEFT
var attacker: Node2D
var age := 0.0

func _ready() -> void:
	z_index = 5
	queue_redraw()

func _physics_process(delta: float) -> void:
	age += delta
	var step := direction * SPEED * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 2)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var prince := hit.collider as ForestPrince
		if prince:
			prince.take_damage(18, global_position, attacker)
		queue_free()
		return
	position += step
	if age > 3.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(0.13, 0.85, 0.92, 0.16))
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 20, Color(0.64, 1.0, 0.98, 0.8), 2.5, true)
	draw_circle(Vector2.ZERO, 5.0, Color(0.70, 1.0, 0.94, 0.8))
