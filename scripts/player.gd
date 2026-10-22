extends CharacterBody3D

# Movement tuned for a responsive, slightly weighty third-person character.
const WALK_SPEED := 3.6
const RUN_SPEED := 6.2
const GROUND_ACCELERATION := 18.0
const GROUND_FRICTION := 22.0
const AIR_ACCELERATION := 5.0
const JUMP_VELOCITY := 5.2
const GRAVITY := 16.0
const MOUSE_SENSITIVITY := 0.0025
const MIN_CAMERA_PITCH := deg_to_rad(-55.0)
const MAX_CAMERA_PITCH := deg_to_rad(25.0)
const WALK_ANIMATION_SPEED := 8.5
const RUN_ANIMATION_SPEED := 12.0

@onready var camera: Camera3D = $Camera3D
@onready var left_arm: Node3D = get_node_or_null("UpperArm_L")
@onready var right_arm: Node3D = get_node_or_null("UpperArm_R")
@onready var left_forearm: Node3D = get_node_or_null("UpperArm_L/Forearm_L")
@onready var right_forearm: Node3D = get_node_or_null("UpperArm_R/Forearm_R")
@onready var left_leg: Node3D = get_node_or_null("Leg_L")
@onready var right_leg: Node3D = get_node_or_null("Leg_R")
@onready var left_foot: Node3D = get_node_or_null("Foot_L")
@onready var right_foot: Node3D = get_node_or_null("Foot_R")

var jump_requested := false
var animation_time := 0.0
var movement_amount := 0.0

func _ready() -> void:
	camera.look_at(global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_ENTER and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_SPACE:
			jump_requested = true
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Gravity applies only while airborne; landing is handled by move_and_slide().
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump is triggered once per key press, not repeatedly while Space is held.
	if jump_requested and is_on_floor():
		velocity.y = JUMP_VELOCITY
	jump_requested = false

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0

	input_dir = input_dir.normalized()
	var move_dir := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target_speed := RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	var target_velocity := move_dir * target_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION

	if input_dir.length_squared() > 0.0:
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, GROUND_FRICTION * delta if is_on_floor() else AIR_ACCELERATION * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	move_and_slide()
	_update_limb_animation(delta, input_dir.length())

func _update_limb_animation(delta: float, input_strength: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_running := Input.is_key_pressed(KEY_SHIFT)
	var is_moving := is_on_floor() and input_strength > 0.0 and horizontal_speed > 0.2

	if is_moving:
		var cycle_speed := RUN_ANIMATION_SPEED if is_running else WALK_ANIMATION_SPEED
		animation_time += delta * cycle_speed
		movement_amount = move_toward(movement_amount, 1.0, delta * 7.0)
	else:
		movement_amount = move_toward(movement_amount, 0.0, delta * 6.0)

	var swing := sin(animation_time) * 0.48 * movement_amount
	var opposite_swing := sin(animation_time + PI) * 0.48 * movement_amount
	var air_pose := 0.0
	if not is_on_floor():
		air_pose = clampf(velocity.y / JUMP_VELOCITY, -1.0, 1.0) * 0.12

	if left_leg:
		left_leg.rotation.x = swing + air_pose
	if right_leg:
		right_leg.rotation.x = opposite_swing + air_pose
	if left_arm:
		left_arm.rotation.x = opposite_swing - air_pose
	if right_arm:
		right_arm.rotation.x = swing - air_pose
	if left_forearm:
		left_forearm.rotation.x = opposite_swing * 0.45
	if right_forearm:
		right_forearm.rotation.x = swing * 0.45
	if left_foot:
		left_foot.rotation.x = swing * 0.25
	if right_foot:
		right_foot.rotation.x = opposite_swing * 0.25
