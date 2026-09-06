## A collection of placement decisions for a single foliage chunk.
## This is the data structure operated on by [FoliageLayer].
class_name FoliagePlacement
extends RefCounted

var assets: Array[FoliageAsset]
var transforms: Array[Transform3D]
var normals: PackedVector3Array
var base_texture_ids: PackedInt32Array
var overlay_texture_ids: PackedInt32Array
var texture_blend_amounts: PackedFloat32Array

## Count of the available points on the grid.
func size() -> int:
	return len(assets)

## Resizes the available points on the grid.
## [b]Warning:[/b] this is an advanced feature, it allows scripts to generate custom grids.
func resize(new_size: int, preserve: bool = false) -> void:
	if not preserve:
		assets.clear()
		transforms.clear()
		normals.clear()
		base_texture_ids.clear()
		overlay_texture_ids.clear()
		texture_blend_amounts.clear()
	assets.resize(new_size)
	transforms.resize(new_size)
	normals.resize(new_size)
	base_texture_ids.resize(new_size)
	overlay_texture_ids.resize(new_size)
	texture_blend_amounts.resize(new_size)

## Get the global transform of the i-th available grid point.
func get_transform(i: int) -> Transform3D:
	return transforms[i]

### Gets the height of the i-th available grid point.
func get_height(i: int) -> float:
	return transforms[i].origin.y

### Set the global transform of the i-th available grid point.
func set_transform(i: int, transform: Transform3D) -> void:
	transforms[i] = transform

### Gets the terrain normal vector of the i-th available grid point.
func get_normal(i: int) -> Vector3:
	return normals[i]

### Gets the terrain slope of the i-th availabnle grid point, in radians.
func get_slope(i: int) -> float:
	return PI / 2 - acos(absf(normals[i].y))

## Get the asset placed at the i-th available grid point.
## If there isn't an asset currently placed, returns [code]null[/code].
func get_asset(i: int) -> FoliageAsset:
	return assets[i]

## Set the asset placed at the i-th available grid point.
## To remove an asset, set it to [code]null[/code].
func set_asset(i: int, asset: FoliageAsset) -> void:
	assets[i] = asset

## Set the asset placed at the i-th available grid point, and randomize its transform
## according to the parameters set on the [FoliageAsset] resource.
func place_asset(i: int, asset: FoliageAsset) -> void:
	assets[i] = asset
	if not asset: return
	var transform := transforms[i]
	var normal := normals[i]
	var position := Vector2(transform.origin.x, transform.origin.z)
	var random_pitch := FoliageRandom.new(-3030054608389)
	var random_pitch_axis := FoliageRandom.new(5851782439795)
	var random_yaw := FoliageRandom.new(5558960081466)
	var random_scale := FoliageRandom.new(8422615989223)
	var pitch_axis := Vector3.RIGHT
	if asset.randomize_pitch:
		pitch_axis = pitch_axis.rotated(Vector3.UP, random_pitch_axis.prng2(position) * TAU)
	var pitch_rotation: float = lerpf(asset.pitch_min, asset.pitch_max, random_pitch.prng2(position))
	transform = transform.rotated_local(pitch_axis, pitch_rotation)
	if asset.randomize_yaw:
		transform = transform.rotated_local(Vector3.UP, random_yaw.prng2(position) * TAU)
	var normal_align_quat := Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP, normal), asset.align_to_normal)
	transform = Transform3D(Basis(normal_align_quat) * transform.basis, transform.origin)
	var scale: float = lerpf(asset.scale_min, asset.scale_max, random_scale.prng2(position))
	transform = transform.scaled_local(Vector3(scale, scale, scale))
	transforms[i] = transform

## Returns the blend amount of terrain texture [param texture_id] sampled at point i.
## [b]Warning:[/b] sampling happens before [member FoliageLayer._place] runs.
## If you modify point transforms inside [member FoliageLayer._place], you will have to resample textures.
func sample_texture(i: int, texture_id: int) -> float:
	if base_texture_ids[i] == texture_id:
		if overlay_texture_ids[i] == texture_id:
			return 1
		else:
			return 1.0 - texture_blend_amounts[i]
	else:
		if overlay_texture_ids[i] == texture_id:
			return texture_blend_amounts[i]
		else:
			return 0

func add_point(transform: Transform3D, normal: Vector3, base_texture_id: int, overlay_texture_id: int, texture_blend_amount: float) -> void:
	assets.push_back(null)
	transforms.push_back(transform)
	normals.push_back(normal)
	base_texture_ids.push_back(base_texture_id)
	overlay_texture_ids.push_back(overlay_texture_id)
	texture_blend_amounts.push_back(texture_blend_amount)
