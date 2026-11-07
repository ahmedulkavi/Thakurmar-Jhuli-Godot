class_name ForestLevel
extends Node2D

signal journey_complete

const WORLD_WIDTH: float = 3840.0
const GROUND_Y: float = 586.0
const START := Vector2(170.0, GROUND_Y)
const GOAL_X: float = 3550.0
const SWORD_PICKUP = preload("res://scripts/sword_pickup.gd")
const FOREST_ENEMY = preload("res://scripts/forest_enemy.gd")

@onready var player: ForestPrince = $Prince
@onready var camera: Camera2D = $Camera
var completed: bool = false
var sword_pickup: Area2D
var enemies: Array[CharacterBody2D] = []

func _ready() -> void:
	$Goal.body_entered.connect(_on_goal_entered)
	_build_combat()
	reset_journey()
	_animate_atmosphere()

func _process(_delta: float) -> void:
	# The original camera places the prince left of centre for a view ahead.
	camera.position.x = clampf(player.position.x + 220.0, 640.0, WORLD_WIDTH - 640.0)

func reset_journey() -> void:
	completed = false
	player.reset_to(START)
	sword_pickup.reset_pickup()
	for enemy in enemies:
		enemy.reset_enemy()
	camera.position = Vector2(640.0, 360.0)
	camera.reset_smoothing()
	$Goal/Sparkles.restart()

func _on_goal_entered(body: Node2D) -> void:
	if body == player and player.health > 0 and not completed:
		completed = true
		journey_complete.emit()

func _build_combat() -> void:
	sword_pickup = Area2D.new()
	sword_pickup.name = "SwordPickup"
	sword_pickup.set_script(SWORD_PICKUP)
	sword_pickup.position = Vector2(2650, 466)
	add_child(sword_pickup)
	for x in [3010.0, 3310.0]:
		var enemy := CharacterBody2D.new()
		enemy.set_script(FOREST_ENEMY)
		enemy.position = Vector2(x, GROUND_Y)
		enemy.player = player
		add_child(enemy)
		enemies.append(enemy)

func _animate_atmosphere() -> void:
	for i in range(9):
		var mist := Sprite2D.new()
		mist.texture = preload("res://scenes/soft_glow.tres")
		mist.position = Vector2(i * 500.0 + 80.0, 530.0 + (i % 2) * 24.0)
		mist.scale = Vector2(5.3, 0.625)
		mist.modulate = Color(0.64, 0.92, 0.84, 0.045)
		mist.z_index = -1
		add_child(mist)
		var drift := create_tween().set_loops().set_parallel(true)
		drift.tween_property(mist, "position:x", mist.position.x + 70.0, 5.5 + i * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(mist, "modulate:a", 0.08, 5.5 + i * 0.35)
		drift.chain().tween_property(mist, "position:x", mist.position.x, 5.5 + i * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.parallel().tween_property(mist, "modulate:a", 0.045, 5.5 + i * 0.35)
