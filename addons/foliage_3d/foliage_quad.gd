class_name FoliageQuad
extends RefCounted


# The rect on the 2d map that the quad takes up.
var rect: Rect2

# Quad LOD, goes from 0 to the maximal required quad lod.
var qlod: int

# Children.
var child_t_l: FoliageQuad
var child_t_r: FoliageQuad
var child_b_l: FoliageQuad
var child_b_r: FoliageQuad

# This is the computed data that the quad stores.
# Supported types: Mesh, MultiMesh.
# They aren't initialized straight away, but are passed to the quad from the worker thread pool when the build is completed.
var resources: Array

# Building the quad happens on a separate thread.
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
	qlod = parent.qlod - 1

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

func build_sync() -> Array:
	return []

var build_task_id: int = 0

# Starts the build.
func build() -> void:
	assert(build_task_id == 0, "build() called twice on the same quad")
	build_task_id = WorkerThreadPool.add_task(build_sync_static.bind(self))

# This is a computationally expensive function that runs on the worker pool thread.
# It must call on_build_completed on the main thread (by using call_deferred) upon completion.
static func build_sync_static(this: FoliageQuad) -> void:
	var res: Array = this.build_sync()
	on_build_completed.call_deferred(this, res)

# Only call this function on the main thread.
# Use call_deferred to trigger it from the worker pool thread.
# IMPORTANT: the first (index 0) element of res_resources should be the terrain mesh.
static func on_build_completed(this: FoliageQuad, res_resources: Array) -> void:
	this.resources = res_resources
	WorkerThreadPool.wait_for_task_completion(this.build_task_id)
	this.build_task_id = 0
	this.build_completed = true
