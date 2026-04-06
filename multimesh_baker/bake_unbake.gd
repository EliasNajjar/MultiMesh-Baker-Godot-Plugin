@tool
extends Node

func _on_bake_to_multimesh_pressed() -> void:
	var selected = EditorInterface.get_selection().get_selected_nodes()
	if selected.size() != 1:
		push_warning("MultiMesh Baker: Select 1 node.")
		return

	var node: Node = selected.front()
	var scene_root: Node = node.get_tree().edited_scene_root
	var is_scene_root := node == node.get_tree().edited_scene_root
	var parent: Node = node if is_scene_root else node.get_parent()
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var insert_index := -1
	if not is_scene_root:
		insert_index = node.get_index() + 1

	if node.get_child_count() == 0:
		push_warning("MultiMesh Baker: Selected node has no children.")
		return

	var children := node.get_children()
	var first_child: Node = children.front()

	var is_2d: bool
	if first_child is MeshInstance2D:
		is_2d = true
	elif first_child is MeshInstance3D:
		is_2d = false
	else:
		push_warning("MultiMesh Baker: Children must be a MeshInstance2D or MeshInstance3D. Found: %s" % first_child.get_class())
		return

	var shared_mesh: Mesh = first_child.mesh
	if shared_mesh == null:
		push_warning("MultiMesh Baker: First child has no mesh assigned.")
		return

	if is_2d:
		var multimesh := MultiMesh.new()
		multimesh.mesh = shared_mesh
		multimesh.instance_count = children.size()

		for i in children.size():
			var child: Node = children[i]
			if child.get_class() != "MeshInstance2D":
				push_warning("MultiMesh Baker: All children must be MeshInstance2D. Found: %s" % child.get_class())
				return
			elif child.mesh != shared_mesh:
				push_warning("MultiMesh Baker: All children must have same mesh. Found: %s" % child.mesh)
				return
			multimesh.set_instance_transform_2d(i, child.get_global_transform())

		var mmi := MultiMeshInstance2D.new()
		mmi.name = node.name + "_MultiMesh2D"
		mmi.multimesh = multimesh

		undo.create_action("Bake to MultiMesh2D")
		undo.add_do_method(parent, "add_child", mmi, true)
		undo.add_do_method(mmi, "set_owner", scene_root)

		if insert_index >= 0:
			undo.add_do_method(parent, "move_child", mmi, insert_index)
		undo.add_undo_method(parent, "remove_child", mmi)
		undo.commit_action()

		print("MultiMesh Baker: Created MultiMeshInstance2D '%s' with %d instances." % [mmi.name, children.size()])
	else:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = shared_mesh
		multimesh.instance_count = children.size()

		for i in children.size():
			var child: Node = children[i]
			if child.get_class() != "MeshInstance3D":
				push_warning("MultiMesh Baker: All children must be MeshInstance3D. Found: %s" % child.get_class())
				return
			elif child.mesh != shared_mesh:
				push_warning("MultiMesh Baker: All children must have same mesh. Found: %s and %s" % [shared_mesh, child.mesh])
				return
			multimesh.set_instance_transform(i, child.global_transform)

		var mmi := MultiMeshInstance3D.new()
		mmi.name = node.name + "_MultiMesh"
		mmi.multimesh = multimesh

		undo.create_action("Bake to MultiMesh3D")
		undo.add_do_method(parent, "add_child", mmi, true)
		undo.add_do_method(mmi, "set_owner", scene_root)

		if insert_index >= 0:
			undo.add_do_method(parent, "move_child", mmi, insert_index)
		undo.add_undo_method(parent, "remove_child", mmi)
		undo.commit_action()

		print("MultiMesh Baker: Created MultiMeshInstance3D '%s' with %d instances." % [mmi.name, children.size()])


func _on_unbake_to_meshes_pressed() -> void:
	var selected = EditorInterface.get_selection().get_selected_nodes()
	if selected.size() != 1:
		push_warning("MultiMesh Baker: Select 1 node.")
		return

	var node: Node = selected.front()
	var scene_root: Node = node.get_tree().edited_scene_root
	var is_scene_root := node == scene_root
	var parent: Node = node if is_scene_root else node.get_parent()
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var insert_index := -1
	if not is_scene_root:
		insert_index = node.get_index() + 1

	if node is MultiMeshInstance2D:
		if node.multimesh == null or node.multimesh.mesh == null:
			push_warning("MultiMesh Baker: Selected MultiMeshInstance2D has no Mesh.")
			return

		if parent == null:
			push_warning("MultiMesh Baker: MultiMeshInstance2D has no parent.")
			return

		var group := Node2D.new()
		group.name = node.name + "_Meshes"

		var mm: MultiMesh = node.multimesh
		var shared_mesh: Mesh = mm.mesh

		undo.create_action("Unbake MultiMesh2D to Meshes")

		undo.add_do_method(parent, "add_child", group, true)
		undo.add_do_method(group, "set_owner", scene_root)
		if insert_index >= 0:
			undo.add_do_method(parent, "move_child", group, insert_index)

		for i in mm.instance_count:
			var child := MeshInstance2D.new()
			child.name = "MeshInstance2D%d" % (i + 1) if i > 0 else "MeshInstance2D"
			child.mesh = shared_mesh
			child.global_transform = node.global_transform * mm.get_instance_transform_2d(i)

			undo.add_do_method(group, "add_child", child, true)
			undo.add_do_method(child, "set_owner", scene_root)
			undo.add_undo_method(group, "remove_child", child)

		undo.add_undo_method(parent, "remove_child", group)

		undo.commit_action()

		print("MultiMesh Baker: Created Node2D '%s' with %d MeshInstance2D children." % [group.name, mm.instance_count])
		return

	if node is MultiMeshInstance3D:
		if node.multimesh == null or node.multimesh.mesh == null:
			push_warning("MultiMesh Baker: Selected MultiMeshInstance3D has no Mesh.")
			return

		if parent == null:
			push_warning("MultiMesh Baker: MultiMeshInstance3D has no parent.")
			return

		var group := Node3D.new()
		group.name = node.name + "_Meshes"

		var mm: MultiMesh = node.multimesh
		var shared_mesh: Mesh = mm.mesh

		undo.create_action("Unbake MultiMesh3D to Meshes")

		undo.add_do_method(parent, "add_child", group, true)
		undo.add_do_method(group, "set_owner", scene_root)
		if insert_index >= 0:
			undo.add_do_method(parent, "move_child", group, insert_index)

		for i in mm.instance_count:
			var child := MeshInstance3D.new()
			child.name = "MeshInstance3D%d" % (i + 1) if i > 0 else "MeshInstance3D"
			child.mesh = shared_mesh
			child.global_transform = node.global_transform * mm.get_instance_transform(i)

			undo.add_do_method(group, "add_child", child, true)
			undo.add_do_method(child, "set_owner", scene_root)
			undo.add_undo_method(group, "remove_child", child)

		undo.add_undo_method(parent, "remove_child", group)

		undo.commit_action()

		print("MultiMesh Baker: Created Node3D '%s' with %d MeshInstance3D children." % [group.name, mm.instance_count])
		return

	push_warning("MultiMesh Baker: Select a MultiMeshInstance2D or MultiMeshInstance3D to unbake.")
