# Foliage3D

## Usage

### Adding to the project

1.  Open Godot4, create a new project.
2.  Head to AssetLib and download Terrain3D (or alternatively download from [here](https://github.com/TokisanGames/Terrain3D))
3.  Copy the `assets/foliage_3d` folder into your project
4.  Head to Project Settings and enable `Terrain3D` and `Foliage3D`.
5.  Restart the engine.

### Preparing foliage assets

You'll be using a few custom resources:

1.  `FoliageMesh` --- holds a reference to mesh, together with a list of material overrides for each of the surface of the mesh.
2.  `FoliageLOD` --- describes a foliage asset rendered at some LOD. Contains a list of meshes and other optional parameters.
3.  `FoliageAsset` --- describes an asset that can be instanced by Foliage3D.
	1.  Levels of Detail --- here you can set different `FoliageLOD` objects. Also you need to map the quad tree LODs to foliage LODs using `qlod_to_flod`.
	2.  Interactive Scene --- low-lod (by default, only LOD-0) instances will be asynchronously replaced by an instanced scene. This is how you can achieve
		collisions and further interactivity.
	3.  Transform --- set rotation / scaling randomization here.
4.  `FoliageSpecies` --- essentially a FoliageAsset, but with some more meta information.
	Includes abundance (probability of finding this species at a random location) and grid randomization settings.
5.  `FoliageLayer` --- this describes a collection of species placed on a grid with configurable spacing.
	E.g. this can be "forest trees".
	A very important setting here is `terrain_texture_names`: foliage will only be generated on matching textures.

### Adding foliage to the level

Just create a top-level `Foliage3D` node, and in the settings give it:

1.  A reference to your `Terrain3D`.
2.  A reference to your observer `Node3D`: this is the origin object around which the LODs will expand.
3.  A list of foliage layers.

### How do I paint foliage?

You don't.

This plugin assumes foliage is procedurally generated on the painted terrain.
You can control the foliage by painting different textures on the terrain.
