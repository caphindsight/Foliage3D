class_name FoliageChunk
extends Node3D

var layer: FoliageLayer
var rect: Rect2
var lod: int
var future: FoliageChunkFuture
var mesh_dict: Dictionary[Mesh, FoliageMultiMesh]

## Builds the chunk.
## [b]Runs on the worker thread![/b]
func build() -> void:
	# Prepare the node.
	hide()
	var rect_center := rect.get_center()
	var origin := Vector3(rect_center.x, 0, rect_center.y)
	set_position(origin)

	# Place assets.
	var placement := layer.prepare_placement(rect)
	layer.place(placement)

	# Build meshes.
	mesh_dict.clear()
	for i in placement.size():
		var transform = placement.get_transform(i)
		var asset = placement.get_asset(i)
		if not asset: continue
		if lod >= len(asset.lod_map): continue
		var asset_lod: int = asset.lod_map[lod]
		var use_scene: bool = false
		if asset_lod < 0:
			use_scene = true
			asset_lod = 0
		if asset_lod >= len(asset.lods): continue
		var mesh: Mesh = asset.lods[asset_lod]
		var multimesh: FoliageMultiMesh
		if mesh_dict.has(mesh):
			multimesh = mesh_dict[mesh]
		else:
			multimesh = FoliageMultiMesh.new()
			multimesh.init_mesh(mesh, asset.cast_shadow)
			if use_scene:
				multimesh.scene = asset.scene
			mesh_dict[mesh] = multimesh
		multimesh.add_transform(transform.translated(-origin))
	for multimesh: FoliageMultiMesh in mesh_dict.values():
		multimesh.flush_transforms()
		add_child(multimesh)

	# Schedule the finalizer on the main thread.
	FoliageChunkFuture.finalize.call_deferred(future)
	future = null  # Break the RC loop.
