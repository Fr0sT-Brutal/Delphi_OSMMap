{
  Generic (no real implementation) base class for tile image provider.
  Stores properties that could be specific to a real providers.

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
  @author(Martin (https://github.com/array81))
}
unit OSM.TilesProvider;

interface

uses
  SysUtils,
  OSM.SlippyMapUtils;

type
  // Abstract base class for tile image provider. Real implementations must
  // inherit from it, assign properties and override methods.
  TTilesProvider = class
  protected
    function GetProperty(const Index: string): string; virtual;
    procedure SetProperty(const Index, Value: string); virtual;
  public
    // Minimal zoom level. Usually `0`
    MinZoomLevel: TMapZoomLevel;
    // Maximal zoom level
    MaxZoomLevel: TMapZoomLevel;
{}//    TileFormat: TTileImage;
    // Tile copyright that will be painted in the corner of the map
    TilesCopyright: string;
    // [opt] API key for requesting tiles
    APIKey: string;

    // Method to get URL of specified tile
    function GetTileURL(const Tile: TTile): string; virtual; abstract;

    // Generic storage for provider-specific properties. Raises exception in
    // base class, should be implemented in descendants
    property Properties[const Index: string]: string read GetProperty write SetProperty;
  end;

  // Dummy tile provider class, used as a stub in map control if no real provider
  // is assigned. For offline mode only, shouldn't be used in network request.
  TDummyTilesProvider = class(TTilesProvider)
  public
    constructor Create;
    function GetTileURL(const Tile: TTile): string; override;
  end;

implementation

{ TTilesProvider }

function TTilesProvider.GetProperty(const Index: string): string;
begin
  raise Exception.Create('Getter for Properties not implemented');
end;

procedure TTilesProvider.SetProperty(const Index, Value: string);
begin
  raise Exception.Create('Setter for Properties not implemented');
end;

{ TDummyTilesProvider }

constructor TDummyTilesProvider.Create;
begin
  MinZoomLevel := Low(TMapZoomLevel);
  MaxZoomLevel := High(TMapZoomLevel);
  TilesCopyright := '(c) Tile provider (loaded from offline)';
end;

function TDummyTilesProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := '';
end;

end.
