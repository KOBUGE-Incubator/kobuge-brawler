extends KinematicBody2D

enum Ability {NONE, WEAPON_A, WEAPON_B, WEAPON_BOTH, DASH, DASH_WEAPON_A, DASH_WEAPON_B}

export(float) var max_speed
export(float) var time_to_max_speed
export(float) var time_to_stop
export(float) var max_angular_speed_deg
export(float) var angular_acceleration_time
export(float) var max_health

onready var max_angular_speed = deg2rad(max_angular_speed_deg)
onready var animation_player = $animation_player
onready var overlay = $overlay

var ability = Ability.NONE
onready var health = max_health
var velocity = Vector2()
var angular_velocity = 0
var movement_direction = Vector2(0,0)
onready var aim_pos = position

func _ready():
	update_healthbar()

func _process(delta):
	overlay.rotation = -rotation

func _physics_process(delta):
	handle_movement(delta)
	handle_aiming(delta)
	handle_ability(delta)

func handle_movement(delta):
	if movement_direction.dot(velocity.normalized()) < 0.4 or movement_direction.length_squared() == 0:
		velocity *= pow(0.1, delta / time_to_stop)
	
	velocity += movement_direction * (max_speed / time_to_max_speed) * delta
	velocity = velocity.clamped(max_speed)
	
	velocity = move_and_slide(velocity, Vector2(), 5, 2)

func handle_aiming(delta):
	var wanted = (aim_pos - global_position).normalized()
	var current = Vector2(0, -1).rotated(rotation) # Vector points "forward"
	
	var wanted_change = truncate(current.angle_to(wanted), 1) * max_angular_speed - angular_velocity
	angular_velocity += truncate(wanted_change, max_angular_speed / angular_acceleration_time)
	angular_velocity = min(max_angular_speed, abs(angular_velocity)) * sign(angular_velocity)
	
	rotation += angular_velocity * delta

func handle_ability(delta):
	if ability == Ability.WEAPON_A:
		animation_player.play("weapon_a")
		ability = NONE

func update_healthbar():
	$overlay/progress_bar.max_value = max_health
	$overlay/progress_bar.value = health

func receive_hit(by, damage):
	health -= damage
	update_healthbar()

func set_movement_direction(movement_direction):
	self.movement_direction = movement_direction

func set_aim_pos(aim_pos):
	self.aim_pos = aim_pos

func set_ability(ability):
	self.ability = ability

static func truncate(scalar, magnitude):
	return min(magnitude, abs(scalar)) * sign(scalar)

