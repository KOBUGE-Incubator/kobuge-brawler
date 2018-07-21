extends Node2D

const Unit = preload("res://unit/unit.gd")
onready var unit = get_parent()

func _ready():
	pass

func _physics_process(delta):
	if unit and unit is Unit:
		handle_movement(delta)
		handle_aiming(delta)

func handle_movement(delta):
	var movement_direction = Vector2()
	if Input.is_action_pressed("move_left"):
		movement_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		movement_direction.x += 1
	if Input.is_action_pressed("move_up"):
		movement_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		movement_direction.y += 1
	
	unit.set_movement_direction( movement_direction )
	
func handle_aiming(delta):
	unit.set_aim_pos( get_global_mouse_position() )


