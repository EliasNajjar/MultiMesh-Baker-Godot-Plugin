@tool
extends Node

# ──────────────────────────────────────────────────────────────────
#  Drawing helper – parented to EditorInterface.get_base_control()
#  so _input() and _process() fire for all editor events.
# ──────────────────────────────────────────────────────────────────

var _active: bool = false
var _plugin: EditorPlugin = null

# Ghost preview node shown while hovering (lives in the edited scene).
var _ghost: Node = null

# The container node (Node2D or Node3D) that drawn copies go into.
# Created once per draw session and reused until a new template is selected.
var _draw_layer: Node = null
var _draw_layer_template: Node = null  # template that _draw_layer was made for

# Callback so multimesh_baker.gd can sync button visuals.
var on_deactivated: Callable = Callable()

# Rotation options (3D only).
# allow_rotation: if false, placed nodes keep the template's original rotation.
# allow_vertical_rotation: if true, +Y aligns with the surface normal;
#   if false, only the XZ heading is adjusted and +Y stays world-up.
var allow_rotation: bool          = true
var allow_vertical_rotation: bool = true


# ──────────────────────────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────────────────────────

func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func is_active() -> bool:
	return _active


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


# ──────────────────────────────────────────────────────────────────
#  Per-frame: move the ghost to match the cursor
# ──────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _active:
		return

	if _is_3d_screen_active():
		_update_ghost_3d()
	elif _is_2d_screen_active():
		_update_ghost_2d()
	else:
		_destroy_ghost()


# ──────────────────────────────────────────────────────────────────
#  Input
# ──────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		deactivate()
		return

	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and (event as InputEventMouseButton).pressed:

		if _is_3d_screen_active():
			var vp3d := _get_active_3d_viewport()
			if vp3d != null:
				var mouse_pos := vp3d.get_mouse_position()
				var camera := vp3d.get_camera_3d()
				if camera != null:
					get_viewport().set_input_as_handled()
					_place_3d(mouse_pos, camera, vp3d)
		elif _is_2d_screen_active():
			var vp2d := _get_2d_viewport()
			if vp2d != null:
				var mouse_pos := vp2d.get_mouse_position()
				get_viewport().set_input_as_handled()
				_place_2d(mouse_pos, vp2d)


# ──────────────────────────────────────────────────────────────────
#  Viewport helpers
# ──────────────────────────────────────────────────────────────────

# Returns true when at least one 3D SubViewportContainer is visible,
# which is the case only when the "3D" editor tab is active.
func _is_3d_screen_active() -> bool:
	for i in range(4):
		var vp: SubViewport = EditorInterface.get_editor_viewport_3d(i)
		if vp == null:
			continue
		var container := vp.get_parent() as SubViewportContainer
		if container != null and container.is_visible_in_tree():
			return true
	return false


# Returns true when the 2D SubViewportContainer is visible,
# which is the case only when the "2D" editor tab is active.
func _is_2d_screen_active() -> bool:
	var vp := EditorInterface.get_editor_viewport_2d() as SubViewport
	if vp == null:
		return false
	var container := vp.get_parent() as SubViewportContainer
	return container != null and container.is_visible_in_tree()


# Returns the 3D SubViewport whose container rect contains the mouse,
# using canvas-space coordinates so toolbar buttons are excluded correctly.
func _get_active_3d_viewport() -> SubViewport:
	for i in range(4):
		var vp: SubViewport = EditorInterface.get_editor_viewport_3d(i)
		if vp == null:
			continue
		var container := vp.get_parent() as SubViewportContainer
		if container == null:
			continue
		if _container_has_mouse(container):
			return vp
	return null


# Returns the 2D SubViewport only when the mouse is inside its container rect.
func _get_2d_viewport() -> SubViewport:
	var vp := EditorInterface.get_editor_viewport_2d() as SubViewport
	if vp == null:
		return null
	var container := vp.get_parent() as SubViewportContainer
	if container == null:
		return null
	if _container_has_mouse(container):
		return vp
	return null


# Check mouse against container using get_global_rect() and the window-space
# mouse position from the container's own viewport, so both are in the same
# coordinate space and toolbar buttons are not mistakenly included.
func _container_has_mouse(container: SubViewportContainer) -> bool:
	var vp := container.get_viewport()
	if vp == null:
		return false
	var mouse: Vector2 = vp.get_mouse_position()
	return container.get_global_rect().has_point(mouse)


# ──────────────────────────────────────────────────────────────────
#  Ghost helpers
# ──────────────────────────────────────────────────────────────────

func _destroy_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _make_ghost(template: Node) -> Node:
	_destroy_ghost()
	var copy: Node = template.duplicate()
	# Disable all collision so the ghost is purely visual.
	_disable_ghost_collision(copy)
	# Make every VisualInstance transparent via modulate / transparency property.
	_set_ghost_transparency(copy)
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root != null:
		scene_root.add_child(copy)
		# Do NOT set owner – ghost is temporary and must not be saved.
	_ghost = copy
	return copy


# Recursively disable all collision on the ghost by zeroing collision layers
# and masks on every node that exposes them. This is fully general: it covers
# physics bodies, CSG shapes, and any future Godot node types, without
# freeing anything so child nodes are preserved.
func _disable_ghost_collision(node: Node) -> void:
	if "collision_layer" in node:
		node.collision_layer = 0
	if "collision_mask" in node:
		node.collision_mask = 0
	for child in node.get_children():
		_disable_ghost_collision(child)


func _set_ghost_transparency(node: Node) -> void:
	# 2D: modulate alpha.
	if node is CanvasItem:
		(node as CanvasItem).modulate = Color(1, 1, 1, 0.4)
	# 3D: set transparency on every GeometryInstance3D in the subtree.
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.transparency = 0.6
	for child in node.get_children():
		_set_ghost_transparency(child)


func _update_ghost_3d() -> void:
	var template := _get_template()
	if template == null or not (template is Node3D):
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

	# Recreate ghost if the template changed.
	if _ghost == null or not is_instance_valid(_ghost):
		_make_ghost(template)

	if _ghost is Node3D:
		var normal: Vector3 = (result["normal"] as Vector3).normalized()
		var ts: Vector3     = (template as Node3D).scale
		var up: Vector3      = normal
		var ref: Vector3     = Vector3.FORWARD if abs(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var right: Vector3   = up.cross(ref).normalized()
		var fwd: Vector3     = right.cross(up).normalized()
		var aligned: Basis   = Basis(right, up, -fwd) * Basis().scaled(ts)
		var basis: Basis    = _make_placement_basis(normal, ts, (template as Node3D).global_basis)
		var pos: Vector3    = (result["position"] as Vector3) + _surface_offset(template as Node3D, normal, aligned)
		(_ghost as Node3D).global_transform = Transform3D(basis, pos)


func _update_ghost_2d() -> void:
	var template := _get_template()
	if template == null or not (template is Node2D or template is Control):
		_destroy_ghost()
		return

	var vp2d := _get_2d_viewport()
	if vp2d == null:
		_destroy_ghost()
		return

	var world_pos: Vector2 = vp2d.get_canvas_transform().affine_inverse() \
		* vp2d.get_mouse_position()

	if _ghost == null or not is_instance_valid(_ghost):
		_make_ghost(template)

	if _ghost is Node2D:
		(_ghost as Node2D).global_position = world_pos
	elif _ghost is Control:
		(_ghost as Control).global_position = world_pos


# ──────────────────────────────────────────────────────────────────
#  Draw layer – shared container for all placed copies
# ──────────────────────────────────────────────────────────────────

# Returns the existing draw layer for this template, or null if a new one
# needs to be created. The caller is responsible for creating the layer and
# including it in the same undo action as the placed node.
func _get_draw_layer(template: Node) -> Node:
	if _draw_layer != null and is_instance_valid(_draw_layer) \
			and _draw_layer.is_inside_tree() \
			and _draw_layer_template == template:
		return _draw_layer
	# Cache is stale (e.g. after undo removed the layer) – clear it.
	_draw_layer = null
	_draw_layer_template = null
	return null


# Creates a new draw layer and caches it. Called by the place functions
# before committing the undo action so both steps share one action.
func _create_draw_layer(template: Node, is_3d: bool) -> Node:
	var layer: Node
	if is_3d:
		layer = Node3D.new()
	else:
		layer = Node2D.new()
	layer.name = template.name + "_DrawLayer"
	# Clear the cache automatically if undo removes the layer from the tree.
	layer.tree_exited.connect(_on_draw_layer_exited)
	_draw_layer = layer
	_draw_layer_template = template
	return layer


func _on_draw_layer_exited() -> void:
	_draw_layer = null
	_draw_layer_template = null


# ──────────────────────────────────────────────────────────────────
#  2-D placement
# ──────────────────────────────────────────────────────────────────

func _place_2d(viewport_pos: Vector2, vp: SubViewport) -> void:
	var template: Node = _get_template()
	if template == null:
		push_warning("MultiMesh Baker Draw: Select a node to use as a template.")
		return

	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return

	var world_pos: Vector2 = vp.get_canvas_transform().affine_inverse() * viewport_pos

	var layer := _get_draw_layer(template)
	var layer_is_new := layer == null
	if layer_is_new:
		layer = _create_draw_layer(template, false)

	var copy: Node = template.duplicate()

	if copy is Node2D:
		(copy as Node2D).global_position = world_pos
	elif copy is Control:
		(copy as Control).global_position = world_pos

	var parent: Node = template.get_parent() if template.get_parent() != null else scene_root
	var insert_index: int = template.get_index() + 1

	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo.create_action("Draw Place Node2D")
	if layer_is_new:
		undo.add_do_method(parent, "add_child", layer)
		undo.add_do_method(layer,  "set_owner", scene_root)
		undo.add_do_method(parent, "move_child", layer, insert_index)
		undo.add_undo_method(parent, "remove_child", layer)
	undo.add_do_method(layer, "add_child", copy)
	undo.add_do_reference(copy)
	_add_set_owner_actions(undo, copy, scene_root)
	undo.add_undo_method(layer, "remove_child", copy)
	undo.commit_action()

	print("MultiMesh Baker Draw: Placed '%s' at %s" % [copy.name, world_pos])


# ──────────────────────────────────────────────────────────────────
#  3-D placement
# ──────────────────────────────────────────────────────────────────

func _place_3d(viewport_pos: Vector2, camera: Camera3D, vp: SubViewport) -> void:
	var template: Node = _get_template()
	if template == null:
		push_warning("MultiMesh Baker Draw: Select a node to use as a template.")
		return

	var result := _raycast_3d(viewport_pos, camera, vp)
	if result.is_empty():
		return  # Void – do nothing.

	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return

	var layer := _get_draw_layer(template)
	var layer_is_new := layer == null
	if layer_is_new:
		layer = _create_draw_layer(template, true)

	var copy: Node = template.duplicate()

	if copy is Node3D:
		var normal: Vector3 = (result["normal"] as Vector3).normalized()
		var ts: Vector3     = (template as Node3D).scale
		var up: Vector3      = normal
		var ref: Vector3     = Vector3.FORWARD if abs(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var right: Vector3   = up.cross(ref).normalized()
		var fwd: Vector3     = right.cross(up).normalized()
		var aligned: Basis   = Basis(right, up, -fwd) * Basis().scaled(ts)
		var basis: Basis    = _make_placement_basis(normal, ts, (template as Node3D).global_basis)
		var pos: Vector3    = (result["position"] as Vector3) + _surface_offset(template as Node3D, normal, aligned)
		(copy as Node3D).global_transform = Transform3D(basis, pos)

	var parent: Node = template.get_parent() if template.get_parent() != null else scene_root
	var insert_index: int = template.get_index() + 1

	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo.create_action("Draw Place Node3D")
	if layer_is_new:
		undo.add_do_method(parent, "add_child", layer)
		undo.add_do_method(layer,  "set_owner", scene_root)
		undo.add_do_method(parent, "move_child", layer, insert_index)
		undo.add_undo_method(parent, "remove_child", layer)
	undo.add_do_method(layer, "add_child", copy)
	undo.add_do_reference(copy)
	_add_set_owner_actions(undo, copy, scene_root)
	undo.add_undo_method(layer, "remove_child", copy)
	undo.commit_action()

	print("MultiMesh Baker Draw: Placed '%s' at %s" % [copy.name, result["position"]])


# ──────────────────────────────────────────────────────────────────
#  Placement basis
# ──────────────────────────────────────────────────────────────────

# Builds the Basis for a placed node.
# - allow_rotation = false  → keep the template's exact rotation unchanged.
# - allow_vertical_rotation = true  → full alignment: +Y tracks the normal.
# - allow_vertical_rotation = false → heading only: +Y stays world-up,
#     XZ axes face away from the surface.
func _make_placement_basis(normal: Vector3, scale: Vector3, template_basis: Basis) -> Basis:
	if not allow_rotation:
		# Preserve the template's rotation exactly, only apply its scale.
		return template_basis.orthonormalized() * Basis().scaled(scale)
	if allow_vertical_rotation:
		# Full alignment: +Y = surface normal.
		var up: Vector3    = normal
		var ref: Vector3   = Vector3.FORWARD if abs(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var right: Vector3 = up.cross(ref).normalized()
		var fwd: Vector3   = right.cross(up).normalized()
		return Basis(right, up, -fwd) * Basis().scaled(scale)
	else:
		# Heading only: keep +Y world-up, rotate around Y to face away from surface.
		var fwd: Vector3   = Vector3(normal.x, 0.0, normal.z).normalized()
		if fwd.length_squared() < 0.001:
			fwd = Vector3.BACK
		var right: Vector3 = Vector3.UP.cross(fwd).normalized()
		return Basis(right, Vector3.UP, -fwd) * Basis().scaled(scale)


# ──────────────────────────────────────────────────────────────────
#  Owner helpers
# ──────────────────────────────────────────────────────────────────

# Recursively register set_owner undo actions for every node in the subtree
# so the editor shows all children in the scene tree after placement.
func _add_set_owner_actions(undo: EditorUndoRedoManager, node: Node, scene_root: Node) -> void:
	undo.add_do_method(node, "set_owner", scene_root)
	for child in node.get_children():
		_add_set_owner_actions(undo, child, scene_root)


# ──────────────────────────────────────────────────────────────────
#  Surface offset – push the object away from the hit surface so it
#  sits flush against it rather than clipping through.
# ──────────────────────────────────────────────────────────────────

# Returns how far along `normal` the node's origin must be offset from the
# hit point so the object sits flush on the surface without clipping.
#
# We work entirely in the node's own local space (its current template
# rotation). The surface normal is expressed in that local frame, then we
# find the furthest point of the AABB along that direction. This is the
# same approach Godot's own editor uses when dragging scenes into the
# viewport: no basis re-orientation, just local AABB + local normal.
func _surface_offset(node: Node3D, normal: Vector3, _aligned_basis: Basis) -> Vector3:
	var aabb: AABB = _get_local_aabb(node)
	if aabb.size == Vector3.ZERO:
		return Vector3.ZERO
	# _collect_aabb uses root.global_transform.inverse() * node.global_transform,
	# which folds in rotation AND scale of all nodes in the subtree relative to
	# the root. The resulting AABB is therefore already in world-scale units,
	# expressed in the root node's local orientation (no parent transforms).
	# So: transform the world normal by just the root node's own rotation
	# (orthonormalized strips scale), no extra scaling needed.
	var local_normal: Vector3 = node.basis.orthonormalized().inverse() * normal
	var mn: Vector3 = aabb.position
	var mx: Vector3 = aabb.end
	# Support function: for each axis pick the corner that projects furthest
	# along local_normal (positive → max corner, negative → min corner).
	var extent: float = 0.0
	extent += mx.x * local_normal.x if local_normal.x >= 0.0 else mn.x * local_normal.x
	extent += mx.y * local_normal.y if local_normal.y >= 0.0 else mn.y * local_normal.y
	extent += mx.z * local_normal.z if local_normal.z >= 0.0 else mn.z * local_normal.z
	return normal * extent


# Accumulate the AABB of all geometry in the subtree in the root node's
# local space. Uses get_aabb() directly where available so it covers
# MeshInstance3D, CSGShape3D, and any other geometry node type.
func _get_local_aabb(root: Node3D) -> AABB:
	return _collect_aabb(root, root, false).aabb


func _collect_aabb(root: Node3D, node: Node3D, found: bool) -> Dictionary:
	var result: AABB = AABB()
	if node.has_method("get_aabb"):
		var local_aabb: AABB = root.global_transform.inverse() * \
				node.global_transform * node.get_aabb()
		if not found:
			result = local_aabb
			found = true
		else:
			result = result.merge(local_aabb)
	for child in node.get_children():
		if child is Node3D:
			var sub := _collect_aabb(root, child as Node3D, found)
			if sub.found:
				if not found:
					result = sub.aabb
					found = true
				else:
					result = result.merge(sub.aabb)
	return { "aabb": result, "found": found }


# ──────────────────────────────────────────────────────────────────
#  Shared raycast
# ──────────────────────────────────────────────────────────────────

func _raycast_3d(viewport_pos: Vector2, camera: Camera3D, vp: SubViewport) -> Dictionary:
	var world3d: World3D = vp.find_world_3d()
	if world3d == null:
		return {}
	var space_state: PhysicsDirectSpaceState3D = world3d.direct_space_state
	if space_state == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(viewport_pos),
		camera.project_ray_origin(viewport_pos) + camera.project_ray_normal(viewport_pos) * camera.far
	)
	query.collide_with_areas  = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)


# ──────────────────────────────────────────────────────────────────
#  Helpers
# ──────────────────────────────────────────────────────────────────

func _get_template() -> Node:
	var selection := EditorInterface.get_selection().get_selected_nodes()
	if selection.is_empty():
		return null
	return selection.front()
