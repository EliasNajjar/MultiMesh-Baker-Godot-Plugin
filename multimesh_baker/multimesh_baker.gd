@tool
extends EditorPlugin

var _button_3d: Button
var _button_2d: Button
var _draw_button_3d: CheckBox
var _draw_button_2d: CheckBox
var _rotate_button_3d: CheckBox
var _rotate_button_2d: CheckBox
var _vertical_rotate_button_3d: CheckBox
var _vertical_rotate_button_2d: CheckBox

var baker  = preload("res://addons/multimesh_baker/bake_unbake.gd").new()
var drawer = preload("res://addons/multimesh_baker/drawing.gd").new()

func _enter_tree() -> void:
	drawer.setup(self)
	EditorInterface.get_base_control().add_child(drawer)
	drawer.on_deactivated = _on_draw_deactivated

	# ── 3-D toolbar ──────────────────────────────────────────────
	_button_3d = Button.new()
	_button_3d.text = "Meshes <-> MultiMesh"
	_button_3d.tooltip_text = "Convert selected node's children into a MultiMesh sibling"
	_button_3d.pressed.connect(baker._on_bake_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _button_3d)

	_draw_button_3d = CheckBox.new()
	_draw_button_3d.text = "Draw"
	_draw_button_3d.tooltip_text = "Toggle draw mode: click in the 3D viewport to place the selected node on existing geometry"
	_draw_button_3d.pressed.connect(_on_draw_toggled)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _draw_button_3d)

	_rotate_button_3d = CheckBox.new()
	_rotate_button_3d.text = "Rotate"
	_rotate_button_3d.tooltip_text = "When checked, placed nodes rotate to match the surface. When unchecked, they keep the template's rotation."
	_rotate_button_3d.button_pressed = true
	_rotate_button_3d.visible = false
	_rotate_button_3d.toggled.connect(_on_rotate_toggled)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _rotate_button_3d)

	_vertical_rotate_button_3d = CheckBox.new()
	_vertical_rotate_button_3d.text = "Vertical Rotation"
	_vertical_rotate_button_3d.tooltip_text = "When checked, +Y aligns with the surface normal. When unchecked, only heading (Y-axis rotation) is applied."
	_vertical_rotate_button_3d.button_pressed = true
	_vertical_rotate_button_3d.visible = false
	_vertical_rotate_button_3d.toggled.connect(_on_vertical_rotate_toggled)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _vertical_rotate_button_3d)

	# ── 2-D toolbar ──────────────────────────────────────────────
	_button_2d = Button.new()
	_button_2d.text = "Meshes <-> MultiMesh"
	_button_2d.tooltip_text = "Convert selected node's children into a MultiMesh sibling"
	_button_2d.pressed.connect(baker._on_bake_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _button_2d)

	_draw_button_2d = CheckBox.new()
	_draw_button_2d.text = "Draw"
	_draw_button_2d.tooltip_text = "Toggle draw mode: click in the 2D viewport to place the selected node"
	_draw_button_2d.pressed.connect(_on_draw_toggled)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _draw_button_2d)

	_rotate_button_2d = CheckBox.new()
	_rotate_button_2d.text = "Rotate"
	_rotate_button_2d.tooltip_text = "When checked, placed nodes rotate to match the surface. When unchecked, they keep the template's rotation."
	_rotate_button_2d.button_pressed = true
	_rotate_button_2d.visible = false
	_rotate_button_2d.toggled.connect(_on_rotate_toggled)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _rotate_button_2d)

	_vertical_rotate_button_2d = CheckBox.new()
	_vertical_rotate_button_2d.text = "Vertical Rotation"
	_vertical_rotate_button_2d.tooltip_text = "When checked, +Y aligns with the surface normal. When unchecked, only heading (Y-axis rotation) is applied."
	_vertical_rotate_button_2d.button_pressed = true
	_vertical_rotate_button_2d.visible = false
	_vertical_rotate_button_2d.toggled.connect(_on_vertical_rotate_toggled)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _vertical_rotate_button_2d)


func _exit_tree() -> void:
	if drawer.is_active():
		drawer.deactivate()
	if drawer.get_parent() != null:
		drawer.get_parent().remove_child(drawer)
	drawer.queue_free()

	if _button_3d:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _button_3d)
		_button_3d.queue_free()
	if _draw_button_3d:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _draw_button_3d)
		_draw_button_3d.queue_free()
	if _rotate_button_3d:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _rotate_button_3d)
		_rotate_button_3d.queue_free()
	if _vertical_rotate_button_3d:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _vertical_rotate_button_3d)
		_vertical_rotate_button_3d.queue_free()
	if _button_2d:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _button_2d)
		_button_2d.queue_free()
	if _draw_button_2d:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _draw_button_2d)
		_draw_button_2d.queue_free()
	if _rotate_button_2d:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _rotate_button_2d)
		_rotate_button_2d.queue_free()
	if _vertical_rotate_button_2d:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _vertical_rotate_button_2d)
		_vertical_rotate_button_2d.queue_free()


# ── Button callbacks ──────────────────────────────────────────────

func _on_draw_toggled() -> void:
	if drawer.is_active():
		drawer.deactivate()  # will call _on_draw_deactivated via the callback
	else:
		drawer.activate()
		_draw_button_3d.button_pressed = true
		_draw_button_2d.button_pressed = true
		_set_rotation_buttons_visible(true)


# Called by drawer.on_deactivated when draw mode ends (button or ui_cancel).
func _on_draw_deactivated() -> void:
	_draw_button_3d.button_pressed = false
	_draw_button_2d.button_pressed = false
	_set_rotation_buttons_visible(false)


func _on_rotate_toggled(pressed: bool) -> void:
	drawer.allow_rotation = pressed
	_rotate_button_3d.button_pressed = pressed
	_rotate_button_2d.button_pressed = pressed
	# When rotation is turned off, also turn off vertical rotation.
	if not pressed:
		drawer.allow_vertical_rotation = false
		_vertical_rotate_button_3d.button_pressed = false
		_vertical_rotate_button_2d.button_pressed = false
	# Second checkbox is visible but disabled when rotation is off.
	_vertical_rotate_button_3d.disabled = not pressed
	_vertical_rotate_button_2d.disabled = not pressed


func _on_vertical_rotate_toggled(pressed: bool) -> void:
	drawer.allow_vertical_rotation = pressed
	_vertical_rotate_button_3d.button_pressed = pressed
	_vertical_rotate_button_2d.button_pressed = pressed


func _set_rotation_buttons_visible(visible: bool) -> void:
	_rotate_button_3d.visible = visible
	_rotate_button_2d.visible = visible
	_vertical_rotate_button_3d.visible = visible
	_vertical_rotate_button_2d.visible = visible
