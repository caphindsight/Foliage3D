## Procedurally generates foliage in a 3D scene using a quad tree.
## The world is subdivided into square chunks organized into multiple levels of detail (LODs).
## LOD-0 represents the smallest and most detailed chunks. These are the ones closest to the camera.
## Each successive LOD increases the chunk linear size by 2x (so the covered area increases by 4x).
## By itself, [FoliagePartition] simply partitions the world into invisible chunks.
## To place foliage on chunks, add and configure a [FoliageLayer] child node.
## Multiple [FoliageLayer] nodes can be used to place different types of foliage in parallel.
@icon("res://addons/foliage_3d/icons/foliage_partition.svg")
class_name FoliagePartition
extends Node

## Reference to the [Terrain3D] node. The foliage will spawn on the terrain.
## Terrain3D is a required dependency, Foliage3D doesn't work without it.
## See [url]https://store.godotengine.org/asset/tokisangames/terrain3d[/url].
@export var terrain: Terrain3D

## The linear size of a LOD-0 chunk, measured in world units, for both horizontal directions X and Z.
## The linear size of a LOD-k chunk is lod0_size * 2^k.
@export var lod0_size: float = 32

## The libear size of the largest visible chunk in the quad tree.
## Must cover the entire world (centered at the coordinate origin).
@export var horizon_size: float = 4096

## 2D angle limit for a single chunk, when viewed from the camera position.
## When the chunk's angular resolution is higher than this value,
## the chunk is subdivided into four lower-LOD chunks.
## Controls how aggressively the quad tree culls LODs.
## Values that are too low lead to lots of highly detailed chunks and poor performance.
## Values that are too high lead to poor visual quality.
## We have two threshold: [b]lo[/b] for merging chunks and [b]hi[/b] for splitting chunks.
## The [b]lo[/b] threshold should be below the [b]hi[/b] threshold.
@export_range(0, 180, 0.1, "radians_as_degrees") var chunk_angular_threshold_lo: float = deg_to_rad(60)

## 2D angle limit for a single chunk, when viewed from the camera position.
## When the chunk's angular resolution is higher than this value,
## the chunk is subdivided into four lower-LOD chunks.
## Controls how aggressively the quad tree culls LODs.
## Values that are too low lead to lots of highly detailed chunks and poor performance.
## Values that are too high lead to poor visual quality.
## We have two threshold: [b]lo[/b] for merging chunks and [b]hi[/b] for splitting chunks.
## The [b]lo[/b] threshold should be below the [b]hi[/b] threshold.
@export_range(0, 180, 0.1, "radians_as_degrees") var chunk_angular_threshold_hi: float = deg_to_rad(70)

func _ready() -> void:
	layers.clear()
	for child in get_children():
		if child is FoliageLayer:
			layers.append(child)
	assert(len(layers) < 32, "Max allowed number of layers is 31.")

	if terrain:
		for layer in layers:
			layer.terrain_data = terrain.data
	
	quad_tree.clear()
	quad_tree_vacant_indexes.clear()
	var root_lod: int = roundi(log(horizon_size / lod0_size) / log(2))
	var root_size: float = lod0_size * (1 << root_lod)
	var root_rect := Rect2(-root_size / 2, -root_size / 2, root_size, root_size)
	push_quad(root_rect, root_lod)

func _process(_delta: float) -> void:
	observer_position = find_observer_position()
	restructure_quad_tree(0)
	update_visibility(0)

var layers: Array[FoliageLayer]
var quad_tree: Array[Quad]
var quad_tree_vacant_indexes: Array[int]
var observer_position: Vector3

# Returns the index of the newly created quad.
# Chunks the quad on all layers.
func push_quad(rect: Rect2, lod: int) -> int:
	var quad := Quad.new()
	quad.rect = rect
	quad.lod = lod
	for layer in layers:
		layer.chunk(rect, lod)
	if quad_tree_vacant_indexes.is_empty():
		quad_tree.push_back(quad)
		return len(quad_tree) - 1
	else:
		var index = quad_tree_vacant_indexes.pop_back()
		quad_tree[index] = quad
		return index

func pop_quad(quad: int) -> void:
	var rect: Rect2 = quad_tree[quad].rect
	for layer in layers:
		layer.unchunk(rect)
	quad_tree[quad] = null
	quad_tree_vacant_indexes.append(quad)

func pop_subtree(quad: int) -> void:
	var q: Quad = quad_tree[quad]
	if q.has_children:
		for i in 4:
			pop_subtree(q.children[i])
	pop_quad(quad)

func angular_size(quad: int) -> float:
	var rect: Rect2 = quad_tree[quad].rect
	var o3: Vector3 = observer_position
	var o := Vector2(o3.x, o3.z)
	if rect.has_point(o): return PI
	var p := rect.position
	var q := rect.end
	var points: PackedVector2Array = [p, q, Vector2(p.x, q.y), Vector2(q.x, p.y)]
	var res: float = 0
	for i in 4:
		for j in i:
			var subres: float = absf((points[i] - o).angle_to(points[j] - o))
			if subres > res:
				res = subres
	return res

func find_observer_position() -> Vector3:
	var viewport := get_viewport()
	if not viewport: return Vector3.ZERO
	var camera := viewport.get_camera_3d()
	if not camera: return Vector3.ZERO
	return camera.global_position

func restructure_quad_tree(quad: int) -> void:
	var q: Quad = quad_tree[quad]
	var ang: float = angular_size(quad)
	var should_subdivide: bool = q.lod > 0 and ang > chunk_angular_threshold_hi
	var should_unsubdivide: bool = q.lod > 0 and ang < chunk_angular_threshold_lo
	if should_subdivide and not q.has_children:
		subdivide_quad(quad)
	if should_unsubdivide and q.has_children:
		unsubdivide_quad(quad)
	if q.has_children:
		for i in 4:
			restructure_quad_tree(q.children[i])

const TL: int = 0
const TR: int = 1
const BR: int = 2
const BL: int = 3

func subdivide_quad(quad: int) -> void:
	var q: Quad = quad_tree[quad]
	if q.has_children: return
	q.has_children = true
	var pos: Vector2 = q.rect.position
	var sz: Vector2 = q.rect.size / 2
	var dx := Vector2(sz.x, 0)
	var dy := Vector2(0, sz.y)
	q.children.resize(4)
	q.children[TL] = push_quad(Rect2(pos, sz), q.lod - 1)
	q.children[TR] = push_quad(Rect2(pos + dx, sz), q.lod - 1)
	q.children[BR] = push_quad(Rect2(pos + dx + dy, sz), q.lod - 1)
	q.children[BL] = push_quad(Rect2(pos + dy, sz), q.lod - 1)

func unsubdivide_quad(quad: int) -> void:
	var q: Quad = quad_tree[quad]
	if not q.has_children: return
	q.has_children = false
	for i in 4:
		pop_subtree(q.children[i])
	q.children = []

func update_visibility(quad: int) -> void:
	var q: Quad = quad_tree[quad]
	if q.has_children:
		for i in 4:
			update_visibility(q.children[i])
	for i in len(layers):
		var chunk := layers[i].chunk(q.rect, q.lod)
		if not chunk:
			q.chunks_ready |= 1 << i
			continue
		if chunk.is_chunk_ready:
			q.chunks_ready |= 1 << i
			if q.has_children:
				var all_children_are_ready: bool = true
				for j in 4:
					if quad_tree[q.children[j]].chunks_ready & (1 << i) == 0:
						all_children_are_ready = false
						break
				if all_children_are_ready:
					chunk.hide_chunk()
				else:
					chunk.show_chunk()
					for j in 4:
						var child_chunk := layers[i].chunk(quad_tree[q.children[j]].rect, q.lod - 1)
						if child_chunk and child_chunk.is_chunk_ready:
							child_chunk.hide_chunk()
			else:
				chunk.show_chunk()
		else:
			q.chunks_ready &= ~(1 << i)

class Quad:
	var rect: Rect2
	var lod: int
	var has_children: bool = false
	var children: PackedInt64Array = []
	var chunks_ready: int = 0  # Bit mask.
