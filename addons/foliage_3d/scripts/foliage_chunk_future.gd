class_name FoliageChunkFuture
extends RefCounted

var layer: FoliageLayer
var rect: Rect2
var chunk: FoliageChunk
var is_chunk_ready: bool
var is_chunk_orphaned: bool
var task_id: int

func _init(p_layer: FoliageLayer, p_rect: Rect2, p_lod: int) -> void:
	layer = p_layer
	rect = p_rect
	chunk = FoliageChunk.new()
	chunk.layer = p_layer
	chunk.rect = p_rect
	chunk.lod = p_lod
	chunk.future = self
	task_id = WorkerThreadPool.add_task(chunk.build)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(chunk):
			chunk.queue_free()

static func finalize(this: FoliageChunkFuture) -> void:
	this._finalize_impl()

func orphan() -> void:
	is_chunk_orphaned = true
	if is_chunk_ready:
		if is_instance_valid(chunk):
			chunk.queue_free()

func show_chunk() -> void:
	assert(is_chunk_ready, "Called show_chunk() on a chunk that isn't ready.")
	self.chunk.show()

func hide_chunk() -> void:
	assert(is_chunk_ready, "Called hide_chunk() on a chunk that isn't ready.")
	self.chunk.hide()

func _finalize_impl() -> void:
	if is_chunk_ready: return
	WorkerThreadPool.wait_for_task_completion(task_id)
	is_chunk_ready = true
	if not is_chunk_orphaned:
		layer.add_child(chunk)
