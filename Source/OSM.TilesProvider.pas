{
  Generic (no real implementation) base class for tile image provider.
  Stores properties that could be specific to real providers.

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
  @author(Martin (https://github.com/array81))
}
unit OSM.TilesProvider;

{$IFDEF FPC}  // For FPC enable Delphi mode and lambdas
  {$MODE Delphi}
  {$MODESWITCH FUNCTIONREFERENCES}
  {$MODESWITCH ANONYMOUSFUNCTIONS}
{$ENDIF}

interface

uses
  SysUtils, StrUtils, Types,
  OSM.SlippyMapUtils;

type
  // Specific feature of a tile provider
  TTileProviderFeature = (
    tpfRequiresAPIKey
  );

  TTileProviderFeatures = set of TTileProviderFeature;

  // Value and description of one option of a required property that is used
  // to generate tile URL
  TPropertyValue = record
    Value: string; // Fragment used in URL
    Descr: string; // Description for humans
  end;

  // Value and description of a required property that is used to generate tile URL.
  // Value is the fragment used in URL and Descr is description for humans
  TRequiredProperty = record
    Name: string;  // Property name that is used in URL pattern as `{propame}`
    Descr: string; // Description for humans
    Values: array of TPropertyValue; // All available values of the property
  end;

  TRequiredProperties = array of TRequiredProperty;

  // Abstract base class for tile image provider. Real implementations must
  // inherit from it, assign properties and override methods. @br
  // Note to implementors: take any of the existing implementations as base.
  // Try to store all constants within the class declaration leaving no
  // magic values in implementation. This way all values won't be scattered
  // between methods and will be easy to modify.
  TTilesProvider = class
  protected
    //~ Provider constants - must be assigned in c-tor and never change since then
    FFeatures: TTileProviderFeatures;
    FMinZoomLevel: TMapZoomLevel;
    FMaxZoomLevel: TMapZoomLevel;
    FRequiredProperties: TRequiredProperties;

    function GetProperty(const Index: string): string; virtual;
    procedure SetProperty(const Index, Value: string); virtual;
    procedure AddRequiredProperty(const Name, Descr: string; const Values: array of TPropertyValue);
  public
{}//~    TileFormat: TTileImage;
    //~ Provider variables - could change any time
    // [opt] Tile copyright that will be painted in the corner of the map.
    // Gets default value when instance is created.
    TilesCopyright: string;
    // Pattern of tile URL. For format see FormatTileURL.
    // Gets default value when instance is created, unlikely needed to modify
    TileURLPatt: string;
    // [opt] API key for requesting tiles
    APIKey: string;

    constructor Create; virtual; abstract;

    // Function to return displayable provider name.
    // Name could be used for selection in UI, file paths etc.
    // There's no special limitations on the format of this string so when using it for
    // something other than simple display, the value probably must be validated/preprocessed.
    // The only recommendation is to keep the name short.
    class function Name: string; virtual; abstract;

    // Function to return current provider's ID for storage.
    // It could depend on current values of properties (f.ex., streets/satellite).
    // There's no special limitations on the format of this string so when using it
    // for storage, the value probably must be validated/preprocessed.
    // The only recommendation is to keep the name short.
    // By default returns result of Name method.
    function StorageID: string; virtual;

    // Method to get URL of specified tile. Uses TileURLPatt
    function GetTileURL(const Tile: TTile): string; virtual; abstract;

    // Create clone of provider instance copying all data.
    function Clone: TTilesProvider; virtual;

    // Provider features / capabilities / requirements
    property Features: TTileProviderFeatures read FFeatures;
    // Minimal zoom level. Usually `0`
    property MinZoomLevel: TMapZoomLevel read FMinZoomLevel;
    // Maximal zoom level
    property MaxZoomLevel: TMapZoomLevel read FMaxZoomLevel;
    // Set of available required properties. Provided for end user to choose.
    // App is responsible for assigning chosen values to Properties.
    property RequiredProperties: TRequiredProperties read FRequiredProperties;

    // Generic storage for provider-specific properties. Raises exception in
    // base class, should be implemented in descendants
    property Properties[const Index: string]: string read GetProperty write SetProperty;
  end;

  // Tiles provider that implements storing of properties
  TTilesProviderWithProps = class(TTilesProvider)
  private
    type
      TNameVal = record
        Name, Value: string;
      end;
    var
      FProperties: TArray<TNameVal>;
  protected
    function GetProperty(const Index: string): string; override;
    procedure SetProperty(const Index, Value: string); override;
  end;

  // Dummy tile provider class, used as a stub in map control if no real provider
  // is assigned. For offline mode only, shouldn't be used in network request.
  TDummyTilesProvider = class(TTilesProvider)
  private
    const TPName = 'Dummy';
  public
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

function TTilesProvider.StorageID: string;
begin
  Result := Name;
end;

function TTilesProvider.Clone: TTilesProvider;
begin
  Result := TTilesProviderClass(Self.ClassType).Create;
  Result.TilesCopyright := Self.TilesCopyright;
  Result.TileURLPatt := Self.TileURLPatt;
  Result.APIKey := Self.APIKey;
end;

//~ These functions better be abstract but then all instances of descendants that
// are not overriding them will emit warning about creating abstract class.
function TTilesProvider.GetProperty(const Index: string): string;
begin
  raise Exception.Create('Getter for Properties not implemented');
end;

procedure TTilesProvider.SetProperty(const Index, Value: string);
begin
  raise Exception.Create('Setter for Properties not implemented');
end;

// Adds a required property to list and sets Properties[Name] to the first element in Values
// (assigns default value).
procedure TTilesProvider.AddRequiredProperty(const Name, Descr: string; const Values: array of TPropertyValue);
var
  ReqProp: TRequiredProperty;
  i: Integer;
begin
  ReqProp.Name := Name;
  ReqProp.Descr := Descr;
  SetLength(ReqProp.Values, Length(Values));
  for i := Low(Values) to High(Values) do
    ReqProp.Values[i] := Values[i];
  SetLength(FRequiredProperties, Length(FRequiredProperties) + 1);
  FRequiredProperties[High(FRequiredProperties)] := ReqProp;
  Properties[Name] := Values[0].Value;
end;

{ TTilesProviderWithProps }

function TTilesProviderWithProps.GetProperty(const Index: string): string;
var i: Integer;
begin
  for i := Low(FProperties) to High(FProperties) do
    if FProperties[i].Name = Index then
      Exit(FProperties[i].Value);
end;

procedure TTilesProviderWithProps.SetProperty(const Index, Value: string);
var i: Integer;
begin
  for i := Low(FProperties) to High(FProperties) do
    if FProperties[i].Name = Index then
    begin
      FProperties[i].Value := Value;
      Exit;
    end;
  SetLength(FProperties, Length(FProperties) + 1);
  FProperties[High(FProperties)].Name := Index;
  FProperties[High(FProperties)].Value := Value;
end;

{~ TDummyTilesProvider }

constructor TDummyTilesProvider.Create;
begin
  FMinZoomLevel := Low(TMapZoomLevel);
  FMaxZoomLevel := High(TMapZoomLevel);
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
//   - `{key}` - provider API key ([Provider.APIKey](#TTilesProvider.APIKey) property)
//   - `{?}` - where "?" is any string - provider property named "?"
//     (obtained via [Provider.Properties](#TTilesProvider.Properties))
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
