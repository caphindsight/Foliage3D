class_name FoliageMultiMesh
extends MultiMeshInstance3D

var mesh: Mesh
var transforms: Array[Transform3D]
var scene: PackedScene

func init_mesh(p_mesh: Mesh, p_cast_shadow: GeometryInstance3D.ShadowCastingSetting) -> void:
	mesh = p_mesh
	multimesh = MultiMesh.new()
	multimesh.set_mesh(mesh)
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	cast_shadow = p_cast_shadow

## Appends to RAM, but doesn't write to VRAM yet.
func add_transform(transform: Transform3D) -> void:
	transforms.push_back(transform)

## Writes from RAM to VRAM.
func flush_transforms() -> void:
	var k = multimesh.instance_count
	var n = len(transforms)
	multimesh.instance_count = k + n
	multimesh.visible_instance_count = k + n
	for i in n:
		multimesh.set_instance_transform(k + i, transforms[i])
	transforms.clear()

func _process(_delta: float) -> void:
	if not scene: return
	if multimesh.visible_instance_count == 0: return
	multimesh.visible_instance_count -= 1
	var instance_transform = multimesh.get_instance_transform(multimesh.visible_instance_count)
	var instance = scene.instantiate()
	if instance is Node3D:
		instance.transform = instance_transform
	add_child(instance)
