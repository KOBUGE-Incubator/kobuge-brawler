extends KinematicBody2D

export(float) var max_speed
export(float) var time_to_max_speed
export(float) var time_to_stop
export(float) var max_angular_speed_deg
export(float) var angular_acceleration_time

var velocity = Vector2()
var angular_velocity = 0
onready var max_angular_speed = deg2rad(max_angular_speed_deg)

func _ready():
	pass

func _physics_process(delta):
	handle_movement(delta)
	handle_aiming(delta)

func handle_movement(delta):
	var movement = Vector2()
	if Input.is_action_pressed("move_left"):
		movement.x -= 1
	if Input.is_action_pressed("move_right"):
		movement.x += 1
	if Input.is_action_pressed("move_up"):
		movement.y -= 1
	if Input.is_action_pressed("move_down"):
		movement.y += 1
	
	if movement.dot(velocity.normalized()) < 0.4 or movement.length_squared() == 0:
		velocity *= pow(0.1, delta / time_to_stop)
	
	velocity += movement * (max_speed / time_to_max_speed) * delta
	velocity = velocity.clamped(max_speed)
	
	velocity = move_and_slide(velocity, Vector2(), 5, 2)

func handle_aiming(delta):
	var wanted = (get_global_mouse_position() - global_position).normalized()
	var current = Vector2(0, -1).rotated(rotation) # Vector points "forward"
	
	var wanted_change = truncate(current.angle_to(wanted), 1) * max_angular_speed - angular_velocity
	angular_velocity += truncate(wanted_change, max_angular_speed / angular_acceleration_time)
	angular_velocity = min(max_angular_speed, abs(angular_velocity)) * sign(angular_velocity)
	
	rotation += angular_velocity * delta


static func truncate(scalar, magnitude):
	return min(magnitude, abs(scalar)) * sign(scalar)

