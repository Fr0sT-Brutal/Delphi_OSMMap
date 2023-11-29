{
  2GIS tile image provider.

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.TilesProvider.TwoGIS;

interface

uses
  SysUtils,
  OSM.SlippyMapUtils, OSM.TilesProvider;

type
  // 2GIS tile image provider
  T2GISTilesProvider = class(TTilesProvider)
  private
    const TPName = '2GIS maps';
  const
    //~ global defaults
    // Default copyright text
    DefTilesCopyright = '(c) 2GIS';
    // Default pattern of tile URL
    DefTileURLPatt = 'http://tile{0-4}.maps.2gis.com/tiles?x={x}&y={y}&z={z}&v=1&ts=online_sd_ar';
  public
    constructor Create; override;
    class function Name: string; override;
    function GetTileURL(const Tile: TTile): string; override;
  end;

implementation

constructor T2GISTilesProvider.Create;
begin
  FMinZoomLevel := 2;
  FMaxZoomLevel := 18;
  TilesCopyright := DefTilesCopyright;
  TileURLPatt := DefTileURLPatt;
end;

class function T2GISTilesProvider.Name: string;
begin
  Result := TPName;
end;

function T2GISTilesProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := FormatTileURL(TileURLPatt, Tile, Self);
end;

initialization
  RegisterTilesProvider(T2GISTilesProvider);

end.
