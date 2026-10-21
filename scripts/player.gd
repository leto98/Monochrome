extends CharacterBody3D

const WALK_SPEED := 4.0
const RUN_SPEED := 6.5
const JUMP_VELOCITY := 4.5
const GRAVITY := 12.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
    camera.look_at(global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta

    if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
        velocity.y = JUMP_VELOCITY

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
    var speed := RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
    velocity.x = input_dir.x * speed
    velocity.z = input_dir.y * speed
    move_and_slide()
