{
  Generic (no real implementation) base class for tile image provider.
  Stores properties that could be specific to real providers.

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
  // inherit from it, assign properties and override methods. @br
  // Note to implementors: take any of the existing implementations as base.
  // Try to store all constants within the class declaration leaving no
  // magic values in implementation. This way all values won't be scattered
  // between methods and will be easy to modify.
  TTilesProvider = class
  protected
    function GetProperty(const Index: string): string; virtual;
    procedure SetProperty(const Index, Value: string); virtual;
  public
    // Minimal zoom level. Usually `0`
    MinZoomLevel: TMapZoomLevel;
    // Maximal zoom level
    MaxZoomLevel: TMapZoomLevel;
{}//~    TileFormat: TTileImage;
    // Tile copyright that will be painted in the corner of the map
    TilesCopyright: string;
    // [opt] API key for requesting tiles
    APIKey: string;

    constructor Create; virtual; abstract;

    // Function to return displayable provider name.
    // Name could be used for selection in UI, file paths etc.
    // There's no special limitations on the format of this string so when using it for
    // something other than simple display, the value must be validated/preprocessed.
    // The only recommendation is to keep the name short.
    class function Name: string; virtual; abstract;

    // Method to get URL of specified tile
    function GetTileURL(const Tile: TTile): string; virtual; abstract;

    // Generic storage for provider-specific properties. Raises exception in
    // base class, should be implemented in descendants
    property Properties[const Index: string]: string read GetProperty write SetProperty;
  end;

  // Dummy tile provider class, used as a stub in map control if no real provider
  // is assigned. For offline mode only, shouldn't be used in network request.
  TDummyTilesProvider = class(TTilesProvider)
  private
    const TPName = 'Dummy';
  const
    //~ global defaults
    // Default copyright text
    DefTilesCopyright = '(c) Tile provider (loaded from offline)';
  public
    constructor Create; override;
    class function Name: string; override;
    function GetTileURL(const Tile: TTile): string; override;
  end;

  TTilesProviderClass = class of TTilesProvider;

var
  // Global list of registered tiles providers. Use it if you want to support
  // multiple providers within the same app.
  TilesProviders: TArray<TTilesProviderClass>;

// Add class of tiles provider to global TilesProviders array. Handles multiple
// calls with the same class (by ignoring duplicates).
procedure RegisterTilesProvider(TilesProviderClass: TTilesProviderClass);

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
  TilesCopyright := DefTilesCopyright;
end;

class function TDummyTilesProvider.Name: string;
begin
  Result := TPName;
end;

function TDummyTilesProvider.GetTileURL(const Tile: TTile): string;
begin
  Result := '';
end;

procedure RegisterTilesProvider(TilesProviderClass: TTilesProviderClass);
var i: Integer;
begin
  // Check if this class was registered already
  for i := Low(TilesProviders) to High(TilesProviders) do
    if TilesProviders[i] = TilesProviderClass then
      Exit;
  SetLength(TilesProviders, Length(TilesProviders) + 1);
  TilesProviders[High(TilesProviders)] := TilesProviderClass;
end;

end.
