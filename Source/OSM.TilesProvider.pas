unit OSM.TilesProvider;

interface

uses
  OSM.SlippyMapUtils;

type
  TTilesProvider = class
  public
    MinZoomLevel: TMapZoomLevel;
    MaxZoomLevel: TMapZoomLevel;
//    TileFormat: TTileImage;
    TilesCopyright: string;
    APIKey: string;
    function GetTileURL(const Tile: TTile): string; virtual; abstract;
  end;

implementation

end.
