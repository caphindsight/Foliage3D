## This should be enough for most basic use cases, like placing some trees and grass.
## For more advanced use cases, implement your own subclass of [FoliageLayer].
class_name FoliageLayerBasic
extends FoliageLayer

## Use these collections.
## [FoliageLayerBasic] will first pick a collection based on individual probability densities for each collection,
## and then pick a [FoliageAsset] inside that collection based on the probabilities of assets within the collection.
@export var collections: Array[FoliageCollectionBasic]

func place(placement: FoliagePlacement) -> void:
	var collections_thread_local: Array[FoliageCollectionBasic] = collections.duplicate_deep()
	var n_col: int = len(collections_thread_local)
	var probabilities: PackedFloat64Array
	probabilities.resize(n_col)
	for i in n_col:
		collections_thread_local[i].precompute()
	var rng := FoliageRandom.new(772364723)
	for i in placement.size():
		for j in len(probabilities):
			probabilities[j] = collections_thread_local[j].get_collection_probability(placement, i)
		var total_probability: float = 0
		for j in len(probabilities):
			total_probability += probabilities[j]
		# If they sum up to >1, normalize them.
		if total_probability > 1:
			for j in len(probabilities):
				probabilities[j] /= total_probability
		var picked_collection: int = -1
		var cumulative_probability: float = 0
		var pos := placement.get_transform(i).origin
		rng.seed_with_vec2(Vector2(pos.x, pos.z))
		var uniform: float = rng.randf()
		for j in len(probabilities):
			cumulative_probability += probabilities[j]
			if cumulative_probability > uniform:
				picked_collection = j
				uniform = lerpf(0, 1, (uniform - cumulative_probability + probabilities[j]) / probabilities[j])
				break
		if picked_collection >= 0:
			placement.place_asset(i, collections_thread_local[picked_collection].get_asset(uniform))
