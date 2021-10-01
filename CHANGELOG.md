0.6.0
=====

- Introduced the concept of map layers. Mapmarks now are sorted by layer number so that the greater layer number, the later a mark is drawn. MapControl also has property VisibleLayers that allows control mapmarks visibility by layer
- TMapControl, doesn't call OnDrawMapMark if a mapmark is invisible or its layer is invisible

0.5.0
=====

- Greatly improved abilities of network engines. Added ability to specify proxy, request headers, login etc
- Proper handling of request errors
- Demo has proxy configuration