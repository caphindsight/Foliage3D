class_name FoliageRandom
extends RandomNumberGenerator

var sensitivity: float = 1e-3

func _init(p_seed: int) -> void:
	seed = p_seed

## Generates a pseudo-random number that depends only on [param x].
func prng1(x: float) -> float:
	state = hash(floori(x / sensitivity))
	self.randf()
	return self.randf()

## Generates a pseudo-random number that depends only on [param v].
func prng2(v: Vector2) -> float:
	state = hash(Vector2i(floori(v.x / sensitivity), floori(v.y / sensitivity)))
	self.randf()
	return self.randf()

## Generates a pseudo-random number that depends only on [param v].
func prng3(v: Vector3) -> float:
	state = hash(Vector3i(floori(v.x / sensitivity), floori(v.y / sensitivity), floori(v.z / sensitivity)))
	self.randf()
	return self.randf()
