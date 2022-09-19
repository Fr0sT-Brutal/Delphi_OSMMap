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
    {~ TODO: Note that difference in the "lyrs" parameter in the URL:
      Hybrid: s,h;
      Satellite: s;
      Streets: m;
      Terrain: p;
    }
    // Default pattern of tile URL. Placeholders are for: Random subdomain (0..MaxSubdomainNum), X, Y, Zoom
    DefTileURLPatt = 'http://mt%d.google.com/vt/lyrs=m&hl=en&x=%d&y=%d&z=%d';
    // Maximal subdomain number
    MaxSubdomainNum = 3;
  public
    // Pattern of tile URL. Placeholders are for: Random subdomain (0..MaxSubdomainNum), X, Y, Zoom
    TileURLPatt: string;

    constructor Create;
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

function TGoogleTilesProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := Format(TileURLPatt, [Random(MaxSubdomainNum), Tile.ParameterX, Tile.ParameterY, Tile.Zoom]);
end;

end.
