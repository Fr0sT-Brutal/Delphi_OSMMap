0.11.3
======

`Added`

- OSM.TilesProvider.pas: TTilesProvider.Clone
- OSM.NetworkRequest.pas: GetSystemProxy
- OSM.NetworkRequest.RTL.pas: RTL network engine for FPC now is able to use system proxy
- OSM.NetworkRequest.Synapse.pas: Synapse network engine now is able to use system proxy on Linux; retrieval of system proxy on Windows is improved
- Demo: request user for API key when a provider that requires it (only HERE currently) is selected

`Changed`

- OSM.TilesProvider.pas: TTileProvider, interface redesign. MinZoomLevel, MaxZoomLevel are read-only properties now; TileURLPatt added to base class; added read-only property Features
- OSM.NetworkRequest.pas: uses TTilesProvider.Clone so bg threads all use their own instances
- Demo: uses TTilesProvider.Clone thus eliminating two calls to TTilesProvider.Create

0.11.2
======

`Added`

+ Tracks, MapMarks: .Sort method added for manual resort if key properties of some items were changed

`Changed`

- OSM.MapControl.pas: TTrack is object now
- OSM.MapControl.pas: Tracks list is full analog of MapMarks with map auto redraw on adding/deleting, items are sorted by layer number, etc.
- OSM.MapControl.pas: TMapMark, inits Visible to true in c-tor for convenience
- OSM.MapControl.pas: TMapControl.OnPaint => TMapControl.OnDrawLayer; called BEFORE drawing map objects (mapmarks, tracks, labels)

0.11.1
======

`Added`

- OSM.MapControl.pas: Track now could be assigned to a layer. TTrack.Layer added
- OSM.MapControl.pas: TMapControl.MapToCanvas, CanvasToMap methods that consider ClipRect differences in Delphi & Lazarus as the only point of converting map coords to canvas coords. 
- OSM.MapControl.pas: TMapControl.OnPaint - Callback to custom draw whole map view
- Demo: demo of custom painting

`Changed`

- OSM.MapControl.pas: TMapControl.MapToInner, InnerToMap moved to protected section (required only internally)
- Demo: Fully tested with Lazarus on Windows

`Fixed`

- OSM.MapControl.pas: tracks drawing now doesn't use custom clipping - fixed issues on large zoom levels
- OSM.MapControl.pas: TMapMarkList.Add, fix addition to empty list
- OSM.MapControl.pas: TMapControl.DrawLabels, fix scale label positioning bug

0.11.0
======

`Added`

- OSM.MapControl.pas: Add long-awaited feature to add and paint tracks! Use them via TMapControl.Tracks
- OSM.MapControl.pas: TMapMarkGlyphStyle.Opacity
- OSM.MapControl.pas: TMapControl.OnDrawMapMarkGlyph to custom draw glyph only
- OSM.MapControl.pas: Triangle, RectByCenterAndSize functions made public
- OSM.MapControl.pas: TMapControl.DrawMapMark, supports opacity and custom drawing for glyphs. However, simple Canvas.Draw(Bitmap, Opacity) didn't work. Needs additional manipulations

`Changed`

- OSM.SlippyMapUtils.pas: CheckValid* raise exceptions on invalid values so will do all functions using these checks

`Fixed`

- OSM.NetworkRequest.WinInet.pas: NetworkRequest, tune some flags, enlarge buffer, add check for errors during reading the file

0.10.0
======

`[BREAKING]`

- OSM.MapControl.pas: TMapMarkList.Find, ConsiderMapMarkSize argument replaced by TMapMarkFindOptions set and namely mfoConsiderGlyphSize value. However, it is not default anymore (and disallowed for searching by geo coords raising an exception because glyph size doesn't map reliably to geo coords). It didn't work before anyway.

  **End-user code required changes** Modify all TMapMarkList.Find calls:
  
  - Where you need to consider glyph size - use Find(TPoint, [mfoConsiderGlyphSize]) overload. Glyph size is only actual when dealing with pixels.
  - In other places - use TMapMarkList.Find(GeoRect, [], idx) (will be forced by compiler)
  - You may also want to include mfoOnlyVisible option

- OSM.MapControl.pas: TMapMouseMode has changed its meaning. Now it reflects current map state of mouse events not the kind of reaction on mouse press-and-move. mmNone is default state, mmDrag/mmSelect renamed to mmDragging/mmSelecting.

  **End-user code required changes**:
  
  - Move mode setting from init section to MouseDown handlers. Or assign TMapControl.SelectionShiftState, DragShiftState instead
  - Rename mmDrag/mmSelect to mmDragging/mmSelecting (will be forced by compiler)

`Added`

- OSM.MapControl.pas: TMapMarkCaptionStyle.Visible to control display of the caption
- OSM.MapControl.pas: TMapMarkList gets upgrades: enumerator to use in for-in loops, Find(Pointer) to search by .Data field, Delete(Integer) to remove item by index, default Items property to get rid of writing Get().
- OSM.MapControl.pas: TMapMarkList.Find(TPoint), overload that allows considering glyph size with mfoConsiderGlyphSize option set
- OSM.MapControl.pas: TMapMarkFindOptions, mfoOnlyVisible option to allow skipping invisible marks. Method calls TMapControl.MapMarkVisible to determine effective visibility considering not only Visible flag but also visibility of mapmark layer.
- OSM.MapControl.pas: TMapControl.MapMarkAtPos method to find topmost visible mapmark at given pixel coords.
- OSM.MapControl.pas: TMapControl.MapMarkVisible - Returns mapmark visibility based on mapmark's own property and also on currently selected visible layers of the map. TMapMarkList.Find methods all use this method.
- OSM.MapControl.pas: TOnSelectionBox now is called on every selection box change to reflect changes on-the-fly. Added parameter "Finished"
- OSM.MapControl.pas: TMapControl.OnMapMarkMouse(Down|Up) events
- OSM.MapControl.pas: TMapControl.SelectionShiftState, DragShiftState properties that set combination to enter selection/dragging state on mouse down. Assigning these properties removes necessity of handling MouseDown event just for changing map state
- OSM.MapControl.pas: ShiftStateIs function for correct comparison of shift states (to use in MouseUp|Move|Down event handlers)

`Changed`

- OSM.SlippyMapUtils.pas: EnsureInMap, ensures negative coords as well
- OSM.MapControl.pas: TMapControl.SetZoom, cancels selection/dragging
- OSM.NetworkRequest.pas: request props are cloned and assigned to every TNetworkRequestThread in its c-tor to avoid multithread access issues.

`Fixed`

- OSM.MapControl.pas: TMapMarkList.Find(TGeoPoint), fixed StartIndex not incremented
- OSM.MapControl.pas: fixed map dragging

0.9.4
=====

`[BREAKING]`

- Major redesign of NetworkRequest. Reuse connections to speedup downloads and reduce server load. Engine capabilities are checked against request details. API changes for implementations of NetworkRequest only, no changes visible to end-user.

- OSM.NetworkRequest.pas: TBlockingNetworkRequestFunc => TBlockingNetworkRequestProc, must raise exception on error thus removing excess ErrMsg and result flag; add Client parameter. API changes for implementations of NetworkRequest only, no changes visible to end-user.

  **End-user code required changes**: none except for custom implementations of NetworkRequest. For those:
  
  - Function must be turned to procedure with other set of arguments (will be forced by compiler)
  - Procedure should call engine capabilities check
  - Procedure must raise exception on error
  - Procedure should reuse existing Client object

`Added`

- OSM.NetworkRequest.Synapse.pas: to use SSL, define `SynapseSSL` in project options.
- Updated Synapse to the last release version with original file structure. Added SSL libs from Synapse site (untested!)
- OSM.NetworkRequest.Synapse.pas: supports System proxy

0.9.3
=====

- Tile URL is now defined with OpenLayers-compatible templates with extended features

`Added`

- OpenTopoMap tile provider
- OSM.TilesProvider.*.pas: use new template-base system for retrieval of tile URL

0.9.2
=====

- Improvements for multi-provider apps

`Added`

- `TTilesProvider`, virtual constructor to allow creation via class types. `TTilesProvider.Name` virtual method to return provider's label for display and other purposes. 
- Global list of tiles providers. `TTilesProviderClass` definition, `TilesProviders` array, `RegisterTilesProvider` function
- Demo: support multiple providers

`Fixed`

- OSM.TileStorage.pas: `TTileStorage`, clear cache on file path change
- OSM.MapControl.pas: `TMapControl`, fixes to change tiles provider properly

0.9.1
=====

`Added`

- Google map tile provider

0.9.0
=====

`Added`

- Ability to use map tile provider other than OSM. Added HERE provider. Added property `Properties` to access provider-specific properties.

`[BREAKING]`

- OSM.NetworkRequest.pas: uses `TileProvider` object. `TNetworkRequestQueue.Create`, 3rd parameter is `TTilesProvider` and `GotTile` callback must be set via `OnGotTileBgThr` property
- OSM.MapControl.pas: uses `TileProvider` object. New `TMapControl.TilesProvider` property

0.8.0
=====

`[BREAKING]`

- * Rename network request units according to generic rules: `OSM.NetworkRequest.%implementation%`

`Added`

- `TMapControl`, ability to tune cache image and label margin. Add `TMapControl.LabelMargin` and `TMapControl.SetCacheImageProperties`
- `TMapControl.OnGetTile` callback that is somewhat simpler to use than `OnDrawTile`
- `TMapControl`, export map view to image. `TMapControl.SaveToBitmap` added

`Fixed`

- `TMapControl.SetZoom` now respects `MinZoom` value
- `TMapControl`, mapmarks won't be painted over labels

0.7.0
=====

`Added`

- OSM.SlippyMapUtils.pas: add `ToTileHeightGreater`, `ToTileHeightLesser`, `ToTileWidthGreater`, `ToTileWidthLesser`, `ToTileBoundary` functions
- Network requester allows to set current viewport of a map by `TNetworkRequestQueue.SetCurrentViewRect` method so that extraction of queued tiles first looks for those in this area. This removed time lag before current view area is fully downloaded and shown. `TNetworkRequestQueue.DumbQueueOrder` property set to `True` returns old behavior

`Changed`

- Network requester now by default cancels currently pending tiles when a tile with another zoom level is requested to make map viewable ASAP when a user zooms in/out quickly through multiple levels. `TNetworkRequestQueue.DumbQueueOrder` property set to `True` returns old behavior

0.6.0
=====

`Added`

- Introduced the concept of map layers. Mapmarks now are sorted by layer number so that the greater layer number, the later a mark is drawn. MapControl also has property VisibleLayers that allows control mapmarks visibility by layer


`Changed`

- TMapControl, doesn't call OnDrawMapMark if a mapmark is invisible or its layer is invisible

0.5.0
=====

`Added`

- Greatly improved abilities of network engines. Added ability to specify proxy, request headers, login etc
- Proper handling of request errors
- Demo has proxy configuration