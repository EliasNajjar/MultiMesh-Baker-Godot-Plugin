@tool
extends EditorPlugin

var _bake_button_3d: Button
var _unbake_button_3d: Button
var _bake_button_2d: Button
var _unbake_button_2d: Button

var _draw_button_3d: CheckBox
var _rotate_button_3d: CheckBox
var _vertical_rotate_button_3d: CheckBox
var _draw_button_2d: CheckBox

var baker  = preload("res://addons/drawing_tool/bake_unbake.gd").new()
var drawer = preload("res://addons/drawing_tool/drawing.gd").new()

func _enter_tree() -> void:
	EditorInterface.get_base_control().add_child(drawer)
	drawer.on_deactivated = _on_draw_deactivated

	_bake_button_3d = Button.new()
	_bake_button_3d.text = "Meshes -> MultiMesh"
	_bake_button_3d.tooltip_text = "Convert selected node's children into a MultiMesh sibling"
	_bake_button_3d.pressed.connect(baker._on_bake_to_multimesh_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _bake_button_3d)

	_unbake_button_3d = Button.new()
	_unbake_button_3d.text = "MultiMesh -> Meshes"
	_unbake_button_3d.tooltip_text = "Convert selected MultiMesh into MeshInstance children"
	_unbake_button_3d.pressed.connect(baker._on_unbake_to_meshes_pressed)
	_unbake_button_3d.visible = false
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _unbake_button_3d)

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

	_bake_button_2d = Button.new()
	_bake_button_2d.text = "Meshes -> MultiMesh"
	_bake_button_2d.tooltip_text = "Convert selected node's children into a MultiMesh sibling"
	_bake_button_2d.pressed.connect(baker._on_bake_to_multimesh_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _bake_button_2d)

	_unbake_button_2d = Button.new()
	_unbake_button_2d.text = "MultiMesh -> Meshes"
	_unbake_button_2d.tooltip_text = "Convert selected MultiMesh into MeshInstance children"
	_unbake_button_2d.pressed.connect(baker._on_unbake_to_meshes_pressed)
	_unbake_button_2d.visible = false
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _unbake_button_2d)

	_draw_button_2d = CheckBox.new()
	_draw_button_2d.text = "Draw"
	_draw_button_2d.tooltip_text = "Toggle draw mode: click in the 2D viewport to place the selected node"
	_draw_button_2d.pressed.connect(_on_draw_toggled)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _draw_button_2d)

	var sel := EditorInterface.get_selection()
	if sel and not sel.selection_changed.is_connected(_update_unbake_buttons_visibility):
		sel.selection_changed.connect(_update_unbake_buttons_visibility)
	_update_unbake_buttons_visibility()

func _exit_tree() -> void:
	var sel := EditorInterface.get_selection()
	if sel and sel.selection_changed.is_connected(_update_unbake_buttons_visibility):
		sel.selection_changed.disconnect(_update_unbake_buttons_visibility)

	if drawer._active:
		drawer.deactivate()
	if drawer.get_parent() != null:
		drawer.get_parent().remove_child(drawer)
	drawer.queue_free()

	if _bake_button_3d:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _bake_button_3d)
		_bake_button_3d.queue_free()
	if _unbake_button_3d:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _unbake_button_3d)
		_unbake_button_3d.queue_free()
	if _draw_button_3d:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _draw_button_3d)
		_draw_button_3d.queue_free()
	if _rotate_button_3d:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _rotate_button_3d)
		_rotate_button_3d.queue_free()
	if _vertical_rotate_button_3d:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _vertical_rotate_button_3d)
		_vertical_rotate_button_3d.queue_free()

	if _bake_button_2d:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _bake_button_2d)
		_bake_button_2d.queue_free()
	if _unbake_button_2d:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _unbake_button_2d)
		_unbake_button_2d.queue_free()
	if _draw_button_2d:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _draw_button_2d)
		_draw_button_2d.queue_free()


func _on_draw_toggled() -> void:
	if drawer._active:
		drawer.deactivate()
	else:
		drawer.activate()
		_draw_button_3d.button_pressed = true
		_draw_button_2d.button_pressed = true
		_set_rotation_buttons_visible(true)

func _on_draw_deactivated() -> void:
	_draw_button_3d.button_pressed = false
	_draw_button_2d.button_pressed = false
	_set_rotation_buttons_visible(false)

func _on_rotate_toggled(pressed: bool) -> void:
	drawer.allow_rotation = pressed
	_rotate_button_3d.button_pressed = pressed
	if not pressed:
		drawer.allow_vertical_rotation = false
		_vertical_rotate_button_3d.button_pressed = false
	_vertical_rotate_button_3d.disabled = not pressed

func _on_vertical_rotate_toggled(pressed: bool) -> void:
	drawer.allow_vertical_rotation = pressed
	_vertical_rotate_button_3d.button_pressed = pressed

func _set_rotation_buttons_visible(visible: bool) -> void:
	_rotate_button_3d.visible = visible
	_vertical_rotate_button_3d.visible = visible

func _update_unbake_buttons_visibility() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	var show := false
	if selected.size() == 1:
		var node := selected.front()
		show = (node is MultiMeshInstance2D) or (node is MultiMeshInstance3D)

	if _unbake_button_3d:
		_unbake_button_3d.visible = show
	if _unbake_button_2d:
		_unbake_button_2d.visible = show
