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
const FREE_LOOK_SENSITIVITY := 0.0025
const FREE_LOOK_RETURN_SPEED := 8.0
const CAMERA_DISTANCES := [6.8, 3.4, 0.36]
const CAMERA_HEIGHTS := [1.65, 0.75, 0.03]
const CAMERA_MODE_NAMES := ["Far third-person", "Close third-person", "First-person"]
const MIN_CAMERA_PITCH := deg_to_rad(-55.0)
const MAX_CAMERA_PITCH := deg_to_rad(25.0)
const WALK_ANIMATION_SPEED := 8.5
const RUN_ANIMATION_SPEED := 12.0
const AUDIO_RATE := 22050

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var left_arm: Node3D = get_node_or_null("UpperArm_L")
@onready var right_arm: Node3D = get_node_or_null("UpperArm_R")
@onready var left_forearm: Node3D = get_node_or_null("UpperArm_L/Forearm_L")
@onready var right_forearm: Node3D = get_node_or_null("UpperArm_R/Forearm_R")
@onready var left_leg: Node3D = get_node_or_null("Leg_L")
@onready var right_leg: Node3D = get_node_or_null("Leg_R")
@onready var left_foot: Node3D = get_node_or_null("Foot_L")
@onready var right_foot: Node3D = get_node_or_null("Foot_R")
@onready var movement_audio: AudioStreamPlayer3D = _create_audio_player()

var jump_requested := false
var animation_time := 0.0
var movement_amount := 0.0
var free_look_active := false
var free_look_yaw := 0.0
var free_look_pitch := 0.0
var camera_base_pitch := 0.0
var camera_mode := 0
var footstep_clock := 0.0
var was_on_floor := true

func _ready() -> void:
	camera_base_pitch = camera_pivot.rotation.x
	was_on_floor = is_on_floor()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Hold Left Alt to orbit the camera around the stationary character, like PUBG free-look.
	if event is InputEventKey and event.keycode == KEY_ALT and not event.echo:
		if event.pressed and not free_look_active:
			free_look_active = true
			free_look_yaw = 0.0
			free_look_pitch = 0.0
		elif not event.pressed:
			free_look_active = false
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if free_look_active:
			free_look_yaw -= event.relative.x * FREE_LOOK_SENSITIVITY
			free_look_pitch -= event.relative.y * FREE_LOOK_SENSITIVITY
			free_look_pitch = clampf(free_look_pitch, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
		else:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			camera_base_pitch = clampf(camera_base_pitch - event.relative.y * MOUSE_SENSITIVITY, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
			camera_pivot.rotation.x = camera_base_pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_ENTER and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_SPACE and not free_look_active:
			jump_requested = true
		elif event.keycode == KEY_V:
			_cycle_camera_mode()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_update_free_look(delta)
	# Gravity applies only while airborne; landing is handled by move_and_slide().
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump is triggered once per key press, not repeatedly while Space is held.
	if jump_requested and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_play_movement_sound("jump", -7.0)
	jump_requested = false

	var input_dir := Vector2.ZERO
	if not free_look_active:
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
	_update_footsteps(delta, input_dir.length())
	if not was_on_floor and is_on_floor():
		_play_movement_sound("land", -8.0)
	was_on_floor = is_on_floor()


func _create_audio_player() -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.name = "MovementAudio"
	audio.volume_db = -8.0
	audio.max_distance = 18.0
	audio.unit_size = 5.0
	add_child(audio)
	return audio

func _update_footsteps(delta: float, input_strength: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and input_strength > 0.0 and horizontal_speed > 0.65:
		footstep_clock -= delta
		if footstep_clock <= 0.0:
			var running := Input.is_key_pressed(KEY_SHIFT)
			_play_movement_sound("run_step" if running else "step", -11.0 if running else -13.0)
			footstep_clock = 0.34 if running else 0.48
	else:
		footstep_clock = minf(footstep_clock, 0.12)

func _play_movement_sound(kind: String, volume: float) -> void:
	movement_audio.stream = _make_sound(kind)
	movement_audio.volume_db = volume
	movement_audio.pitch_scale = randf_range(0.92, 1.08)
	movement_audio.play()

func _make_sound(kind: String) -> AudioStreamWAV:
	# Short generated Foley: a soft low thump plus filtered noise, with no external assets required.
	var duration := 0.16
	if kind == "jump":
		duration = 0.20
	elif kind == "land":
		duration = 0.23
	var count := int(AUDIO_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / AUDIO_RATE
		var envelope := exp(-t * (24.0 if kind == "step" or kind == "run_step" else 15.0))
		var noise := randf_range(-1.0, 1.0)
		var low := sin(TAU * (72.0 if kind == "land" else 95.0) * t) * exp(-t * 18.0)
		var grit := noise * exp(-t * (34.0 if kind == "step" or kind == "run_step" else 22.0))
		var sample := 0.0
		if kind == "jump":
			sample = (sin(TAU * 125.0 * t) * 0.35 + grit * 0.35) * exp(-t * 19.0)
		elif kind == "land":
			sample = low * 0.62 + grit * 0.24
		else:
			sample = low * 0.48 + grit * 0.32
		sample *= envelope
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 12000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_RATE
	stream.stereo = false
	stream.data = bytes
	return stream

func _cycle_camera_mode() -> void:
	camera_mode = (camera_mode + 1) % CAMERA_DISTANCES.size()
	_apply_camera_mode()

func _apply_camera_mode() -> void:
	# The camera remains attached to the orbit pivot so free-look still circles the character.
	if camera_mode == 2:
		# Place the camera just in front of the face for first-person view.
		camera.position = Vector3(0.0, CAMERA_HEIGHTS[camera_mode], -CAMERA_DISTANCES[camera_mode])
		camera.look_at(camera.global_position + -camera_pivot.global_basis.z * 10.0, Vector3.UP)
	else:
		camera.position = Vector3(0.0, CAMERA_HEIGHTS[camera_mode], CAMERA_DISTANCES[camera_mode])
		camera.look_at(camera_pivot.global_position, Vector3.UP)

func _update_free_look(delta: float) -> void:
	if free_look_active:
		# Orbit around the character's centre instead of spinning the camera in place.
		camera_pivot.rotation.y = free_look_yaw
		camera_pivot.rotation.x = clampf(camera_base_pitch + free_look_pitch, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
	else:
		# Return smoothly to the normal over-the-shoulder view after Left Alt is released.
		camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, 0.0, delta * FREE_LOOK_RETURN_SPEED)
		camera_pivot.rotation.x = lerpf(camera_pivot.rotation.x, camera_base_pitch, delta * FREE_LOOK_RETURN_SPEED)
		if absf(camera_pivot.rotation.y) < 0.005:
			camera_pivot.rotation.y = 0.0
		if absf(camera_pivot.rotation.x - camera_base_pitch) < 0.005:
			camera_pivot.rotation.x = camera_base_pitch

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
