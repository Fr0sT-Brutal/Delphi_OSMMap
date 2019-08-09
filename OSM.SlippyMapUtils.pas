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

function LongitudeToMapCoord(Longitude: Double; Zoom: TMapZoomLevel): Integer;
function LatitudeToMapCoord(Latitude: Double; Zoom: TMapZoomLevel): Integer;
function MapCoordToLongitude(X: Integer; Zoom: TMapZoomLevel): Double;
function MapCoordToLatitude(Y: Integer; Zoom: TMapZoomLevel): Double;
function MapToGeoCoords(const MapPt: TPoint; Zoom: TMapZoomLevel): TPointF;
function GeoCoordsToMap(const GeoCoords: TPointF; Zoom: TMapZoomLevel): TPoint;

function CalcLinDistanceInMeter(const Coord1, Coord2: TPointF): Double;
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

function TilesEqual(const Tile1, Tile2: TTile): Boolean;
begin
  Result :=
    (Tile1.Zoom = Tile2.Zoom) and
    (Tile1.ParameterX = Tile2.ParameterX) and
    (Tile1.ParameterY = Tile2.ParameterY);
end;

// Degrees to pixels

function LongitudeToMapCoord(Longitude: Double; Zoom: TMapZoomLevel): Integer;
begin
  Result := Floor((Longitude + 180.0) / 360.0 * TileCount(Zoom)*TILE_IMAGE_WIDTH);
end;

function LatitudeToMapCoord(Latitude: Double; Zoom: TMapZoomLevel): Integer;
var
  SavePi: Extended;
  LatInRad: Extended;
begin
  SavePi := Pi;
  LatInRad := Latitude * SavePi / 180.0;
  Result := Floor((1.0 - ln(Tan(LatInRad) + 1.0 / Cos(LatInRad)) / SavePi) / 2.0 * TileCount(Zoom)*TILE_IMAGE_HEIGHT);
end;

function GeoCoordsToMap(const GeoCoords: TPointF; Zoom: TMapZoomLevel): TPoint;
begin
  Result := Point(
    LongitudeToMapCoord(GeoCoords.X, Zoom),
    LatitudeToMapCoord(GeoCoords.Y, Zoom)
  );
end;

// Pixels to degrees

function MapCoordToLongitude(X: Integer; Zoom: TMapZoomLevel): Double;
begin
  Result := X / (TileCount(Zoom)*TILE_IMAGE_WIDTH) * 360.0 - 180.0;
end;

function MapCoordToLatitude(Y: Integer; Zoom: TMapZoomLevel): Double;
var
  n: Extended;
  SavePi: Extended;
begin
  SavePi := Pi;
  n := SavePi - 2.0 * SavePi * Y / (TileCount(Zoom)*TILE_IMAGE_HEIGHT);

  Result := 180.0 / SavePi * ArcTan(0.5 * (Exp(n) - Exp(-n)));
end;

function MapToGeoCoords(const MapPt: TPoint; Zoom: TMapZoomLevel): TPointF;
begin
  Result := PointF(
    MapCoordToLongitude(MapPt.X, Zoom),
    MapCoordToLatitude(MapPt.Y, Zoom)
  );
end;

// Other

function CalcLinDistanceInMeter(const Coord1, Coord2: TPointF): Double;
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
  dLambda := (Coord1.X - Coord2.X) * D2R;
  dPhi := (Coord1.Y - Coord2.Y) * D2R;
  Phimean := ((Coord1.Y + Coord2.Y) / 2.0) * D2R;

  Temp := 1 - e2 * Sqr(Sin(Phimean));
  Rho := (a * (1 - e2)) / Power(Temp, 1.5);
  Nu := a / (Sqrt(1 - e2 * (Sin(Phimean) * Sin(Phimean))));

  z := Sqrt(Sqr(Sin(dPhi / 2.0)) + Cos(Coord2.Y * D2R) *
    Cos(Coord1.Y * D2R) * Sqr(Sin(dLambda / 2.0)));

  z := 2 * ArcSin(z);

  Alpha := Cos(Coord2.Y * D2R) * Sin(dLambda) * 1 / Sin(z);
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
