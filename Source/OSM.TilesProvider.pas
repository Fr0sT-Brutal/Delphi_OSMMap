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
  SysUtils, StrUtils, Types,
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
    // [opt] Tile copyright that will be painted in the corner of the map
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

// Format URL for a given tile using OpenLayers-compatible URL template.
function FormatTileURL(const Template: string; const Tile: TTile; Provider: TTilesProvider): string;

implementation

{~ TTilesProvider }

function TTilesProvider.GetProperty(const Index: string): string;
begin
  raise Exception.Create('Getter for Properties not implemented');
end;

procedure TTilesProvider.SetProperty(const Index, Value: string);
begin
  raise Exception.Create('Setter for Properties not implemented');
end;

{~ TDummyTilesProvider }

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

type
  // Callback for ReplaceTokens
  //   @param Token - [IN] found token {OUT] token replacement
  // @returns whether replacement should be done. If @false, token will be removed
  //   or left unchanged depending on EatUnmatched parameter
  TReplTokenCallback = reference to function(var Token: string): Boolean;

// Replaces all string occurrences between TokenStart and TokenEnd chars inside Patt string
// and replaces them with result of calling Callback function.
// EatUnmatched determines whether entries for which Callback returned False should be
// removed (EatUnmatched = False) or left unchanged
function ReplaceTokens(const Patt: string; TokenStart, TokenEnd: Char; EatUnmatched: Boolean;
                       Callback: TReplTokenCallback): string;
var
  Token: String;
  Curr, TxtBeg, PosBeg, PosEnd: Integer;
begin
  Curr := 1; TxtBeg := 1; Result := '';
  // While pattern has tokens
  while Curr <= Length(Patt) do
  begin
    // Extract token (string between TokenStart and TokenEnd)
    PosBeg := PosEx(TokenStart, Patt, Curr);
    if PosBeg = 0 then Break;
    PosEnd := PosEx(TokenEnd, Patt, PosBeg+1);
    if PosEnd = 0 then Break;
    Token := Copy(patt, PosBeg+1, PosEnd-PosBeg-1);
    // Call callback and check its result
    if Callback(Token) then
      Result := Result + Copy(Patt, TxtBeg, PosBeg-TxtBeg) + Token
    else
      if EatUnmatched // eat or skip
        then Result := Result + Copy(Patt, TxtBeg, PosBeg-TxtBeg)
        else begin Inc(Curr); Continue; end;
    // go on
    Curr := PosEnd+1;
    TxtBeg := PosEnd+1;
  end;
  // Add string tail
  Result := Result + Copy(Patt, TxtBeg, Length(Patt));
end;

// Accepts a string defining a set of values like "aa|dd|hh|rr" and randomly returns
// one of them. Values could be any.
function RandomFromSet(const SetStr: string): string;
var Values: TStringDynArray;
begin
  Values := SplitString(SetStr, '|');
  Result := Values[Random(Length(Values))];
end;

// Accepts string defining a range of values like "a-d" and randomly returns
// one of them. Values should be digits or chars. If they're not, only the
// first chars are considered.
function RandomFromRange(const RangeStr: string): string;
var
  Values: TStringDynArray;
  StartChar, EndChar: Char;
begin
  Values := SplitString(RangeStr, '-');
  StartChar := Values[0][1];
  EndChar := Values[1][1];
  Result := Char(Ord(StartChar) + Random(Ord(EndChar) - Ord(StartChar) + 1));
end;

// Format URL for a given tile using OpenLayers-compatible URL template.
// Template could contain following placeholders enclosed in {}'s:
//   - `{x}` - horizontal tile number
//   - `{y}` - vertical tile number
//   - `{z}` - zoom level
//   - `{?|?|...}` - set of any values used to determine random subdomain
//   - `{?-?}` - range of digits or chars used to determine random subdomain
//   - `{key}` - provider API key (@link(TTilesProvider.APIKey Provider.APIKey) property)
//   - `{?}` - where "?" is any string - provider property named "?"
//     (obtained via @link(TTilesProvider.Properties Provider.Properties))
function FormatTileURL(const Template: string; const Tile: TTile; Provider: TTilesProvider): string;
var VarTile: TTile;
begin
  VarTile := Tile; // can't capture const params >_<
  Result := ReplaceTokens(Template, '{', '}', False,
    function(var Token: string): Boolean
    begin
      if Token = 'x' then
        Token := IntToStr(VarTile.ParameterX)
      else
      if Token = 'y' then
        Token := IntToStr(VarTile.ParameterY)
      else
      if Token = 'z' then
        Token := IntToStr(VarTile.Zoom)
      else
      if Token = 'key' then
        Token := Provider.APIKey
      else
      if Pos('|', Token) <> 0 then
        Token := RandomFromSet(Token)
      else
      if Pos('-', Token) <> 0 then
        Token := RandomFromRange(Token)
      else
        Token := Provider.GetProperty(Token);
      Result := True;
    end);
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
