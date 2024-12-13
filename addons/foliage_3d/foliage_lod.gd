class_name FoliageLOD
extends Resource

## These meshes compose this foliage LOD.
## E.g. these can be the trunk and leaves of the tree.
@export var meshes: Array[FoliageMesh]

## This extra offset will be applied to each of the meshes.
@export var offset: Vector3


# Implementation.

var initialized := false

func init() -> void:
	if initialized: return
	initialized = true
	for mesh in meshes:
		mesh.init()
