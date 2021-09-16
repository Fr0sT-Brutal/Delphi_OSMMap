{
  Visual control displaying a map.
  Data for the map (tile images) must be supplied via callbacks.
  @seealso OSM.TileStorage

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.MapControl;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  LCLIntf, LCLType,
  {$ENDIF}
  {$IFDEF DCC} // Currently VCL only => Windows only
  Windows,
  {$ENDIF}
  Messages, SysUtils, Classes, Graphics, Controls, ExtCtrls, Forms,
  Math, Types, Generics.Collections,
  OSM.SlippyMapUtils;

const
  // Default W and H of cache image in number of tiles.
  // Memory occupation of an image:
  //   (4 bytes per pixel) * `TilesH` * `TilesV` * (65536 pixels in single tile) @br
  // For value 8 it counts 16.7 Mb
  CacheImageDefTilesH = 8;
  CacheImageDefTilesV = 8;
  // Default W and H of cache image in pixels
  CacheImageDefWidth = CacheImageDefTilesH*TILE_IMAGE_WIDTH;
  CacheImageDefHeight = CacheImageDefTilesV*TILE_IMAGE_HEIGHT;
  // Margin that is added to cache image to hold view area, in number of tiles
  CacheMarginSize = 2;
  // Size of margin for labels on map, in pixels
  LabelMargin = 2;

type
  // Shape of mapmark glyph
  TMapMarkGlyphShape = (gshCircle, gshSquare, gshTriangle);

  // Visual properties of mapmark's glyph
  TMapMarkGlyphStyle = record
    Shape: TMapMarkGlyphShape;
    Size: Cardinal;
    BorderColor: TColor;
    BgColor: TColor;
  end;
  PMapMarkGlyphStyle = ^TMapMarkGlyphStyle;

  // Visual properties of mapmark's caption
  TMapMarkCaptionStyle = record
    Color: TColor;
    BgColor: TColor;
    DX, DY: Integer;
    Transparent: Boolean;
    {}//TODO: text position, alignment
  end;
  PMapMarkCaptionStyle = ^TMapMarkCaptionStyle;

  // Flags to indicate which properties must be taken from MapMark object when drawing.
  // By default props will use owner's values
  TMapMarkCustomProp = (propGlyphStyle, propCaptionStyle, propFont);
  TMapMarkCustomProps = set of TMapMarkCustomProp;

  // Class representing a single mapmark.
  // It is recommended to be created by TMapMarkList.NewItem
  TMapMark = class
  public
    //~ Mapmark data
    Coord: TGeoPoint;
    Caption: string;
    Visible: Boolean;
    Data: Pointer;
    //~ Visual style
    CustomProps: TMapMarkCustomProps;
    GlyphStyle: TMapMarkGlyphStyle;
    CaptionStyle: TMapMarkCaptionStyle;
    CaptionFont: TFont;
    Layer: Word;

    destructor Destroy; override;
  end;

  TMapControl = class;

  // Notification of an action over a mapmark in a list
  TOnItemNotify = procedure (Sender: TObject; Item: TMapMark; Action: TListNotification) of object;

  // List of mapmarks
  TMapMarkList = class
  strict private
    FMap: TMapControl;
    FList: TList;
    FUpdateCount: Integer;

    FOnItemNotify: TOnItemNotify;
  public
    constructor Create(Map: TMapControl);
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;
    function Get(Index: Integer): TMapMark;
    // Find the next map mark that is near specified coordinates.
    //   @param GeoCoords - coordinates to search
    //   @param ConsiderMapMarkSize - widen an area to search by mapmark size
    //   @param(PrevIndex - index of previous found mapmark in the list.
    //     `-1` (default) will start from the 1st element)
    //   @returns index of mapmark in the list, `-1` if not found.
    //
    // Samples:
    //   1) Check if there's any map marks at this point:
    //     ```pascal
    //     if Find(Point) <> -1 then ...
    //     ```
    //   2) Select all map marks at this point
    //     ```pascal
    //     idx := -1;
    //     repeat
    //       idx := MapMarks.Find(Point, idx);
    //       if idx = -1 then Break;
    //       ... do something with MapMarks[idx] ...
    //     until False;
    //     ```
    function Find(const GeoCoords: TGeoPoint; ConsiderMapMarkSize: Boolean = True; StartIndex: Integer = -1): Integer; overload;
    // The same as above but searches within specified rectangle
    function Find(const GeoRect: TGeoRect; ConsiderMapMarkSize: Boolean = True; StartIndex: Integer = -1): Integer; overload;
    // Create TMapMark object and initially assign values from owner map's fields
    function NewItem: TMapMark;
    // Simple method to add a mapmark by coords and caption
    function Add(const GeoCoords: TGeoPoint; const Caption: string; Layer: Word = 0): TMapMark; overload;
    // Add a mapmark with fully customizable properties. `MapMark` should be init-ed by NewItem
    function Add(MapMark: TMapMark): TMapMark; overload;
    procedure Delete(MapMark: TMapMark);
    function Count: Integer;
    procedure Clear;
    // Assigning a handler for this event allows implementing custom init, disposal
    // of allocated memory etc.
    property OnItemNotify: TOnItemNotify read FOnItemNotify write FOnItemNotify;
  end;

  // Options of map control
  TMapOption = (moDontDrawCopyright, moDontDrawScale);
  TMapOptions = set of TMapOption;

  // Mode of handling of plain left mouse button press
  TMapMouseMode = (mmDrag, mmSelect);

  // Callback to draw an image of a single tile having number (`TileHorzNum`;`TileVertNum`)
  // at point `TopLeft` on canvas `Canvas`.
  // Callback must set `Handled` to @true, otherwise default actions will be done.
  // This type is common for both TMapControl.OnDrawTile and TMapControl.OnDrawTileLoading callbacks.
  //
  // _Note for TMapControl.OnDrawTile:_@br
  // If `Handled` is not set to @true, TMapControl.DrawTileLoading method is called for this tile.
  // Usually you have to assign this callback only.
  //
  // _Note for TMapControl.OnDrawTileLoading:_@br
  // The handler is called only for empty tiles allowing a user to draw his own label
  TOnDrawTile = procedure (Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal;
    const TopLeft: TPoint; Canvas: TCanvas; var Handled: Boolean) of object;

  // Callback to custom draw a mapmark. It is called before default drawing.
  // If `Handled` is not set to @true, default drawing will be done.
  // User could draw a mapmark fully or just change some props and let default
  // drawing do its job
  TOnDrawMapMark = procedure (Sender: TMapControl; Canvas: TCanvas; const Point: TPoint;
    MapMark: TMapMark; var Handled: Boolean) of object;

  // Callback to react on selection by mouse
  TOnSelectionBox = procedure (Sender: TMapControl; const GeoRect: TGeoRect) of object;

  // Control displaying a map or its visible part.
  TMapControl = class(TScrollBox)
  strict private
    FMapSize: TSize;         // current map dims in pixels
    FCacheImage: TBitmap;    // drawn tiles (it could be equal to or larger than view area!)
    FCopyright,              // lazily created cache images for
    FScaleLine: TBitmap;     //    scale line and copyright
    FZoom: Integer;          // current zoom; integer for simpler operations
    FCacheImageRect: TRect;  // position of cache image on map in map coords
    FMapOptions: TMapOptions;
    FDragPos: TPoint;
    FMaxZoom, FMinZoom: TMapZoomLevel; // zoom constraints
    FMapMarkList: TMapMarkList;
    FSelectionBox: TShape;   // much simpler than drawing on canvas, tracking bounds etc.
    FSelectionBoxBindPoint: TPoint;  // point at which selection starts
    FMouseMode: TMapMouseMode;

    FOnDrawTile: TOnDrawTile;
    FOnDrawTileLoading: TOnDrawTile;
    FOnZoomChanged: TNotifyEvent;
    FOnDrawMapMark: TOnDrawMapMark;
    FOnSelectionBox: TOnSelectionBox;
  strict protected
    //~ overrides
    procedure PaintWindow(DC: HDC); override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DragOver(Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure WMHScroll(var Message: TWMHScroll); message WM_HSCROLL;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    //~ main methods
    function ViewInCache: Boolean; inline;
    procedure UpdateCache;
    procedure MoveCache;
    function SetCacheDimensions: Boolean;
    procedure DrawTileLoading(TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas);
    procedure DrawTile(TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas);
    procedure DrawMapMark(Canvas: TCanvas; MapMarksLayers: TDictionary<Word, TBitmap>; MapMark: TMapMark);
    //~ getters/setters
    procedure SetNWPoint(const MapPt: TPoint); overload;
    function GetCenterPoint: TGeoPoint;
    procedure SetCenterPoint(const GeoCoords: TGeoPoint);
    function GetNWPoint: TGeoPoint;
    procedure SetNWPoint(const GeoCoords: TGeoPoint); overload;
    procedure SetZoomConstraint(Index: Integer; ZoomConstraint: TMapZoomLevel);
    //~ helpers
    function ViewAreaRect: TRect;
    class procedure DrawCopyright(const Text: string; DestBmp: TBitmap);
    class procedure DrawScale(Zoom: TMapZoomLevel; DestBmp: TBitmap);
  public
    // Default glyph style of mapmarks. New items will be init-ed with this value
    MapMarkGlyphStyle: TMapMarkGlyphStyle;
    // Default caption style of mapmarks. New items will be init-ed with this value
    MapMarkCaptionStyle: TMapMarkCaptionStyle;
    // Default font of mapmarks. New items will be init-ed with this value
    MapMarkCaptionFont: TFont;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // (Re)draw single tile having numbers `(TileHorzNum;TileVertNum)`
    procedure RefreshTile(TileHorzNum, TileVertNum: Cardinal);

    // Convert a point from map pixel coords to geo coords
    function MapToGeoCoords(const MapPt: TPoint): TGeoPoint; overload;
    // Convert a rect from map pixel coords to geo coords
    function MapToGeoCoords(const MapRect: TRect): TGeoRect; overload;
    // Convert a point from geo coords to map pixel coords
    function GeoCoordsToMap(const GeoCoords: TGeoPoint): TPoint; overload;
    // Convert a rect from geo coords to map pixel coords
    function GeoCoordsToMap(const GeoRect: TGeoRect): TRect; overload;
    // Convert a point from view area coords to map coords
    function ViewToMap(const ViewPt: TPoint): TPoint; overload;
    // Convert a rect from view area coords to map coords
    function ViewToMap(const ViewRect: TRect): TRect; overload;
    // Convert a point from map coords to view area coords
    function MapToView(const MapPt: TPoint): TPoint; overload;
    // Convert a rect from map coords to view area coords
    function MapToView(const MapRect: TRect): TRect; overload;
    // Convert map points to scrollbox inner coordinates (not client!)
    function MapToInner(const MapPt: TPoint): TPoint;
    // Convert scrollbox inner coordinates (not client!) to map points
    function InnerToMap(const Pt: TPoint): TPoint;

    // Delta move the view area
    procedure ScrollMapBy(DeltaHorz, DeltaVert: Integer);
    // Absolutely move the view area
    procedure ScrollMapTo(Horz, Vert: Integer);
    // Set zoom level to new value and reposition to given point
    //   @param Value - new zoom value
    //   @param MapBindPt - point in map coords that must keep its position within view
    procedure SetZoom(Value: Integer; const MapBindPt: TPoint); overload;
    // Simple zoom change with binding to top-left corner
    procedure SetZoom(Value: Integer); overload;
    // Zoom to show given region `GeoRect`
    procedure ZoomToArea(const GeoRect: TGeoRect);
    // Zoom to fill view area as much as possible
    procedure ZoomToFit;

    //~ properties
    // Current zoom level
    property Zoom: Integer read FZoom;
    // Map options
    property MapOptions: TMapOptions read FMapOptions write FMapOptions;
    // Point of center of current view area. Set this property to move view
    property CenterPoint: TGeoPoint read GetCenterPoint write SetCenterPoint;
    // Point of top-left corner of current view area. Set this property to move view
    property NWPoint: TGeoPoint read GetNWPoint write SetNWPoint;
    // Minimal zoom level. Zoom couldn't be set to a value less than this value
    property MinZoom: TMapZoomLevel index 0 read FMinZoom write SetZoomConstraint;
    // Maximal zoom level. Zoom couldn't be set to a value greater than this value
    property MaxZoom: TMapZoomLevel index 1 read FMaxZoom write SetZoomConstraint;
    // List of mapmarks on a map
    property MapMarks: TMapMarkList read FMapMarkList;
    // Mode of handling left mouse button press
    property MouseMode: TMapMouseMode read FMouseMode write FMouseMode;
    // View area in map coords
    property ViewRect: TRect read ViewAreaRect;
    //~ events/callbacks
    // Callback is called when map tile must be drawn
    property OnDrawTile: TOnDrawTile read FOnDrawTile write FOnDrawTile;
    // Callback is called when map tile with loading state must be drawn
    property OnDrawTileLoading: TOnDrawTile read FOnDrawTileLoading write FOnDrawTileLoading;
    // Callback is called when zoom level is changed
    property OnZoomChanged: TNotifyEvent read FOnZoomChanged write FOnZoomChanged;
    // Callback is called when mapmark must be drawn
    property OnDrawMapMark: TOnDrawMapMark read FOnDrawMapMark write FOnDrawMapMark;
    // Callback is called when selection with mouse was made
    property OnSelectionBox: TOnSelectionBox read FOnSelectionBox write FOnSelectionBox;
  end;

function ToInnerCoords(const StartPt, Pt: TPoint): TPoint; overload; inline;
function ToOuterCoords(const StartPt, Pt: TPoint): TPoint; overload; inline;
function ToInnerCoords(const StartPt: TPoint; const Rect: TRect): TRect; overload; inline;
function ToOuterCoords(const StartPt: TPoint; const Rect: TRect): TRect; overload; inline;

const
  // Default style of mapmark glyph.
  // TMapControl.MapMarkGlyphStyle is init-ed with this value
  DefaultMapMarkGlyphStyle: TMapMarkGlyphStyle = (
    Shape: gshCircle;
    Size: 20;
    BorderColor: clWindowFrame;
    BgColor: clSkyBlue;
  );
  // Default style of mapmark caption.
  // TMapControl.MapMarkGlyphStyle is init-ed with this value
  DefaultMapMarkCaptionStyle: TMapMarkCaptionStyle = (
    Color: clMenuText;
    BgColor: clWindow;
    DX: 3;
    Transparent: True
  );

const
  S_Lbl_Loading = 'Loading [%d : %d]...';

// @exclude
procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('OSM', [TMapControl]);
end;

// *** Utils ***

// Like Client<=>Screen

function ToInnerCoords(const StartPt, Pt: TPoint): TPoint;
begin
  Result := Pt.Subtract(StartPt);
end;

function ToInnerCoords(const StartPt: TPoint; const Rect: TRect): TRect;
begin
  Result := RectFromPoints(
    ToInnerCoords(StartPt, Rect.TopLeft),
    ToInnerCoords(StartPt, Rect.BottomRight)
  );
end;

function ToOuterCoords(const StartPt, Pt: TPoint): TPoint;
begin
  Result := Pt.Add(StartPt);
end;

function ToOuterCoords(const StartPt: TPoint; const Rect: TRect): TRect;
begin
  Result := RectFromPoints(
    ToOuterCoords(StartPt, Rect.TopLeft),
    ToOuterCoords(StartPt, Rect.BottomRight)
  );
end;

// Floor value to tile size

function ToTileWidthLesser(Width: Cardinal): Cardinal; inline;
begin
  Result := (Width div TILE_IMAGE_WIDTH)*TILE_IMAGE_WIDTH;
end;

function ToTileHeightLesser(Height: Cardinal): Cardinal; inline;
begin
  Result := (Height div TILE_IMAGE_HEIGHT)*TILE_IMAGE_HEIGHT;
end;

// Ceil value to tile size

function ToTileWidthGreater(Width: Cardinal): Cardinal; inline;
begin
  Result := ToTileWidthLesser(Width);
  if Width mod TILE_IMAGE_WIDTH > 0 then
    Inc(Result, TILE_IMAGE_WIDTH);
end;

function ToTileHeightGreater(Height: Cardinal): Cardinal; inline;
begin
  Result := ToTileHeightLesser(Height);
  if Height mod TILE_IMAGE_HEIGHT > 0 then
    Inc(Result, TILE_IMAGE_HEIGHT);
end;

// Draw triangle on canvas
procedure Triangle(Canvas: TCanvas; const Rect: TRect);
begin
  Canvas.Polygon([
    Point(Rect.Left, Rect.Bottom),
    Point(Rect.Left + Rect.Width div 2, Rect.Top),
    Rect.BottomRight]);
end;

{ TMapMark }

destructor TMapMark.Destroy;
begin
  if CaptionFont <> nil then
    FreeAndNil(CaptionFont);
end;

{ TMapMarkList }

constructor TMapMarkList.Create(Map: TMapControl);
begin
  FMap := Map;
  FList := TList.Create;
end;

destructor TMapMarkList.Destroy;
begin
  Clear;
  FreeAndNil(FList);
  inherited;
end;

procedure TMapMarkList.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TMapMarkList.EndUpdate;
begin
  if FUpdateCount > 0 then
    Dec(FUpdateCount);
  if FUpdateCount = 0 then // redraw map view if update is not held back
    FMap.Invalidate;
end;

function TMapMarkList.Count: Integer;
begin
  Result := FList.Count;
end;

procedure TMapMarkList.Clear;
var i: Integer;
begin
  for i := 0 to FList.Count - 1 do
  begin
    if Assigned(FOnItemNotify) then
      FOnItemNotify(Self, FList[i], lnDeleted);
    TMapMark(FList[i]).Free;
  end;
  FList.Clear;

  if FUpdateCount = 0 then // redraw map view if update is not held back
    FMap.Invalidate;
end;

function TMapMarkList.Get(Index: Integer): TMapMark;
begin
  Result := FList[Index];
end;

function TMapMarkList.Find(const GeoCoords: TGeoPoint; ConsiderMapMarkSize: Boolean; StartIndex: Integer): Integer;
var
  i: Integer;
  MapMark: TMapMark;
begin
  if StartIndex = -1 then
    StartIndex := 0;

  for i := StartIndex to Count - 1 do
  begin
    MapMark := Get(i);
    {}// TODO ConsiderMapMarkSize
    if SameValue(GeoCoords.Long, MapMark.Coord.Long) and SameValue(GeoCoords.Lat, MapMark.Coord.Lat) then
      Exit(i);
  end;

  Result := -1;
end;

function TMapMarkList.Find(const GeoRect: TGeoRect; ConsiderMapMarkSize: Boolean; StartIndex: Integer): Integer;
var
  i: Integer;
  MapMark: TMapMark;
begin
  if StartIndex = -1 then
    StartIndex := 0
  else
    Inc(StartIndex);

  for i := StartIndex to Count - 1 do
  begin
    MapMark := Get(i);
    {}// TODO ConsiderMapMarkSize
    if GeoRect.Contains(MapMark.Coord) then
      Exit(i);
  end;

  Result := -1;
end;

function TMapMarkList.NewItem: TMapMark;
begin
  Result := TMapMark.Create;
  Result.Visible := True;
  Result.GlyphStyle := FMap.MapMarkGlyphStyle;
  Result.CaptionStyle := FMap.MapMarkCaptionStyle;
end;

// Add mapmark with specified coords and caption.
function TMapMarkList.Add(const GeoCoords: TGeoPoint; const Caption: string; Layer: Word = 0): TMapMark;
var MapMark: TMapMark;
begin
  MapMark := NewItem;
  MapMark.Coord := GeoCoords;
  MapMark.Caption := Caption;
  Result := Add(MapMark);
end;

function TMapMarkList.Add(MapMark: TMapMark): TMapMark;
begin
  Result := MapMark;
  FList.Add(Result);

  if Assigned(FOnItemNotify) then
    FOnItemNotify(Self, Result, lnAdded);

  if FUpdateCount = 0 then // redraw map view if update is not held back
    FMap.Invalidate;
end;

procedure TMapMarkList.Delete(MapMark: TMapMark);
var i: Integer;
begin
  i := FList.IndexOf(MapMark);
  if i <> -1 then
  begin
    if Assigned(FOnItemNotify) then
      FOnItemNotify(Self, MapMark, lnDeleted);
    TMapMark(FList[i]).Free;
    FList.Delete(i);
  end;

  if FUpdateCount = 0 then // redraw map view if update is not held back
    FMap.Invalidate;
end;

{ TMapControl }

constructor TMapControl.Create(AOwner: TComponent);
begin
  inherited;

  // Setup Scrollbox's properties
  Self.HorzScrollBar.Tracking := True;
  Self.VertScrollBar.Tracking := True;
  Self.DragCursor := crSizeAll;
  Self.AutoScroll := True;

  FCacheImage := TBitmap.Create;

  FSelectionBox := TShape.Create(Self);
  FSelectionBox.Visible := False;
  FSelectionBox.Parent := Self;
  FSelectionBox.Brush.Style := bsClear;
  FSelectionBox.Pen.Mode := pmNot;
  FSelectionBox.Pen.Style := psDashDot;

  FMapMarkList := TMapMarkList.Create(Self);

  FMinZoom := Low(TMapZoomLevel);
  FMaxZoom := High(TMapZoomLevel);

  MapMarkGlyphStyle := DefaultMapMarkGlyphStyle;
  MapMarkCaptionStyle := DefaultMapMarkCaptionStyle;
  MapMarkCaptionFont := TFont.Create;
  MapMarkCaptionFont.Assign(Self.Font);

  // Assign outbound value to ensure the zoom will be changed
  FZoom := -1;
  SetZoom(Low(TMapZoomLevel));
end;

destructor TMapControl.Destroy;
begin
  FreeAndNil(FCacheImage);
  FreeAndNil(FCopyright);
  FreeAndNil(FScaleLine);
  FreeAndNil(FMapMarkList);
  FreeAndNil(MapMarkCaptionFont);
  inherited;
end;

// *** overrides - events ***

// Main drawing routine
// ! Compiler-specific input !
// DC here varies:
//   - Delphi: dimensions of current display res and top-left at viewport's top-left
//   - LCL: dimensions somewhat larger than client area and top-left at control top-left
// Canvas.ClipRect helps avoiding defines here
procedure TMapControl.PaintWindow(DC: HDC);
var
  ViewRect: TRect;
  Canvas: TCanvas;
  MapViewGeoRect: TGeoRect;
  Idx: Integer;
  DCClipRectTopLeft: TPoint;
  MapMarksLayers: TObjectDictionary<Word, TBitmap>;
  LayerList: Tarray<Word>;
begin
  // if view area lays within cached image, no update required
  if not ViewInCache then
  begin
    MoveCache;
    UpdateCache;
  end;

  // ViewRect is current view area in CacheImage coords
  ViewRect := ToInnerCoords(FCacheImageRect.TopLeft, ViewAreaRect);

  //Create Layers holder
  MapMarksLayers := TObjectDictionary<Word, TBitmap>.Create([doOwnsValues]);

  Canvas := TCanvas.Create; // Prefer canvas methods over bit blitting
  try
    Canvas.Handle := DC;
    // Top-left point of view area in DC coords
    DCClipRectTopLeft := Canvas.ClipRect.TopLeft;

    // draw cache (map background)
    Canvas.CopyRect(
      TRect.Create(DCClipRectTopLeft, ViewRect.Width, ViewRect.Height),
      FCacheImage.Canvas,
      ViewRect
    );

    // init copyright bitmap if not inited yet and draw it in bottom-right corner
    if not (moDontDrawCopyright in FMapOptions) then
    begin
      if FCopyright = nil then
      begin
        FCopyright := TBitmap.Create;
        FCopyright.Transparent := True;
        FCopyright.TransparentColor := clWhite;
        DrawCopyright(TilesCopyright, FCopyright);
      end;
      Canvas.Draw(
        DCClipRectTopLeft.X + ViewRect.Width - FCopyright.Width - LabelMargin,
        DCClipRectTopLeft.Y + ViewRect.Height - FCopyright.Height - LabelMargin,
        FCopyright
      );
    end;

    // scaleline bitmap must've been inited already in SetZoom
    // draw it in bottom-left corner
    if not (moDontDrawScale in FMapOptions) then
    begin
      Canvas.Draw(
        DCClipRectTopLeft.X + LabelMargin,
        DCClipRectTopLeft.Y + ViewRect.Height - FScaleLine.Height - LabelMargin,
        FScaleLine
      );
    end;

    // Draw mapmarks
    if FMapMarkList.Count > 0 then
    begin
      idx := -1;
      // Determine rect of map in view (map could be smaller than view!)
      MapViewGeoRect := MapToGeoCoords(EnsureInMap(FZoom, ViewAreaRect));
      // Draw marks within rect
      repeat
        idx := FMapMarkList.Find(MapViewGeoRect, True, idx);
        if idx = -1 then Break;
        DrawMapMark(Canvas, TDictionary<Word, TBitmap>(MapMarksLayers), FMapMarkList.Get(idx));
      until False;

      //Draw Mapmarks Layers on map in order
      LayerList := MapMarksLayers.Keys.ToArray;
      TArray.Sort<Word>(LayerList);
      for var Layer in LayerList do
      begin
        Canvas.Draw(0, 0, MapMarksLayers[Layer]);
      end;

    end;
  finally
    FreeAndNil(Canvas);
    MapMarksLayers.Free;
  end;

end;

// NB: painting on TWinControl is pretty tricky, doing it ordinary way leads
// to weird effects as DC's do not cover whole client area.
// Luckily this could be solved with Invalidate which fully redraws the control
procedure TMapControl.WMHScroll(var Message: TWMHScroll);
begin
  Invalidate;
  inherited;
end;

procedure TMapControl.WMVScroll(var Message: TWMVScroll);
begin
  Invalidate;
  inherited;
end;

// ! Only with csCustomPaint ControlState the call chain
// TWinControl.WMPaint > PaintHandler > PaintWindow will be executed.
procedure TMapControl.WMPaint(var Message: TWMPaint);
begin
  ControlState := ControlState + [csCustomPaint];
  inherited;
  ControlState := ControlState - [csCustomPaint];
end;

// Control resized - reposition cache, set new scrollbar props
// Parent's method only calls OnResize
procedure TMapControl.Resize;
begin
  if SetCacheDimensions then
    UpdateCache;
  {$IFDEF FPC}
  // ! Compiler-specific !
  // LCL has weird scrollbars - they require Page to be set to actual size
  Self.HorzScrollBar.Page := Self.ClientWidth;
  Self.VertScrollBar.Page := Self.ClientHeight;
  {$ENDIF}
  Invalidate;
  inherited;
end;

// Focus self on mouse press
// Start dragging or selecting on mouse press
procedure TMapControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var MousePos: TPoint;
begin
  SetFocus;
  // Left button and no shifts only
  if (Button = mbLeft) and (Shift = [ssLeft]) then
    case MouseMode of
      mmDrag:
        begin
          MousePos := ViewToMap(Point(X, Y));
          // Position is inside map and no mapmark below
          if InMap(Zoom, MousePos) and (FMapMarkList.Find(MapToGeoCoords(MousePos), True) = -1) then
            BeginDrag(False, -1);  // < 0 - use the DragThreshold property of the global Mouse variable (c) help
          inherited;
        end;
      mmSelect:
        begin
          MousePos := ViewToMap(Point(X, Y));
          // Position is inside map - start selection
          if InMap(Zoom, MousePos) then
          begin
            FSelectionBoxBindPoint := MapToInner(MousePos);
            FSelectionBox.BoundsRect := TRect.Create(FSelectionBoxBindPoint, 0, 0);
            FSelectionBox.Visible := True;
          end;
          inherited;
        end;
    end; // case
end;

// Resize selection box if active
procedure TMapControl.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  if FSelectionBox.Visible then
  begin
    // ! Rect here could easily become non-normalized (Top below Bottom, f.ex.) so we normalize it
    FSelectionBox.BoundsRect := TRect.Create(FSelectionBoxBindPoint,
      MapToInner(EnsureInMap(Zoom, ViewToMap(Point(X, Y)))), True);
    Invalidate;
  end;
  inherited;
end;

procedure TMapControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var GeoRect: TGeoRect;
begin
  if FSelectionBox.Visible then
  begin
    FSelectionBox.Visible := False;
    Invalidate;
    GeoRect := MapToGeoCoords(
      TRect.Create(InnerToMap(FSelectionBox.BoundsRect.TopLeft), FSelectionBox.Width, FSelectionBox.Height)
    );
    if Assigned(FOnSelectionBox) then
      FOnSelectionBox(Self, GeoRect);
  end;
  inherited;
end;

// Zoom in/out on mouse wheel
// ! Compiler-specific input !
//   - Delphi: Mouse position is in screen coords, it could be any point outside the client area!
//   - FPC: Mouse position is in client coords
function TMapControl.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  inherited;

  // Calc mouse pos in client coords
  {$IFDEF DCC}
  MousePos := ScreenToClient(MousePos);
  {$ENDIF}

  SetZoom(FZoom + Sign(WheelDelta), EnsureInMap(FZoom, ViewToMap(MousePos)));
  Result := True;
end;

// Process dragging
procedure TMapControl.DragOver(Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  inherited;

  Accept := True;

  case State of
    dsDragEnter: // drag started - save initial drag position
      FDragPos := Point(X, Y);
    dsDragMove: // dragging - move the map
      begin
        ScrollMapBy(FDragPos.X - X, FDragPos.Y - Y);
        FDragPos := Point(X, Y);
      end;
  end;
end;

// Cancel selection box on Escape press
procedure TMapControl.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if FSelectionBox.Visible then
    if (Shift = []) and (Key = VK_ESCAPE) then
    begin
      FSelectionBox.Visible := False;
      Invalidate;
    end;
  inherited;
end;

// *** new methods ***

procedure TMapControl.SetZoom(Value: Integer; const MapBindPt: TPoint);
var
  CurrBindPt, NewViewNW, ViewBindPt: TPoint;
  BindCoords: TGeoPoint;
begin
  // New value violates contraints - reject it
  if not (Value in [FMinZoom..FMaxZoom]) then Exit;
  if Value = FZoom then Exit;

  // save bind point if zoom is valid (zoom value is used to calc geo coords)
  if FZoom in [Low(TMapZoomLevel)..High(TMapZoomLevel)]
    then BindCoords := MapToGeoCoords(MapBindPt)
    else BindCoords := OSM.SlippyMapUtils.MapToGeoCoords(Low(TMapZoomLevel), Point(0, 0));

  ViewBindPt := MapToView(MapBindPt); // save bind point in view coords, we'll reposition to it after zoom
  FZoom := Value;
  FMapSize := TSize.Create(MapWidth(FZoom), MapHeight(FZoom));

  HorzScrollBar.Range := FMapSize.cx;
  VertScrollBar.Range := FMapSize.cy;

  // init copyright bitmap if not inited yet and draw it
  if not (moDontDrawScale in FMapOptions) then
  begin
    if FScaleLine = nil then
      FScaleLine := TBitmap.Create;
    DrawScale(FZoom, FScaleLine);
  end;

  // move viewport
  CurrBindPt := GeoCoordsToMap(BindCoords); // bind point in new map coords
  NewViewNW := CurrBindPt.Subtract(ViewBindPt); // view's top-left corner in new map coords
  SetNWPoint(NewViewNW);

  SetCacheDimensions;
  if not ViewInCache then
    MoveCache;
  UpdateCache; // zoom changed - update cache anyway

  Refresh;

  if Assigned(FOnZoomChanged) then
    FOnZoomChanged(Self);
end;

procedure TMapControl.SetZoom(Value: Integer);
begin
  SetZoom(Value, Point(0,0));
end;

// Determines cache image size according to control and map size
// Returns true if size was changed
function TMapControl.SetCacheDimensions: Boolean;
var
  CtrlSize, CacheSize: TSize;
begin
  // dims of view area in pixels rounded to full tiles
  CtrlSize.cx := ToTileWidthGreater(ClientWidth);
  CtrlSize.cy := ToTileHeightGreater(ClientHeight);

  // cache dims = Max(control+margins, Min(map, default+margins))
  CacheSize.cx := Min(FMapSize.cx, CacheImageDefWidth + CacheMarginSize*TILE_IMAGE_WIDTH);
  CacheSize.cy := Min(FMapSize.cy, CacheImageDefHeight + CacheMarginSize*TILE_IMAGE_HEIGHT);

  CacheSize.cx := Max(CacheSize.cx, CtrlSize.cx + CacheMarginSize*TILE_IMAGE_WIDTH);
  CacheSize.cy := Max(CacheSize.cy, CtrlSize.cy + CacheMarginSize*TILE_IMAGE_HEIGHT);

  Result := (FCacheImageRect.Width <> CacheSize.cx) or (FCacheImageRect.Height <> CacheSize.cy);
  if not Result then Exit;
  FCacheImageRect.Size := CacheSize;
  FCacheImage.SetSize(CacheSize.cx, CacheSize.cy);
end;

function TMapControl.ViewToMap(const ViewPt: TPoint): TPoint;
begin
  Result := ToOuterCoords(ViewAreaRect.TopLeft, ViewPt);
end;

function TMapControl.ViewToMap(const ViewRect: TRect): TRect;
begin
  Result := ToOuterCoords(ViewAreaRect.TopLeft, ViewRect);
end;

function TMapControl.MapToView(const MapPt: TPoint): TPoint;
begin
  Result := ToInnerCoords(ViewAreaRect.TopLeft, MapPt);
end;

function TMapControl.MapToView(const MapRect: TRect): TRect;
begin
  Result := ToInnerCoords(ViewAreaRect.TopLeft, MapRect);
end;

// ! Compiler-specific !
// TScrollBox is different in different compilers.
//   - FPC considers internal area just as scrollbars' range are set (that is, whole
//     scrollable area inside the box).
//   - Delphi considers control bounds only (just a visible area)
// So this method converts map points to scrollbox inner coordinates (not client!)
function TMapControl.MapToInner(const MapPt: TPoint): TPoint;
begin
  {$IFDEF FPC}
  Result := MapPt; // scrollbox coords = absolute coords
  {$ENDIF}
  {$IFDEF DCC}
  Result := MapToView(MapPt); // scrollbox coords = current view coords
  {$ENDIF}
end;

function TMapControl.InnerToMap(const Pt: TPoint): TPoint;
begin
  {$IFDEF FPC}
  Result := Pt; // scrollbox coords = absolute coords
  {$ENDIF}
  {$IFDEF DCC}
  Result := ViewToMap(Pt); // scrollbox coords = current view coords
  {$ENDIF}
end;

// View area position and size in map coords
function TMapControl.ViewAreaRect: TRect;
begin
  Result := ClientRect;
  Result.Offset(Point(HorzScrollBar.Position, VertScrollBar.Position));
end;

// Whether view area is inside cache image
function TMapControl.ViewInCache: Boolean;
begin
  Result := FCacheImageRect.Contains(ViewAreaRect);
end;

// Fill the cache image
procedure TMapControl.UpdateCache;
var
  CacheHorzCount, CacheVertCount, horz, vert, CacheHorzNum, CacheVertNum: Integer;
begin
  // Clear the image
  FCacheImage.Canvas.Brush.Color := Self.Color;
  FCacheImage.Canvas.FillRect(TRect.Create(Point(0, 0), FCacheImage.Width, FCacheImage.Height));
  // Get dimensions of cache
  CacheHorzCount := Min(FMapSize.cx - FCacheImageRect.Left, FCacheImageRect.Width) div TILE_IMAGE_WIDTH;
  CacheVertCount := Min(FMapSize.cy - FCacheImageRect.Top, FCacheImageRect.Height) div TILE_IMAGE_HEIGHT;
  // Get top-left of cache in tiles
  CacheHorzNum := FCacheImageRect.Left div TILE_IMAGE_WIDTH;
  CacheVertNum := FCacheImageRect.Top div TILE_IMAGE_HEIGHT;
  // Draw cache tiles
  for horz := 0 to CacheHorzCount - 1 do
    for vert := 0 to CacheVertCount - 1 do
      DrawTile(CacheHorzNum + horz, CacheVertNum + vert, Point(horz*TILE_IMAGE_WIDTH, vert*TILE_IMAGE_HEIGHT), FCacheImage.Canvas);
end;

// Calc new cache coords to cover current view area
procedure TMapControl.MoveCache;
var
  ViewRect: TRect;
  MarginH, MarginV: Cardinal;
begin
  ViewRect := ViewAreaRect;
  // move view rect to the border of tiles (to lesser value)
  ViewRect.Left := ToTileWidthLesser(ViewRect.Left);
  ViewRect.Top := ToTileHeightLesser(ViewRect.Top);
  // resize view rect to the border of tiles (to greater value)
  ViewRect.Right := ToTileWidthGreater(ViewRect.Right);
  ViewRect.Bottom := ToTileHeightGreater(ViewRect.Bottom);

  // reposition new cache rect to cover tile-aligned view area
  // calc margins
  MarginH := FCacheImageRect.Width - ViewRect.Width;
  MarginV := FCacheImageRect.Height - ViewRect.Height;
  // margins on the both sides
  if MarginH > TILE_IMAGE_WIDTH then
    MarginH := MarginH div 2;
  if MarginV > TILE_IMAGE_HEIGHT then
    MarginV := MarginV div 2;
  FCacheImageRect.SetLocation(ViewRect.TopLeft);
  FCacheImageRect.TopLeft.Subtract(Point(MarginH, MarginV));
end;

procedure TMapControl.RefreshTile(TileHorzNum, TileVertNum: Cardinal);
var
  TileTopLeft: TPoint;
begin
  // calc tile rect in map coords
  TileTopLeft := Point(TileHorzNum*TILE_IMAGE_WIDTH, TileVertNum*TILE_IMAGE_HEIGHT);
  // the tile is not in cache
  if not FCacheImageRect.Contains(TileTopLeft) then
    Exit;
  // convert tile to cache image coords
  TileTopLeft.SetLocation(ToInnerCoords(FCacheImageRect.TopLeft, TileTopLeft));
  // draw to cache
  DrawTile(TileHorzNum, TileVertNum, TileTopLeft, FCacheImage.Canvas);
  // redraw the view
  Refresh;
end;

// Draw single tile (TileHorzNum;TileVertNum) to canvas Canvas at point TopLeft
procedure TMapControl.DrawTile(TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas);
var Handled: Boolean;
begin
  // check if user wants custom draw
  if Assigned(FOnDrawTile) then
  begin
    Handled := False;
    FOnDrawTile(Self, TileHorzNum, TileVertNum, TopLeft, Canvas, Handled);
    if Handled then
      Exit;
  end;
  // not handled - draw "loading"
  if Assigned(FOnDrawTileLoading) then
  begin
    Handled := False;
    FOnDrawTileLoading(Self, TileHorzNum, TileVertNum, TopLeft, Canvas, Handled);
    if Handled then
      Exit;
  end;
  // default draw
  DrawTileLoading(TileHorzNum, TileVertNum, TopLeft, Canvas);
end;

// Draw single tile (TileHorzNum;TileVertNum) loading to canvas Canvas at point TopLeft
procedure TMapControl.DrawTileLoading(TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas);
var
  TileRect: TRect;
  TextExt: TSize;
  txt: string;
begin
  TileRect.TopLeft := TopLeft;
  TileRect.Size := TSize.Create(TILE_IMAGE_WIDTH, TILE_IMAGE_HEIGHT);

  Canvas.Brush.Color := Color;
  Canvas.Pen.Color := clDkGray;
  Canvas.Rectangle(TileRect);

  txt := Format(S_Lbl_Loading, [TileHorzNum, TileVertNum]);
  TextExt := Canvas.TextExtent(txt);
  Canvas.Font.Color := clGreen;
  Canvas.TextOut(
    TileRect.Left + (TileRect.Width - TextExt.cx) div 2,
    TileRect.Top + (TileRect.Height - TextExt.cy) div 2,
    txt);
end;

// Draw copyright label on bitmap and set its size. Happens only once.
class procedure TMapControl.DrawCopyright(const Text: string; DestBmp: TBitmap);
var
  Canv: TCanvas;
  TextExt: TSize;
begin
  Canv := DestBmp.Canvas;

  Canv.Font.Name := 'Arial';
  Canv.Font.Size := 8;
  Canv.Font.Style := [];

  TextExt := Canv.TextExtent(Text);
  DestBmp.SetSize(TextExt.cx, TextExt.cy);

  // Fill background
  Canv.Brush.Color := clWhite;
  Canv.FillRect(Rect(0, 0, DestBmp.Width, DestBmp.Height));

  // Text
  Canv.Font.Color := clGray;
  Canv.TextOut(0, 0, Text);
end;

// Draw scale line on bitmap and set its size. Happens every zoom change.
class procedure TMapControl.DrawScale(Zoom: TMapZoomLevel; DestBmp: TBitmap);
var
  Canv: TCanvas;
  LetterWidth, ScalebarWidthPixel, ScalebarWidthMeter: Cardinal;
  Text: string;
  TextExt: TSize;
  ScalebarRect: TRect;
begin
  Canv := DestBmp.Canvas;

  GetScaleBarParams(Zoom, ScalebarWidthPixel, ScalebarWidthMeter, Text);

  Canv.Font.Name := 'Arial';
  Canv.Font.Size := 8;
  Canv.Font.Style := [];

  TextExt := Canv.TextExtent(Text);
  LetterWidth := Canv.TextWidth('W');

  DestBmp.Width := LetterWidth + TextExt.cx + LetterWidth + ScalebarWidthPixel; // text, space, bar
  DestBmp.Height := 2*LabelMargin + TextExt.cy;

  // Frame
  Canv.Brush.Color := clWhite;
  Canv.Pen.Color := clSilver;
  Canv.Rectangle(0, 0, DestBmp.Width, DestBmp.Height);

  // Text
  Canv.Font.Color := clBlack;
  Canv.TextOut(LetterWidth div 2, LabelMargin, Text);

  // Scale-Bar
  Canv.Brush.Color := clWhite;
  Canv.Pen.Color := clBlack;
  ScalebarRect.Left := LetterWidth div 2 + TextExt.cx + LetterWidth;
  ScalebarRect.Top := (DestBmp.Height - TextExt.cy div 2) div 2;
  ScalebarRect.Width := ScalebarWidthPixel;
  ScalebarRect.Height := TextExt.cy div 2;
  Canv.Rectangle(ScalebarRect);
end;

// Pixels => degrees
function TMapControl.MapToGeoCoords(const MapPt: TPoint): TGeoPoint;
begin
  Result := OSM.SlippyMapUtils.MapToGeoCoords(FZoom, MapPt);
end;

function TMapControl.MapToGeoCoords(const MapRect: TRect): TGeoRect;
begin
  Result := OSM.SlippyMapUtils.MapToGeoCoords(FZoom, MapRect);
end;

// Degrees => pixels
function TMapControl.GeoCoordsToMap(const GeoCoords: TGeoPoint): TPoint;
begin
  Result := OSM.SlippyMapUtils.GeoCoordsToMap(FZoom, GeoCoords);
end;

function TMapControl.GeoCoordsToMap(const GeoRect: TGeoRect): TRect;
begin
  Result := OSM.SlippyMapUtils.GeoCoordsToMap(FZoom, GeoRect);
end;

procedure TMapControl.ScrollMapBy(DeltaHorz, DeltaVert: Integer);
begin
  HorzScrollBar.Position := HorzScrollBar.Position + DeltaHorz;
  VertScrollBar.Position := VertScrollBar.Position + DeltaVert;
  Invalidate;
end;

procedure TMapControl.ScrollMapTo(Horz, Vert: Integer);
begin
  HorzScrollBar.Position := Horz;
  VertScrollBar.Position := Vert;
  Invalidate;
end;

// Move the view area to new top-left point
procedure TMapControl.SetNWPoint(const MapPt: TPoint);
begin
  ScrollMapTo(MapPt.X, MapPt.Y);
end;

{}//?
function TMapControl.GetCenterPoint: TGeoPoint;
begin
  Result := MapToGeoCoords(ViewAreaRect.CenterPoint);
end;

procedure TMapControl.SetCenterPoint(const GeoCoords: TGeoPoint);
var
  ViewRect: TRect;
  Pt: TPoint;
begin
  // new center point in map coords
  Pt := GeoCoordsToMap(GeoCoords);
  // new NW point
  ViewRect := ViewAreaRect;
  Pt.Offset(-ViewRect.Width div 2, -ViewRect.Height div 2);
  // move
  SetNWPoint(Pt);
end;

// Get top-left point of the view area
function TMapControl.GetNWPoint: TGeoPoint;
begin
  Result := MapToGeoCoords(ViewAreaRect.TopLeft);
end;

// Move the view area to new top-left point
procedure TMapControl.SetNWPoint(const GeoCoords: TGeoPoint);
begin
  SetNWPoint(GeoCoordsToMap(GeoCoords));
end;

// Set zoom restriction and change current zoom if it is beyond this border
procedure TMapControl.SetZoomConstraint(Index: Integer; ZoomConstraint: TMapZoomLevel);
begin
  case Index of
    0: FMinZoom := ZoomConstraint;
    1: FMaxZoom := ZoomConstraint;
  end;
  if FZoom < FMinZoom then
    SetZoom(FMinZoom)
  else
  if FZoom > FMaxZoom then
    SetZoom(FMaxZoom);
end;

procedure TMapControl.ZoomToArea(const GeoRect: TGeoRect);
var
  zoom, NewZoomH, NewZoomV: TMapZoomLevel;
  ViewRect: TRect;
begin
  ViewRect := ViewToMap(ViewAreaRect);
  // Determine maximal zoom in which selected region will fit into view
  // Separately for width and height
  NewZoomH := FMaxZoom;
  for zoom := FZoom to FMaxZoom do
    if OSM.SlippyMapUtils.GeoCoordsToMap(zoom, GeoRect).Width > ViewRect.Width then
    begin
      NewZoomH := zoom;
      Break;
    end;
  NewZoomV := FMaxZoom;
  for zoom := FZoom to FMaxZoom do
    if OSM.SlippyMapUtils.GeoCoordsToMap(zoom, GeoRect).Height > ViewRect.Height then
    begin
      NewZoomV := zoom;
      Break;
    end;

  SetZoom(Min(NewZoomH, NewZoomV));
  SetNWPoint(GeoRect.TopLeft);
end;

// Zoom to fill view area as much as possible
procedure TMapControl.ZoomToFit;
begin
  ZoomToArea(MapToGeoCoords(TRect.Create(Point(0, 0), FMapSize.cx, FMapSize.cy)));
end;

// Base method to draw mapmark. Calls callback to do custom actions
procedure TMapControl.DrawMapMark(Canvas: TCanvas; MapMarksLayers: TDictionary<Word, TBitmap>; MapMark: TMapMark);
var
  Handled: Boolean;
  MMPt: TPoint;
  MapMarkRect: TRect;
  pEffGlStyle: PMapMarkGlyphStyle;
  pEffCapStyle: PMapMarkCaptionStyle;
  CapFont: TFont;
  LayerBitmap: TBitmap;
begin
  Handled := False;
  MMPt := ToInnerCoords(ViewAreaRect.TopLeft, GeoCoordsToMap(MapMark.Coord));
  // ! Consider Canvas.ClipRect
  MMPt.Offset(Canvas.ClipRect.TopLeft);

  //replace map canvas with layer
  if (not MapMarksLayers.TryGetValue(MapMark.Layer, LayerBitmap)) then
  begin
    LayerBitmap := TBitmap.Create(Canvas.ClipRect.Width, Canvas.ClipRect.Height);
    LayerBitmap.Transparent := true;
    LayerBitmap.TransparentColor := RGB(255,0,255); //TODO: good idea to make it configurable
    LayerBitmap.TransparentMode := tmFixed;
    LayerBitmap.Canvas.Brush.Color := LayerBitmap.TransparentColor;
    LayerBitmap.Canvas.FillRect(Canvas.ClipRect);
    MapMarksLayers.Add(MapMark.Layer, LayerBitmap);
  end;
  Canvas := LayerBitmap.Canvas;

  if Assigned(FOnDrawMapMark) then
    FOnDrawMapMark(Self, Canvas, MMPt, MapMark, Handled);
  if Handled then Exit;

  if not MapMark.Visible then Exit;

  // Draw glyph

  // Determine effective glyph style
  if propGlyphStyle in MapMark.CustomProps
    then pEffGlStyle := @MapMark.GlyphStyle
    else pEffGlStyle := @MapMarkGlyphStyle;

  // Determine size
  MapMarkRect.TopLeft := MMPt;
  MapMarkRect.Offset(-pEffGlStyle.Size div 2, -pEffGlStyle.Size div 2);
  MapMarkRect.Size := TSize.Create(pEffGlStyle.Size, pEffGlStyle.Size);

  Canvas.Brush.Color := pEffGlStyle.BgColor;
  Canvas.Pen.Color := pEffGlStyle.BorderColor;

  case pEffGlStyle.Shape of
    gshCircle:
      Canvas.Ellipse(MapMarkRect);
    gshSquare:
      Canvas.Rectangle(MapMarkRect);
    gshTriangle:
      Triangle(Canvas, MapMarkRect);
  end;

  // Draw caption
  if MapMark.Caption <> '' then
  begin
    // Determine effective caption style
    if propCaptionStyle in MapMark.CustomProps
      then pEffCapStyle := @MapMark.CaptionStyle
      else pEffCapStyle := @MapMarkCaptionStyle;
    // Determine effective caption font
    if propFont in MapMark.CustomProps
      then CapFont := MapMark.CaptionFont
      else CapFont := MapMarkCaptionFont;

    Canvas.Font := CapFont;
    Canvas.Font.Color := pEffCapStyle.Color;

    {}// TODO: text position, alignment, ...
    MMPt := Point(MapMarkRect.Right + pEffCapStyle.DX, MapMarkRect.Top + pEffCapStyle.DY);

    if pEffCapStyle.Transparent then
      Canvas.Brush.Style := bsClear
    else
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := pEffCapStyle.BgColor;
    end;

    Canvas.TextOut(MMPt.X, MMPt.Y, MapMark.Caption);
  end;
end;

end.
