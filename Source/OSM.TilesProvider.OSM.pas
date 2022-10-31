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
  private
    const TPName = 'OpenStreetMap';
  const
    //~ global defaults
    // Default copyright text
    DefTilesCopyright = '(c) OpenStreetMap contributors';
    // Default pattern of tile URL
    DefTileURLPatt = 'http://tile.openstreetmap.org/{z}/{x}/{y}.png';
  public
    // Pattern of tile URL. For format see FormatTileURL
    TileURLPatt: string;

    constructor Create; override;
    class function Name: string; override;
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

class function TOSMTilesProvider.Name: string;
begin
  Result := TPName;
end;

function TOSMTilesProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := FormatTileURL(TileURLPatt, Tile, Self);
end;

initialization
  RegisterTilesProvider(TOSMTilesProvider);

end.
