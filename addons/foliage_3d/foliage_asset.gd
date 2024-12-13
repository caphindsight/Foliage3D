class_name FoliageAsset
extends Resource

@export_group("Visuals")

@export_subgroup("Levels of Detail")

## An array of foliage LODs used in this asset.
## Usually range from the most detailed mesh (LOD-0) to a billboard impostor.
@export var flods: Array[FoliageLOD]

## This array maps quad LODs to foliage LOD indexes.
## E.g. when this is set to [0, 1, 2, 2];
## LOD-0 quads will render the flods[0] foliage LOD.
## LOD-1 quads will render the flods[1] foliage LOD.
## LOD-2 and LOD-3 quads will render the flods[2] foliage LOD.
## LOD-4 and higher quads will not render this foliage asset at all.
@export var qlod_to_flod: PackedInt32Array

@export_subgroup("Interactive Scene")

## If set, low LOD assets will be asynchronously replaced with instances of this packed scene.
## This allows for powerful interactive foliage in the area near the player.
@export var scene: PackedScene

## Maximal quad LOD (and [b]not[/b] foliage LOD!) for which this foliage asset
## will be asynchronously replaced with an instance of [member scene].
## Usually you want to keep this at default (zero).
@export var scene_qlod_threshold: int = 0

@export_group("Transform")

@export_subgroup("Position")

## This offset is applied to the asset before rotating and rescaling.
@export var offset: Vector3

## This offset is applied to the asset after rotating and rescaling.
@export var offset_final: Vector3

@export_subgroup("Rotation")

## When set to 0, the asset will be facing up before applying random pitch.
## When set to 1, the asset will be facing along the terrain normal before applying random pitch.
## Set to a value between 0 and 1 to lerp between these two rotations.
@export_range(0, 1, 0.01) var align_to_terrain_normal_lerp_alpha: float = 0

## Pitch angle will be randomly chosen between 0 and [member pitch_max].
@export_range(0, 180, 0.1, "radians_as_degrees") var pitch_max: float = 0

@export_subgroup("Scale")

## Scale will be randomly chosen in the interval between [member scale_min] and [member scale_max].
@export var scale_min: float = 1

## Scale will be randomly chosen in the interval between [member scale_min] and [member scale_max].
@export var scale_max: float = 1


# Implementation.

var initialized := false

func init() -> void:
	if initialized: return
	initialized = true
	for flod in flods:
		flod.init()
