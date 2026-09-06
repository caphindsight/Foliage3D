## Basic foliage layer, provides limited controls over placement configuration.
class_name FoliageLayerBasic
extends FoliageLayer

## A list of assets to place.
@export var assets: Array[FoliageAsset]

## Probabilities of each of the asset from the list above, in the same order.
## If unspecified, probabilities are assumed to be uniform.
@export var probabilities: PackedFloat32Array

## Assets will be only placed on the selected terrain texture ids.
@export_flags_3d_render var textures: PackedInt32Array

## If specified, allows specifying the dependence of the asset density on height.
@export var height_density_curve: Curve

## If specified, allows specifying the dependence of the asset density on the terrain slope (in degrees).
@export var slope_density_curve: Curve

## If specified, allows specifying the dependence of the asset density on a 2d noise (in world coordinates).
@export var density_noise: Noise

var cumulative_probabilities: PackedFloat32Array
var texture_mask: int

func _ready() -> void:
	cumulative_probabilities.resize(len(probabilities))
	for i in len(probabilities):
		cumulative_probabilities[i] = probabilities[i]
		if i > 0:
			cumulative_probabilities[i] += cumulative_probabilities[i - 1]
	texture_mask = 0
	for i in textures:
		texture_mask |= 1 << i

func place(placement: FoliagePlacement) -> void:
	var height_density_curve_thread_local: Curve
	if height_density_curve:
		height_density_curve_thread_local = height_density_curve.duplicate(true)
	var slope_density_curve_thread_local: Curve
	if slope_density_curve:
		slope_density_curve_thread_local = slope_density_curve.duplicate(true)
	var density_noise_thread_local: Noise
	if density_noise:
		density_noise_thread_local = density_noise.duplicate(true)
	for i in placement.size():
		var probability: float = 1.0
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
		if height_density_curve_thread_local:
			probability *= height_density_curve_thread_local.sample(position.y)
		if slope_density_curve_thread_local:
			probability *= slope_density_curve_thread_local.sample(rad_to_deg(placement.get_slope(i)))
		if density_noise_thread_local:
			var noise: float = density_noise_thread_local.get_noise_2d(position.x, position.z)
			probability *= (noise / 2.0 + 0.5)
		var rng := FoliageRandom.new(32487673875)
		var rand: float = rng.prng3(position)
		if rand >= probability: continue
		rand /= probability
		var ind: int = cumulative_probabilities.bsearch(rand)
		if ind >= len(assets): continue
		placement.place_asset(i, assets[ind])
