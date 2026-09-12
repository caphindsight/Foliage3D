class_name FoliageRandom
extends RandomNumberGenerator

var master_seed: float = 0
var sensitivity: float = 1e-3

func _init(p_master_seed: int) -> void:
	master_seed = splitmix_hash(splitmix_hash(p_master_seed))

static func splitmix_hash(x: int) -> int:
	x ^= x >> 30
	x *= 4564476756301768121
	x ^= x >> 27
	x *= 1499779743744070123
	x ^= x >> 31
	return x

static func splitmix_combine(a: int, b: int) -> int:
	return a ^ (b + 2177342782468422677 + (a << 6) + (a >> 2))

func seed_with_float(value: float) -> void:
	seed = splitmix_combine(master_seed, splitmix_hash(roundi(value / sensitivity)))
	self.randf()

func seed_with_vec2(value: Vector2) -> void:
	var hx: int = splitmix_hash(roundi(value.x / sensitivity))
	var hy: int = splitmix_hash(roundi(value.y / sensitivity))
	seed = splitmix_combine(master_seed, splitmix_combine(hx, hy))
	self.randf()

func seed_with_vec3(value: Vector3) -> void:
	var hx: int = splitmix_hash(roundi(value.x / sensitivity))
	var hy: int = splitmix_hash(roundi(value.y / sensitivity))
	var hz: int = splitmix_hash(roundi(value.z / sensitivity))
	seed = splitmix_combine(master_seed, splitmix_combine(hx, splitmix_combine(hy, hz)))
	self.randf()

func seed_with_vec4(value: Vector4) -> void:
	var hx: int = splitmix_hash(roundi(value.x / sensitivity))
	var hy: int = splitmix_hash(roundi(value.y / sensitivity))
	var hz: int = splitmix_hash(roundi(value.z / sensitivity))
	var hw: int = splitmix_hash(roundi(value.w / sensitivity))
	seed = splitmix_combine(master_seed, splitmix_combine(hx, splitmix_combine(hy, splitmix_combine(hz, hw))))
	self.randf()
