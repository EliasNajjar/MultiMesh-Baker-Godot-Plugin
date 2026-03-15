# MultiMesh-Baker-Godot-Plugin

Godot 4 editor plugin to bake and unbake MultiMeshes from your scene.

## Features
- Bake 2D or 3D mesh children of selected node into a MultiMesh
- Unbake multimesh to restore editable nodes

## Installation
1. Copy the plugin folder into your project so you have:

   - `res://addons/multimesh_baker/`

2. In Godot, go to: **Project → Project Settings → Plugins**
3. Enable MultiMesh Baker

## Usage
The plugin create button in the 2D and 3D editor menus labelled Meshes <-> MultiMesh.  
When pressed, if a MultimeshInstance2D/3D node is selected, it will create a Node2D/3D with individual meshes for each instance as children.  
Otherwise, it looks at the children of the selected node, and creates a multimesh based on the meshes inside. The meshes must be the same mesh but can have different transformations.
