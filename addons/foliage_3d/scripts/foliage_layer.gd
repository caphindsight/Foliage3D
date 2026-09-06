## Represents a single layer of foliage covering the entire world.
## The layer uses a coordinate-aligned lattice with a fixed value of lattice spacing.
## The lattice nodes are randomized, and can be further adjusted by overriding the place method.
@icon("res://addons/foliage_3d/icons/foliage_layer.svg")
class_name FoliageLayer
extends Node

## Lattice spacing for this foliage layer.
## This should be picked with the size of foliage assets in mind.
## For example, for trees, a good value is around 16 (the default).
## For grass / flowers, this can be tuned down to about 2.
@export var lattice_spacing: float = 16

## Lattice node positions are randomized.
## Each node ends up within a square with linear size 2 * lattice_spacing * randomness,
## centered around its original position.
## Set this to 0 to place foliage in a rectangular lattice (useful for e.g. crops, vineyards, etc.).
@export var randomness: float = 0.8

## Each lattice node will be kept with this probability.
## Useful to make foliage placement look more natural.
@export var keep: float = 0.5

## If set to a non-negative value, quad tree LODs that are equal or greater to this value
## will not be instantiated at all. Necessary to avoid generating expensive chunks.
## For example, you will want to set this to something like 3 for grass, while keeping it
## high (around 7-8) for trees.
@export var hide_lod: int = -1

var chunks: Dictionary[Rect2, FoliageChunkFuture]
var terrain_data: Terrain3DData

## Override this function in the extending script.
## [b]Warning:[/b] it runs on the worker thread!
func place(placement: FoliagePlacement) -> void:
	return

## Creates a [FoliageChunk] node and starts building it on the worker thread.
## Returns a [FoliageChunkFuture] object that can be used to poll and manipulate the chunk.
func chunk(rect: Rect2, lod: int) -> FoliageChunkFuture:
	if hide_lod >= 0 and lod >= hide_lod:
		return null
	if chunks.has(rect):
		return chunks[rect]
	else:
		var chunk := FoliageChunkFuture.new(self, rect, lod)
		chunks[rect] = chunk
		return chunk

## Drops the chunk for a given [param rect].
func unchunk(rect: Rect2) -> void:
	if chunks.has(rect):
		chunks[rect].orphan()
		chunks.erase(rect)

# Runs on the worker thread!
func prepare_placement(rect: Rect2) -> FoliagePlacement:
	var placement := FoliagePlacement.new(terrain_data)
	var x1 := rect.position.x - lattice_spacing * 1.5
	var i1 := floori(x1 / lattice_spacing)
	var x2 := rect.end.x + lattice_spacing * 1.5
	var i2 := ceili(x2 / lattice_spacing)
	var y1 := rect.position.y - lattice_spacing * 1.5
	var j1 := floori(y1 / lattice_spacing)
	var y2 := rect.end.y + lattice_spacing * 1.5
	var j2 := ceili(y2 / lattice_spacing)
	for di in (i2 - i1):
		var i: int = i1 + di
		for dj in (j2 - j1):
			var j: int = j1 + dj
			var position := Vector2(lattice_spacing * i, lattice_spacing * j)
			var rand_jitter_x := FoliageRandom.new(571658977732)
			var rand_jitter_y := FoliageRandom.new(4319594216159)
			var rand_keep := FoliageRandom.new(2812107841962)
			var jitter := Vector2(rand_jitter_x.prng2(position), rand_jitter_y.prng2(position))
			jitter = Vector2(-1, -1) + jitter * 2
			position = position + jitter * lattice_spacing * randomness
			var keep_rnd: float = rand_keep.prng2(position)
			if keep_rnd >= keep: continue
			if not rect.has_point(position): continue
			var position3 := Vector3(position.x, 0, position.y)
			var normal := Vector3.UP
			var base_texture_id: int = 0
			var overlay_texture_id: int = -1
			var texture_blend_amount: float = 0
			if terrain_data:
				var height: float = terrain_data.get_height(position3)
				if not is_finite(height): height = 0
				normal = terrain_data.get_normal(position3)
				if not normal.is_finite() or normal.is_zero_approx(): normal = Vector3.UP
				normal = normal.normalized()
				var hole: bool = terrain_data.get_control_hole(position3)
				if hole: continue
				base_texture_id = terrain_data.get_control_base_id(position3)
				overlay_texture_id = terrain_data.get_control_overlay_id(position3)
				texture_blend_amount = terrain_data.get_control_blend(position3)
				position3.y = height
			var transform = Transform3D(Basis.IDENTITY, position3)
			placement.add_point(transform, normal, base_texture_id, overlay_texture_id, texture_blend_amount)
	return placement
