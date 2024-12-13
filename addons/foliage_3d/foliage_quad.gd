class_name FoliageQuad
extends RefCounted

# Foliage layers to build.
var layers: Array[FoliageLayer]

# The rect on the 2d map that the quad takes up.
var rect: Rect2

# Quad LOD, goes from 0 to the maximal required quad lod.
var qlod: int

# Max foliage quad lod plus 1, e.g. if foliage is required for lods 0, 1 and 2; this will be 3.
var nqlod: int

# Children.
var child_t_l: FoliageQuad
var child_t_r: FoliageQuad
var child_b_l: FoliageQuad
var child_b_r: FoliageQuad

# This is the computed data that the quad stores.
# Supported types: Mesh, MultiMesh.
# They aren't initialized straight away, but are passed to the quad from the worker thread pool when the build is completed.
var resources: Array

# Building the quad happens on separate threads.
var build_completed: bool = false

func get_distance2_to_observer(p: Vector2) -> float:
	var dx: float = 0
	if p.x < rect.position.x: dx = rect.position.x - p.x
	if p.x > rect.end.x: dx = p.x - rect.end.x
	var dy: float = 0
	if p.y < rect.position.y: dy = rect.position.y - p.y
	if p.y > rect.end.y: dy = p.y - rect.end.y
	return dx * dx + dy * dy

func get_distance_to_observer(p: Vector2) -> float:
	return sqrt(get_distance2_to_observer(p))

func get_children() -> Array[FoliageQuad]:
	var children: Array[FoliageQuad] = []
	if child_t_l: children.push_back(child_t_l)
	if child_t_r: children.push_back(child_t_r)
	if child_b_l: children.push_back(child_b_l)
	if child_b_r: children.push_back(child_b_r)
	return children

func has_children() -> bool:
	var n_children: int = 0
	if child_t_l: n_children += 1
	if child_t_r: n_children += 1
	if child_b_l: n_children += 1
	if child_b_r: n_children += 1
	assert(n_children in [0, 4])
	return n_children > 0

func copy_parent_properties(parent: FoliageQuad) -> void:
	layers = parent.layers
	qlod = parent.qlod - 1
	nqlod = parent.nqlod

func init_children(force: bool = true, as_dummy: bool = false) -> void:
	var size: Vector2 = rect.size / 2
	var right := Vector2(size.x, 0)
	var down := Vector2(0, size.y)

	if not child_t_l or force:
		child_t_l = FoliageQuad.new()
		child_t_l.rect = Rect2(rect.position, size)
		child_t_l.copy_parent_properties(self)
		child_t_l.build()

	if not child_t_r or force:
		child_t_r = FoliageQuad.new()
		child_t_r.rect = Rect2(rect.position + right, size)
		child_t_r.copy_parent_properties(self)
		child_t_r.build()

	if not child_b_l or force:
		child_b_l = FoliageQuad.new()
		child_b_l.rect = Rect2(rect.position + down, size)
		child_b_l.copy_parent_properties(self)
		child_b_l.build()

	if not child_b_r or force:
		child_b_r = FoliageQuad.new()
		child_b_l.rect = Rect2(rect.get_center(), size)
		child_b_r.copy_parent_properties(self)
		child_b_r.build()

func drop_children():
	child_t_l = null
	child_t_r = null
	child_b_l = null
	child_b_r = null

var build_tasks: PackedInt32Array
var build_tasks_pending: int = 0

# Starts the build.
func build() -> void:
	assert(build_tasks.is_empty() and not build_completed, "build() called twice on the same quad")
	var n := len(layers)
	build_tasks.resize(n)
	for i in n:
		build_tasks[i] = WorkerThreadPool.add_task(build_sync_static.bind(self, i, layers[i]))
	build_tasks_pending = n


# IMPORTANT:
# ==========
#
# The following functions run on the worker thread.
# The following variables are to be accessed only from the worker thread.

static func build_sync_static(this: FoliageQuad, task_index: int, layer: FoliageLayer) -> void:
	var generated_resources: Array = this.build_sync(layer)
	on_build_completed.call_deferred(this, task_index, generated_resources)

static func on_build_completed(this: FoliageQuad, task_index: int, generated_resources: Array) -> void:
	this.resources.append_array(generated_resources)
	WorkerThreadPool.wait_for_task_completion(this.build_tasks[task_index])
	this.build_tasks[task_index] = 0
	this.build_tasks_pending -= 1
	if this.build_tasks_pending <= 0:
		this.build_completed = true

var instance_dict: Dictionary
var queue: FoliageQueue

const SEEDS_N: int = 6
const SMALL_SEEDS: PackedFloat64Array = [
	16.009,
	-29.774,
	31.741,
	25.201,
	12.684,
	-19.498
]
const LARGE_SEEDS: PackedFloat64Array = [
	43649.6711781,
	67134.4902175,
	59873.1192490,
	61291.9428323,
	47839.2365821,
	54344.3590345,
]

static func prng(a: float, b: float, seed_id: int) -> float:
	return fposmod(
		sin(
			a * SMALL_SEEDS[seed_id % SEEDS_N] +
			b * SMALL_SEEDS[(seed_id + 1) % SEEDS_N]
		) * LARGE_SEEDS[seed_id % SEEDS_N],
		1.0
	)

func build_sync(layer: FoliageLayer) -> Array:
	return []
