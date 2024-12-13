class_name Foliage3D
extends Node3D

@export_group("Terrain and Observer")

## Foliage is rendered on top of the terrain.
@export var terrain: Terrain3D

## A reference to the observer node.
@export var observer: Node3D

## Add all foliage layers you want to render in here.
@export var foliage_layers: Array[FoliageLayer]

@export_group("Quad Tree")

## The side length of the LOD-0 quad (aka cell).
@export var cell_size: float = 32

## The maximal quad lod. Choose to cover the entire terrain.
## You probably don't want to change the default value, which covers a 16km * 16km area.
@export var qlod_max: int = 9

## This is the threshold value for the angular resolution of the quad, in radians.
## When the quad is closer to the observer, we subdivide it (unless it's an LOD-0 quad aka cell).
@export var subdivide_threshold_angle: float = 0.75

## This is the multiplier for the Y axis component in the distance formula between an observer and a quad.
@export var observer_height_sensitivity: float = 1

## Observer's global position is snapped to a 3d grid with this spacing to avoid jitter.
@export var observer_snapping_step: Vector3 = Vector3(10, 10, 10)

## Observer's position is updated with this time interval to avoid jitter.
@export var update_interval: float = 0.2


# Implementation.

var root: FoliageQuad
var update_timer: Timer
var terrain_static_body: StaticBody3D
var queue := FoliageQueue.new()
var nqlod: int


func _ready():
	# Compute the number of required quad LODs.
	nqlod = 0
	for layer in foliage_layers:
		layer.init()
		nqlod = maxi(nqlod, layer.nqlod)
	if nqlod == 0: return  # No foliage to render.
	root = FoliageQuad.new()
	var max_size: float = cell_size * pow(2, qlod_max - 1)
	root.terrain = terrain
	root.layers = foliage_layers
	root.rect = Rect2(-max_size / 2, -max_size / 2, max_size, max_size)
	root.qlod = qlod_max
	root.nqlod = nqlod
	root.build()
	root.init_children(true, true)

	update_timer = Timer.new()
	update_timer.autostart = true
	update_timer.wait_time = update_interval
	update_timer.timeout.connect(update)
	add_child(update_timer, false, Node.INTERNAL_MODE_FRONT)

func _process(_delta: float) -> void:
	if nqlod == 0: return  # No foliage to render.
	# Go over the foliage queue and replace multimesh instances with instantiated scenes.
	# We roughly equate 10 cheap operations to 1 computationally expensive operation.
	for i in 10:
		if queue.process_one(): break

class QuadNodes:
	var instances: Dictionary
	
	func init(foliage: Foliage3D, quad: FoliageQuad) -> void:
		var keys: Dictionary
		for res in quad.resources:
			keys[res] = true
			if instances.has(res): continue
			if res is Mesh:
				instances[res] = MeshInstance3D.new()
				instances[res].mesh = res
				instances[res].hide()
			elif res is MultiMesh:
				instances[res] = MultiMeshInstance3D.new()
				instances[res].multimesh = res
				instances[res].hide()
			elif res is FoliageQueue:
				if res.queue.is_empty(): continue
				instances[res] = Node3D.new()
				res.set_parent(weakref(res), instances[res])
				foliage.queue.queue.append_array(res.queue)
				res.queue.clear()
				instances[res].hide()
			else:
				assert(false, "Unsupported resource type")
			instances[res].position = Vector3(
				quad.rect.get_center().x,
				0,
				quad.rect.get_center().y,
			)
			foliage.add_child(instances[res], false, Node.INTERNAL_MODE_BACK)
		for res in instances.keys():
			if not keys.has(res):
				if instances[res]: instances[res].queue_free()
				instances.erase(res)

	func show() -> void:
		for instance in instances.values():
			instance.show()

	func hide() -> void:
		for instance in instances.values():
			instance.hide()

	func destroy() -> void:
		for instance in instances.values():
			if instance: instance.queue_free()
		instances = {}


var quad_nodes: Dictionary  # From Quad to QuadNodes.


func destroy_subtree(quad: FoliageQuad, destroy_self: bool = false) -> void:
	if destroy_self and quad_nodes.has(quad):
		var nodes = quad_nodes[quad]
		assert(nodes is QuadNodes)
		nodes.destroy()
	for child in quad.get_children():
		destroy_subtree(child, true)

func init_missing_nodes(quad: FoliageQuad = null) -> void:
	if not quad: quad = root
	if quad.build_completed:
		var nodes: QuadNodes
		if not quad_nodes.has(quad):
			nodes = QuadNodes.new()
			quad_nodes[quad] = nodes
		else:
			nodes = quad_nodes[quad]
		nodes.init(self, quad)
	for child in quad.get_children():
		init_missing_nodes(child)

func recycle_unused_nodes() -> void:
	var all_quads := collect_quads()
	var keys = quad_nodes.keys()
	for key in keys:
		if not all_quads.has(key):
			quad_nodes[key].destroy()
			quad_nodes.erase(key)

func collect_quads() -> Dictionary:
	var dict := {}
	collect_quads_rec(root, dict)
	return dict

func collect_quads_rec(quad: FoliageQuad, dict: Dictionary):
	dict[quad] = true
	for child in quad.get_children():
		collect_quads_rec(child, dict)

# Walks the tree recursively and splits / merges quads.
func restructure() -> void:
	update_observer_position()
	restructure_rec(root)

func restructure_rec(quad: FoliageQuad) -> void:
	var observer_gpos2 := Vector2(observer_gpos.x, observer_gpos.z)
	var d: float = sqrt(quad.get_distance2_to_observer(observer_gpos2) + pow(maxf(0, observer_gpos.y - observer_elevation) * observer_height_sensitivity, 2))
	var a: float = atan2(cell_size * pow(2, quad.qlod), d)
	var should_subdivide: bool = a > subdivide_threshold_angle and quad.qlod > 0
	if should_subdivide:
		if not quad.has_children():
			quad.init_children()
	else:
		if quad.has_children() and quad.build_completed:
			destroy_subtree(quad)
			quad.drop_children()
	for child in quad.get_children():
		restructure_rec(child)

func dump_tree(quad: FoliageQuad = null, indent: int = 0) -> void:
	if not quad: quad = root
	var observer_gpos2 := Vector2(observer_gpos.x, observer_gpos.z)
	var d: float = sqrt(quad.get_distance2_to_observer(observer_gpos2) + pow(maxf(0, observer_gpos.y - observer_elevation) * observer_height_sensitivity, 2))
	var a: float = atan2(cell_size * pow(2, quad.qlod), d)
	var line = ""
	for i in indent: line += "  "
	line += "[LOD" + str(quad.qlod) + "] at " + str(quad.rect) + " with d=" + str(d) + " and a=" + str(a) + " vs threshold=" + str(subdivide_threshold_angle)
	if quad.build_completed:
		line += " - ready"
	print(line)
	for child in quad.get_children():
		dump_tree(child, indent + 1)
	if quad == root: print("")

# Walks the tree recursively and determines which quads to activate / deactivate.
# The ideal state is that leaf quads are active and branch quads are inactive.
# However, if some of the leaf quads aren't built yet, we keep the branch quads as active instead.
func reactivate(quad: FoliageQuad = null) -> bool:
	if not quad: quad = root
	if quad.has_children():
		var children_reactivation_failed := false
		for child in quad.get_children():
			if not reactivate(child):
				children_reactivation_failed = true
				break
		if children_reactivation_failed:
			deactivate(quad, false)
		else:
			if quad_nodes.has(quad):
				quad_nodes[quad].hide()
			return true
	if quad_nodes.has(quad):
		quad_nodes[quad].show()
		return true
	else:
		return false

func deactivate(quad: FoliageQuad, deactivate_self: bool = true) -> void:
	if deactivate_self:
		if quad_nodes.has(quad):
			quad_nodes[quad].hide()
	for child in quad.get_children():
		deactivate(child, true)

# Runs the quad tree update cycle.
func update() -> void:
	restructure()
	init_missing_nodes()
	reactivate()
	recycle_unused_nodes()

var observer_gpos: Vector3
var observer_elevation: float

func update_observer_position() -> void:
	if not observer: return
	observer_gpos = observer.global_position.snapped(observer_snapping_step)
	observer_elevation = terrain.data.get_height(observer_gpos)
