class_name FoliageSpecies
extends Resource

## The foliage asset to use.
@export var asset: FoliageAsset

## Probability of finding this asset type at a point on the grid.
## Abundances for all species in the layer should [b]always[/b] add up to a value that is less or equal than 1.
@export var abundance: float = 0.1

## When set to 0, the assets will be placed on the square grid.
## When set to 1, the asset positions will be maximally randomized.
## In practice, set to a value between 0 and 1.
## You most probably want to keep the default value.
@export var randomness: float = 0.8
