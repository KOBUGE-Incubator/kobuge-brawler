extends Area2D

const Unit = preload("res://unit/unit.gd")

export(float) var damage

func _ready():
	pass

func hit():
	for body in get_overlapping_bodies():
		if body is Unit and body != get_parent():
			body.receive_hit(get_parent(), damage)
