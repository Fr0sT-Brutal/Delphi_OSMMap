OSM MapControl
==============

Delphi/Lazarus visual component for displaying a map. Could use any map tile provider (currently implemented OpenStreetMap, OpenTopoMap, HERE, Google). Also includes helper classes for storing and downloading map tiles.
Demo project implements downloading map tiles from network.

:exclamation: **Alpha version, interface could change** :exclamation:

Features
--------

- Multiple tile providers
- Multiple network request engines
- Layers to control visibility easily
- Customizable map marks
- Customizable routes (called tracks)
- Custom paint on the view area (allows drawing any regions, shapes, images etc)

Compatibility
-------------

Tested on:

  - Delphi XE2 and 10.1, VCL, Windows
  - Lazarus 2.1.0 trunk & FPC 3.3.1 trunk, LCL, Windows / Linux

Tile providers
--------------

Adding a new tile provider is easy, just learn its API and take implemented providers as example. When you're done, create pull request and I'll happily merge it.

For description of tile URL template placeholders refer to OSM.TilesProvider.FormatTileURL function (or [docs](https://fr0st-brutal.github.io/Delphi_OSMMap/docs/OSM.TilesProvider.html#FormatTileURL))

Project structure
-----------------

  - `OSM.SlippyMapUtils` - utility functions, variables and types
  - `OSM.TileStorage` - classes `TTileBitmapCache` implementing cache of map tiles organized as a queue and `TTileStorage` implementing disc storage of map tiles.
  - `OSM.NetworkRequest` - utils and classes for network requesting of map tiles. Class `TNetworkRequestQueue` implements threaded non-blocking queue of network requests. Unit doesn't contain any real network request engine.
  - `OSM.NetworkRequest.Synapse`, `OSM.NetworkRequest.WinInet`, `OSM.NetworkRequest.RTL` contain concrete implementations of network requesting routines
  - `OSM.MapControl` contains classes `TMapMark` and `TMapMarkList` for managing a set of map points and `TMapControl` itself
  - `OSM.TilesProvider` - base abstract class of map tile provider.
  - `OSM.TilesProvider.*` contain concrete implementations of map tile providers
  
Full docs for all units listed above is available [here](https://fr0st-brutal.github.io/Delphi_OSMMap/)

Third party
-----------

If you wish to use **Synapse** network engine and don't have it yet, you can take it from **Releases** section.

Screen shows Demo app built with Delphi and running on Windows using OSM tiles with random map marks, random track and square painted from callback.

![screen1](https://raw.githubusercontent.com/Fr0sT-Brutal/Delphi_OSMMap/master/Screen/screen1.png)

Screen shows Demo app built with Delphi and running on Windows using Google tiles

![screen2](https://raw.githubusercontent.com/Fr0sT-Brutal/Delphi_OSMMap/master/Screen/screen2.png)