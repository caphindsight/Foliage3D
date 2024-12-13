class_name FoliageMesh
extends Resource

## The mesh that's used as (part of a) foliage LOD.
@export var mesh: Mesh

## If specified, override the mesh materials.
## One for each surface of the mesh.
@export var material_overrides: Array[Material]


# Implementation.

var initialized := false

func init() -> void:
	if initialized: return
	initialized = true
	mesh = mesh.duplicate(true)  # In case it is reused in different FoliageMesh objects.
	for i in len(material_overrides):
		if not material_overrides[i]: continue
		mesh.surface_set_material(i, material_overrides[i])
