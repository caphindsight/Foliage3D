class_name FoliageLayer
extends Resource

## Split the LOD-0 quad (aka cell) into a grid with this many edges per side.
## The grid will be used for asset placement.
@export var grid_subdivisions: int = 4

## Foliage species that belong to this layer.
## Abundancies should [b]always[/b] add up to a value that is less or equal than 1.
@export var species: Array[FoliageSpecies]

## A foliage layer applies to a mask of terrain textures.
@export var terrain_texture_names: Array[StringName]


# Implementation.

var initialized := false
var cumulative_abundancies: PackedFloat32Array
var nqlod: int = 0

func init() -> void:
	if initialized: return
	initialized = true
	for sp in species:
		sp.init()
	var n := len(species)
	cumulative_abundancies.resize(n)
	for i in n:
		nqlod = maxi(nqlod, len(species[i].asset.qlod_to_flod))
		cumulative_abundancies[i] = species[i].abundance
		if i > 0: cumulative_abundancies[i] += cumulative_abundancies[i - 1]
		assert(cumulative_abundancies[i] <= 1, "Sum of abundances of foliage species exceeds 1")

# Based on a value of a (assumed to be uniform between 0 and 1) pseudo-random number, pick a species.
# Can return null if no species was picked.
func pick_species(prng: float) -> FoliageSpecies:
	var ind := cumulative_abundancies.bsearch(prng)
	if ind < 0 or ind >= len(species):
		return null
	return species[ind]
