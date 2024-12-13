class_name Foliage3D
extends Node3D

## Foliage is rendered on top of the terrain.
@export var terrain: Terrain3D

## Add all foliage layers you want to render in here.
@export var foliage_layers: Array[FoliageLayer]
