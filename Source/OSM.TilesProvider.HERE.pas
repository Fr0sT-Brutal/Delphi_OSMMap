{
  HERE tile image provider.
  https://developer.here.com/documentation/map-tile/dev_guide/topics/introduction.html

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
  @author(Martin (https://github.com/array81))
}
unit OSM.TilesProvider.HERE;

interface

uses
  SysUtils,
  OSM.SlippyMapUtils, OSM.TilesProvider;

type
  // HERE tile image provider
  THERETilesProvider = class(TTilesProvider)
  private
    const TPName = 'HERE map';
  const
    //~ global defaults
    // Default copyright text
    DefTilesCopyright = '(c) HERE';
    // Default pattern of tile URL. Placeholders are for: Random subdomain (1..MaxSubdomainNum), Zoom, X, Y, ApiKEY
    DefTileURLPatt = 'https://%d.base.maps.ls.hereapi.com/maptile/2.1/maptile/newest/normal.day/%d/%d/%d/256/png8?apiKey=%s';
    // Maximal subdomain number
    MaxSubdomainNum = 4;
  public
    // Pattern of tile URL. Placeholders are for: Random subdomain (1..MaxSubdomainNum), Zoom, X, Y, ApiKEY
    TileURLPatt: string;

    constructor Create; override;
    class function Name: string; override;
    function GetTileURL(const Tile: TTile): string; override;
  end;

implementation

constructor THERETilesProvider.Create;
begin
  MinZoomLevel := Low(TMapZoomLevel);
  MaxZoomLevel := 20;
//  TileFormat.Format := 'png';
//  TileFormat.Width := 256;
//  TileFormat.Height := 256;
  TilesCopyright := DefTilesCopyright;
  TileURLPatt := DefTileURLPatt;
  RegisterTilesProvider(TTilesProviderClass(Self.ClassType));
end;

class function THERETilesProvider.Name: string;
begin
  Result := TPName;
end;

function THERETilesProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := Format(TileURLPatt, [Random(MaxSubdomainNum) + 1, Tile.Zoom, Tile.ParameterX, Tile.ParameterY, APIKey]);
end;

initialization
  RegisterTilesProvider(THERETilesProvider);

end.
