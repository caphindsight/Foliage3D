extends CharacterBody3D

@export var mouse_sensitivity = 0.0025
@export_range(0, 90, 5, "radians_as_degrees") var max_look_alt = deg_to_rad(80)

@onready var camera: Camera3D = $Camera

var speed = 5

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		self.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -max_look_alt, max_look_alt)
	elif event.is_action_pressed("1"):
		speed = 5
	elif event.is_action_pressed("2"):
		speed = 25
	elif event.is_action_pressed("3"):
		speed = 100
	elif event.is_action_pressed("4"):
		speed = 250
	elif event.is_action_pressed("5"):
		speed = 1000

func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("a", "d", "w", "s")
	var vert := Input.get_axis("q", "e")
	velocity = (global_basis.x * input.x + global_basis.z * input.y + global_basis.y * vert) * speed
	move_and_slide()
