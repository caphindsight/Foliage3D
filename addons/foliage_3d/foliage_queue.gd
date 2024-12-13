class_name FoliageQueue
extends RefCounted

class QueueItem:
	# This item means instantiate a scene, with a given transform,
	# and decrement visible instances count for each multimesh given.
	var wr: WeakRef  # Anchor to make sure the item is still needed when it's processed.
	var parent: Node
	var scene: PackedScene
	var transform: Transform3D
	var scale_prop: StringName
	var scale_val: Vector3
	var meshes: Array[Mesh]  # Temporary storage, transformed into multimeshes later.
	var multimeshes: Array[MultiMesh]

var queue: Array[QueueItem]

# Returns true if it ran a computationally expensive operation.
func process_one() -> bool:
	if queue.is_empty(): return true  # Special case: queue is empty, need to yield.
	var item: QueueItem = queue.pop_back()  # Really it's kind of a stack.
	var obj: Object = item.wr.get_ref()
	if not obj: return false  # This item is no longer needed.
	assert(item.scene.can_instantiate())
	var instance: Node = item.scene.instantiate()
	var instance_3d := instance as Node3D
	if not instance_3d:
		assert(false, "Instantiated foliage scene root is not a Node3D")
		if instance: instance.queue_free()
		return true
	instance_3d.transform = item.transform
	item.parent.add_child(instance_3d)
	if item.scale_prop:
		instance.set(item.scale_prop, item.scale_val)
	for mm in item.multimeshes:
		mm.visible_instance_count -= 1
	return true

func set_parent(wr: WeakRef, parent: Node):
	for item in queue:
		item.wr = wr
		item.parent = parent
