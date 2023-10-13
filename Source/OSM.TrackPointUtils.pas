{
  OSM map types & functions related to track points.

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.TrackPointUtils;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  Types;

type
  // Line segment data determined by 2 end points and coeffs of line equation A*x+B*y+C=0
  TLine = record
    Pt1, Pt2: TPoint;
    A, B, C: Int64;
  end;

  // Side of rectangle
  TRectSide = (sideLeft, sideTop, sideRight, sideBottom);

  // Lines of rectangle
  TRectLines = array[TRectSide] of TLine;

// From pixel coords (Y axis 0..Max from top to bottom) to cartesian (Y axis 0..-Max from top to bottom)
function ToCartesian(const Pt: TPoint): TPoint;
// From cartesian coords to pixel
function ToPixel(const Pt: TPoint): TPoint;
// Create line segment record from 2 points in cartesian and calc line equation coeffs
function CalcLine(const Pt1, Pt2: TPoint): TLine;
// Create line segment array for rect in cartesian
function CalcRectLines(const Rect: TRect): TRectLines;
// Determine segment of line segment that is contained inside given rect, return True if found.
// Rect, Line, resulting points are all in cartesian
function FindLineSegmentInRect(const Rect: TRect; const RectLines: TRectLines; const Line: TLine; out IntPt1, IntPt2: TPoint): Boolean;

implementation

function ToCartesian(const Pt: TPoint): TPoint;
begin
  Result := Point(Pt.X, -Pt.Y);
end;

function ToPixel(const Pt: TPoint): TPoint;
begin
  Result := Point(Pt.X, -Pt.Y);
end;

function CalcLine(const Pt1, Pt2: TPoint): TLine;
begin
  Result.Pt1 := Pt1;
  Result.Pt2 := Pt2;
  // Line equation is (x - x1)/(x2 - x1) = (y - y1)/(y2 - y1), transforming to A-B-C form
  // get (y2 - y1)*x + (x1 - x2)*y + (x2*y1 - x1*y2) = 0
  // y2 - y1
  Result.A := Pt2.Y - Pt1.Y;
  // x1 - x2
  Result.B := Pt1.X - Pt2.X;
  // x2*y1 - x1*y2
  Result.C := Pt2.X*Pt1.Y - Pt1.X*Pt2.Y;
  // Normalize to get A > 0
  if Result.A < 0 then
  begin
    Result.A := -Result.A;
    Result.B := -Result.B;
    Result.C := -Result.C;
  end;
  Assert(Result.A*Pt1.X + Result.B*Pt1.Y + Result.C = 0);
  Assert(Result.A*Pt2.X + Result.B*Pt2.Y + Result.C = 0);
end;

function CalcRectLines(const Rect: TRect): TRectLines;
begin
  Result[sideLeft]   := CalcLine(Rect.TopLeft, Point(Rect.Left, Rect.Bottom));
  Result[sideTop]    := CalcLine(Rect.TopLeft, Point(Rect.Right, Rect.Top));
  Result[sideRight]  := CalcLine(Rect.BottomRight, Point(Rect.Right, Rect.Top));
  Result[sideBottom] := CalcLine(Rect.BottomRight, Point(Rect.Left, Rect.Bottom));
end;

// Ensure Bound1 <= Bound2
procedure NormalizeBounds(var Bound1, Bound2: Integer); inline;
var tmp: Integer;
begin
  if Bound1 <= Bound2 then Exit;
  tmp := Bound2;
  Bound2 := Bound1;
  Bound1 := tmp;
end;

// Check if value is in range where caller doesn't care that Bound1 should be >= Bound2
function ValInRange(Val: Single; Bound1, Bound2: Integer): Boolean; overload;
begin
  NormalizeBounds(Bound1, Bound2);
  Result := (Val >= Bound1) and (Val <= Bound2);
end;

// Check if value is in range where caller doesn't care that Bound1 should be >= Bound2
function ValInRange(Val, Bound1, Bound2: Integer): Boolean; overload;
begin
  NormalizeBounds(Bound1, Bound2);
  Result := (Val >= Bound1) and (Val <= Bound2);
end;

// Check if point belongs to the range of the line segment. Assuming that point
// is on the line containing that segment.
function PtInLine(const Pt: TPointF; const Line: TLine): Boolean;
begin
  Result :=
    ValInRange(Pt.X, Line.Pt1.X, Line.Pt2.X) and
    ValInRange(Pt.Y, Line.Pt1.Y, Line.Pt2.Y);
end;

// Check if point belongs to the rectangle (both in Cartesian coords so rect.Includes won't work).
function PtInRect(const Pt: TPoint; const Rect: TRect): Boolean;
begin
  Result :=
    ValInRange(Pt.X, Rect.Left, Rect.Right) and
    ValInRange(Pt.Y, Rect.Top, Rect.Bottom);
end;

// Find intersection point of two line segments, return True if found
function FindLinesIntersect(const Line1, Line2: TLine; out IntPt: TPoint): Boolean;
var
  Divisor: Double;
  Pt: TPointF;
begin
  // 1. Find point of intersection of two endless lines
  // D = A1*B2 - A2*B1
  // X = (B1*C2 - B2*C1)/D
  // Y = (A2*C1 - A1*C2)/D
  Divisor := (Line1.A + 0.0)*Line2.B - (Line2.A + 0.0)*Line1.B;
  if Divisor = 0 then Exit(False); // parallel
  Pt.X := ((Line1.B + 0.0)*Line2.C - (Line2.B + 0.0)*Line1.C) / Divisor; // this could be a very big number outside int range
  Pt.Y := ((Line2.A + 0.0)*Line1.C - (Line1.A + 0.0)*Line2.C) / Divisor;
  // 2. Check whether this point belongs to both segments
  Result := PtInLine(Pt, Line1) and PtInLine(Pt, Line2);
  if not Result then Exit;
  // 3. Assign rounded coords
  IntPt.X := Round(Pt.X);
  IntPt.Y := Round(Pt.Y);
end;

function FindLineSegmentInRect(const Rect: TRect; const RectLines: TRectLines; const Line: TLine; out IntPt1, IntPt2: TPoint): Boolean;
var
  side: TRectSide;
  Pt1Found, Pt2Found: Boolean;
begin
  // Optimization: exit if line is completely outside of rect: upper than top,
  // lower than bottom, lefter than left, rigther than right
  // Cartesian coords where top Y > bottom Y
  if (Line.Pt1.Y > Rect.Top)    and (Line.Pt2.Y > Rect.Top)    then Exit(False);
  if (Line.Pt1.Y < Rect.Bottom) and (Line.Pt2.Y < Rect.Bottom) then Exit(False);
  if (Line.Pt1.X < Rect.Left)   and (Line.Pt2.X < Rect.Left)   then Exit(False);
  if (Line.Pt1.X > Rect.Right)  and (Line.Pt2.X > Rect.Right)  then Exit(False);

  // if one of line ends is within the rect
  Pt1Found := PtInRect(Line.Pt1, Rect);
  if Pt1Found then
    IntPt1 := Line.Pt1;
  Pt2Found := PtInRect(Line.Pt2, Rect);
  if Pt2Found then
    IntPt2 := Line.Pt2;

  for side := Low(RectLines) to High(RectLines) do
  begin
    if not Pt1Found then
    begin
      Pt1Found := FindLinesIntersect(RectLines[side], Line, IntPt1);
      if Pt1Found then
        Continue; // Don't check the same line twice!
    end;
    if not Pt2Found then
      Pt2Found := FindLinesIntersect(RectLines[side], Line, IntPt2);
  end;

  Result := Pt1Found and Pt2Found;
end;

end.
