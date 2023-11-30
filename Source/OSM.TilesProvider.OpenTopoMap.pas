{
  OpenTopoMap tile image provider.

  https://wiki.openstreetmap.org/wiki/OpenTopoMap

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.TilesProvider.OpenTopoMap;

interface

uses
  SysUtils,
  OSM.SlippyMapUtils, OSM.TilesProvider;

type
  // OpenStreetMap tile image provider
  TOpenTopoMapTilesProvider = class(TTilesProvider)
  private
    const TPName = 'OpenTopoMap';
  public
    const
    //~ global defaults
    // Default copyright text
    DefTilesCopyright = '(c) OpenStreetMap contributors, SRTM';
    // Default pattern of tile URL
    DefTileURLPatt = 'http://{a|b|c}.tile.opentopomap.org/{z}/{x}/{y}.png';
  public
    constructor Create; override;
    class function Name: string; override;
    function GetTileURL(const Tile: TTile): string; override;
  end;

implementation

constructor TOpenTopoMapTilesProvider.Create;
begin
  FMinZoomLevel := Low(TMapZoomLevel);
  FMaxZoomLevel := 15;
//  TileFormat.Format := 'png';
//  TileFormat.Width := 256;
//  TileFormat.Height := 256;
  TilesCopyright := DefTilesCopyright;
  TileURLPatt := DefTileURLPatt;
end;

class function TOpenTopoMapTilesProvider.Name: string;
begin
  Result := TPName;
end;

function TOpenTopoMapTilesProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := FormatTileURL(TileURLPatt, Tile, Self);
end;

initialization
  RegisterTilesProvider(TOpenTopoMapTilesProvider);

end.
