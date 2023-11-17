{
  Visual control displaying a map.
  Data for the map (tile images) must be supplied via callbacks.
  @seealso OSM.TileStorage

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.MapControl;

{$IFDEF FPC}  // For FPC enable Delphi mode and lambdas
  {$MODE Delphi}
  {$MODESWITCH FUNCTIONREFERENCES}
  {$MODESWITCH ANONYMOUSFUNCTIONS}
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

  // Opacity level, from 0 (transparent) to $FF (non-transparent)
  TOpacity = Byte;

  // Visual properties of mapmark's glyph
  TMapMarkGlyphStyle = record
    Shape: TMapMarkGlyphShape;
    Size: Cardinal;
    BorderColor: TColor;
    BgColor: TColor;
    Opacity: TOpacity;    // Glyph transparence. Slows drawing down when there are many mapmarks in view
  end;
  PMapMarkGlyphStyle = ^TMapMarkGlyphStyle;

  // Visual properties of mapmark's caption
  TMapMarkCaptionStyle = record
    Visible: Boolean;             // Visibility flag
    Color: TColor;
    BgColor: TColor;              // Caption background color if @link(Transparent) is @false
    DX, DY: Integer;              // Caption offsets from the TopRight corner of mapmark glyph rectangle, in pixels
    Transparent: Boolean;         // Caption transparency flag
    {}//TODO: text position, alignment
  end;
  PMapMarkCaptionStyle = ^TMapMarkCaptionStyle;

  // Flags to indicate which properties must be taken from MapMark object when drawing.
  // By default props will use owner's values
  TMapMarkCustomProp = (propGlyphStyle, propCaptionStyle, propFont);
  TMapMarkCustomProps = set of TMapMarkCustomProp;

  // Number of a layer. `0` means default, base layer.
  TMapLayer = Byte;
  TMapLayers = set of Byte;

  TMapControl = class;

  // Notification that item is added to the list or removed from it
  TOnItemNotify<T: class> = procedure (Sender: TObject; Item: T; Action: TListNotification) of object;

  // Base wrapper for list of map's child objects (mapmarks, tracks).
  // List is linked to map and controls redrawing when an item is added or removed.
  // List owns added objects and disposes them on delete.
  TChildObjList<T: class> = class
  strict private
    FList: TObjectList<T>;
    FUpdateCount: Integer;

    FOnItemNotify: TOnItemNotify<T>;
  strict protected
    FMap: TMapControl;
    procedure ListNotify(Sender: TObject; const Item: T; Action: TCollectionNotification);
  protected
    function GetComparer: IComparer<T>; virtual; abstract;
  public
    constructor Create(Map: TMapControl);
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;
    function GetEnumerator: TObjectList<T>.TEnumerator; inline;
    function Get(Index: Integer): T; inline;
    // Add an item
    function Add(Item: T): T;
    // Remove item by index
    procedure Delete(Ind: Integer); overload;
    // Remove given item
    procedure Delete(Item: T); overload;
    // Re-sort the list after modification of items' properties
    procedure Sort;
    // Return count of elements in list
    function Count: Integer; inline;
    // Remove all elements
    procedure Clear;
    // Assigning a handler for this event allows implementing custom init, disposal
    // of allocated memory and so on
    property OnItemNotify: TOnItemNotify<T> read FOnItemNotify write FOnItemNotify;
    property Items[Index: Integer]: T read Get; default;
  end;

  // Class representing a single mapmark.
  // It is recommended to create mapmarks by TMapMarkList.NewItem that assigns
  // visual properties from map's values
  TMapMark = class
  public
    //~ Mapmark data
    Coord: TGeoPoint;                    // Coordinates
    Caption: string;                     // Label
    Visible: Boolean;                    // Visibility flag
    Data: Pointer;                       // User data
    Layer: TMapLayer;                    // Number of layer the mapmark belongs to
    //~ Visual style
    CustomProps: TMapMarkCustomProps;    // Set of properties that differ from map's global values
    GlyphStyle: TMapMarkGlyphStyle;
    CaptionStyle: TMapMarkCaptionStyle;
    CaptionFont: TFont;

    constructor Create;
    destructor Destroy; override;
  end;

  // Options for TMapMarkList.Find. Default is empty set
  TMapMarkFindOption = (
    // If set (for map pixels only): consider mapmark glyph size as well.
    // If not set (default): search by exact coords.
    mfoConsiderGlyphSize,
    // If set: consider only visible mapmarks.
    // If not set (default), consider all mapmarks
    mfoOnlyVisible
  );
  TMapMarkFindOptions = set of TMapMarkFindOption;

  // List of mapmarks.
  // Items are sorted by layer number and painted in this order, ascending
  TMapMarkList = class(TChildObjList<TMapMark>)
  protected
    function GetComparer: IComparer<TMapMark>; override;
  public
    // Find the next map mark that is near specified coordinates.
    //   @param GeoCoords - coordinates to search
    //   @param Options - set of search options
    //   @param StartIndex - index of previous found mapmark in the list.    \
    //     `-1` (default) will start from the 1st element
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
    //       idx := MapMarks.Find(Point, [], idx);
    //       if idx = -1 then Break;
    //       ... do something with MapMarks[idx] ...
    //     until False;
    //     ```
    function Find(const GeoCoords: TGeoPoint; Options: TMapMarkFindOptions = []; StartIndex: Integer = -1): Integer; overload;
    // The same as above but searches within specified rectangle
    function Find(const GeoRect: TGeoRect; Options: TMapMarkFindOptions = []; StartIndex: Integer = -1): Integer; overload;
    // The same as above but searches by map point in pixels
    function Find(const MapPt: TPoint; Options: TMapMarkFindOptions; StartIndex: Integer): Integer; overload;
    // Find map mark by its [Data](#TMapMark.Data) field
    //   @param Data - value to search for
    //   @returns index of mapmark in the list having [Data](#TMapMark.Data)  \
    //     field same as `Data`, `-1` if not found.
    function Find(Data: Pointer): Integer; overload;
    // Create TMapMark object and initially assign values from owner map's fields
    function NewItem: TMapMark;
    // Simple method to add a mapmark by coords, caption and layer
    function Add(const GeoCoords: TGeoPoint; const Caption: string; Layer: TMapLayer = 0): TMapMark; overload;
  end;

  // Options for drawing track lines
  TLineDrawProps = record
    Width: Integer;
    Style: TPenStyle;
    Color: TColor;
  end;

  // Track data
  TTrack = class
    Visible: Boolean;              // Visibility flag
    Layer: TMapLayer;              // Number of layer the track belongs to
    Points: array of TGeoPoint;    // Geo points that form a track
    LineDrawProps: TLineDrawProps; // Drawing options
    constructor Create;
    // Just a shorthand for adding a single point. Pre-allocating the array and
    // assigning values to empty cells is always more efficient.
    procedure AddPoint(const Point: TGeoPoint);
  end;

  // List of tracks.
  // Items are sorted by layer number and painted in this order, ascending
  TTrackList = class(TChildObjList<TTrack>)
  protected
    function GetComparer: IComparer<TTrack>; override;
  end;

  // Options of map control
  TMapOption = (moDontDrawCopyright, moDontDrawScale);
  TMapOptions = set of TMapOption;

  // Mode of current handling of mouse events:
  TMapMouseMode = (
    mmNone,       // default handling - mouse doesn't activate the map
    mmDragging,   // dragging the map
    mmSelecting   // drawing selection box
  );

  // Callback to get an image of a single tile having number (`TileHorzNum`;`TileVertNum`).
  // Must return bitmap of a tile or @nil if it's not available at the moment
  TOnGetTile = function (Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal): TBitmap of object;

  // Callback to draw an image of a single tile having number (`TileHorzNum`;`TileVertNum`)
  // at point `TopLeft` on canvas `Canvas`.
  // Must set `Handled` to @true, otherwise default actions will be done.
  // This type is common for both TMapControl.OnDrawTile and TMapControl.OnDrawTileLoading callbacks.
  TOnDrawTile = procedure (Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal;
    const TopLeft: TPoint; Canvas: TCanvas; var Handled: Boolean) of object;

  // Callback to custom draw a mapmark or just a glyph with center point `Point`.
  // It is called before default drawing. If `Handled` is not set to @true, default drawing will be done.
  TOnDrawMapMark = procedure (Sender: TMapControl; Canvas: TCanvas; const Point: TPoint;
    MapMark: TMapMark; var Handled: Boolean) of object;

  // Callback to custom draw a visible layer of whole map view. `CanvasRect` is rectangle of current view in
  // canvas coords (use it in paint functions) and `MapInViewRect` is rectangle of current view in map
  // coords (use it to check visibility of objects).
  TOnDrawLayer = procedure (Sender: TMapControl; Layer: TMapLayer; Canvas: TCanvas; const CanvasRect,
    MapInViewRect: TRect) of object;

  // Callback to react on selection by mouse
  TOnSelectionBox = procedure (Sender: TMapControl; const GeoRect: TGeoRect; Finished: Boolean) of object;

  // Callback to react on mouse button press/release
  TOnMapMarkMouseButtonEvent = procedure (Sender: TMapControl; MapMark: TMapMark;
    Button: TMouseButton; Shift: TShiftState) of object;

  // Control displaying a map or its visible part.
  TMapControl = class(TScrollBox)
  strict private
    FMapRect: TRect;         // current map dimensions in pixels, with TopLeft always at (0,0)
    FCacheImage: TBitmap;    // drawn tiles (it could be equal to or larger than view area!)
    FCopyright: TBitmap;     // lazily created cache images for
    FScaleLine: TBitmap;     //    scale line and copyright
    FZoom: Integer;          // current zoom; integer for simpler operations
    FCacheImageRect: TRect;  // position of cache image on map in map coords
    FMapOptions: TMapOptions;
    FMouseDownPos: TPoint;   // position of current mouse button press, in client coords.
                             // When mouse button is released, (-1,-1) is assigned.
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
    FTracks: TTrackList;

    FOnGetTile: TOnGetTile;
    FOnDrawTile: TOnDrawTile;
    FOnDrawTileLoading: TOnDrawTile;
    FOnZoomChanged: TNotifyEvent;
    FOnDrawMapMark: TOnDrawMapMark;
    FOnDrawMapMarkGlyph: TOnDrawMapMark;
    FOnDrawLayer: TOnDrawLayer;
    FOnSelectionBox: TOnSelectionBox;
    FOnMapMarkMouseDown: TOnMapMarkMouseButtonEvent;
    FOnMapMarkMouseUp: TOnMapMarkMouseButtonEvent;
  protected
    //~ overrides
    procedure PaintWindow(DC: HDC); override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DragOver(Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean); override;
    procedure DoEndDrag(Target: TObject; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Loaded; override;
  strict protected
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
    procedure DrawTrack(Canvas: TCanvas; const Track: TTrack);
    procedure DrawTracks(Canvas: TCanvas);
    procedure DrawMapMark(Canvas: TCanvas; MapMark: TMapMark);
    procedure DrawMapMarks(Canvas: TCanvas; const Rect: TRect);
    procedure DrawLabels(Canvas: TCanvas; const Rect: TRect; DrawOptions: TMapOptions);
    function MapToInner(const MapPt: TPoint): TPoint;
    function InnerToMap(const Pt: TPoint): TPoint;
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
    procedure SetMouseMode(Value: TMapMouseMode);
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
    // Modifiers and mouse buttons combination to enter selection state on mouse down.
    // Assigning this property removes necessity of handling "mouse down" event just
    // for changing map state.
    SelectionShiftState: TShiftState;
    // Modifiers and mouse buttons combination to enter dragging state on mouse down.
    // Assigning this property removes necessity of handling "mouse down" event just
    // for changing map state.
    DragShiftState: TShiftState;

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
    // Convert a point from map coords to view area's canvas coords
    function MapToCanvas(const MapPt: TPoint; Canvas: TCanvas): TPoint; overload;
    // Convert a rect from map coords to view area's canvas coords
    function MapToCanvas(const MapRect: TRect; Canvas: TCanvas): TRect; overload;

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
    // Returns mapmark visibility based on mapmark's own property and also on
    // currently selected visible layers of the map
    function MapMarkVisible(MapMark: TMapMark): Boolean; inline;
    // Returns most recently added visible mapmark located at given map point
    // considering its glyph size.
    function MapMarkAtPos(const MapPt: TPoint): TMapMark;

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
    // Point of center of current view area. Set this property to move view.
    // If map is smaller than view area and resulting point falls out of the map, the 
    // Eastmost-Southmost (Bottom-right) point is returned and any assigning to this 
    // property has no effect.
    property CenterPoint: TGeoPoint read GetCenterPoint write SetCenterPoint;
    // Point of top-left corner of current view area. Set this property to move view
    // If map is smaller than view area any assigning to this property has no effect.
    property NWPoint: TGeoPoint read GetNWPoint write SetNWPoint;
    // Minimal zoom level. Zoom couldn't be set to a value less than this value
    property MinZoom: TMapZoomLevel index 0 read FMinZoom write SetZoomConstraint;
    // Maximal zoom level. Zoom couldn't be set to a value greater than this value
    property MaxZoom: TMapZoomLevel index 1 read FMaxZoom write SetZoomConstraint;
    // List of mapmarks on a map. Addition and deletion of items automatically
    // redraws the parent map but to reflect any modifications of item properties
    // call Map.Invalidate manually.
    property MapMarks: TMapMarkList read FMapMarkList;
    // List of tracks. After any modifications call TMapControl.Invalidate or Refresh
    // to display changes.
    property Tracks: TTrackList read FTracks;
    // Mode of handling left mouse button press
    property MouseMode: TMapMouseMode read FMouseMode write SetMouseMode;
    // Size of margin for labels on map, in pixels
    property LabelMargin: Cardinal read FLabelMargin write SetLabelMargin;
    // View area in map coords. Could be larger than the map on low zoom levels
    property ViewRect: TRect read ViewAreaRect;
    // Set of visible layers. Initially includes all layers. Quickly show/hide all layers
    // with LayersAll and LayersNone constants
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
    // User could draw a mapmark fully or change some props of a mapmark and let default
    // drawing do its job.
    property OnDrawMapMark: TOnDrawMapMark read FOnDrawMapMark write FOnDrawMapMark;
    // Callback to custom draw a mapmark's glyph. It is called before default drawing.
    // If `Handled` is not set to @true, default drawing will be done. @br
    // Glyph rounding rectangle could be calculated with RectByCenterAndSize function
    // and effective glyph style.
    property OnDrawMapMarkGlyph: TOnDrawMapMark read FOnDrawMapMarkGlyph write FOnDrawMapMarkGlyph;
    // Callback to custom draw a layer of whole map view. It is called for visible layers after
    // drawing tiles and before drawing all objects (mapmarks, tracks, labels)
    property OnDrawLayer: TOnDrawLayer read FOnDrawLayer write FOnDrawLayer;
    // Called when selection with mouse changes
    property OnSelectionBox: TOnSelectionBox read FOnSelectionBox write FOnSelectionBox;
    // Called when user presses a mouse button above a mapmark
    property OnMapMarkMouseDown: TOnMapMarkMouseButtonEvent read FOnMapMarkMouseDown write FOnMapMarkMouseDown;
    // Called when user releases a mouse button above a mapmark
    property OnMapMarkMouseUp: TOnMapMarkMouseButtonEvent read FOnMapMarkMouseUp write FOnMapMarkMouseUp;
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

// Draw triangle on canvas
procedure Triangle(Canvas: TCanvas; const Rect: TRect);
// Return rectangle with center point in CenterPt and with size Size
function RectByCenterAndSize(const CenterPt: TPoint; Size: Integer): TRect;

// Determine whether current ShiftState corresponds to desired one (that is, if
// mouse button and pressed modifiers are the same - not a simple comparison because
// TShiftState could include additional entries like "Pen", "Touch" and so on.
// This function only checks Ctrl, Alt, Shift and Left, Right, Middle mouse buttons.
function ShiftStateIs(Current, Desired: TShiftState): Boolean;

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
    Opacity: High(TOpacity);
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
  // Default style of track line.
  DefLineDrawProps: TLineDrawProps = (
    Width: 3;
    Style: psSolid;
    Color: clBlue
  );
  // Constant containing all numbers of layers
  LayersAll: TMapLayers = [Low(TMapLayer)..High(TMapLayer)];
  // Constant containing no layers
  LayersNone: TMapLayers = [];

resourcestring
  // Default pattern to draw on currently loading tiles
  S_Lbl_Loading = 'Loading [%d : %d]...';

// @exclude
procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('OSM', [TMapControl]);
end;

resourcestring
  S_Err_OptionNotAllowed = 'TMapMarkList.Find: option is not allowed in this mode';
  S_Err_TileUnavail = 'Tile image unavailable: %d * [%d : %d]';
  S_Err_AssignInst = 'TMapControl.SetTilesProvider, assigning an instance of %s is prohibited. Assign nil instead.';

// *** Utils ***

//~ Like Client<=>Screen

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

procedure Triangle(Canvas: TCanvas; const Rect: TRect);
begin
  // Note that -1's estimating line width
  Canvas.Polygon([
    Point(Rect.Left, Rect.Bottom - 1),
    Point(Rect.Left + Rect.Width div 2, Rect.Top),
    Point(Rect.Right, Rect.Bottom - 1)]);
end;

function RectByCenterAndSize(const CenterPt: TPoint; Size: Integer): TRect;
begin
  Result.TopLeft := CenterPt;
  Result.Offset(-Size div 2, -Size div 2);
  Result.Size := TSize.Create(Size, Size);
end;

function ShiftStateIs(Current, Desired: TShiftState): Boolean;
const
  Modifiers = [ssShift, ssAlt, ssCtrl];
  Buttons = [ssLeft, ssRight, ssMiddle];
begin
  Result :=
    // Check modifiers
    (Current*Modifiers = Desired*Modifiers) and
    // Check button(s)
    (Current*Buttons = Desired*Buttons);
end;

{~ TChildObjList<T> }

constructor TChildObjList<T>.Create(Map: TMapControl);
begin
  FMap := Map;
  // List is always sorted
  FList := TObjectList<T>.Create(GetComparer, True);
  FList.OnNotify := ListNotify;
  FList.OwnsObjects := True;
end;

destructor TChildObjList<T>.Destroy;
begin
  BeginUpdate; // No sense in redrawing deletion of each item
  Clear;
  EndUpdate;
  FreeAndNil(FList);
  inherited;
end;

procedure TChildObjList<T>.ListNotify(Sender: TObject; const Item: T; Action: TCollectionNotification);
begin
  if Assigned(FOnItemNotify) then
    case Action of
      cnAdded     : FOnItemNotify(Self, Item, lnAdded);
      cnRemoved   : FOnItemNotify(Self, Item, lnDeleted);
      cnExtracted : FOnItemNotify(Self, Item, lnExtracted);
    end;

  if FUpdateCount = 0 then // redraw map view if update is not held back
    FMap.Invalidate;
end;

procedure TChildObjList<T>.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TChildObjList<T>.EndUpdate;
begin
  if FUpdateCount > 0 then
    Dec(FUpdateCount);
  if FUpdateCount = 0 then // redraw map view if update is not held back
    FMap.Invalidate;
end;

function TChildObjList<T>.GetEnumerator: TObjectList<T>.TEnumerator;
begin
  Result := FList.GetEnumerator;
end;

function TChildObjList<T>.Get(Index: Integer): T;
begin
  Result := FList[Index];
end;

function TChildObjList<T>.Add(Item: T): T;
// List<T>.BinarySearch expects different types of output in FPC and Delphi
var i: {$IFDEF FPC} SizeInt {$ELSE} Integer {$ENDIF};
begin
  Result := Item;
  // Add the item in sort order
  if FList.BinarySearch(Item, i) then
    FList.Insert(i, Result)
  else
    FList.Add(Result);
end;

procedure TChildObjList<T>.Delete(Item: T);
// List<T>.BinarySearch expects different types of output in FPC and Delphi
var i: {$IFDEF FPC} SizeInt {$ELSE} Integer {$ENDIF};
begin
  // Binary search is faster
  if FList.BinarySearch(Item, i) then
    FList.Delete(i);
end;

procedure TChildObjList<T>.Delete(Ind: Integer);
begin
  FList.Delete(Ind);
end;

procedure TChildObjList<T>.Sort;
begin
  FList.Sort;
end;

function TChildObjList<T>.Count: Integer;
begin
  Result := FList.Count;
end;

procedure TChildObjList<T>.Clear;
begin
  FList.Clear;

  if FUpdateCount = 0 then // redraw map view if update is not held back
    FMap.Invalidate;
end;

{~ TMapMark }

constructor TMapMark.Create;
begin
  Visible := True;
end;

destructor TMapMark.Destroy;
begin
  if CaptionFont <> nil then
    FreeAndNil(CaptionFont);
end;

{~ TMapMarkList }

// Return comparer that sorts the list by Layer
function TMapMarkList.GetComparer: IComparer<TMapMark>;
begin
  Result := TComparer<TMapMark>.Construct(
    function (const Left, Right: TMapMark): Integer
    begin
      Result := CompareValue(Left.Layer, Right.Layer);
    end);
end;

function TMapMarkList.Find(const GeoCoords: TGeoPoint; Options: TMapMarkFindOptions; StartIndex: Integer): Integer;
var
  i: Integer;
  MapMark: TMapMark;
begin
  if mfoConsiderGlyphSize in Options then
    raise Exception.Create(S_Err_OptionNotAllowed);

  if StartIndex = -1 then
    StartIndex := 0
  else
    Inc(StartIndex);

  for i := StartIndex to Count - 1 do
  begin
    MapMark := Get(i);
    // Consider mfoOnlyVisible option
    if (mfoOnlyVisible in Options) and not FMap.MapMarkVisible(MapMark) then
      Continue;
    if GeoCoords.Same(MapMark.Coord) then
      Exit(i);
  end;

  Result := -1;
end;

function TMapMarkList.Find(const GeoRect: TGeoRect; Options: TMapMarkFindOptions; StartIndex: Integer): Integer;
var
  i: Integer;
  MapMark: TMapMark;
begin
  if mfoConsiderGlyphSize in Options then
    raise Exception.Create(S_Err_OptionNotAllowed);

  if StartIndex = -1 then
    StartIndex := 0
  else
    Inc(StartIndex);

  for i := StartIndex to Count - 1 do
  begin
    MapMark := Get(i);
    // Consider mfoOnlyVisible option
    if (mfoOnlyVisible in Options) and not FMap.MapMarkVisible(MapMark) then
      Continue;

    if GeoRect.Contains(MapMark.Coord) then
      Exit(i);
  end;

  Result := -1;
end;

function TMapMarkList.Find(const MapPt: TPoint; Options: TMapMarkFindOptions; StartIndex: Integer): Integer;
var
  i: Integer;
  MapMark: TMapMark;
  GlyphSize: Integer;
  SearchRect: TRect;
begin
  // Without considering glyph size it's the equivalent of Find(GeoPt)
  if not (mfoConsiderGlyphSize in Options) then
    Exit(Find(FMap.MapToGeoCoords(MapPt), Options, StartIndex));

  if StartIndex = -1 then
    StartIndex := 0
  else
    Inc(StartIndex);

  for i := StartIndex to Count - 1 do
  begin
    MapMark := Get(i);
    // Consider mfoOnlyVisible option
    if (mfoOnlyVisible in Options) and not FMap.MapMarkVisible(MapMark) then
      Continue;
    // Calc the glyph area considering mapmark options
    if propGlyphStyle in MapMark.CustomProps
      then GlyphSize := MapMark.GlyphStyle.Size
      else GlyphSize := FMap.MapMarkGlyphStyle.Size;
    // Determine rounding rect of glyph with mapmark's coords as center point
    SearchRect := EnsureInMap(FMap.Zoom, RectByCenterAndSize(MapPt, GlyphSize));
    if FMap.MapToGeoCoords(SearchRect).Contains(MapMark.Coord) then
      Exit(i);
  end;

  Result := -1;
end;

function TMapMarkList.Find(Data: Pointer): Integer;
begin
  for Result := 0 to Count - 1 do
    if Get(Result).Data = Data then
      Exit;
  Result := -1;
end;

function TMapMarkList.NewItem: TMapMark;
begin
  Result := TMapMark.Create;
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

{~ TTrack }

constructor TTrack.Create;
begin
  inherited;
  Visible := True;
end;

procedure TTrack.AddPoint(const Point: TGeoPoint);
begin
  SetLength(Self.Points, Length(Self.Points) + 1);
  Self.Points[High(Self.Points)] := Point;
end;

{~ TTrackList }

// Return comparer that sorts the list by Layer
function TTrackList.GetComparer: IComparer<TTrack>;
begin
  Result := TComparer<TTrack>.Construct(
    function (const Left, Right: TTrack): Integer
    begin
      Result := CompareValue(Left.Layer, Right.Layer);
    end);
end;

{~ TMapControl }

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
  FTracks := TTrackList.Create(Self);

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
  FreeAndNil(FTracks);
  FreeAndNil(MapMarkCaptionFont);
  inherited;
end;

// *** overrides - events ***

// Main drawing routine
procedure TMapControl.PaintWindow(DC: HDC);
var
  ViewRect, MapInViewRect: TRect;
  Canvas: TCanvas;
  CanvasRect: TRect;
  Layer: TMapLayer;
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
    CanvasRect := MapToCanvas(ViewAreaRect, Canvas);

    // draw cache (map background)
    Canvas.CopyRect(
      CanvasRect,
      FCacheImage.Canvas,
      ViewRect
    );

    // Draw mapmarks and tracks inside view (map could be smaller than view!)
    MapInViewRect := EnsureInMap(FZoom, ViewAreaRect);

    if Assigned(FOnDrawLayer) then
      for Layer in VisibleLayers do
        FOnDrawLayer(Self, Layer, Canvas, CanvasRect, MapInViewRect);

    DrawMapMarks(Canvas, MapInViewRect);
    DrawTracks(Canvas);
    DrawLabels(Canvas, CanvasRect, FMapOptions);
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

// Focus self on mouse press, save mouse position, run mapmark press event, change mode
procedure TMapControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var MapMark: TMapMark;
begin
  SetFocus;
  FMouseDownPos := Point(X, Y);

  // mapmark pressed?
  if Assigned(FOnMapMarkMouseDown) then
  begin
    MapMark := MapMarkAtPos(ViewToMap(FMouseDownPos));
    if MapMark <> nil then
      FOnMapMarkMouseDown(Self, MapMark, Button, Shift);
  end;

  // check assigned combinations for selection and dragging
  if ShiftStateIs(Shift, SelectionShiftState) then
    MouseMode := mmSelecting
  else
  if ShiftStateIs(Shift, DragShiftState) then
    MouseMode := mmDragging;

  inherited;
end;

// Resize selection box if active
// ! Note X, Y could be negative.
procedure TMapControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var GeoRect: TGeoRect;
begin
  if MouseMode = mmSelecting then
  begin
    // ! Rect here could easily become non-normalized (Top below Bottom, f.ex.) so we normalize it
    FSelectionBox.BoundsRect := TRect.Create(FSelectionBoxBindPoint,
      MapToInner(EnsureInMap(Zoom, ViewToMap(Point(X, Y)))), True);
    Invalidate;
    if Assigned(FOnSelectionBox) then
    begin
      GeoRect := MapToGeoCoords(
        TRect.Create(InnerToMap(FSelectionBox.BoundsRect.TopLeft), FSelectionBox.Width, FSelectionBox.Height)
      );
      FOnSelectionBox(Self, GeoRect, False);
    end;
  end;
  inherited;
end;

// Change mouse mode to "None".
procedure TMapControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  GeoRect: TGeoRect;
  MapMark: TMapMark;
begin
  // Mapmark event - only if not selecting or dragging
  if MouseMode = mmNone then
    if Assigned(FOnMapMarkMouseUp) then
    begin
      MapMark := MapMarkAtPos(ViewToMap(FMouseDownPos));
      if MapMark <> nil then
        FOnMapMarkMouseUp(Self, MapMark, Button, Shift);
    end;

  if MouseMode = mmSelecting then
  begin
    if Assigned(FOnSelectionBox) then
    begin
      GeoRect := MapToGeoCoords(
        TRect.Create(InnerToMap(FSelectionBox.BoundsRect.TopLeft), FSelectionBox.Width, FSelectionBox.Height)
      );
      FOnSelectionBox(Self, GeoRect, True);
    end;
  end;

  // **Note**. When a control is started dragging, mouse presses/releases are consumed.
  // "Mouse LB Up" event is fired from inside TControl.BeginDrag and there will be no "Mouse LB Down".
  // Instead, DoEndDrag is called.
  // So here we finish all modes except mmDragging which is finished in DoEndDrag.
  if MouseMode <> mmDragging then
    MouseMode := mmNone;

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

// Handle dragging: start and in process
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
    // ! Here should be dsDragLeave but it's non-reliable - not called on mouse click
    // (no mouse move - below threshold - no real dragging started). So we have to
    // override DoEndDrag as well
  end;
end;

// Handle dragging: finish
procedure TMapControl.DoEndDrag(Target: TObject; X, Y: Integer);
begin
  MouseMode := mmNone;
  inherited;
end;

// Cancel selection box on Escape press
procedure TMapControl.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if MouseMode = mmSelecting then
    if Key = VK_ESCAPE then
      MouseMode := mmNone;
  inherited;
end;

// Enable DoubleBuffering by default or the image will flicker
procedure TMapControl.Loaded;
begin
  inherited;
  Self.DoubleBuffered := True;
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
  // Cancel selection / dragging
  MouseMode := mmNone;

  // New value violates contraints - reject it
  if not (Value in [FMinZoom..FMaxZoom]) then Exit;
  if Value = FZoom then Exit;

  // save bind point if zoom is valid (zoom value is used to calc geo coords)
  if FZoom <> UnassignedZoom
    then BindCoords := MapToGeoCoords(EnsureInMap(FZoom, MapBindPt))
    else BindCoords := OSM.SlippyMapUtils.MapToGeoCoords(FMinZoom, Point(0, 0));

  ViewBindPt := MapToView(MapBindPt); // save bind point in view coords, we'll reposition to it after zoom
  if FZoom <> UnassignedZoom then
    ViewBindPt := EnsureInMap(FZoom, ViewBindPt);
  FZoom := Value;
  FMapRect := TRect.Create(Point(0, 0), MapWidth(FZoom), MapHeight(FZoom));

  HorzScrollBar.Range := FMapRect.Width;
  VertScrollBar.Range := FMapRect.Height;

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
  SetZoom(Value, Point(0, 0));
end;

// Determines cache image size according to control and map size
// Returns true if size was changed
function TMapControl.SetCacheDimensions: Boolean;
var
  CtrlSize, CacheSize: TSize;
begin
  // dims of view area in pixels rounded to full tiles
  // Type cast: remove FPC@Linux build error
  CtrlSize.cx := Integer(ToTileWidthGreater(ClientWidth));
  CtrlSize.cy := Integer(ToTileHeightGreater(ClientHeight));

  // cache dims = Max(control+margins, Min(map, default+margins))
  CacheSize.cx := Min(FMapRect.Width, FCacheImageTilesH*TILE_IMAGE_WIDTH + FCacheMarginSize*TILE_IMAGE_WIDTH);
  CacheSize.cy := Min(FMapRect.Height, FCacheImageTilesV*TILE_IMAGE_HEIGHT + FCacheMarginSize*TILE_IMAGE_HEIGHT);

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

// Convert map points to scrollbox inner coordinates (not client!)                   @br
// ! Compiler-specific !                                                             @br
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

// Convert scrollbox inner coordinates (not client!) to map points
function TMapControl.InnerToMap(const Pt: TPoint): TPoint;
begin
  {$IFDEF FPC}
  Result := Pt; // scrollbox coords = absolute coords
  {$ENDIF}
  {$IFDEF DCC}
  Result := ViewToMap(Pt); // scrollbox coords = current view coords
  {$ENDIF}
end;

// ! Compiler-specific input !
// Canvas here varies:
//   - Delphi: dimensions of current display res and top-left is at viewport's top-left
//   - LCL: dimensions somewhat larger than client area and top-left is at control top-left
// Canvas.ClipRect helps avoiding defines here
function TMapControl.MapToCanvas(const MapPt: TPoint; Canvas: TCanvas): TPoint;
begin
  Result := MapToView(MapPt);
  Result.Offset(Canvas.ClipRect.TopLeft);
end;

function TMapControl.MapToCanvas(const MapRect: TRect; Canvas: TCanvas): TRect;
begin
  Result := MapToView(MapRect);
  Result.Offset(Canvas.ClipRect.TopLeft);
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
  CacheHorzCount := Min(FMapRect.Width - FCacheImageRect.Left, FCacheImageRect.Width) div TILE_IMAGE_WIDTH;
  CacheVertCount := Min(FMapRect.Height - FCacheImageRect.Top, FCacheImageRect.Height) div TILE_IMAGE_HEIGHT;
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

//~ Pixels => degrees

function TMapControl.MapToGeoCoords(const MapPt: TPoint): TGeoPoint;
begin
  Result := OSM.SlippyMapUtils.MapToGeoCoords(FZoom, MapPt);
end;

function TMapControl.MapToGeoCoords(const MapRect: TRect): TGeoRect;
begin
  Result := OSM.SlippyMapUtils.MapToGeoCoords(FZoom, MapRect);
end;

//~ Degrees => pixels

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
  Result := MapToGeoCoords(EnsureInMap(FZoom, ViewAreaRect.CenterPoint));
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
  SetNWPoint(EnsureInMap(FZoom, Pt));
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
    raise Exception.CreateFmt(S_Err_AssignInst, [TDummyTilesProvider.ClassName]);

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

procedure TMapControl.SetMouseMode(Value: TMapMouseMode);
begin
  if FMouseMode = Value then Exit;

  // Cleanup previous state
  case FMouseMode of
    mmNone:
      ;
    mmDragging:
      begin
        FDragPos := Default(TPoint);
        EndDrag(True);
      end;
    mmSelecting:
      begin
        FSelectionBox.Visible := False;
        FSelectionBoxBindPoint := Default(TPoint);
        FSelectionBox.BoundsRect := Default(TRect);
        Invalidate;
      end;
  end;

  FMouseMode := Value;

  // Start new state
  case FMouseMode of
    mmNone: //
      FMouseDownPos := Point(-1, -1);
    mmDragging:
      begin
        BeginDrag(False, -1);  // < 0 - use the DragThreshold property of the global Mouse variable (c) help
      end;
    mmSelecting:
      begin
        // Position is inside map - start selection
        if InMap(Zoom, ViewToMap(FMouseDownPos)) then
        begin
          FSelectionBoxBindPoint := FMouseDownPos;
          FSelectionBox.BoundsRect := TRect.Create(FSelectionBoxBindPoint, 0, 0);
          FSelectionBox.Visible := True;
        end;
      end;
  end;
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

procedure TMapControl.ZoomToFit;
begin
  ZoomToArea(MapToGeoCoords(FMapRect));
end;

function TMapControl.MapMarkVisible(MapMark: TMapMark): Boolean;
begin
  Result := MapMark.Visible and (MapMark.Layer in FVisibleLayers);
end;

function TMapControl.MapMarkAtPos(const MapPt: TPoint): TMapMark;
var
  idx: Integer;
begin
  Result := nil;

  // Check if position is inside map
  if not InMap(Zoom, MapPt) then Exit;

  // Check if there's any mapmark with given options. Loop through all
  // mapmarks that satisfy the conditions until the last one is found
  // TODO search from the end backwards
  idx := -1;
  repeat
    idx := FMapMarkList.Find(MapPt, [mfoOnlyVisible, mfoConsiderGlyphSize], idx);
    if idx = -1 then Exit;
    Result := FMapMarkList[idx];
  until False;
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

  procedure DrawGlyph(Canvas: TCanvas; Rect: TRect; const GlyphStyle: TMapMarkGlyphStyle);
  begin
    Canvas.Brush.Color := GlyphStyle.BgColor;
    Canvas.Pen.Color := GlyphStyle.BorderColor;
    case GlyphStyle.Shape of
      gshCircle:
        Canvas.Ellipse(Rect);
      gshSquare:
        Canvas.Rectangle(Rect);
      gshTriangle:
        Triangle(Canvas, Rect);
    end;
  end;

var
  Handled: Boolean;
  MMPt: TPoint;
  MapMarkRect, GlyphRect: TRect;
  pEffGlStyle: PMapMarkGlyphStyle;
  pEffCapStyle: PMapMarkCaptionStyle;
  CapFont: TFont;
  bmpGlyph: TBitmap;
begin
  MMPt := MapToCanvas(GeoCoordsToMap(MapMark.Coord), Canvas);

  // Let the user modify properties or handle drawing completely
  if Assigned(FOnDrawMapMark) then
  begin
    Handled := False;
    FOnDrawMapMark(Self, Canvas, MMPt, MapMark, Handled);
    if Handled then Exit;
    if not MapMarkVisible(MapMark) then Exit; // user could have changed visibility properties
  end;

  // Draw glyph

  // Let the user handle glyph drawing
  Handled := False;
  if Assigned(FOnDrawMapMarkGlyph) then
    FOnDrawMapMarkGlyph(Self, Canvas, MMPt, MapMark, Handled);

  if not Handled then
  begin
    // Determine effective glyph style
    if propGlyphStyle in MapMark.CustomProps
      then pEffGlStyle := @MapMark.GlyphStyle
      else pEffGlStyle := @MapMarkGlyphStyle;

    // Determine rounding rect of glyph with mapmark's coords as center point
    MapMarkRect := RectByCenterAndSize(MMPt, pEffGlStyle.Size);

    // Draw glyph with opacity - via temporary bitmap
    if pEffGlStyle.Opacity < High(TOpacity) then
    begin
      GlyphRect := Rect(0, 0, MapMarkRect.Width, MapMarkRect.Height);
      // Warning: opacity doesn't work in this code! TODO
      bmpGlyph := TBitmap.Create;
      bmpGlyph.Transparent := True;
      bmpGlyph.TransparentMode := tmFixed;
      bmpGlyph.TransparentColor := clWhite;
      bmpGlyph.SetSize(GlyphRect.Width, GlyphRect.Height);
      DrawGlyph(bmpGlyph.Canvas, GlyphRect, pEffGlStyle^);
      Canvas.Draw(MapMarkRect.Left, MapMarkRect.Top, bmpGlyph{$IFDEF DCC}, pEffGlStyle.Opacity{$ENDIF});
      FreeAndNil(bmpGlyph);
    end
    else
      DrawGlyph(Canvas, MapMarkRect, pEffGlStyle^);
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
  // Whole map? Just loop through all marks (faster)
  if Rect = FMapRect then
  begin
    for idx := 0 to FMapMarkList.Count - 1 do
      if MapMarkVisible(FMapMarkList[idx]) then
        DrawMapMark(Canvas, FMapMarkList[idx]);
    Exit;
  end;

  // Only a part of the map - select marks only within the area
  if FMapMarkList.Count > 0 then
  begin
    idx := -1;
    GeoRect := MapToGeoCoords(Rect);
    // Draw marks within geo rect
    repeat
      idx := FMapMarkList.Find(GeoRect, [mfoOnlyVisible], idx);
      if idx = -1 then Break;
      DrawMapMark(Canvas, FMapMarkList[idx]);
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
      Rect.Left + Integer(FLabelMargin),
      Rect.Bottom - FScaleLine.Height - Integer(FLabelMargin),
      FScaleLine
    );
  end;
end;

// Draw one track on canvas inside specified rect
procedure TMapControl.DrawTrack(Canvas: TCanvas; const Track: TTrack);
var
  Idx: Integer;
  NextPt: TPoint;
begin
  if not Track.Visible then Exit;
  if not (Track.Layer in VisibleLayers) then Exit;

  if Length(Track.Points) <= 1 then Exit;

  Canvas.Pen.Color := Track.LineDrawProps.Color;
  Canvas.Pen.Width := Track.LineDrawProps.Width;
  Canvas.Pen.Style := Track.LineDrawProps.Style;
  Canvas.PenPos := MapToCanvas(GeoCoordsToMap(Track.Points[0]), Canvas);

  for Idx := Low(Track.Points) + 1 to High(Track.Points) do
  begin
    NextPt := MapToCanvas(GeoCoordsToMap(Track.Points[Idx]), Canvas);
    Canvas.LineTo(NextPt.X, NextPt.Y);
  end;
end;

// Draw all tracks on canvas inside specified rect
procedure TMapControl.DrawTracks(Canvas: TCanvas);
var Idx: Integer;
begin
  for Idx := 0 to Tracks.Count - 1 do
    DrawTrack(Canvas, Tracks[Idx]);
end;

function TMapControl.SaveToBitmap(const SaveRect: TRect; DrawOptions: TMapOptions; DrawMapMarks: Boolean): TBitmap;
var
  TileAlignedSaveRect, DestRect: TRect;
  HorzCount, VertCount, horz, vert, HorzStartNum, VertStartNum: Integer;
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
        raise Exception.CreateFmt(S_Err_TileUnavail,
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
  Result := SaveToBitmap(FMapRect, DrawOptions, DrawMapMarks);
end;

end.
