## A readily available implementation for the [FoliageLayerBasic].
## This should be enough for most basic use cases, like placing some trees and grass.
## For more advanced use cases, implement your own subclass of [FoliageLayer].
@icon("res://addons/foliage_3d/icons/foliage_collection.svg")
class_name FoliageCollectionBasic
extends Resource

## A list of assets to place.
@export var assets: Array[FoliageAsset]

## Weights of each of the asset from the list above, in the same order.
## If unspecified, weights are assumed to be uniform.
@export var weights: PackedFloat32Array

## Assets will be only placed on the selected terrain texture ids.
@export var textures: PackedInt32Array

## Base probability of finding an asset of this collection at a lattice point.
@export var density: float = 1.0

## If specified, allows specifying the dependence of the asset density on height.
@export var height_density_curve: Curve

## If specified, allows specifying the dependence of the asset density on the terrain slope (in degrees).
@export var slope_density_curve: Curve

## If specified, allows specifying the dependence of the asset density on a 2d noise (in world coordinates).
@export var density_noise: Noise

var cumulative_probabilities: PackedFloat32Array
var texture_mask: int

## Has to be called before this collection can be used.
func precompute() -> void:
	var total_weight: float = 0
	for weight in weights:
		total_weight += weight
	cumulative_probabilities.resize(len(weights))
	for i in len(cumulative_probabilities):
		cumulative_probabilities[i] = weights[i] / total_weight
		if i > 0:
			cumulative_probabilities[i] += cumulative_probabilities[i - 1]
	texture_mask = 0
	for i in textures:
		texture_mask |= 1 << i

## Returns the probability of an asset from this collection to be placed at a specific location.
func get_collection_probability(placement: FoliagePlacement, i: int) -> float:
	var probability: float = density
	if texture_mask != 0:
		var texture_probability: float = 0.0
		var base_id: int = placement.base_texture_ids[i]
		var overlay_id: int = placement.overlay_texture_ids[i]
		var blend_amount: float = placement.texture_blend_amounts[i]
		if base_id >= 0 and texture_mask & (1 << base_id) != 0:
			texture_probability += (1 - blend_amount)
		if overlay_id >= 0 and texture_mask & (1 << overlay_id) != 0:
			texture_probability += blend_amount
		probability *= texture_probability
	var position: Vector3 = placement.get_transform(i).origin
	if height_density_curve:
		probability *= height_density_curve.sample(position.y)
	if slope_density_curve:
		probability *= slope_density_curve.sample(rad_to_deg(placement.get_slope(i)))
	if density_noise:
		var noise: float = density_noise.get_noise_2d(position.x, position.z)
		probability *= (noise / 2.0 + 0.5)
	return probability

## Given a uniformly distributed between [0..1) number, return an asset.
func get_asset(uniform: float) -> FoliageAsset:
	var ind: int = cumulative_probabilities.bsearch(uniform)
	if ind >= len(assets):
		return null
	return assets[ind]
