class_name FoliageQuad
extends RefCounted

# The terrain node reference, must outlive the quad.
var terrain: Terrain3D

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
	terrain = parent.terrain
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
		child_b_r.rect = Rect2(rect.get_center(), size)
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
	if qlod >= nqlod:
		resources = []
		build_completed = true
		return  # Nothing to build.
	var n := len(layers)
	build_tasks.resize(n)
	build_tasks_pending = n
	for i in n:
		build_tasks[i] = WorkerThreadPool.add_task(build_sync_static.bind(self, i, layers[i]))


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

static func prng(at: Vector2, seed_id: int) -> float:
	return fposmod(
		sin(
			at.x * SMALL_SEEDS[seed_id % SEEDS_N] +
			at.y * SMALL_SEEDS[(seed_id + 1) % SEEDS_N]
		) * LARGE_SEEDS[seed_id % SEEDS_N],
		1.0
	)

func push_instance(species: FoliageSpecies, at: Vector2, offset: Vector2, instance_dict: Dictionary, queue: FoliageQueue, texture_mask: int) -> void:
	var asset := species.asset
	assert(asset)
	if qlod >= len(asset.qlod_to_flod): return  # Nothing to push.
	var flod := asset.flods[asset.qlod_to_flod[qlod]]
	assert(flod)

	var pos3 := Vector3(at.x + offset.x, 0, at.y + offset.y)
	var height: float = terrain.data.get_height(pos3)
	if is_nan(height):
		return

	var offset3 := Vector3(
		(at.x + offset.x) - rect.get_center().x,
		height,
		(at.y + offset.y) - rect.get_center().y,
	)

	var texture_base: int = terrain.data.get_control_base_id(pos3)
	var texture_overlay: int = terrain.data.get_control_overlay_id(pos3)
	var texture_blend: float = terrain.data.get_control_blend(pos3)
	assert(not is_nan(texture_blend))
	var texture_id = texture_base if texture_blend < 0.5 else texture_overlay
	if not texture_mask & (1 << texture_id): return  # Rejected by texture.

	var scale: float = lerpf(asset.scale_min, asset.scale_max, prng(at, 3))
	var pitch: float = asset.pitch_max * prng(at, 4)
	var yaw: float = TAU * prng(at, 5)
	var yaw2: float = TAU * prng(at, 6)
	
	var tr_local := Transform3D.IDENTITY
	var normal := terrain.data.get_normal(pos3)
	var axis := Vector3.UP.cross(normal).normalized()
	var angle := Vector3.UP.angle_to(normal)
	tr_local = tr_local.rotated_local(axis, angle * asset.align_to_terrain_normal_lerp_alpha)
	tr_local = tr_local.rotated_local(Vector3.UP, yaw)
	tr_local = tr_local.rotated_local(Vector3.RIGHT.rotated(Vector3.UP, yaw2), pitch)
	tr_local = tr_local.translated_local(asset.offset)

	var item: FoliageQueue.QueueItem = null
	if asset.scene and asset.scene_qlod_threshold >= qlod:
		item = FoliageQueue.QueueItem.new()
		item.scene = asset.scene
		var tr_local_scaled := tr_local
		if not asset.scene_scale_property_name:
			tr_local_scaled = tr_local.scaled_local(Vector3(scale, scale, scale))
		item.transform = Transform3D(Basis.IDENTITY, offset3) * tr_local_scaled
		item.scale_prop = asset.scene_scale_property_name
		item.scale_val = Vector3(scale, scale, scale)
		item.meshes = []
		queue.queue.push_back(item)
		
	for fmesh in flod.meshes:
		var mesh := fmesh.mesh
		if item: item.meshes.push_back(mesh)
		if not instance_dict.has(mesh):
			instance_dict[mesh] = []
		var instances: Array = instance_dict[mesh]
		var tr_local_scaled := tr_local.scaled_local(Vector3(scale, scale, scale))
		instances.push_back(Transform3D(Basis.IDENTITY, offset3) * tr_local_scaled)

func build_sync(layer: FoliageLayer) -> Array:
	if qlod >= layer.nqlod: return []  # Nothing to build.
	var instance_dict := {}
	var queue := FoliageQueue.new()
	var texture_mask: int = 0
	for t in terrain.assets.get_texture_count():
		var texture := terrain.assets.get_texture(t)
		if texture.name in layer.terrain_texture_names:
			texture_mask |= (1 << texture.id)
	var grid_subdivisions: int = layer.grid_subdivisions << qlod
	var dx: float = rect.size.x / grid_subdivisions
	var dy: float = rect.size.y / grid_subdivisions
	for j in grid_subdivisions:
		for i in grid_subdivisions:
			var at := rect.position + Vector2(dx * (i + 0.5), dy * (j + 0.5))
			var species := layer.pick_species(prng(at, 0))
			if not species: continue
			var offset := Vector2(
				lerpf(-dx / 2, dx / 2, prng(at, 1) * species.randomness),
				lerpf(-dy / 2, dy / 2, prng(at, 2) * species.randomness),
			)
			push_instance(species, at, offset, instance_dict, queue, texture_mask)
	var res: Array = []
	var mesh_to_mm: Dictionary
	for mesh in instance_dict.keys():
		var mm := MultiMesh.new()
		mesh_to_mm[mesh] = mm
		mm.mesh = mesh
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var transforms = instance_dict[mesh]
		mm.instance_count = len(transforms)
		mm.visible_instance_count = mm.instance_count
		for i in len(transforms):
			mm.set_instance_transform(i, transforms[i])
		res.push_back(mm)
	for item in queue.queue:
		for m in item.meshes:
			var mm: MultiMesh = mesh_to_mm.get(m, null)
			if mm: item.multimeshes.push_back(mm)
		item.meshes.clear()
	if not queue.queue.is_empty(): res.push_back(queue)
	return res
