extends Node3D

const TREE_COUNT := 54
const HOUSE_POSITION := Vector3(0.0, 0.0, -25.0)
const DOOR_POSITION := Vector3(0.0, 1.0, -21.5)
const INTERACTION_DISTANCE := 2.6

var player: CharacterBody3D
var door: MeshInstance3D
var prompt: Label
var inside_message: Label
var door_open := false

func _ready() -> void:
	_create_environment()
	_create_ground_and_path()
	_create_forest()
	_create_house()
	_create_player()
	_create_ui()

func _process(_delta: float) -> void:
	if player == null:
		return
	var near_door := player.global_position.distance_to(DOOR_POSITION) <= INTERACTION_DISTANCE
	prompt.visible = near_door and not door_open
	if inside_message.visible and Input.is_key_pressed(KEY_ESCAPE):
		inside_message.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and player.global_position.distance_to(DOOR_POSITION) <= INTERACTION_DISTANCE:
			door_open = true
			door.rotation_degrees.y = -75.0
			prompt.visible = false
			inside_message.visible = true

func _mat(color: Color, roughness := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _mesh_box(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.23, 0.25)
	sky_material.sky_horizon_color = Color(0.48, 0.48, 0.49)
	sky_material.ground_bottom_color = Color(0.10, 0.10, 0.11)
	sky_material.ground_horizon_color = Color(0.38, 0.38, 0.39)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.58, 0.58, 0.60)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.48, 0.48, 0.49)
	environment.fog_density = 0.018
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -25, 0)
	sun.light_color = Color(0.78, 0.78, 0.80)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)

func _create_ground_and_path() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(100, 1, 100)
	var ground_visual := MeshInstance3D.new()
	ground_visual.mesh = ground_mesh
	ground_visual.position.y = -0.5
	ground_visual.material_override = _mat(Color(0.16, 0.16, 0.17))
	ground.add_child(ground_visual)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(100, 1, 100)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.5
	ground.add_child(ground_collision)
	add_child(ground)

	var path := MeshInstance3D.new()
	path.name = "ForestPath"
	var path_mesh := BoxMesh.new()
	path_mesh.size = Vector3(3.2, 0.04, 42.0)
	path.mesh = path_mesh
	path.position = Vector3(0, 0.025, -13.0)
	path.material_override = _mat(Color(0.29, 0.29, 0.30))
	add_child(path)

func _create_forest() -> void:
	var trunk_material := _mat(Color(0.20, 0.20, 0.21))
	var leaf_material := _mat(Color(0.31, 0.31, 0.32))
	var rng := RandomNumberGenerator.new()
	rng.seed = 24019
	for i in range(TREE_COUNT):
		var side := -1.0 if i % 2 == 0 else 1.0
		var tree := Node3D.new()
		tree.name = "Tree_%02d" % i
		var x := side * rng.randf_range(3.0, 13.0)
		var z := rng.randf_range(-38.0, 13.0)
		tree.position = Vector3(x, 0, z)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.16
		trunk_mesh.bottom_radius = 0.28
		trunk_mesh.height = rng.randf_range(2.5, 4.2)
		trunk.mesh = trunk_mesh
		trunk.position.y = trunk_mesh.height / 2.0
		trunk.material_override = trunk_material
		tree.add_child(trunk)
		var crown := MeshInstance3D.new()
		var crown_mesh := PrismMesh.new()
		crown_mesh.size = Vector3(rng.randf_range(1.8, 3.0), rng.randf_range(2.2, 3.8), rng.randf_range(1.8, 3.0))
		crown.mesh = crown_mesh
		crown.position.y = trunk_mesh.height + crown_mesh.size.y * 0.28
		crown.material_override = leaf_material
		tree.add_child(crown)
		add_child(tree)

func _create_house() -> void:
	var house := Node3D.new()
	house.name = "DistantHouse"
	house.position = HOUSE_POSITION
	add_child(house)
	var wall_material := _mat(Color(0.19, 0.19, 0.20))
	var roof_material := _mat(Color(0.11, 0.11, 0.12))
	var door_material := _mat(Color(0.08, 0.08, 0.09))
	_mesh_box(house, "HouseBody", Vector3(7.0, 3.2, 5.0), Vector3(0, 1.6, 0), wall_material)
	_mesh_box(house, "Roof", Vector3(7.8, 0.35, 5.8), Vector3(0, 3.35, 0), roof_material)
	_mesh_box(house, "FrontStep", Vector3(2.4, 0.18, 0.8), Vector3(0, 0.09, 2.8), roof_material)
	door = _mesh_box(house, "Door", Vector3(1.15, 2.2, 0.12), Vector3(0, 1.1, 2.57), door_material)
	door.position = Vector3(-0.57, 1.1, 2.57)
	door.position += Vector3(0.57, 0, 0)
	door.rotation_degrees.y = 0.0
	# Pivot the door at its left edge so it can swing open.
	door.position.x = -0.57
	door.set_meta("closed_position", door.position)
	var knob := _mesh_box(house, "DoorKnob", Vector3(0.08, 0.08, 0.08), Vector3(0.38, 1.0, 2.48), _mat(Color(0.55, 0.55, 0.56)))
	knob.visible = true
	# A simple dark opening behind the door gives the entrance depth.
	_mesh_box(house, "Doorway", Vector3(1.35, 2.35, 0.08), Vector3(0, 1.15, 2.53), _mat(Color(0.035, 0.035, 0.04)))

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Boy"
	player.position = Vector3(0, 0.95, 5.0)
	player.set_script(load("res://scripts/player.gd"))
	add_child(player)

	var skin := _mat(Color(0.48, 0.48, 0.49))
	var clothes := _mat(Color(0.25, 0.25, 0.26))
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.24
	body_mesh.height = 0.9
	body.mesh = body_mesh
	body.position.y = -0.12
	body.material_override = clothes
	player.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	head.mesh = head_mesh
	head.position = Vector3(0, 0.55, 0)
	head.material_override = skin
	player.add_child(head)

	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	collider.shape = capsule
	player.add_child(collider)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 3.0, 6.8)
	camera.current = true
	player.add_child(camera)
	camera.look_at(player.global_position + Vector3(0, 0.5, -4), Vector3.UP)

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	prompt = Label.new()
	prompt.name = "DoorPrompt"
	prompt.text = "Press E to enter"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.anchor_left = 0.25
	prompt.anchor_right = 0.75
	prompt.anchor_top = 0.82
	prompt.anchor_bottom = 0.9
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(0.92, 0.92, 0.93))
	prompt.visible = false
	layer.add_child(prompt)

	inside_message = Label.new()
	inside_message.name = "InsidePlaceholder"
	inside_message.text = "The house interior will come later.\nPress Esc to continue exploring."
	inside_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inside_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inside_message.anchor_left = 0.1
	inside_message.anchor_right = 0.9
	inside_message.anchor_top = 0.35
	inside_message.anchor_bottom = 0.65
	inside_message.add_theme_font_size_override("font_size", 20)
	inside_message.add_theme_color_override("font_color", Color(0.92, 0.92, 0.93))
	inside_message.visible = false
	layer.add_child(inside_message)
