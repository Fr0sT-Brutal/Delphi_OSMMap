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
  Math, Types, Generics.Collections, Generics.Defaults,
  OSM.SlippyMapUtils, OSM.TilesProvider;

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
    Visible: Boolean;
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

  // Number of a layer
  TMapLayer = Byte;
  TMapLayers = set of Byte;

  // Class representing a single mapmark.
  // It is recommended to be created by TMapMarkList.NewItem
  TMapMark = class
  public
    //~ Mapmark data
    Coord: TGeoPoint;                    // Coordinates
    Caption: string;                     // Label
    Visible: Boolean;                    // Visibility flag
    Data: Pointer;                       // User data
    Layer: TMapLayer;                    // Layer number
    //~ Visual style
    CustomProps: TMapMarkCustomProps;
    GlyphStyle: TMapMarkGlyphStyle;
    CaptionStyle: TMapMarkCaptionStyle;
    CaptionFont: TFont;

    destructor Destroy; override;
  end;

  TMapControl = class;

  // Notification of an action over a mapmark in a list
  TOnItemNotify = procedure (Sender: TObject; Item: TMapMark; Action: TListNotification) of object;

  // List of mapmarks.
  // Items are sorted by layer number and painted in this order, ascending
  TMapMarkList = class
  strict private
    FMap: TMapControl;
    FList: TObjectList<TMapMark>;
    FUpdateCount: Integer;

    FOnItemNotify: TOnItemNotify;
  strict protected
    procedure ListNotify(Sender: TObject; const Item: TMapMark; Action: TCollectionNotification);
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
    // Simple method to add a mapmark by coords, caption and layer
    function Add(const GeoCoords: TGeoPoint; const Caption: string; Layer: TMapLayer = 0): TMapMark; overload;
    // Add a mapmark with fully customizable properties. `MapMark` should be init-ed by NewItem
    function Add(MapMark: TMapMark): TMapMark; overload;
    // Remove mapmark object
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

  // Callback to get an image of a single tile having number (`TileHorzNum`;`TileVertNum`).
  // Must return bitmap of a tile or @nil if it's not available at the moment
  TOnGetTile = function (Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal): TBitmap of object;

  // Callback to draw an image of a single tile having number (`TileHorzNum`;`TileVertNum`)
  // at point `TopLeft` on canvas `Canvas`.
  // Must set `Handled` to @true, otherwise default actions will be done.
  // This type is common for both TMapControl.OnDrawTile and TMapControl.OnDrawTileLoading callbacks.
  TOnDrawTile = procedure (Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal;
    const TopLeft: TPoint; Canvas: TCanvas; var Handled: Boolean) of object;

  // Callback to custom draw a mapmark. It is called before default drawing.
  // If `Handled` is not set to @true, default drawing will be done.
  TOnDrawMapMark = procedure (Sender: TMapControl; Canvas: TCanvas; const Point: TPoint;
    MapMark: TMapMark; var Handled: Boolean) of object;

  // Callback to react on selection by mouse
  TOnSelectionBox = procedure (Sender: TMapControl; const GeoRect: TGeoRect) of object;

  // Control displaying a map or its visible part.
  TMapControl = class(TScrollBox)
  strict private
    FMapSize: TSize;         // current map dims in pixels
    FCacheImage: TBitmap;    // drawn tiles (it could be equal to or larger than view area!)
    FCopyright: TBitmap;     // lazily created cache images for
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
    FVisibleLayers: TMapLayers;
    FTilesProvider: TTilesProvider;
    FCacheImageTilesH,               // properties of cache image
    FCacheImageTilesV,
    FCacheMarginSize: Cardinal;
    FLabelMargin: Cardinal;

    FOnGetTile: TOnGetTile;
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
    function DrawTileImage(TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas): Boolean;
    procedure DrawTileLoading(TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas);
    procedure DrawTile(TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas);
    procedure DrawMapMark(Canvas: TCanvas; MapMark: TMapMark);
    procedure DrawMapMarks(Canvas: TCanvas; const Rect: TRect);
    procedure DrawLabels(Canvas: TCanvas; const Rect: TRect; DrawOptions: TMapOptions);
    //~ getters/setters
    procedure SetNWPoint(const MapPt: TPoint); overload;
    function GetCenterPoint: TGeoPoint;
    procedure SetCenterPoint(const GeoCoords: TGeoPoint);
    function GetNWPoint: TGeoPoint;
    procedure SetNWPoint(const GeoCoords: TGeoPoint); overload;
    procedure SetZoomConstraint(Index: Integer; ZoomConstraint: TMapZoomLevel);
    procedure SetVisibleLayers(Value: TMapLayers);
    procedure SetLabelMargin(Value: Cardinal);
    procedure SetTilesProvider(Value: TTilesProvider);
    //~ helpers
    function ViewAreaRect: TRect;
    class procedure DrawCopyright(const Text: string; DestBmp: TBitmap);
    class procedure DrawScale(Zoom: TMapZoomLevel; LabelMargin: Cardinal; DestBmp: TBitmap);
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
    procedure SetZoom(Value: Integer; const MapBindPt: TPoint); overload;
    // Simple zoom change with binding to top-left corner
    procedure SetZoom(Value: Integer); overload;
    // Zoom to show given region `GeoRect`
    procedure ZoomToArea(const GeoRect: TGeoRect);
    // Zoom to fill view area as much as possible
    procedure ZoomToFit;

    // Set properties of cache image and rebuild it
    procedure SetCacheImageProperties(TilesHorz, TilesVert, MarginSize: Cardinal);

    // Export map fragment as bitmap.
    // @raises Exception if a tile is unavailable
    //   @param SaveRect - rect in map coords to export
    //   @param DrawOptions - drawing options
    //   @param DrawMapMarks - draw mapmarks or not
    function SaveToBitmap(const SaveRect: TRect; DrawOptions: TMapOptions; DrawMapMarks: Boolean): TBitmap; overload;
    // Export whole map as bitmap.
    // @raises Exception if a tile is unavailable
    //   @param DrawOptions - drawing options
    //   @param DrawMapMarks - draw mapmarks or not
    function SaveToBitmap(DrawOptions: TMapOptions; DrawMapMarks: Boolean): TBitmap; overload;

    //~ properties
    // Tiles provider object. Assigning this property could change some map properties
    // (zoom range, for example, and hence current zoom) so cache will be cleared and
    // the map will be redrawn with new conditions. @br
    // Map control takes ownership on assigned object and destroys it when needed. @br
    // Assign @nil to use an instance of TDummyTilesProvider.
    property TilesProvider: TTilesProvider read FTilesProvider write SetTilesProvider;
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
    // Size of margin for labels on map, in pixels
    property LabelMargin: Cardinal read FLabelMargin write SetLabelMargin;
    // View area in map coords
    property ViewRect: TRect read ViewAreaRect;
    // Set of visible layers. You can use LayersAll and LayersNone constants
    property VisibleLayers: TMapLayers read FVisibleLayers write SetVisibleLayers;
    //~ events/callbacks
    // Callback to get an image of a single tile having number (`TileHorzNum`;`TileVertNum`).
    // Must return bitmap of a tile or @nil if it's not available at the moment. @br
    // Called when map tile must be drawn. Usually you have to assign this callback only.
    // @name could replace OnDrawTile and exists for simplicity - you don't
    // have to paint tile image every time, the map will do it internally.
    // It could also be assigned together with OnDrawTile which will only be called
    // if @name doesn't return a result.
    property OnGetTile: TOnGetTile read FOnGetTile write FOnGetTile;
    // Callback to draw an image of a single tile having number (`TileHorzNum`;`TileVertNum`)
    // at point `TopLeft` on canvas `Canvas`.
    // Must set `Handled` to @true, otherwise default actions will be done. @br
    // Called when map tile must be drawn.
    // @name could replace OnGetTile but provides more flexibility - handler fully
    // controls painting which allows adding watermarks, layers and so on.
    // It could also be assigned together with OnGetTile and will only be called
    // if OnGetTile doesn't return a result.
    //
    // If `Handled` is not set to @true, default drawing is called for the tile.
    property OnDrawTile: TOnDrawTile read FOnDrawTile write FOnDrawTile;
    // Callback to draw a loading state of a single tile having number (`TileHorzNum`;`TileVertNum`)
    // at point `TopLeft` on canvas `Canvas`.
    // Must set `Handled` to @true, otherwise default actions will be done.
    // Called when map tile with loading state must be drawn. @br
    // @name is called only for empty tiles allowing a user to draw his own label
    property OnDrawTileLoading: TOnDrawTile read FOnDrawTileLoading write FOnDrawTileLoading;
    // Called when zoom level is changed
    property OnZoomChanged: TNotifyEvent read FOnZoomChanged write FOnZoomChanged;
    // Callback to custom draw a mapmark. It is called before default drawing.
    // If `Handled` is not set to @true, default drawing will be done.
    // User could draw a mapmark fully or just change some props and let default
    // drawing do its job
    property OnDrawMapMark: TOnDrawMapMark read FOnDrawMapMark write FOnDrawMapMark;
    // Called when selection with mouse was made
    property OnSelectionBox: TOnSelectionBox read FOnSelectionBox write FOnSelectionBox;
  end;

//~ Like Client<=>Screen

// Convert absolute map coords to a point inside a viewport having given top-left point
function ToInnerCoords(const StartPt, Pt: TPoint): TPoint; overload; inline;
// Convert a point inside a viewport having given top-left point to absolute map coords
function ToOuterCoords(const StartPt, Pt: TPoint): TPoint; overload; inline;
// Convert absolute map rect to a rect inside a viewport having given top-left point
function ToInnerCoords(const StartPt: TPoint; const Rect: TRect): TRect; overload; inline;
// Convert a rect inside a viewport having given top-left point to absolute map rect
function ToOuterCoords(const StartPt: TPoint; const Rect: TRect): TRect; overload; inline;

const
  // Default Width (Horizontal dimension) and Height (Vertical dimension) of cache image
  // in number of tiles. Cache is init-ed with these values but could be changed later.@br
  // Memory occupation of an image:
  //   (4 bytes per pixel) * `TilesH` * `TilesV` * (65536 pixels in single tile) @br
  // For value 8 it counts 16.7 Mb
  DefaultCacheImageTilesHorz = 8;
  DefaultCacheImageTilesVert = 8;
  // Default margin that is added to cache image to hold view area, in number of tiles
  DefaultCacheMarginSize = 2;
  // Default size of margin for labels on map, in pixels
  DefaultLabelMargin = 2;
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
    Visible: True;
    Color: clMenuText;
    BgColor: clWindow;
    DX: 3;
    Transparent: True
  );
  // Constant containing all numbers of layers
  LayersAll: TMapLayers = [Low(TMapLayer)..High(TMapLayer)];
  // Constant containing no layers
  LayersNone: TMapLayers = [];

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

// Sort the list by Layer currently
function ListSortCompare(const Left, Right: TMapMark): Integer;
begin
  Result := CompareValue(Left.Layer, Right.Layer);
end;

constructor TMapMarkList.Create(Map: TMapControl);
begin
  FMap := Map;
  // List is always sorted
  FList := TObjectList<TMapMark>.Create(TComparer<TMapMark>.Construct(ListSortCompare), True);
  FList.OnNotify := ListNotify;
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
begin
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

function TMapMarkList.Add(const GeoCoords: TGeoPoint; const Caption: string; Layer: TMapLayer): TMapMark;
var MapMark: TMapMark;
begin
  MapMark := NewItem;
  MapMark.Coord := GeoCoords;
  MapMark.Caption := Caption;
  MapMark.Layer := Layer;
  Result := Add(MapMark);
end;

function TMapMarkList.Add(MapMark: TMapMark): TMapMark;
var i: Integer;
begin
  Result := MapMark;
  // Add the item in sort order
  FList.BinarySearch(MapMark, i);
  FList.Insert(i, Result);

  if FUpdateCount = 0 then // redraw map view if update is not held back
    FMap.Invalidate;
end;

procedure TMapMarkList.Delete(MapMark: TMapMark);
var i: Integer;
begin
  // Binary search is faster
  if FList.BinarySearch(MapMark, i) then
    FList.Delete(i);

  if FUpdateCount = 0 then // redraw map view if update is not held back
    FMap.Invalidate;
end;

procedure TMapMarkList.ListNotify(Sender: TObject; const Item: TMapMark; Action: TCollectionNotification);
begin
  if Assigned(FOnItemNotify) then
    case Action of
      cnAdded     : FOnItemNotify(Self, Item, lnAdded);
      cnRemoved   : FOnItemNotify(Self, Item, lnDeleted);
      cnExtracted : FOnItemNotify(Self, Item, lnExtracted);
    end;
end;

{ TMapControl }

const
  UnassignedZoom = Low(TMapZoomLevel) - 1;

constructor TMapControl.Create(AOwner: TComponent);
begin
  inherited;

  // Setup Scrollbox's properties
  Self.HorzScrollBar.Tracking := True;
  Self.VertScrollBar.Tracking := True;
  Self.DragCursor := crSizeAll;
  Self.AutoScroll := True;
  FCacheImage := TBitmap.Create;
  // Set default cache props
  FCacheImageTilesH := DefaultCacheImageTilesHorz;
  FCacheImageTilesV := DefaultCacheImageTilesVert;
  FCacheMarginSize := DefaultCacheMarginSize;

  FSelectionBox := TShape.Create(Self);
  FSelectionBox.Visible := False;
  FSelectionBox.Parent := Self;
  FSelectionBox.Brush.Style := bsClear;
  FSelectionBox.Pen.Mode := pmNot;
  FSelectionBox.Pen.Style := psDashDot;

  FMapMarkList := TMapMarkList.Create(Self);

  // The map is visual control so we can't change c-tor but tile provider is needed
  // to know some properties on creation (zoom range, etc). We can't wait for user
  // code to assign a provider and create dummy one (setting provider to nil assigns
  // a new instance of TDummyTilesProvider).
  SetTilesProvider(nil);

  FVisibleLayers := LayersAll;
  FLabelMargin := DefaultLabelMargin;

  MapMarkGlyphStyle := DefaultMapMarkGlyphStyle;
  MapMarkCaptionStyle := DefaultMapMarkCaptionStyle;
  MapMarkCaptionFont := TFont.Create;
  MapMarkCaptionFont.Assign(Self.Font);

  // Assign outbound value to ensure the zoom will be changed
  FZoom := UnassignedZoom;
  SetZoom(FMinZoom);
end;

destructor TMapControl.Destroy;
begin
  FreeAndNil(FTilesProvider);
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
  DCClipViewRect: TRect;
begin
  // if view area lays within cached image, no update required
  if not ViewInCache then
  begin
    MoveCache;
    UpdateCache;
  end;

  // ViewRect is current view area in CacheImage coords
  ViewRect := ToInnerCoords(FCacheImageRect.TopLeft, ViewAreaRect);

  Canvas := TCanvas.Create; // Prefer canvas methods over bit blitting
  try
    Canvas.Handle := DC;
    // View rect in DC coords
    DCClipViewRect := TRect.Create(Canvas.ClipRect.TopLeft, ViewRect.Width, ViewRect.Height);

    // draw cache (map background)
    Canvas.CopyRect(
      DCClipViewRect,
      FCacheImage.Canvas,
      ViewRect
    );

    // Draw mapmarks inside view (map could be smaller than view!)
    DrawMapMarks(Canvas, EnsureInMap(FZoom, ViewAreaRect));

    DrawLabels(Canvas, DCClipViewRect, FMapOptions);
  finally
    FreeAndNil(Canvas);
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

// Set zoom level to new value and reposition to given point
//   @param Value - new zoom value
//   @param MapBindPt - point in map coords that must keep its position within view
procedure TMapControl.SetZoom(Value: Integer; const MapBindPt: TPoint);
var
  CurrBindPt, NewViewNW, ViewBindPt: TPoint;
  BindCoords: TGeoPoint;
begin
  // New value violates contraints - reject it
  if not (Value in [FMinZoom..FMaxZoom]) then Exit;
  if Value = FZoom then Exit;

  // save bind point if zoom is valid (zoom value is used to calc geo coords)
  if FZoom <> UnassignedZoom
    then BindCoords := MapToGeoCoords(MapBindPt)
    else BindCoords := OSM.SlippyMapUtils.MapToGeoCoords(FMinZoom, Point(0, 0));

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
    DrawScale(FZoom, FLabelMargin, FScaleLine);
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
  CacheSize.cx := Min(FMapSize.cx, FCacheImageTilesH*TILE_IMAGE_WIDTH + FCacheMarginSize*TILE_IMAGE_WIDTH);
  CacheSize.cy := Min(FMapSize.cy, FCacheImageTilesV*TILE_IMAGE_HEIGHT + FCacheMarginSize*TILE_IMAGE_HEIGHT);

  // Cast to signed to get rid of warning
  CacheSize.cx := Max(CacheSize.cx, CtrlSize.cx + Integer(FCacheMarginSize)*TILE_IMAGE_WIDTH);
  CacheSize.cy := Max(CacheSize.cy, CtrlSize.cy + Integer(FCacheMarginSize)*TILE_IMAGE_HEIGHT);

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
  ViewRect := ToTileBoundary(ViewAreaRect);

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

// Draw single tile image (TileHorzNum;TileVertNum) to canvas Canvas at point TopLeft.
// Return success flag.
function TMapControl.DrawTileImage(TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas): Boolean;
var TileBmp: TBitmap;
begin
  Result := False;
  // try to get tile bitmap
  if Assigned(FOnGetTile) then
  begin
    TileBmp := FOnGetTile(Self, TileHorzNum, TileVertNum);
    if TileBmp <> nil then
    begin
      Canvas.Draw(TopLeft.X, TopLeft.Y, TileBmp);
      Exit(True);
    end;
  end;
  // check if user wants custom draw
  if Assigned(FOnDrawTile) then
  begin
    FOnDrawTile(Self, TileHorzNum, TileVertNum, TopLeft, Canvas, Result);
  end;
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

// Draw single tile (TileHorzNum;TileVertNum) to canvas Canvas at point TopLeft.
// If tile image is unavailable, draw "loading"
procedure TMapControl.DrawTile(TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas);
var Handled: Boolean;
begin
  if DrawTileImage(TileHorzNum, TileVertNum, TopLeft, Canvas) then
    Exit; // image is drawn

  // not handled - draw "loading"
  if Assigned(FOnDrawTileLoading) then
  begin
    Handled := False;
    FOnDrawTileLoading(Self, TileHorzNum, TileVertNum, TopLeft, Canvas, Handled);
    if Handled then
      Exit;
  end;
  // default "loading" draw
  DrawTileLoading(TileHorzNum, TileVertNum, TopLeft, Canvas);
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
class procedure TMapControl.DrawScale(Zoom: TMapZoomLevel; LabelMargin: Cardinal; DestBmp: TBitmap);
var
  Canv: TCanvas;
  ScalebarWidthPixel, ScalebarWidthMeter: Cardinal;
  LetterWidth: Integer; // Surely unsigned but declared signed just to get rid of warning
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

  DestBmp.Width := LetterWidth + TextExt.cx + LetterWidth + Integer(ScalebarWidthPixel); // text, space, bar
  DestBmp.Height := 2*Integer(LabelMargin) + TextExt.cy;

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

// Set zoom restriction and change current zoom if it is beyond this border.
// Zoom restriction couldn't go beyond tile provider's zoom limits.
procedure TMapControl.SetZoomConstraint(Index: Integer; ZoomConstraint: TMapZoomLevel);
begin
  case Index of
    0: FMinZoom := Max(FTilesProvider.MinZoomLevel, ZoomConstraint);
    1: FMaxZoom := Min(FTilesProvider.MaxZoomLevel, ZoomConstraint);
  end;
  if FZoom < FMinZoom then
    SetZoom(FMinZoom)
  else
  if FZoom > FMaxZoom then
    SetZoom(FMaxZoom);
end;

procedure TMapControl.SetVisibleLayers(Value: TMapLayers);
begin
  FVisibleLayers := Value;
  Refresh;
end;

procedure TMapControl.SetLabelMargin(Value: Cardinal);
begin
  FLabelMargin := Value;
  Refresh;
end;

procedure TMapControl.SetTilesProvider(Value: TTilesProvider);
var
  Init: Boolean;
  OldZoom: TMapZoomLevel;
begin
  // Assigning Dummy is prohibited - we only do it internally
  if Value is TDummyTilesProvider then
    raise Exception.CreateFmt('TMapControl.SetTilesProvider, assigning an ' +
      'instance of %s is prohibited. Assign nil instead.',
      [TDummyTilesProvider.ClassName]);

  // First initial call - the only moment when tile provider is not assigned.
  // Save this flag to assign properties unconditionally
  Init := FTilesProvider = nil;
  FreeAndNil(FTilesProvider);
  FTilesProvider := Value;
  // Provider must be assigned always; assign dummy if nil was set
  if FTilesProvider = nil then
    FTilesProvider := TDummyTilesProvider.Create;

  // Clear cached bitmaps - we want to be sure new provider's properties are used.
  FreeAndNil(FCopyright);
  FCacheImage.Canvas.FillRect(Rect(0, 0, FCacheImage.Width, FCacheImage.Height));

  // Assign some properties

  // Use property setters here to change zoom if it no longer fits into allowed range.
  // Only change zoom limits if they're beyond new ranges - user could've set more
  // tight range already (f.ex., 2..5). Also save old zoom value to determine if it
  // was changed - no need in explicit redraw then.
  OldZoom := Zoom;
  if Init or (FMinZoom < FTilesProvider.MinZoomLevel) then
    MinZoom := FTilesProvider.MinZoomLevel;
  if Init or (FMaxZoom > FTilesProvider.MaxZoomLevel) then
    MaxZoom := FTilesProvider.MaxZoomLevel;
  // Ensure to refresh the cache and map if not refreshed yet due to zoom change
  if Zoom <> OldZoom then Exit;
  UpdateCache;
  Refresh;
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

// Set properties of cache image and rebuild it
//   @param TilesHorz - width (Horizontal dimension) of cache image, in number of tiles
//   @param TilesVert - height (Vertical dimension) of cache image, in number of tiles
//   @param MarginSize - margin that is added to cache image to hold view area, in number of tiles
procedure TMapControl.SetCacheImageProperties(TilesHorz, TilesVert, MarginSize: Cardinal);
begin
  FCacheImageTilesH := TilesHorz;
  FCacheImageTilesV := TilesVert;
  FCacheMarginSize := MarginSize;
  // Update with new values
  SetCacheDimensions;
end;

// Base method to draw mapmark. Calls callback to do custom actions
procedure TMapControl.DrawMapMark(Canvas: TCanvas; MapMark: TMapMark);
var
  Handled: Boolean;
  MMPt: TPoint;
  MapMarkRect: TRect;
  pEffGlStyle: PMapMarkGlyphStyle;
  pEffCapStyle: PMapMarkCaptionStyle;
  CapFont: TFont;
begin
  // Check if mapmark is visible and belongs to a visible layer
  if not (MapMark.Visible and (MapMark.Layer in FVisibleLayers)) then Exit;

  Handled := False;
  MMPt := ToInnerCoords(ViewAreaRect.TopLeft, GeoCoordsToMap(MapMark.Coord));
  // ! Consider Canvas.ClipRect
  MMPt.Offset(Canvas.ClipRect.TopLeft);

  // Let the user modify properties or handle drawing completely
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

    if pEffCapStyle.Visible then
    begin
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
end;

// Method to draw all mapmarks inside a rect
procedure TMapControl.DrawMapMarks(Canvas: TCanvas; const Rect: TRect);
var
  GeoRect: TGeoRect;
  Idx: Integer;
begin
  if FMapMarkList.Count > 0 then
  begin
    idx := -1;
    GeoRect := MapToGeoCoords(Rect);
    // Draw marks within geo rect
    repeat
      idx := FMapMarkList.Find(GeoRect, True, idx);
      if idx = -1 then Break;
      DrawMapMark(Canvas, FMapMarkList.Get(idx));
    until False;
  end;
end;

// Method to draw copyright and scale labels.
//   Rect is view area in DC coords
procedure TMapControl.DrawLabels(Canvas: TCanvas; const Rect: TRect; DrawOptions: TMapOptions);
begin
  // NB: unsigned FLabelMargin produces lots of warnings when mixed with other
  // signed values (even TSize members... what the hell is negative size??).
  // Thus cast it to signed.

  // init copyright bitmap if not inited yet and draw it in bottom-right corner
  if not (moDontDrawCopyright in DrawOptions) then
  begin
    if FCopyright = nil then
    begin
      FCopyright := TBitmap.Create;
      FCopyright.Transparent := True;
      FCopyright.TransparentColor := clWhite;
      DrawCopyright(FTilesProvider.TilesCopyright, FCopyright);
    end;
    Canvas.Draw(
      Rect.Right - FCopyright.Width - Integer(FLabelMargin),
      Rect.Bottom - FCopyright.Height - Integer(FLabelMargin),
      FCopyright
    );
  end;

  // scaleline bitmap must've been inited already in SetZoom
  // draw it in bottom-left corner
  if not (moDontDrawScale in DrawOptions) then
  begin
    Canvas.Draw(
      Rect.Top + Integer(FLabelMargin),
      Rect.Bottom - FScaleLine.Height - Integer(FLabelMargin),
      FScaleLine
    );
  end;
end;

function TMapControl.SaveToBitmap(const SaveRect: TRect; DrawOptions: TMapOptions; DrawMapMarks: Boolean): TBitmap;
var
  TileAlignedSaveRect, DestRect: TRect;
  HorzCount, VertCount, horz, vert, HorzStartNum, VertStartNum: Integer;
  Clipped: TBitmap;
begin
  // To avoid complication, paint to tilesize-aligned canvas
  // SaveRect could be larger than map, reduce it then
  TileAlignedSaveRect := EnsureInMap(FZoom, ToTileBoundary(SaveRect));

  Result := TBitmap.Create;
  Result.SetSize(TileAlignedSaveRect.Width, TileAlignedSaveRect.Height);

  HorzCount := TileAlignedSaveRect.Width div TILE_IMAGE_WIDTH;
  VertCount := TileAlignedSaveRect.Height div TILE_IMAGE_HEIGHT;
  HorzStartNum := TileAlignedSaveRect.Left div TILE_IMAGE_WIDTH;
  VertStartNum := TileAlignedSaveRect.Top div TILE_IMAGE_HEIGHT;

  // Draw tiles. If any tile is unavailable, throw exception.
  for horz := 0 to HorzCount - 1 do
    for vert := 0 to VertCount - 1 do
      if not DrawTileImage(HorzStartNum + horz, VertStartNum + vert,
        Point(horz*TILE_IMAGE_WIDTH, vert*TILE_IMAGE_HEIGHT), Result.Canvas) then
      begin
        FreeAndNil(Result);
        raise Exception.CreateFmt('Tile image unavailable: %d * [%d : %d]',
          [FZoom, horz*TILE_IMAGE_WIDTH, vert*TILE_IMAGE_HEIGHT]);
      end;

  // SaveRect is not aligned to tile size - clip the resulting image by copying
  // needed rect to top-left corner and cutting the dimensions
  if SaveRect <> TileAlignedSaveRect then
  begin
    // Get save area rect relative to tile-aligned rect
    DestRect := ToInnerCoords(TileAlignedSaveRect.TopLeft, SaveRect);
    Result.Canvas.CopyRect(
      Rect(0, 0, DestRect.Width, DestRect.Height),
      Result.Canvas, DestRect);
    Result.SetSize(DestRect.Width, DestRect.Height);
  end;

  if DrawMapMarks then
    Self.DrawMapMarks(Result.Canvas, SaveRect);

  DrawLabels(Result.Canvas, TRect.Create(Point(0, 0), Result.Width, Result.Height), DrawOptions);
end;

function TMapControl.SaveToBitmap(DrawOptions: TMapOptions; DrawMapMarks: Boolean): TBitmap;
begin
  Result := SaveToBitmap(Rect(0, 0, FMapSize.cx, FMapSize.cy), DrawOptions, DrawMapMarks);
end;

end.
