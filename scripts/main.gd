extends Node3D

const TREE_COUNT := 150
const GRASS_CLUMPS := 420
const DEBRIS_COUNT := 180
const HOUSE_POSITION := Vector3(0.0, 0.0, -25.0)
const DOOR_POSITION := Vector3(0.0, 1.0, -21.5)
const INTERACTION_DISTANCE := 2.6

var player: CharacterBody3D
var door: Node3D
var prompt: Label
var inside_message: Label
var door_open := false
var interaction_audio: AudioStreamPlayer3D
var title_screen: Control
var pause_screen: Control
var game_started := false
var is_paused := false
var sound_enabled := true
var title_sound_button: Button
var pause_sound_button: Button
var river_fish: Array[Node3D] = []
var fish_swim_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_environment()
	_create_ground_and_path()
	_create_forest()
	_create_ground_details()
	_create_path_lamp()
	_create_debris()
	_create_expanded_landscape()
	_create_house()
	_create_player()
	_create_ui()
	_create_menu_screens()
	# The title screen uses clickable UI, so never start with the mouse captured.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	interaction_audio = AudioStreamPlayer3D.new()
	interaction_audio.name = "WorldInteractionAudio"
	interaction_audio.volume_db = -10.0
	interaction_audio.max_distance = 16.0
	interaction_audio.unit_size = 4.0
	add_child(interaction_audio)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true

func _process(delta: float) -> void:
	fish_swim_time += delta
	for i in range(river_fish.size()):
		var fish := river_fish[i]
		if is_instance_valid(fish):
			fish.position.z += delta * (0.7 + float(i % 3) * 0.22)
			fish.position.x = fish.get_meta("home_x") + sin(fish_swim_time * 1.3 + float(i)) * 0.32
			fish.rotation.y = sin(fish_swim_time * 1.3 + float(i)) * 0.22
			if fish.position.z > 55.0:
				fish.position.z = -55.0
	if not game_started or is_paused:
		return
	if player == null:
		return
	var near_door := player.global_position.distance_to(DOOR_POSITION) <= INTERACTION_DISTANCE
	prompt.visible = near_door and not door_open

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if not game_started:
			return
		if is_paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not game_started or is_paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and player.global_position.distance_to(DOOR_POSITION) <= INTERACTION_DISTANCE:
			door_open = true
			_play_door_sound()
			door.rotation_degrees.y = -75.0
			prompt.visible = false
			inside_message.visible = true



func _create_menu_screens() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MenuLayer"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	title_screen = _make_menu_panel(layer, "TitleScreen")
	title_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_menu_title(title_screen, "MONOCHROME")
	_add_menu_subtitle(title_screen, "A quiet place beyond the trees")
	_add_menu_button(title_screen, "PLAY GAME", _start_game)
	title_sound_button = _add_menu_button(title_screen, "SOUND: ON", _toggle_sound)
	_add_menu_button(title_screen, "QUIT", _quit_game)

	pause_screen = _make_menu_panel(layer, "PauseScreen")
	_add_menu_title(pause_screen, "PAUSED")
	_add_menu_button(pause_screen, "RESUME", _resume_game)
	_add_menu_button(pause_screen, "SOUND: ON", _toggle_sound)
	_add_menu_button(pause_screen, "MAIN MENU", _return_to_menu)
	pause_sound_button = pause_screen.get_meta("menu_column").get_child(2) as Button
	pause_screen.visible = false

func _make_menu_panel(parent: Node, panel_name: String) -> Control:
	var panel := ColorRect.new()
	panel.name = panel_name
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.color = Color(0.015, 0.015, 0.02, 0.94)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.position = Vector2(-190.0, -145.0)
	column.size = Vector2(380.0, 290.0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	panel.set_meta("menu_column", column)
	return panel

func _add_menu_title(panel: Control, text_value: String) -> void:
	var column := panel.get_meta("menu_column") as VBoxContainer
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.96))
	column.add_child(label)

func _add_menu_subtitle(panel: Control, text_value: String) -> void:
	var column := panel.get_meta("menu_column") as VBoxContainer
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.58, 0.58, 0.62))
	column.add_child(label)

func _add_menu_button(panel: Control, text_value: String, action: Callable) -> Button:
	var column := panel.get_meta("menu_column") as VBoxContainer
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(260.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _menu_button_style(Color(0.08, 0.08, 0.09, 1.0), Color(0.25, 0.25, 0.27, 1.0)))
	button.add_theme_stylebox_override("hover", _menu_button_style(Color(0.18, 0.18, 0.20, 1.0), Color(0.65, 0.65, 0.68, 1.0)))
	button.add_theme_stylebox_override("pressed", _menu_button_style(Color(0.12, 0.12, 0.13, 1.0), Color(0.8, 0.8, 0.82, 1.0)))
	button.pressed.connect(action)
	column.add_child(button)
	return button

func _menu_button_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	AudioServer.set_bus_mute(0, not sound_enabled)
	var label := "SOUND: ON" if sound_enabled else "SOUND: OFF"
	if is_instance_valid(title_sound_button):
		title_sound_button.text = label
	if is_instance_valid(pause_sound_button):
		pause_sound_button.text = label

func _start_game() -> void:
	game_started = true
	is_paused = false
	get_tree().paused = false
	title_screen.visible = false
	pause_screen.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _pause_game() -> void:
	if not game_started:
		return
	is_paused = true
	get_tree().paused = true
	pause_screen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	pause_screen.visible = false
	title_screen.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _return_to_menu() -> void:
	get_tree().paused = false
	is_paused = false
	game_started = false
	pause_screen.visible = false
	title_screen.visible = true
	player.velocity = Vector3.ZERO
	player.position = Vector3(0.0, 0.68, 5.0)
	door_open = false
	door.rotation_degrees.y = 0.0
	prompt.visible = false
	inside_message.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _quit_game() -> void:
	get_tree().quit()

func _play_door_sound() -> void:
	# A quiet wooden latch followed by a short, rough hinge creak.
	var rate := 22050
	var duration := 0.48
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / rate
		var envelope := exp(-t * 5.0)
		var noise := randf_range(-1.0, 1.0)
		var creak_frequency := lerpf(260.0, 115.0, t / duration)
		var creak := sin(TAU * creak_frequency * t) * 0.24
		var latch := sin(TAU * 780.0 * t) * exp(-t * 65.0) * 0.42
		var sample := (noise * 0.18 + creak + latch) * envelope
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 9500.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	interaction_audio.stream = stream
	interaction_audio.pitch_scale = randf_range(0.94, 1.04)
	interaction_audio.play()

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

func _add_box_collision(parent: Node3D, name: String, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.rotation = rot
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)
	return body

func _add_cylinder_collision(parent: Node3D, name: String, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)
	return body

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.055, 0.075, 0.12)
	sky_material.sky_horizon_color = Color(0.28, 0.34, 0.37)
	sky_material.ground_bottom_color = Color(0.10, 0.13, 0.10)
	sky_material.ground_horizon_color = Color(0.27, 0.31, 0.22)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.66, 0.54)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.40, 0.46, 0.40)
	environment.fog_density = 0.018
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -25, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)

func _create_ground_and_path() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(180, 1, 180)
	var ground_visual := MeshInstance3D.new()
	ground_visual.mesh = ground_mesh
	ground_visual.position.y = -0.5
	ground_visual.material_override = _mat(Color(0.20, 0.25, 0.15))
	ground.add_child(ground_visual)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(180, 1, 180)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.5
	ground.add_child(ground_collision)
	add_child(ground)

	# Reliable curved trail made from short overlapping ground-level segments.
	var path_materials := [
		_mat(Color(0.39, 0.29, 0.19)),
		_mat(Color(0.43, 0.33, 0.22)),
		_mat(Color(0.35, 0.26, 0.18))
	]
	var segment_count := 52
	for i in range(segment_count):
		var t := (float(i) + 0.5) / float(segment_count)
		var z := lerpf(9.0, -35.0, t)
		var x := sin(PI * t) * 4.8 * sin(TAU * 1.25 * t)
		var next_t := minf(1.0, t + 1.0 / float(segment_count))
		var next_x := sin(PI * next_t) * 4.8 * sin(TAU * 1.25 * next_t)
		var next_z := lerpf(9.0, -35.0, next_t)
		var segment := MeshInstance3D.new()
		segment.name = "WindingTrail_%02d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.35, 0.035, 1.15)
		segment.mesh = mesh
		segment.position = Vector3(x, 0.02, z)
		segment.rotation.y = atan2(next_x - x, -(next_z - z))
		segment.material_override = path_materials[i % path_materials.size()]
		add_child(segment)

func _create_forest() -> void:
	var trunk_material := _mat(Color(0.24, 0.14, 0.085))
	var trunk_light := _mat(Color(0.38, 0.25, 0.13))
	var bark_shadow := _mat(Color(0.13, 0.075, 0.045))
	var leaf_material := _mat(Color(0.20, 0.34, 0.17))
	var leaf_light := _mat(Color(0.40, 0.48, 0.24))
	var leaf_dark := _mat(Color(0.10, 0.23, 0.13))
	var rng := RandomNumberGenerator.new()
	rng.seed = 24019
	for i in range(TREE_COUNT):
		var side := -1.0 if i % 2 == 0 else 1.0
		var tree := Node3D.new()
		tree.name = "Tree_%02d" % i
		var x := side * rng.randf_range(10.0, 35.0)
		var z := rng.randf_range(-76.0, 56.0)
		tree.position = Vector3(x, 0, z)
		tree.rotation.y = rng.randf_range(-0.35, 0.35)
		var height := rng.randf_range(3.0, 5.8)
		var width := rng.randf_range(0.22, 0.38)

		# Tapered trunk, dark bark scars and spreading roots break up the silhouette.
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = width * 0.45
		trunk_mesh.bottom_radius = width
		trunk_mesh.height = height
		trunk.mesh = trunk_mesh
		trunk.position.y = height * 0.5
		trunk.material_override = trunk_material
		tree.add_child(trunk)
		_add_cylinder_collision(tree, "TrunkCollision", width * 1.25, height, Vector3(0.0, height * 0.5, 0.0))

		for root_index in range(4):
			var angle := float(root_index) * TAU / 4.0 + rng.randf_range(-0.25, 0.25)
			var root := MeshInstance3D.new()
			var root_mesh := BoxMesh.new()
			root_mesh.size = Vector3(width * 0.72, 0.13, rng.randf_range(0.75, 1.25))
			root.mesh = root_mesh
			root.position = Vector3(sin(angle) * 0.32, 0.08, cos(angle) * 0.32)
			root.rotation.y = angle
			root.rotation.x = rng.randf_range(-0.08, 0.08)
			root.material_override = bark_shadow
			tree.add_child(root)

		for scar_index in range(3):
			var scar := MeshInstance3D.new()
			var scar_mesh := BoxMesh.new()
			scar_mesh.size = Vector3(0.035, rng.randf_range(0.35, 0.8), 0.025)
			scar.mesh = scar_mesh
			scar.position = Vector3(rng.randf_range(-width * 0.55, width * 0.55), rng.randf_range(0.55, height - 0.25), -width * 0.92)
			scar.rotation.z = rng.randf_range(-0.12, 0.12)
			scar.material_override = trunk_light if scar_index == 0 else bark_shadow
			tree.add_child(scar)

		# Crooked low-poly limbs peek through the broken, layered canopy.
		for branch_index in range(3):
			var branch := MeshInstance3D.new()
			var branch_mesh := CylinderMesh.new()
			branch_mesh.top_radius = 0.025
			branch_mesh.bottom_radius = 0.085
			branch_mesh.height = rng.randf_range(1.0, 1.65)
			branch.mesh = branch_mesh
			var branch_side := -1.0 if branch_index % 2 == 0 else 1.0
			branch.position = Vector3(branch_side * 0.42, height * (0.52 + branch_index * 0.09), 0)
			branch.rotation.z = branch_side * deg_to_rad(rng.randf_range(38.0, 58.0))
			branch.rotation.x = rng.randf_range(-0.35, 0.35)
			branch.material_override = trunk_material
			tree.add_child(branch)

		# Mix distinct silhouettes: layered pines, broad round crowns, and irregular clustered trees.
		var tree_style := rng.randi_range(0, 2)
		var canopy_colors := [leaf_dark, leaf_material, leaf_light]
		if tree_style == 0:
			for crown_index in range(4):
				var crown := MeshInstance3D.new()
				var crown_mesh := CylinderMesh.new()
				crown_mesh.top_radius = 0.03
				crown_mesh.bottom_radius = rng.randf_range(0.75, 1.35)
				crown_mesh.top_radius = 0.03
				crown_mesh.height = rng.randf_range(1.35, 2.1)
				crown_mesh.radial_segments = rng.randi_range(5, 7)
				crown.mesh = crown_mesh
				crown.position = Vector3(rng.randf_range(-0.2, 0.2), height * 0.48 + crown_index * 0.62, rng.randf_range(-0.2, 0.2))
				crown.rotation.y = rng.randf_range(0.0, TAU)
				crown.material_override = canopy_colors[rng.randi_range(0, 2)]
				tree.add_child(crown)
		elif tree_style == 1:
			for crown_index in range(4):
				var crown := MeshInstance3D.new()
				var crown_mesh := SphereMesh.new()
				crown_mesh.radius = rng.randf_range(0.8, 1.25)
				crown_mesh.height = crown_mesh.radius * rng.randf_range(1.25, 1.8)
				crown.mesh = crown_mesh
				crown.position = Vector3(rng.randf_range(-0.85, 0.85), height + rng.randf_range(0.15, 1.0), rng.randf_range(-0.7, 0.7))
				crown.scale = Vector3(rng.randf_range(0.8, 1.2), 1.0, rng.randf_range(0.8, 1.2))
				crown.material_override = canopy_colors[rng.randi_range(0, 2)]
				tree.add_child(crown)
		else:
			for crown_index in range(5):
				var crown := MeshInstance3D.new()
				var crown_mesh := PrismMesh.new()
				var crown_width := rng.randf_range(1.0, 2.0)
				crown_mesh.size = Vector3(crown_width, rng.randf_range(1.1, 2.1), crown_width * rng.randf_range(0.7, 1.2))
				crown.mesh = crown_mesh
				crown.position = Vector3(rng.randf_range(-0.9, 0.9), height + rng.randf_range(-0.1, 1.3), rng.randf_range(-0.8, 0.8))
				crown.rotation.y = rng.randf_range(-1.0, 1.0)
				crown.material_override = canopy_colors[rng.randi_range(0, 2)]
				tree.add_child(crown)
		add_child(tree)

func _create_ground_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 72144
	var grass_materials := [
		_mat(Color(0.20, 0.20, 0.205)),
		_mat(Color(0.245, 0.245, 0.25)),
		_mat(Color(0.16, 0.16, 0.17))
	]
	var moss_material := _mat(Color(0.235, 0.235, 0.24))
	var soil_material := _mat(Color(0.115, 0.115, 0.12))

	# Irregular patches darken the earth around the path and tree roots.
	for i in range(48):
		var patch := MeshInstance3D.new()
		var patch_mesh := CylinderMesh.new()
		patch_mesh.top_radius = rng.randf_range(0.35, 1.1)
		patch_mesh.bottom_radius = patch_mesh.top_radius * rng.randf_range(0.8, 1.15)
		patch_mesh.height = 0.025
		patch.mesh = patch_mesh
		var px := rng.randf_range(-38.0, 38.0)
		var pz := rng.randf_range(-76.0, 56.0)
		patch.position = Vector3(px, 0.012, pz)
		patch.rotation.y = rng.randf_range(0.0, TAU)
		patch.material_override = soil_material if i % 3 != 0 else moss_material
		add_child(patch)

	# Small angular blades in uneven clumps, kept away from the centre of the path.
	for i in range(GRASS_CLUMPS):
		var x := rng.randf_range(-15.0, 15.0)
		var z := rng.randf_range(-76.0, 56.0)
		if absf(x) < 1.9:
			x = signf(x) * rng.randf_range(2.0, 4.2)
		var clump := Node3D.new()
		clump.name = "Grass_%03d" % i
		clump.position = Vector3(x, 0.025, z)
		clump.rotation.y = rng.randf_range(0.0, TAU)
		var blade_count := rng.randi_range(3, 6)
		for blade_index in range(blade_count):
			var blade := MeshInstance3D.new()
			var blade_mesh := PrismMesh.new()
			blade_mesh.size = Vector3(rng.randf_range(0.045, 0.09), rng.randf_range(0.18, 0.42), 0.045)
			blade.mesh = blade_mesh
			blade.position = Vector3(rng.randf_range(-0.17, 0.17), blade_mesh.size.y * 0.5, rng.randf_range(-0.15, 0.15))
			blade.rotation.z = rng.randf_range(-0.35, 0.35)
			blade.rotation.x = rng.randf_range(-0.3, 0.3)
			blade.material_override = grass_materials[rng.randi_range(0, grass_materials.size() - 1)]
			clump.add_child(blade)
		add_child(clump)

func _create_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88531
	var stone_materials := [
		_mat(Color(0.25, 0.25, 0.26)),
		_mat(Color(0.31, 0.31, 0.32)),
		_mat(Color(0.19, 0.19, 0.20))
	]
	var wood_materials := [
		_mat(Color(0.105, 0.105, 0.11)),
		_mat(Color(0.16, 0.16, 0.165)),
		_mat(Color(0.125, 0.125, 0.13))
	]
	var twig_material := _mat(Color(0.12, 0.12, 0.125))
	var leaf_material := _mat(Color(0.22, 0.22, 0.225))

	for i in range(DEBRIS_COUNT):
		var debris := Node3D.new()
		debris.name = "ForestDebris_%03d" % i
		var x := rng.randf_range(-37.0, 37.0)
		var z := rng.randf_range(-76.0, 56.0)
		if absf(x) < 1.75:
			x = signf(x) * rng.randf_range(2.0, 3.6)
		debris.position = Vector3(x, 0.0, z)
		debris.rotation.y = rng.randf_range(0.0, TAU)
		var kind := rng.randi_range(0, 4)

		if kind <= 1:
			# Weathered fallen limbs and broken logs, with a lighter snapped end.
			var log := MeshInstance3D.new()
			var log_mesh := CylinderMesh.new()
			log_mesh.top_radius = rng.randf_range(0.055, 0.12)
			log_mesh.bottom_radius = log_mesh.top_radius * rng.randf_range(0.8, 1.25)
			log_mesh.height = rng.randf_range(0.8, 1.9)
			log.mesh = log_mesh
			log.position = Vector3(0, log_mesh.top_radius, 0)
			log.rotation.z = deg_to_rad(rng.randf_range(72.0, 105.0))
			log.rotation.x = rng.randf_range(-0.15, 0.15)
			log.material_override = wood_materials[rng.randi_range(0, wood_materials.size() - 1)]
			debris.add_child(log)
			var broken_end := MeshInstance3D.new()
			var end_mesh := CylinderMesh.new()
			end_mesh.top_radius = 0.025
			end_mesh.bottom_radius = 0.07
			end_mesh.height = 0.06
			broken_end.mesh = end_mesh
			broken_end.position = Vector3(0, log_mesh.top_radius + log_mesh.height * 0.42, 0)
			broken_end.rotation.z = log.rotation.z
			broken_end.material_override = stone_materials[1]
			debris.add_child(broken_end)
			for twig_index in range(2):
				var twig := MeshInstance3D.new()
				var twig_mesh := CylinderMesh.new()
				twig_mesh.top_radius = 0.012
				twig_mesh.bottom_radius = 0.035
				twig_mesh.height = rng.randf_range(0.35, 0.65)
				twig.mesh = twig_mesh
				twig.position = Vector3(rng.randf_range(-0.18, 0.18), 0.12, rng.randf_range(-0.15, 0.15))
				twig.rotation.z = rng.randf_range(-1.0, 1.0)
				twig.material_override = twig_material
				debris.add_child(twig)
		elif kind <= 3:
			# Uneven low-poly stones in small scattered groups.
			var stone_count := rng.randi_range(1, 3)
			for stone_index in range(stone_count):
				var stone := MeshInstance3D.new()
				var stone_mesh := PrismMesh.new()
				stone_mesh.size = Vector3(rng.randf_range(0.18, 0.55), rng.randf_range(0.12, 0.34), rng.randf_range(0.18, 0.48))
				stone.mesh = stone_mesh
				stone.position = Vector3(rng.randf_range(-0.35, 0.35), stone_mesh.size.y * 0.35, rng.randf_range(-0.3, 0.3))
				stone.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.0, TAU), rng.randf_range(-0.18, 0.18))
				stone.material_override = stone_materials[rng.randi_range(0, stone_materials.size() - 1)]
				debris.add_child(stone)
		else:
			# Fallen leaves and snapped twig fragments form small litter clusters.
			for leaf_index in range(rng.randi_range(4, 8)):
				var leaf := MeshInstance3D.new()
				var leaf_mesh := PrismMesh.new()
				leaf_mesh.size = Vector3(rng.randf_range(0.08, 0.17), 0.025, rng.randf_range(0.12, 0.23))
				leaf.mesh = leaf_mesh
				leaf.position = Vector3(rng.randf_range(-0.35, 0.35), 0.018, rng.randf_range(-0.35, 0.35))
				leaf.rotation.y = rng.randf_range(0.0, TAU)
				leaf.rotation.x = rng.randf_range(-0.08, 0.08)
				leaf.material_override = leaf_material
				debris.add_child(leaf)
		add_child(debris)


func _create_path_lamp() -> void:
	# A weathered timber post with a hanging, warm-lit lantern beside the trail.
	var lamp := Node3D.new()
	lamp.name = "OldWoodenPathLamp"
	lamp.position = Vector3(2.5, 0.0, -10.0)
	add_child(lamp)

	var dark_wood := _mat(Color(0.12, 0.075, 0.045))
	var worn_wood := _mat(Color(0.25, 0.16, 0.085))
	var wood_highlight := _mat(Color(0.34, 0.23, 0.12))
	var iron := _mat(Color(0.075, 0.07, 0.055))
	var glow_glass := StandardMaterial3D.new()
	glow_glass.albedo_color = Color(1.0, 0.56, 0.20, 0.82)
	glow_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_glass.emission_enabled = true
	glow_glass.emission = Color(1.0, 0.34, 0.07)
	glow_glass.emission_energy_multiplier = 3.0
	glow_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Tall, slightly uneven timber support.
	_mesh_box(lamp, "RoughWoodenPost", Vector3(0.22, 3.25, 0.24), Vector3(0, 1.625, 0), dark_wood)
	_mesh_box(lamp, "WornFrontGrain", Vector3(0.045, 2.65, 0.025), Vector3(-0.045, 1.55, -0.132), worn_wood)
	_mesh_box(lamp, "PostFootBrace", Vector3(0.38, 0.16, 0.36), Vector3(0, 0.12, 0), worn_wood)

	# Short arm and diagonal brace hold the lantern out over the path.
	_mesh_box(lamp, "LanternArm", Vector3(0.95, 0.16, 0.18), Vector3(-0.48, 2.88, 0), worn_wood)
	var brace := _mesh_box(lamp, "ArmBrace", Vector3(0.62, 0.10, 0.12), Vector3(-0.34, 2.66, 0), dark_wood)
	brace.rotation_degrees.z = -32.0
	_mesh_box(lamp, "ArmEndIronBand", Vector3(0.12, 0.21, 0.21), Vector3(-0.89, 2.88, 0), iron)

	# Lantern cage: glowing panes, dark iron corners, a peaked cap and base.
	var lantern := Node3D.new()
	lantern.name = "HangingLantern"
	lantern.position = Vector3(-0.89, 2.49, 0)
	lamp.add_child(lantern)
	_mesh_box(lantern, "TopCap", Vector3(0.48, 0.12, 0.42), Vector3(0, 0.35, 0), dark_wood)
	_mesh_box(lantern, "CapRoofLeft", Vector3(0.29, 0.07, 0.46), Vector3(-0.12, 0.43, 0), worn_wood).rotation_degrees.z = -22.0
	_mesh_box(lantern, "CapRoofRight", Vector3(0.29, 0.07, 0.46), Vector3(0.12, 0.43, 0), worn_wood).rotation_degrees.z = 22.0
	_mesh_box(lantern, "GlowingFrontPane", Vector3(0.30, 0.42, 0.025), Vector3(0, 0.08, -0.19), glow_glass)
	_mesh_box(lantern, "GlowingSidePane", Vector3(0.025, 0.42, 0.30), Vector3(-0.19, 0.08, 0), glow_glass)
	_mesh_box(lantern, "LanternBase", Vector3(0.42, 0.09, 0.38), Vector3(0, -0.17, 0), iron)
	for x in [-0.19, 0.19]:
		for z in [-0.16, 0.16]:
			_mesh_box(lantern, "IronCorner", Vector3(0.045, 0.48, 0.045), Vector3(x, 0.08, z), iron)
	_mesh_box(lantern, "HangingLoop", Vector3(0.06, 0.16, 0.06), Vector3(0, 0.49, 0), iron)

	var light := OmniLight3D.new()
	light.name = "LanternGlow"
	light.position = Vector3(-0.89, 2.55, 0.18)
	light.light_color = Color(1.0, 0.48, 0.16)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.omni_attenuation = 1.4
	lamp.add_child(light)

func _create_house() -> void:
	var house := Node3D.new()
	house.name = "DistantHouse"
	house.position = HOUSE_POSITION
	add_child(house)

	# Keep the cabin geometry deliberately simple and robust for Godot runtime.
	var log_dark := _mat(Color(0.105, 0.085, 0.075))
	var log_mid := _mat(Color(0.19, 0.14, 0.105))
	var log_light := _mat(Color(0.27, 0.20, 0.14))
	var roof_material := _mat(Color(0.20, 0.24, 0.26))
	var roof_light := _mat(Color(0.30, 0.34, 0.34))
	var trim_material := _mat(Color(0.12, 0.09, 0.065))
	var window_frame := _mat(Color(0.08, 0.065, 0.045))
	var stone_material := _mat(Color(0.22, 0.23, 0.22))

	var window_glow := StandardMaterial3D.new()
	window_glow.albedo_color = Color(1.0, 0.58, 0.16)
	window_glow.emission_enabled = true
	window_glow.emission = Color(1.0, 0.34, 0.045)
	window_glow.emission_energy_multiplier = 2.8

	_mesh_box(house, "StoneFoundation", Vector3(6.4, 0.38, 4.9), Vector3(0, 0.19, 0), stone_material)
	_add_box_collision(house, "FoundationCollision", Vector3(6.4, 0.38, 4.9), Vector3(0, 0.19, 0))
	_mesh_box(house, "CabinBody", Vector3(6.0, 2.65, 4.5), Vector3(0, 1.55, 0), log_dark)
	# Four wall colliders leave the doorway open while preventing passage through the cabin.
	_add_box_collision(house, "BackWallCollision", Vector3(6.0, 2.65, 0.20), Vector3(0, 1.55, -2.22))
	_add_box_collision(house, "LeftWallCollision", Vector3(0.20, 2.65, 4.3), Vector3(-2.92, 1.55, 0))
	_add_box_collision(house, "RightWallCollision", Vector3(0.20, 2.65, 4.3), Vector3(2.92, 1.55, 0))
	_add_box_collision(house, "FrontLeftWallCollision", Vector3(2.0, 2.65, 0.20), Vector3(-2.0, 1.55, 2.22))
	_add_box_collision(house, "FrontRightWallCollision", Vector3(2.0, 2.65, 0.20), Vector3(2.0, 1.55, 2.22))

	# Visible horizontal timber courses on each wall.
	for row in range(10):
		var y := 0.48 + float(row) * 0.245
		var course_material := log_mid
		if row % 2 == 1:
			course_material = log_light
		_mesh_box(house, "FrontWallLog_%02d" % row, Vector3(6.08, 0.105, 0.10), Vector3(0, y, 2.27), course_material)
		_mesh_box(house, "BackWallLog_%02d" % row, Vector3(6.08, 0.105, 0.10), Vector3(0, y, -2.27), course_material)
		_mesh_box(house, "LeftWallLog_%02d" % row, Vector3(0.10, 0.105, 4.52), Vector3(-3.02, y, 0), course_material)
		_mesh_box(house, "RightWallLog_%02d" % row, Vector3(0.10, 0.105, 4.52), Vector3(3.02, y, 0), course_material)

	var gable := MeshInstance3D.new()
	gable.name = "TriangularFrontGable"
	var gable_mesh := PrismMesh.new()
	gable_mesh.size = Vector3(6.0, 2.35, 0.18)
	gable.mesh = gable_mesh
	gable.position = Vector3(0, 3.83, 2.29)
	gable.material_override = log_mid
	house.add_child(gable)

	var roof_left := _mesh_box(house, "RoofLeftSlope", Vector3(3.95, 0.20, 5.35), Vector3(-1.57, 3.55, 0), roof_material)
	roof_left.rotation.z = deg_to_rad(37.0)
	var roof_right := _mesh_box(house, "RoofRightSlope", Vector3(3.95, 0.20, 5.35), Vector3(1.57, 3.55, 0), roof_material)
	roof_right.rotation.z = deg_to_rad(-37.0)
	for i in range(7):
		var z := -2.35 + float(i) * 0.72
		var left_board := _mesh_box(house, "RoofWeatheringL_%02d" % i, Vector3(3.65, 0.025, 0.035), Vector3(-1.57, 3.66, z), roof_light if i % 3 == 0 else roof_material)
		left_board.rotation.z = deg_to_rad(37.0)
		var right_board := _mesh_box(house, "RoofWeatheringR_%02d" % i, Vector3(3.65, 0.025, 0.035), Vector3(1.57, 3.66, z), roof_light if i % 3 == 0 else roof_material)
		right_board.rotation.z = deg_to_rad(-37.0)

	_mesh_box(house, "Chimney", Vector3(0.48, 1.45, 0.48), Vector3(1.45, 4.35, -1.15), stone_material)
	_mesh_box(house, "ChimneyCap", Vector3(0.62, 0.12, 0.62), Vector3(1.45, 5.08, -1.15), log_dark)

	# Door assembly pivots at its left hinge so every plank and fitting moves together.
	_mesh_box(house, "Doorway", Vector3(1.25, 2.18, 0.08), Vector3(0, 1.25, 2.31), _mat(Color(0.025, 0.022, 0.02)))
	door = Node3D.new()
	door.name = "DoorHinge"
	door.position = Vector3(-0.97, 1.02, 2.39)
	house.add_child(door)
	_mesh_box(door, "Door", Vector3(0.98, 2.02, 0.12), Vector3(0.49, 0.0, 0.0), log_dark)
	_add_box_collision(door, "DoorCollision", Vector3(0.98, 2.02, 0.16), Vector3(0.49, 0.0, 0.0))
	door.rotation_degrees.y = 0.0
	for plank in range(4):
		_mesh_box(door, "DoorPlank_%d" % plank, Vector3(0.20, 1.82, 0.025), Vector3(0.20 + float(plank) * 0.19, 0.01, -0.075), log_mid)
	_mesh_box(door, "DoorCrossBrace", Vector3(0.82, 0.10, 0.035), Vector3(0.49, -0.47, -0.10), log_light)
	_mesh_box(door, "DoorKnob", Vector3(0.07, 0.07, 0.07), Vector3(0.79, -0.02, -0.12), _mat(Color(0.68, 0.48, 0.20)))
	_mesh_box(house, "FrontStep", Vector3(2.0, 0.18, 0.72), Vector3(0, 0.12, 2.85), stone_material)
	_add_box_collision(house, "FrontStepCollision", Vector3(2.0, 0.18, 0.72), Vector3(0, 0.12, 2.85))

	# Warm windows: two at ground level and one in the attic gable.
	for window_index in range(3):
		var wx := -1.85
		var wy := 1.75
		var ww := 0.92
		var wh := 0.82
		if window_index == 1:
			wx = 1.75
		elif window_index == 2:
			wx = 0.0
			wy = 3.55
			ww = 0.78
			wh = 0.88
		_mesh_box(house, "WindowFrame_%d" % window_index, Vector3(ww + 0.18, wh + 0.18, 0.13), Vector3(wx, wy, 2.34), window_frame)
		_mesh_box(house, "GlowingWindow_%d" % window_index, Vector3(ww, wh, 0.035), Vector3(wx, wy, 2.265), window_glow)
		_mesh_box(house, "WindowCrossbarV_%d" % window_index, Vector3(0.045, wh, 0.045), Vector3(wx, wy, 2.23), trim_material)
		_mesh_box(house, "WindowCrossbarH_%d" % window_index, Vector3(ww, 0.045, 0.045), Vector3(wx, wy, 2.23), trim_material)

	_mesh_box(house, "SideWindowFrame", Vector3(0.12, 0.72, 0.72), Vector3(3.07, 1.72, -0.65), window_frame)
	_mesh_box(house, "SideGlowingWindow", Vector3(0.04, 0.54, 0.52), Vector3(3.145, 1.72, -0.65), window_glow)

	var porch_roof := _mesh_box(house, "PorchRoof", Vector3(4.15, 0.18, 1.85), Vector3(0, 2.65, 3.05), roof_material)
	porch_roof.rotation.x = deg_to_rad(5.0)
	for x in [-1.75, 1.75]:
		_mesh_box(house, "PorchPost", Vector3(0.14, 2.35, 0.14), Vector3(x, 1.18, 3.78), trim_material)
		_mesh_box(house, "PorchPostFoot", Vector3(0.25, 0.16, 0.25), Vector3(x, 0.15, 3.78), log_light)
	_mesh_box(house, "PorchRailing", Vector3(1.2, 0.10, 0.10), Vector3(1.10, 0.75, 3.76), log_mid)

	var porch_light := OmniLight3D.new()
	porch_light.name = "WarmWindowSpill"
	porch_light.position = Vector3(0, 1.9, 3.0)
	porch_light.light_color = Color(1.0, 0.55, 0.20)
	porch_light.light_energy = 1.1
	porch_light.omni_range = 8.0
	porch_light.omni_attenuation = 1.5
	house.add_child(porch_light)


func _create_expanded_landscape() -> void:
	# A wider wilderness with layered soil, uneven ridges, boulders, and a river valley.
	var rng := RandomNumberGenerator.new()
	rng.seed = 613908
	var soil_materials := [
		_mat(Color(0.24, 0.22, 0.18)),
		_mat(Color(0.29, 0.27, 0.22)),
		_mat(Color(0.17, 0.18, 0.16)),
		_mat(Color(0.32, 0.29, 0.23)),
		_mat(Color(0.21, 0.24, 0.19))
	]
	var rock_materials := [
		_mat(Color(0.31, 0.32, 0.31)),
		_mat(Color(0.22, 0.23, 0.23)),
		_mat(Color(0.39, 0.38, 0.34)),
		_mat(Color(0.16, 0.17, 0.17))
	]
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.20, 0.31, 0.32, 0.88)
	water_material.roughness = 0.22
	water_material.metallic = 0.08
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Broad, thin soil patches give the ground several distinct natural surfaces.
	for i in range(145):
		var patch := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = rng.randf_range(1.2, 4.8)
		mesh.bottom_radius = mesh.top_radius * rng.randf_range(0.72, 1.18)
		mesh.height = rng.randf_range(0.025, 0.075)
		mesh.radial_segments = rng.randi_range(5, 9)
		patch.mesh = mesh
		var x := rng.randf_range(-75.0, 75.0)
		var z := rng.randf_range(-78.0, 78.0)
		# Keep the river corridor clear enough to read as a continuous valley.
		if x > 15.0 and x < 39.0:
			x = -rng.randf_range(20.0, 65.0)
		patch.position = Vector3(x, 0.018 + float(i % 3) * 0.004, z)
		patch.rotation.y = rng.randf_range(0.0, TAU)
		patch.material_override = soil_materials[rng.randi_range(0, soil_materials.size() - 1)]
		add_child(patch)

	# Scattered low-poly stones range from pebbles to large boulders.
	for i in range(245):
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 1.6
		mesh.radial_segments = rng.randi_range(5, 8)
		mesh.rings = rng.randi_range(3, 5)
		rock.mesh = mesh
		var x := rng.randf_range(-78.0, 78.0)
		var z := rng.randf_range(-80.0, 80.0)
		# Leave the main trail and the water surface mostly unobstructed.
		if absf(x) < 4.0 and z > -38.0 and z < 12.0:
			x = -rng.randf_range(5.0, 10.0)
		if x > 18.0 and x < 37.0:
			x = rng.randf_range(-70.0, 8.0)
		var size := rng.randf_range(0.12, 0.48)
		if i % 13 == 0:
			size = rng.randf_range(0.75, 1.45)
		rock.scale = Vector3(size * rng.randf_range(0.8, 1.4), size * rng.randf_range(0.55, 1.0), size * rng.randf_range(0.8, 1.3))
		rock.position = Vector3(x, rock.scale.y * 0.42, z)
		rock.rotation = Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(0.0, TAU), rng.randf_range(-0.18, 0.18))
		rock.material_override = rock_materials[rng.randi_range(0, rock_materials.size() - 1)]
		add_child(rock)
		var rock_body := StaticBody3D.new()
		rock_body.name = "BoulderCollision_%03d" % i
		rock_body.position = rock.position
		rock_body.rotation = rock.rotation
		var rock_shape_node := CollisionShape3D.new()
		var rock_shape := SphereShape3D.new()
		rock_shape.radius = maxf(rock.scale.x, rock.scale.z) * 0.82
		rock_shape_node.shape = rock_shape
		rock_body.add_child(rock_shape_node)
		add_child(rock_body)

	# Low irregular ridges on both sides of the valley.
	for i in range(34):
		var ridge := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rng.randf_range(5.0, 14.0), rng.randf_range(0.45, 1.5), rng.randf_range(2.5, 6.0))
		ridge.mesh = mesh
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(10.0, 72.0)
		if side > 0.0 and x < 39.0:
			x = rng.randf_range(40.0, 70.0)
		ridge.position = Vector3(x, mesh.size.y * 0.25 - 0.06, rng.randf_range(-76.0, 76.0))
		ridge.rotation.y = rng.randf_range(-0.6, 0.6)
		ridge.rotation.z = rng.randf_range(-0.12, 0.12)
		ridge.material_override = soil_materials[rng.randi_range(0, soil_materials.size() - 1)]
		add_child(ridge)
		_add_box_collision(self, "RidgeCollision_%02d" % i, mesh.size, ridge.position, ridge.rotation)

	# A long winding river occupies a shallow valley to the east of the cabin.
	# Overlapping segments follow a gentle curve; raised banks frame the water.
	var water_segments := 64
	for i in range(water_segments):
		var t := (float(i) + 0.5) / float(water_segments)
		var z := lerpf(78.0, -78.0, t)
		var x := 27.0 + sin(t * TAU * 1.35) * 5.5
		var next_t := minf(1.0, t + 1.0 / float(water_segments))
		var next_x := 27.0 + sin(next_t * TAU * 1.35) * 5.5
		var segment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(5.6, 0.10, 2.8)
		segment.mesh = mesh
		segment.position = Vector3(x, 0.065, z)
		segment.rotation.y = atan2(next_x - x, -(lerpf(78.0, -78.0, next_t) - z))
		segment.material_override = water_material
		add_child(segment)
		for bank_side in [-1.0, 1.0]:
			var bank := MeshInstance3D.new()
			var bank_mesh := BoxMesh.new()
			bank_mesh.size = Vector3(1.2, 0.42, 3.0)
			bank.mesh = bank_mesh
			bank.position = Vector3(x + bank_side * 3.1, 0.12, z)
			bank.rotation.y = segment.rotation.y
			bank.material_override = soil_materials[1] if i % 3 == 0 else soil_materials[2]
			add_child(bank)
			_add_box_collision(self, "RiverBankCollision_%02d_%d" % [i, int(bank_side)], bank_mesh.size, bank.position, Vector3(0.0, bank.rotation.y, 0.0))

	# A lower, narrow stream sits beneath a separate rocky ravine at the far end.
	for i in range(28):
		var t := (float(i) + 0.5) / 28.0
		var z := lerpf(-80.0, -34.0, t)
		var x := -38.0 + sin(t * TAU * 1.2) * 3.2
		var stream := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.7, 0.06, 2.0)
		stream.mesh = mesh
		stream.position = Vector3(x, 0.055, z)
		stream.rotation.y = sin(t * TAU * 1.2) * 0.12
		stream.material_override = water_material
		add_child(stream)
		for side in [-1.0, 1.0]:
			var cliff := MeshInstance3D.new()
			var cliff_mesh := BoxMesh.new()
			cliff_mesh.size = Vector3(rng.randf_range(2.0, 4.2), rng.randf_range(1.0, 2.3), 2.5)
			cliff.mesh = cliff_mesh
			cliff.position = Vector3(x + side * 3.0, 0.10 + cliff_mesh.size.y * 0.2, z)
			cliff.rotation.z = side * rng.randf_range(-0.16, 0.16)
			cliff.material_override = rock_materials[rng.randi_range(0, rock_materials.size() - 1)]
			add_child(cliff)
			_add_box_collision(self, "RavineCliffCollision_%02d_%d" % [i, int(side)], cliff_mesh.size, cliff.position, cliff.rotation)

	# Small low-poly fish silhouettes swim along the main river.
	var fish_material := _mat(Color(0.62, 0.65, 0.61))
	for i in range(12):
		var fish := Node3D.new()
		fish.name = "RiverFish_%02d" % i
		fish.position = Vector3(27.0 + sin(float(i) * 1.7) * 1.6, 0.16, -72.0 + float(i) * 12.0)
		fish.set_meta("home_x", fish.position.x)
		var body := MeshInstance3D.new()
		var body_mesh := SphereMesh.new()
		body_mesh.radius = 0.22
		body_mesh.height = 0.24
		body.mesh = body_mesh
		body.scale = Vector3(1.35, 0.55, 0.65)
		body.material_override = fish_material
		fish.add_child(body)
		var tail := MeshInstance3D.new()
		var tail_mesh := PrismMesh.new()
		tail_mesh.size = Vector3(0.18, 0.18, 0.05)
		tail.mesh = tail_mesh
		tail.position = Vector3(0.28, 0.0, 0.0)
		tail.rotation.y = deg_to_rad(90.0)
		tail.material_override = fish_material
		fish.add_child(tail)
		add_child(fish)
		river_fish.append(fish)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Boy"
	player.position = Vector3(0, 0.68, 5.0)
	player.scale = Vector3(0.72, 0.72, 0.72)
	player.set_script(load("res://scripts/player.gd"))
	player.process_mode = Node.PROCESS_MODE_PAUSABLE

	# Stylized human silhouette based on the supplied reference: oversized head,
	# soft blocky hair, narrow neck, simple rounded tunic, short arms and slim legs.
	var silhouette := _mat(Color(0.012, 0.012, 0.015))
	var clothing := _mat(Color(0.025, 0.025, 0.03))
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 1.0, 1.0)
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_material.emission_enabled = true
	eye_material.emission = Color(0.95, 0.95, 1.0)
	eye_material.emission_energy_multiplier = 2.2

	# Main torso: slightly wider at the shoulders and rounded at the hem.
	var torso := MeshInstance3D.new()
	torso.name = "Body"
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.255
	torso_mesh.height = 0.82
	torso.mesh = torso_mesh
	torso.position = Vector3(0.0, -0.17, 0.0)
	torso.scale = Vector3(0.92, 1.0, 0.72)
	torso.material_override = clothing
	player.add_child(torso)

	var neck := MeshInstance3D.new()
	neck.name = "Neck"
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.085
	neck_mesh.bottom_radius = 0.105
	neck_mesh.height = 0.20
	neck.mesh = neck_mesh
	neck.position = Vector3(0.0, 0.31, 0.0)
	neck.material_override = silhouette
	player.add_child(neck)

	# Large head, with asymmetrical angular hair tufts to make the silhouette distinctive.
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.37
	head_mesh.height = 0.72
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.64, 0.0)
	head.scale = Vector3(1.0, 1.0, 0.82)
	head.material_override = silhouette
	player.add_child(head)

	var hair_cap := MeshInstance3D.new()
	hair_cap.name = "HairSilhouette"
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.365
	hair_mesh.height = 0.48
	hair_cap.mesh = hair_mesh
	hair_cap.position = Vector3(0.025, 0.79, 0.005)
	hair_cap.scale = Vector3(1.0, 0.72, 0.88)
	hair_cap.material_override = silhouette
	player.add_child(hair_cap)

	for tuft_data in [
		Vector3(-0.22, 0.99, -0.005),
		Vector3(-0.11, 1.015, 0.0),
		Vector3(0.18, 0.94, 0.0)
	]:
		var tuft := MeshInstance3D.new()
		var tuft_mesh := PrismMesh.new()
		tuft_mesh.size = Vector3(0.16, 0.20, 0.20)
		tuft.mesh = tuft_mesh
		tuft.position = tuft_data
		tuft.rotation.z = deg_to_rad(-12.0)
		tuft.material_override = silhouette
		player.add_child(tuft)

	# Articulated shoulders, biceps, forearms and palms.
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0 else "R"
		var shoulder := Node3D.new()
		shoulder.name = "Shoulder_" + suffix
		shoulder.position = Vector3(side * 0.235, 0.12, 0.0)
		player.add_child(shoulder)
		var joint_mesh := SphereMesh.new()
		joint_mesh.radius = 0.105
		joint_mesh.height = 0.20
		var joint := MeshInstance3D.new()
		joint.mesh = joint_mesh
		joint.material_override = clothing
		shoulder.add_child(joint)
		var upper_mesh := CapsuleMesh.new()
		upper_mesh.radius = 0.078
		upper_mesh.height = 0.34
		var upper := MeshInstance3D.new()
		upper.mesh = upper_mesh
		upper.position.y = -0.19
		upper.material_override = clothing
		shoulder.add_child(upper)
		var elbow := Node3D.new()
		elbow.name = "Forearm_" + suffix
		elbow.position.y = -0.36
		shoulder.add_child(elbow)
		var lower_mesh := CapsuleMesh.new()
		lower_mesh.radius = 0.061
		lower_mesh.height = 0.32
		var lower := MeshInstance3D.new()
		lower.mesh = lower_mesh
		lower.position.y = -0.16
		lower.material_override = clothing
		elbow.add_child(lower)
		var palm := Node3D.new()
		palm.name = "Palm_" + suffix
		palm.position = Vector3(0.0, -0.33, -0.005)
		elbow.add_child(palm)
		var palm_mesh := SphereMesh.new()
		palm_mesh.radius = 0.065
		palm_mesh.height = 0.13
		var palm_visual := MeshInstance3D.new()
		palm_visual.mesh = palm_mesh
		palm_visual.scale = Vector3(0.8, 1.0, 0.72)
		palm_visual.material_override = silhouette
		palm.add_child(palm_visual)

	# Separate thigh, calf and foot joints create a readable leg cycle.
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0 else "R"
		var hip := Node3D.new()
		hip.name = "Thigh_" + suffix
		hip.position = Vector3(side * 0.105, -0.43, 0.0)
		player.add_child(hip)
		var thigh_mesh := CapsuleMesh.new()
		thigh_mesh.radius = 0.083
		thigh_mesh.height = 0.38
		var thigh := MeshInstance3D.new()
		thigh.mesh = thigh_mesh
		thigh.position.y = -0.19
		thigh.material_override = clothing
		hip.add_child(thigh)
		var knee := Node3D.new()
		knee.name = "Calf_" + suffix
		knee.position.y = -0.37
		hip.add_child(knee)
		var calf_mesh := CapsuleMesh.new()
		calf_mesh.radius = 0.066
		calf_mesh.height = 0.34
		var calf := MeshInstance3D.new()
		calf.mesh = calf_mesh
		calf.position.y = -0.17
		calf.material_override = clothing
		knee.add_child(calf)
		var ankle := Node3D.new()
		ankle.name = "Foot_" + suffix
		ankle.position = Vector3(0.0, -0.34, -0.035)
		knee.add_child(ankle)
		var shoe_mesh := BoxMesh.new()
		shoe_mesh.size = Vector3(0.13, 0.085, 0.23)
		var shoe := MeshInstance3D.new()
		shoe.mesh = shoe_mesh
		shoe.position = Vector3(0.0, -0.025, -0.055)
		shoe.material_override = silhouette
		ankle.add_child(shoe)

	# Bright, softly glowing eyes visible through the dark face.
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "Eye_%s" % ("L" if side < 0 else "R")
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.052
		eye_mesh.height = 0.15
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.12, 0.66, -0.296)
		eye.scale = Vector3(0.72, 1.0, 0.42)
		eye.material_override = eye_material
		player.add_child(eye)

	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = -0.02
	player.add_child(collider)

	# The camera sits on a pivot near the character's centre, allowing true orbiting.
	var camera_pivot := Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 0.90, 0.0)
	player.add_child(camera_pivot)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 2.29, 9.45)
	camera.current = true
	camera_pivot.add_child(camera)
	camera.look_at(camera_pivot.global_position, Vector3.UP)
	add_child(player)

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
