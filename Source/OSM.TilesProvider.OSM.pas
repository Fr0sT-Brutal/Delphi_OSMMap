unit OSM.TilesProvider.OSM;

interface

uses
  SysUtils,
  OSM.SlippyMapUtils, OSM.TilesProvider;

type
  TOSMProvider = class(TTilesProvider)
  public
    // Pattern of tile URL. Placeholders are for: Zoom, X, Y
    TileURLPatt: string;

    constructor Create;
    function GetTileURL(const Tile: TTile): string; override;
  end;

//~ global defaults
const
  // Copyright text
  DefTilesCopyright = '(c) OpenStreetMap contributors';
  // Pattern of tile URL. Placeholders are for: Zoom, X, Y
  DefTileURLPatt = 'http://tile.openstreetmap.org/%d/%d/%d.png';

implementation

constructor TOSMProvider.Create;
begin
  MinZoomLevel := Low(TMapZoomLevel);
  MaxZoomLevel := 19;
//  TileFormat.Format := 'png';
//  TileFormat.Width := 256;
//  TileFormat.Height := 256;
  TilesCopyright := DefTilesCopyright;
  TileURLPatt := DefTileURLPatt;
end;

function TOSMProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := Format(TileURLPatt, [Tile.Zoom, Tile.ParameterX, Tile.ParameterY]);
end;

end.
