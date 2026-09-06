extends FoliageLayer

const CUBE := preload("res://demo/foliage/assets/cube.tres")

func place(placement: FoliagePlacement) -> void:
	for i in placement.size():
		placement.place_asset(i, CUBE)
