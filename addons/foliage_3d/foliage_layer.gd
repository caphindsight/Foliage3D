class_name FoliageLayer
extends Resource

## Split the LOD-0 quad (aka cell) into a grid with this many edges per side.
## The grid will be used for asset placement.
@export var grid_size: int = 4

## Foliage species that belong to this layer.
## Abundancies should [b]always[/b] add up to a value that is less or equal than 1.
@export var species: Array[FoliageSpecies]

## A foliage layer applies to a mask of terrain textures.
@export var terrain_texture_names: Array[StringName]
