class_name FoliageLayer
extends Resource

## Foliage species that belong to this layer.
## Abundancies should [b]always[/b] add up to a value that is less or equal than 1.
@export var species: Array[FoliageSpecies]

## The side length of the placement grid.
## E.g. set this to something like 4 for trees, 0.5 for grass, etc.
@export var grid_size: float = 8

## A foliage layer applies to a mask of terrain textures.
@export var terrain_texture_names: Array[StringName]
