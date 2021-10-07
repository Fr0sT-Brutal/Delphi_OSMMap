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

- OSM.SlippyMapUtils.pas, add `ToTileHeightGreater`, `ToTileHeightLesser`, `ToTileWidthGreater`, `ToTileWidthLesser`, `ToTileBoundary` functions
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