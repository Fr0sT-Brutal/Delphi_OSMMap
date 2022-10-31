{
  Google tile image provider.

  https://gis.stackexchange.com/questions/225098/using-google-maps-static-tiles-with-leaflet
  - should be an official description but I didn't find it.

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
  @author(Martin (https://github.com/array81))
}
unit OSM.TilesProvider.Google;

interface

uses
  SysUtils,
  OSM.SlippyMapUtils, OSM.TilesProvider;

type
  // Google tile image provider
  TGoogleTilesProvider = class(TTilesProvider)
  const
    //~ global defaults
    // Default copyright text
    DefTilesCopyright = '(c) Google';
    //~ TODO: "lyrs" parameter is the tile ID but none of other options work
    // Default pattern of tile URL
    DefTileURLPatt = 'http://mt{0-3}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}';
  private
    const TPName = 'Google maps';
  public
    // Pattern of tile URL. For format see FormatTileURL
    TileURLPatt: string;

    constructor Create; override;
    class function Name: string; override;
    function GetTileURL(const Tile: TTile): string; override;
  end;

implementation

constructor TGoogleTilesProvider.Create;
begin
  MinZoomLevel := Low(TMapZoomLevel);
  MaxZoomLevel := 19;
//  TileFormat.Format := 'png';
//  TileFormat.Width := 256;
//  TileFormat.Height := 256;
  TilesCopyright := DefTilesCopyright;
  TileURLPatt := DefTileURLPatt;
end;

class function TGoogleTilesProvider.Name: string;
begin
  Result := TPName;
end;

function TGoogleTilesProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := FormatTileURL(TileURLPatt, Tile, Self);
end;

initialization
  RegisterTilesProvider(TGoogleTilesProvider);

end.
