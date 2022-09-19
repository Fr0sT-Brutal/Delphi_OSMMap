{
  OpenStreetMap tile image provider.

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
  @author(Martin (https://github.com/array81))
}
unit OSM.TilesProvider.OSM;

interface

uses
  SysUtils,
  OSM.SlippyMapUtils, OSM.TilesProvider;

type
  // OpenStreetMap tile image provider
  TOSMTilesProvider = class(TTilesProvider)
  const
    //~ global defaults
    // Default copyright text
    DefTilesCopyright = '(c) OpenStreetMap contributors';
    // Default pattern of tile URL. Placeholders are for: Zoom, X, Y
    DefTileURLPatt = 'http://tile.openstreetmap.org/%d/%d/%d.png';
  public
    // Pattern of tile URL. Placeholders are for: Zoom, X, Y
    TileURLPatt: string;

    constructor Create;
    function GetTileURL(const Tile: TTile): string; override;
  end;

implementation

constructor TOSMTilesProvider.Create;
begin
  MinZoomLevel := Low(TMapZoomLevel);
  MaxZoomLevel := 19;
//  TileFormat.Format := 'png';
//  TileFormat.Width := 256;
//  TileFormat.Height := 256;
  TilesCopyright := DefTilesCopyright;
  TileURLPatt := DefTileURLPatt;
end;

function TOSMTilesProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := Format(TileURLPatt, [Tile.Zoom, Tile.ParameterX, Tile.ParameterY]);
end;

end.
