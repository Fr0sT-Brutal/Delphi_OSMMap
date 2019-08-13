{
  OSM map types & functions.
  Ref.: https://wiki.openstreetmap.org/wiki/Slippy_Map

    based on unit by Simon Kroik, 06.2018, kroiksm@gmx.de
    which is based on UNIT openmap.pas
    https://github.com/norayr/meridian23/blob/master/openmap/openmap.pas
    New BSD License
}
unit OSM.SlippyMapUtils;

interface

uses Types, SysUtils, Math;

type
  TMapZoomLevel = 0..19; // 19 = Maximum zoom for Mapnik layer

  TTile = record
    Zoom: TMapZoomLevel;
    ParameterX: Integer;
    ParameterY: Integer;
  end;
  PTile = ^TTile;

  // Intentionally not using TPointF and TRectF because they use other system of
  // coordinates (vertical coord increase from top to down, while lat changes from
  // +85 to -85)
  TGeoPoint = record
    Long: Double;
    Lat: Double;
    constructor Create(Long, Lat: Double);
  end;

  TGeoRect = record
    TopLeft: TGeoPoint;
    BottomRight: TGeoPoint;
    constructor Create(const TopLeft, BottomRight: TGeoPoint);
    function Contains(const GeoPoint: TGeoPoint): Boolean;
  end;

const
  TILE_IMAGE_WIDTH = 256;
  TILE_IMAGE_HEIGHT = 256;
  // https://wiki.openstreetmap.org/wiki/Zoom_levels
  TileMetersPerPixelOnEquator: array [TMapZoomLevel] of Double =
  (
    156412,
    78206,
    39103,
    19551,
    9776,
    4888,
    2444,
    1222,
    610.984,
    305.492,
    152.746,
    76.373,
    38.187,
    19.093,
    9.547,
    4.773,
    2.387,
    1.193,
    0.596,
    0.298
  );

var // configurable
  TilesCopyright: string = '(c) OpenStreetMap contributors';
  MapURLPrefix: string = 'http://tile.openstreetmap.org/';
  MapURLPostfix: string = '';

function TileCount(Zoom: TMapZoomLevel): Integer; inline;
function TileValid(const Tile: TTile): Boolean; inline;
function TileToStr(const Tile: TTile): string;
function TilesEqual(const Tile1, Tile2: TTile): Boolean; inline;

function MapWidth(Zoom: TMapZoomLevel): Integer; inline;
function MapHeight(Zoom: TMapZoomLevel): Integer; inline;
function InMap(Zoom: TMapZoomLevel; const Pt: TPoint): Boolean;
function EnsureInMap(Zoom: TMapZoomLevel; const Pt: TPoint): TPoint;
function LongitudeToMapCoord(Longitude: Double; Zoom: TMapZoomLevel): Integer;
function LatitudeToMapCoord(Latitude: Double; Zoom: TMapZoomLevel): Integer;
function MapCoordToLongitude(X: Integer; Zoom: TMapZoomLevel): Double;
function MapCoordToLatitude(Y: Integer; Zoom: TMapZoomLevel): Double;
function MapToGeoCoords(const MapPt: TPoint; Zoom: TMapZoomLevel): TGeoPoint;
function GeoCoordsToMap(const GeoCoords: TGeoPoint; Zoom: TMapZoomLevel): TPoint;

function CalcLinDistanceInMeter(const Coord1, Coord2: TGeoPoint): Double;
procedure GetScaleBarParams(Zoom: TMapZoomLevel;
  var ScalebarWidthInPixel: Integer; var ScalebarWidthInMeter: Integer;
  var Text: string);

function TileToSlippyMapFileSubURL(const Tile: TTile): string;
function TileToSlippyMapFileSubPath(const Tile: TTile): string;
function TileToFullSlippyMapFileURL(const Tile: TTile): string;

implementation

// Tile utils

// Tile count on <Zoom> level is 2^Zoom
function TileCount(Zoom: TMapZoomLevel): Integer;
begin
  Result := 1 shl Zoom;
end;

// Check tile fields for validity
function TileValid(const Tile: TTile): Boolean;
begin
  Result :=
    (Tile.Zoom in [Low(TMapZoomLevel)..High(TMapZoomLevel)]) and
    (Tile.ParameterX >= 0) and (Tile.ParameterX < TileCount(Tile.Zoom)) and
    (Tile.ParameterY >= 0) and (Tile.ParameterY < TileCount(Tile.Zoom));
end;

// Just a standartized string representation
function TileToStr(const Tile: TTile): string;
begin
  Result := Format('%d * [%d : %d]', [Tile.Zoom, Tile.ParameterX, Tile.ParameterY]);
end;

// Compare tiles
function TilesEqual(const Tile1, Tile2: TTile): Boolean;
begin
  Result :=
    (Tile1.Zoom = Tile2.Zoom) and
    (Tile1.ParameterX = Tile2.ParameterX) and
    (Tile1.ParameterY = Tile2.ParameterY);
end;

// Width of map of given zoom level in pixels
function MapWidth(Zoom: TMapZoomLevel): Integer;
begin
  Result := TileCount(Zoom)*TILE_IMAGE_WIDTH;
end;

// Height of map of given zoom level in pixels
function MapHeight(Zoom: TMapZoomLevel): Integer;
begin
  Result := TileCount(Zoom)*TILE_IMAGE_HEIGHT;
end;

// Check if point Pt is inside a map of given zoom level
function InMap(Zoom: TMapZoomLevel; const Pt: TPoint): Boolean;
begin
  Result := Rect(0, 0, MapWidth(Zoom), MapHeight(Zoom)).Contains(Pt);
end;

// Ensure point Pt is inside a map of given zoom level, move it if necessary
function EnsureInMap(Zoom: TMapZoomLevel; const Pt: TPoint): TPoint;
begin
  Result := Point(
    Min(Pt.X, MapWidth(Zoom)),
    Min(Pt.Y, MapHeight(Zoom))
  );
end;

// Coord checking

procedure CheckValidLong(Longitude: Double); inline;
begin
  Assert(InRange(Longitude, -180, 180));
end;

procedure CheckValidLat(Latitude: Double); inline;
begin
  Assert(InRange(Latitude, -85.1, 85.1));
end;

procedure CheckValidMapX(Zoom: TMapZoomLevel; X: Integer); inline;
begin
  Assert(InRange(X, 0, MapWidth(Zoom)));
end;

procedure CheckValidMapY(Zoom: TMapZoomLevel; Y: Integer); inline;
begin
  Assert(InRange(Y, 0, MapHeight(Zoom)));
end;

{ TGeoPoint }

constructor TGeoPoint.Create(Long, Lat: Double);
begin
  CheckValidLong(Long);
  CheckValidLat(Lat);
  Self.Long := Long;
  Self.Lat := Lat;
end;

{ TGeoRect }

constructor TGeoRect.Create(const TopLeft, BottomRight: TGeoPoint);
begin
  Self.TopLeft := TopLeft;
  Self.BottomRight := BottomRight;
end;

function TGeoRect.Contains(const GeoPoint: TGeoPoint): Boolean;
begin
  Result :=
    InRange(GeoPoint.Long, TopLeft.Long, BottomRight.Long) and
    InRange(GeoPoint.Lat, BottomRight.Lat, TopLeft.Lat); // !
end;

// Degrees to pixels

function LongitudeToMapCoord(Longitude: Double; Zoom: TMapZoomLevel): Integer;
begin
  CheckValidLong(Longitude);

  Result := Floor((Longitude + 180.0) / 360.0 * MapWidth(Zoom));

  CheckValidMapX(Zoom, Result);
end;

function LatitudeToMapCoord(Latitude: Double; Zoom: TMapZoomLevel): Integer;
var
  SavePi: Extended;
  LatInRad: Extended;
begin
  CheckValidLat(Latitude);

  SavePi := Pi;
  LatInRad := Latitude * SavePi / 180.0;
  Result := Floor((1.0 - ln(Tan(LatInRad) + 1.0 / Cos(LatInRad)) / SavePi) / 2.0 * MapHeight(Zoom));

  CheckValidMapY(Zoom, Result);
end;

function GeoCoordsToMap(const GeoCoords: TGeoPoint; Zoom: TMapZoomLevel): TPoint;
begin
  Result := Point(
    LongitudeToMapCoord(GeoCoords.Long, Zoom),
    LatitudeToMapCoord(GeoCoords.Lat, Zoom)
  );
end;

// Pixels to degrees

function MapCoordToLongitude(X: Integer; Zoom: TMapZoomLevel): Double;
begin
  CheckValidMapX(Zoom, X);

  Result := X / MapWidth(Zoom) * 360.0 - 180.0;
end;

function MapCoordToLatitude(Y: Integer; Zoom: TMapZoomLevel): Double;
var
  n: Extended;
  SavePi: Extended;
begin
  CheckValidMapY(Zoom, Y);

  SavePi := Pi;
  n := SavePi - 2.0 * SavePi * Y / MapHeight(Zoom);

  Result := 180.0 / SavePi * ArcTan(0.5 * (Exp(n) - Exp(-n)));
end;

function MapToGeoCoords(const MapPt: TPoint; Zoom: TMapZoomLevel): TGeoPoint;
begin
  Result := TGeoPoint.Create(
    MapCoordToLongitude(MapPt.X, Zoom),
    MapCoordToLatitude(MapPt.Y, Zoom)
  );
end;

// Other

function CalcLinDistanceInMeter(const Coord1, Coord2: TGeoPoint): Double;
var
  Phimean: Double;
  dLambda: Double;
  dPhi: Double;
  Alpha: Double;
  Rho: Double;
  Nu: Double;
  R: Double;
  z: Double;
  Temp: Double;
const
  D2R: Double = 0.017453;
  R2D: Double = 57.295781;
  a: Double = 6378137.0;
  b: Double = 6356752.314245;
  e2: Double = 0.006739496742337;
  f: Double = 0.003352810664747;
begin
  dLambda := (Coord1.Long - Coord2.Long) * D2R;
  dPhi := (Coord1.Lat - Coord2.Lat) * D2R;
  Phimean := ((Coord1.Lat + Coord2.Lat) / 2.0) * D2R;

  Temp := 1 - e2 * Sqr(Sin(Phimean));
  Rho := (a * (1 - e2)) / Power(Temp, 1.5);
  Nu := a / (Sqrt(1 - e2 * (Sin(Phimean) * Sin(Phimean))));

  z := Sqrt(Sqr(Sin(dPhi / 2.0)) + Cos(Coord2.Lat * D2R) *
    Cos(Coord1.Lat * D2R) * Sqr(Sin(dLambda / 2.0)));

  z := 2 * ArcSin(z);

  Alpha := Cos(Coord2.Lat * D2R) * Sin(dLambda) * 1 / Sin(z);
  Alpha := ArcSin(Alpha);

  R := (Rho * Nu) / (Rho * Sqr(Sin(Alpha)) + (Nu * Sqr(Cos(Alpha))));

  Result := (z * R);
end;

procedure GetScaleBarParams(Zoom: TMapZoomLevel; var ScalebarWidthInPixel, ScalebarWidthInMeter: Integer; var Text: string);
const
  ScalebarWidthInKm: array [TMapZoomLevel] of Double =
  (
    10000,
    5000,
    3000,
    1000,
    500,
    300,
    200,
    100,
    50,
    30,
    10,
    5,
    3,
    1,
    0.500,
    0.300,
    0.200,
    0.100,
    0.050,
    0.020
  );
var
  dblScalebarWidthInMeter: Double;
begin
  dblScalebarWidthInMeter := ScalebarWidthInKm[Zoom] * 1000;
  ScalebarWidthInPixel := Round(dblScalebarWidthInMeter / TileMetersPerPixelOnEquator[Zoom]);
  ScalebarWidthInMeter := Round(dblScalebarWidthInMeter);

  if ScalebarWidthInMeter < 1000 then
    Text := IntToStr(ScalebarWidthInMeter) + ' m'
  else
    Text := IntToStr(ScalebarWidthInMeter div 1000) + ' km'
end;

// Tile path

function TileToSlippyMapFileSubURL(const Tile: TTile): string;
begin
  Result :=
    IntToStr(Tile.Zoom) + '/' +
    IntToStr(Tile.ParameterX) + '/' +
    IntToStr(Tile.ParameterY) + '.png';
end;

function TileToSlippyMapFileSubPath(const Tile: TTile): string;
begin
  Result :=
    IntToStr(Tile.Zoom) + PathDelim +
    IntToStr(Tile.ParameterX) + PathDelim +
    IntToStr(Tile.ParameterY) + '.png';
end;

function TileToFullSlippyMapFileURL(const Tile: TTile): string;
begin
  Result := MapURLPrefix + TileToSlippyMapFileSubURL(Tile) + MapURLPostfix;
end;

end.
