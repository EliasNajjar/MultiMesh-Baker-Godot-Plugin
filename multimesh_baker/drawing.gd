@tool
extends Node

var _active: bool = false

var _ghost: Node = null

var _draw_layer: Node = null
var _draw_layer_template: Node = null

var on_deactivated: Callable = Callable()

var allow_rotation: bool = true
var allow_vertical_rotation: bool = true

func activate() -> void:
	_active = true
	_draw_layer = null
	_draw_layer_template = null
	print("MultiMesh Baker – Draw mode ON  (click to place, ui_cancel to exit)")

func deactivate() -> void:
	_active = false
	_destroy_ghost()
	print("MultiMesh Baker – Draw mode OFF")
	if on_deactivated.is_valid():
		on_deactivated.call()

func _process(_delta: float) -> void:
	if not _active:
		return

	if _3d_screen_active():
		var template := _get_template()
		if not template or template is not Node3D:
			_destroy_ghost()
			return

		var vp3d := _get_active_3d_viewport()
		if vp3d == null:
			_destroy_ghost()
			return

		var camera := vp3d.get_camera_3d()
		if camera == null:
			_destroy_ghost()
			return

		var result := _raycast_3d(vp3d.get_mouse_position(), camera, vp3d)
		if result.is_empty():
			_destroy_ghost()
			return

		if not _ghost:
			_make_ghost(template)

		if _ghost is Node3D:
			var normal: Vector3 = (result["normal"]).normalized()
			var basis: Basis = _make_placement_basis(normal, template.scale, template.global_basis)
			_ghost.global_transform = Transform3D(basis, _surface_aligned(_ghost, basis, result["position"], normal))

	elif _2d_screen_active():
		var template := _get_template()
		if not template or not (template is Node2D or template is Control):
			_destroy_ghost()
			return

		var vp2d := _get_2d_viewport()
		if vp2d == null:
			_destroy_ghost()
			return

		var world_pos: Vector2 = vp2d.get_canvas_transform().affine_inverse() * vp2d.get_mouse_position()

		if not _ghost:
			_make_ghost(template)

		if _ghost is Node2D or _ghost is Control:
			_ghost.global_position = world_pos
	else:
		_destroy_ghost()

func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		deactivate()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _3d_screen_active():
			var vp3d := _get_active_3d_viewport()
			if not vp3d:
				return

			var mouse_pos := vp3d.get_mouse_position()
			var camera := vp3d.get_camera_3d()
			if not camera:
				return

			get_viewport().set_input_as_handled()
			var template: Node = _get_template()
			if template == null:
				push_warning("MultiMesh Baker Draw: Select a node to use as a template.")
				return

			var result := _raycast_3d(mouse_pos, camera, vp3d)
			if result.is_empty():
				return

			var scene_root: Node = EditorInterface.get_edited_scene_root()
			if scene_root == null:
				return

			var layer := _get_draw_layer(template)
			var layer_is_new := layer == null
			if layer_is_new:
				layer = _create_draw_layer(template, true)

			var copy: Node = template.duplicate()

			if copy is Node3D:
				if _ghost and _ghost is Node3D:
					copy.global_transform = _ghost.global_transform
				else:
					var normal: Vector3 = result["normal"].normalized()
					var basis: Basis = _make_placement_basis(normal, template.scale, template.global_basis)
					copy.global_transform = Transform3D(basis, _surface_aligned(copy, basis, result["position"], normal))

			var parent: Node
			var move_after_add := false
			var insert_index := -1
			if template == scene_root:
				parent = template
			else:
				parent = template.get_parent() if template.get_parent() else scene_root
				move_after_add = true
				insert_index = template.get_index() + 1

			var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
			undo.create_action("Draw Place Node3D")
			if layer_is_new:
				undo.add_do_method(parent, "add_child", layer, true)
				undo.add_do_method(layer, "set_owner", scene_root)
				if move_after_add and insert_index >= 0:
					undo.add_do_method(parent, "move_child", layer, insert_index)
				undo.add_undo_method(parent, "remove_child", layer)
			undo.add_do_method(layer, "add_child", copy, true)
			undo.add_do_reference(copy)
			undo.add_do_method(copy, "set_owner", scene_root)
			undo.add_undo_method(layer, "remove_child", copy)
			undo.commit_action()

			print("MultiMesh Baker Draw: Placed '%s' at %s" % [copy.name, copy.global_position if copy is Node3D else result["position"]])

		elif _2d_screen_active():
			var vp2d := _get_2d_viewport()
			if not vp2d:
				return

			var mouse_pos := vp2d.get_mouse_position()
			get_viewport().set_input_as_handled()
			var template: Node = _get_template()
			if not template:
				push_warning("MultiMesh Baker Draw: Select a node to use as a template.")
				return

			var scene_root: Node = EditorInterface.get_edited_scene_root()
			if not scene_root:
				return

			var world_pos: Vector2 = vp2d.get_canvas_transform().affine_inverse() * mouse_pos

			var layer := _get_draw_layer(template)
			var layer_is_new := layer == null
			if layer_is_new:
				layer = _create_draw_layer(template, false)

			var copy: Node = template.duplicate()

			if copy is Node2D or copy is Control:
				copy.global_position = world_pos

			var parent: Node
			var move_after_add := false
			var insert_index := -1
			if template == scene_root:
				parent = template
			else:
				parent = template.get_parent() if template.get_parent() else scene_root
				move_after_add = true
				insert_index = template.get_index() + 1

			var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
			undo.create_action("Draw Place Node2D")
			if layer_is_new:
				undo.add_do_method(parent, "add_child", layer, true)
				undo.add_do_method(layer, "set_owner", scene_root)
				if move_after_add and insert_index >= 0:
					undo.add_do_method(parent, "move_child", layer, insert_index)
				undo.add_undo_method(parent, "remove_child", layer)
			undo.add_do_method(layer, "add_child", copy, true)
			undo.add_do_reference(copy)
			undo.add_do_method(copy, "set_owner", scene_root)
			undo.add_undo_method(layer, "remove_child", copy)
			undo.commit_action()

			print("MultiMesh Baker Draw: Placed '%s' at %s" % [copy.name, world_pos])

func _3d_screen_active() -> bool:
	for i in range(4):
		var vp: SubViewport = EditorInterface.get_editor_viewport_3d(i)
		if vp == null:
			continue
		var container := vp.get_parent()
		if container != null and container.is_visible_in_tree():
			return true
	return false

func _2d_screen_active() -> bool:
	var vp := EditorInterface.get_editor_viewport_2d()
	if vp == null:
		return false
	var container := vp.get_parent()
	return container != null and container.is_visible_in_tree()

func _get_active_3d_viewport() -> SubViewport:
	for i in range(4):
		var vp: SubViewport = EditorInterface.get_editor_viewport_3d(i)
		if vp == null:
			continue
		var container := vp.get_parent()
		if container == null:
			continue
		if _container_has_mouse(container):
			return vp
	return null

func _get_2d_viewport() -> SubViewport:
	var vp := EditorInterface.get_editor_viewport_2d()
	if vp == null:
		return null
	var container := vp.get_parent()
	if container == null:
		return null
	if _container_has_mouse(container):
		return vp
	return null

func _container_has_mouse(container: SubViewportContainer) -> bool:
	var vp := container.get_viewport()
	if vp == null:
		return false
	var mouse: Vector2 = vp.get_mouse_position()
	return container.get_global_rect().has_point(mouse)

func _destroy_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null

func _make_ghost(template: Node) -> Node:
	_destroy_ghost()
	var copy: Node = template.duplicate()
	_disable_ghost_collision(copy)
	_set_ghost_transparency(copy)
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root != null:
		scene_root.add_child(copy)
	_ghost = copy
	return copy

func _disable_ghost_collision(node: Node) -> void:
	if "collision_layer" in node:
		node.collision_layer = 0
	if "collision_mask" in node:
		node.collision_mask = 0
	for child in node.get_children():
		_disable_ghost_collision(child)

func _set_ghost_transparency(node: Node) -> void:
	if node is CanvasItem:
		node.modulate = Color(1, 1, 1, 0.4)
	if node is GeometryInstance3D:
		var gi := node
		gi.transparency = 0.6
	for child in node.get_children():
		_set_ghost_transparency(child)

func _get_draw_layer(template: Node) -> Node:
	if _draw_layer and _draw_layer.is_inside_tree() and _draw_layer_template == template:
		return _draw_layer
	_draw_layer = null
	_draw_layer_template = null
	return null

func _create_draw_layer(template: Node, is_3d: bool) -> Node:
	var layer: Node
	if is_3d:
		layer = Node3D.new()
	else:
		layer = Node2D.new()
	layer.name = template.name + "_DrawLayer"
	layer.tree_exited.connect(_on_draw_layer_exited)
	_draw_layer = layer
	_draw_layer_template = template
	return layer

func _on_draw_layer_exited() -> void:
	_draw_layer = null
	_draw_layer_template = null

func _make_placement_basis(normal: Vector3, scale: Vector3, template_basis: Basis) -> Basis:
	if not allow_rotation:
		return template_basis.orthonormalized() * Basis().scaled(scale)
	if allow_vertical_rotation:
		var right: Vector3 = normal.cross(Vector3.FORWARD if abs(normal.dot(Vector3.UP)) > 0.99 else Vector3.UP).normalized()
		return Basis(right, normal, -right.cross(normal).normalized()) * Basis().scaled(scale)
	else:
		var fwd: Vector3 = Vector3(normal.x, 0.0, normal.z).normalized()
		if fwd.length_squared() < 0.001:
			fwd = Vector3.BACK
		return Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, -fwd) * Basis().scaled(scale)

func _raycast_3d(viewport_pos: Vector2, camera: Camera3D, vp: SubViewport) -> Dictionary:
	var world3d: World3D = vp.find_world_3d()
	if not world3d:
		return {}
	var space_state: PhysicsDirectSpaceState3D = world3d.direct_space_state
	if not space_state:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(viewport_pos),
		camera.project_ray_origin(viewport_pos) + camera.project_ray_normal(viewport_pos) * camera.far
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)

func _get_template() -> Node:
	var selection := EditorInterface.get_selection().get_selected_nodes()
	if selection.is_empty():
		return null
	return selection.front()

func _surface_aligned(node: Node3D, basis: Basis, hit_pos: Vector3, hit_normal: Vector3) -> Vector3:
	var n := hit_normal.normalized()
	var min_proj := _projection_along_normal(node, basis, n)
	return hit_pos + n * (-min_proj)

func _projection_along_normal(node: Node3D, basis: Basis, normal: Vector3) -> float:
	var found := false
	var min_proj := INF

	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur := stack.pop_back()

		if cur is VisualInstance3D:
			var vi := cur
			var local_aabb: AABB = vi.get_aabb()

			var to_root_linear: Basis = basis * node.global_basis.inverse() * vi.global_basis

			var p := local_aabb.position
			var s := local_aabb.size
			var corners := [
				p,
				p + Vector3(s.x, 0.0, 0.0),
				p + Vector3(0.0, s.y, 0.0),
				p + Vector3(0.0, 0.0, s.z),
				p + Vector3(s.x, s.y, 0.0),
				p + Vector3(s.x, 0.0, s.z),
				p + Vector3(0.0, s.y, s.z),
				p + s
			]

			var vi_origin_root_local: Vector3 = basis * (node.global_basis.inverse() * (vi.global_position - node.global_position))

			for c in corners:
				var v_root: Vector3 = vi_origin_root_local + (to_root_linear * c)
				var proj := normal.dot(v_root)
				if proj < min_proj:
					min_proj = proj
				found = true

		for child in cur.get_children():
			stack.push_back(child)

	if not found:
		return 0.0

	return min_proj
