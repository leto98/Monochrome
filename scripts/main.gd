extends Node3D

const TREE_COUNT := 76
const GRASS_CLUMPS := 220
const DEBRIS_COUNT := 95
const HOUSE_POSITION := Vector3(0.0, 0.0, -25.0)
const DOOR_POSITION := Vector3(0.0, 1.0, -21.5)
const INTERACTION_DISTANCE := 2.6

var player: CharacterBody3D
var door: MeshInstance3D
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_environment()
	_create_ground_and_path()
	_create_forest()
	_create_ground_details()
	_create_debris()
	_create_house()
	_create_player()
	_create_ui()
	_create_menu_screens()
	interaction_audio = AudioStreamPlayer3D.new()
	interaction_audio.name = "WorldInteractionAudio"
	interaction_audio.volume_db = -10.0
	interaction_audio.max_distance = 16.0
	interaction_audio.unit_size = 4.0
	add_child(interaction_audio)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true

func _process(_delta: float) -> void:
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
	player.position = Vector3(0.0, 0.95, 5.0)
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
	ground_mesh.size = Vector3(100, 1, 100)
	var ground_visual := MeshInstance3D.new()
	ground_visual.mesh = ground_mesh
	ground_visual.position.y = -0.5
	ground_visual.material_override = _mat(Color(0.20, 0.25, 0.15))
	ground.add_child(ground_visual)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(100, 1, 100)
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
	var trunk_material := _mat(Color(0.105, 0.105, 0.112))
	var trunk_light := _mat(Color(0.145, 0.145, 0.152))
	var bark_shadow := _mat(Color(0.075, 0.075, 0.082))
	var leaf_material := _mat(Color(0.205, 0.205, 0.215))
	var leaf_light := _mat(Color(0.265, 0.265, 0.275))
	var leaf_dark := _mat(Color(0.155, 0.155, 0.165))
	var rng := RandomNumberGenerator.new()
	rng.seed = 24019
	for i in range(TREE_COUNT):
		var side := -1.0 if i % 2 == 0 else 1.0
		var tree := Node3D.new()
		tree.name = "Tree_%02d" % i
		var x := side * rng.randf_range(3.4, 15.0)
		var z := rng.randf_range(-43.0, 16.0)
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

		for crown_index in range(3):
			var crown := MeshInstance3D.new()
			var crown_mesh := PrismMesh.new()
			var crown_width := rng.randf_range(1.7, 2.8)
			crown_mesh.size = Vector3(crown_width, rng.randf_range(1.8, 2.8), crown_width * rng.randf_range(0.7, 1.1))
			crown.mesh = crown_mesh
			crown.position = Vector3(rng.randf_range(-0.55, 0.55), height + crown_index * 0.55, rng.randf_range(-0.45, 0.45))
			crown.rotation.y = rng.randf_range(-0.7, 0.7)
			crown.material_override = [leaf_dark, leaf_material, leaf_light][crown_index]
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
		var px := rng.randf_range(-15.0, 15.0)
		var pz := rng.randf_range(-43.0, 17.0)
		patch.position = Vector3(px, 0.012, pz)
		patch.rotation.y = rng.randf_range(0.0, TAU)
		patch.material_override = soil_material if i % 3 != 0 else moss_material
		add_child(patch)

	# Small angular blades in uneven clumps, kept away from the centre of the path.
	for i in range(GRASS_CLUMPS):
		var x := rng.randf_range(-15.0, 15.0)
		var z := rng.randf_range(-44.0, 18.0)
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
		var x := rng.randf_range(-14.0, 14.0)
		var z := rng.randf_range(-44.0, 18.0)
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

func _create_house() -> void:
	var house := Node3D.new()
	house.name = "DistantHouse"
	house.position = HOUSE_POSITION
	add_child(house)

	var wall_material := _mat(Color(0.20, 0.15, 0.12))
	var roof_material := _mat(Color(0.12, 0.15, 0.16))
	var trim_material := _mat(Color(0.31, 0.23, 0.15))
	var door_material := _mat(Color(0.09, 0.055, 0.04))
	var window_frame := _mat(Color(0.10, 0.07, 0.045))
	var window_glow := StandardMaterial3D.new()
	window_glow.albedo_color = Color(1.0, 0.58, 0.19)
	window_glow.emission_enabled = true
	window_glow.emission = Color(1.0, 0.38, 0.08)
	window_glow.emission_energy_multiplier = 2.0

	_mesh_box(house, "HouseBody", Vector3(6.2, 2.8, 4.7), Vector3(0, 1.4, 0), wall_material)
	var gable := MeshInstance3D.new()
	gable.name = "FrontGable"
	var gable_mesh := PrismMesh.new()
	gable_mesh.size = Vector3(6.2, 2.1, 0.16)
	gable.mesh = gable_mesh
	gable.position = Vector3(0, 3.7, 2.35)
	gable.material_override = wall_material
	house.add_child(gable)

	var roof_left := _mesh_box(house, "RoofLeftSlope", Vector3(3.8, 0.22, 5.4), Vector3(-1.55, 3.45, 0), roof_material)
	roof_left.rotation.z = deg_to_rad(32.0)
	var roof_right := _mesh_box(house, "RoofRightSlope", Vector3(3.8, 0.22, 5.4), Vector3(1.55, 3.45, 0), roof_material)
	roof_right.rotation.z = deg_to_rad(-32.0)
	_mesh_box(house, "FrontStep", Vector3(2.4, 0.18, 0.8), Vector3(0, 0.09, 2.8), trim_material)

	_mesh_box(house, "Doorway", Vector3(1.35, 2.25, 0.08), Vector3(0, 1.12, 2.39), _mat(Color(0.025, 0.022, 0.02)))
	door = _mesh_box(house, "Door", Vector3(1.05, 2.05, 0.12), Vector3(-0.53, 1.03, 2.48), door_material)
	door.rotation_degrees.y = 0.0
	door.set_meta("closed_position", door.position)
	_mesh_box(house, "DoorPanel", Vector3(0.72, 1.52, 0.035), Vector3(-0.53, 1.05, 2.405), trim_material)
	_mesh_box(house, "DoorKnob", Vector3(0.07, 0.07, 0.07), Vector3(-0.18, 1.0, 2.36), _mat(Color(0.68, 0.48, 0.20)))

	for window_data in [Vector3(-1.75, 1.85, 2.43), Vector3(1.75, 1.85, 2.43), Vector3(0.0, 3.35, 2.43)]:
		_mesh_box(house, "WindowFrame", Vector3(0.92, 0.92, 0.12), window_data, window_frame)
		_mesh_box(house, "GlowingWindow", Vector3(0.68, 0.68, 0.035), Vector3(window_data.x, window_data.y, 2.355), window_glow)
		_mesh_box(house, "WindowCrossbarV", Vector3(0.045, 0.72, 0.045), Vector3(window_data.x, window_data.y, 2.325), trim_material)
		_mesh_box(house, "WindowCrossbarH", Vector3(0.72, 0.045, 0.045), Vector3(window_data.x, window_data.y, 2.325), trim_material)

	var porch_roof := _mesh_box(house, "SmallPorchRoof", Vector3(3.8, 0.16, 1.4), Vector3(0, 2.65, 3.05), roof_material)
	porch_roof.rotation.x = deg_to_rad(7.0)
	for x in [-1.55, 1.55]:
		_mesh_box(house, "PorchPost", Vector3(0.13, 2.45, 0.13), Vector3(x, 1.22, 3.55), trim_material)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Boy"
	player.position = Vector3(0, 0.95, 5.0)
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

	# Arms rest close to the body so they read as a single clean silhouette.
	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.085
	arm_mesh.height = 0.54
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "UpperArm_%s" % ("L" if side < 0 else "R")
		arm.position = Vector3(side * 0.235, 0.02, 0.0)
		player.add_child(arm)
		var arm_visual := MeshInstance3D.new()
		arm_visual.name = "ArmMesh"
		arm_visual.mesh = arm_mesh
		arm_visual.position = Vector3(side * 0.015, -0.25, 0.0)
		arm_visual.rotation.z = side * deg_to_rad(-7.0)
		arm_visual.material_override = clothing
		arm.add_child(arm_visual)

		var hand := MeshInstance3D.new()
		hand.name = "Hand_%s" % ("L" if side < 0 else "R")
		var hand_mesh := SphereMesh.new()
		hand_mesh.radius = 0.065
		hand_mesh.height = 0.13
		hand.mesh = hand_mesh
		hand.position = Vector3(side * 0.025, -0.53, -0.005)
		hand.scale = Vector3(0.9, 1.0, 0.8)
		hand.material_override = silhouette
		arm.add_child(hand)

	# Short, slim trouser legs and narrow feet, kept separate for the walk cycle.
	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.085
	leg_mesh.height = 0.52
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		leg.name = "Leg_%s" % ("L" if side < 0 else "R")
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.105, -0.59, 0.0)
		leg.material_override = clothing
		player.add_child(leg)

		var foot := MeshInstance3D.new()
		foot.name = "Foot_%s" % ("L" if side < 0 else "R")
		var foot_mesh := CapsuleMesh.new()
		foot_mesh.radius = 0.055
		foot_mesh.height = 0.25
		foot.mesh = foot_mesh
		foot.position = Vector3(side * 0.105, -0.84, -0.055)
		foot.rotation.x = deg_to_rad(90.0)
		foot.material_override = silhouette
		player.add_child(foot)

	# Bright, softly glowing eyes visible through the dark face.
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "Eye_%s" % ("L" if side < 0 else "R")
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.038
		eye_mesh.height = 0.09
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.125, 0.66, -0.292)
		eye.scale = Vector3(0.78, 1.0, 0.55)
		eye.material_override = eye_material
		player.add_child(eye)

	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	collider.shape = capsule
	player.add_child(collider)

	# The camera sits on a pivot near the character's centre, allowing true orbiting.
	var camera_pivot := Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 0.65, 0.0)
	player.add_child(camera_pivot)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 1.65, 6.8)
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
