OSM MapControl
==============

**Version: 0.4.0**

Delphi/Lazarus visual component for displaying OpenStreetMap map. Also includes helper classes for storing and downloading map tiles.
Demo project implements downloading map tiles from network.

:exclamation: **Alpha version, interface could change** :exclamation:

Compatibility
-------------

Tested on:

  - Delphi XE2 and 10.1, VCL, Windows
  - Lazarus 2.1.0 trunk & FPC 3.3.1 trunk, LCL, Windows / Linux

Project structure
-----------------

  - `OSM.SlippyMapUtils` - util functions, variables and types
  - `OSM.TileStorage` - classes `TTileBitmapCache` implementing cache of map tiles organized as a queue and `TTileStorage` implementing disc storage of map tiles.
  - `OSM.NetworkRequest` - utils and classes for network requesting of map tiles. Class `TNetworkRequestQueue` implements threaded non-blocking queue of network requests. Unit doesn't contain any real network request engine.
  - `SynapseRequest`, `WinInetRequest` contain concrete implementations of network requesting routines
  - `OSM.MapControl` contains classes `TMapMark` and `TMapMarkList` for managing a set of map points and `TMapControl` itself
  
Full docs for all units listed above is available [here](https://fr0st-brutal.github.io/Delphi_OSMMap/)

Third party
-----------

If you wish to use **Synapse** network engine and don't have it yet, you can take it from **Releases** section.

![screen](https://raw.githubusercontent.com/Fr0sT-Brutal/Delphi_OSMMap/master/Screen/screen.png)