unit MainUnit;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

// Check whether compiler has stock HTTP request class
{$IFDEF FPC}
  {$DEFINE HAS_RTL_HTTP}
{$ENDIF}
{$IFDEF DCC}
  {$IF CompilerVersion >= 29} // XE8+
    {$DEFINE HAS_RTL_HTTP}
  {$IFEND}
{$ENDIF}

uses
  {$IFDEF FPC}
  LCLIntf, LCLType,
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  Windows,
  {$ENDIF}
  Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, ExtCtrls,
  Buttons, StdCtrls, Math, Types,
  OSM.SlippyMapUtils, OSM.MapControl, OSM.TileStorage,
  OSM.NetworkRequest
  //, OSM.NetworkRequest.Synapse // Use Synapse for HTTP requests
  {$IFDEF HAS_RTL_HTTP}
  , OSM.NetworkRequest.RTL // Use stock RTL classes for HTTP requests
  {$ELSE}
  , OSM.NetworkRequest.WinInet // Use WinInet (Windows only) for HTTP requests
  {$ENDIF}
  , OSM.TilesProvider
  , OSM.TilesProvider.OSM
  , OSM.TilesProvider.OpenTopoMap
  , OSM.TilesProvider.Google
  , OSM.TilesProvider.HERE
  , TestSuite;

const
  {$IF NOT DECLARED(WM_APP)}
  WM_APP = $8000;
  {$IFEND}
  MSG_GOTTILE = WM_APP + 200;

  MaxLayer = 4;

type
  // Nice trick to avoid registering TMapControl as design-time component
  TScrollBox = class(TMapControl)
  end;

  TGotTileData = record
    Tile: TTile;
    Ms: TMemoryStream;
    Error: string;
  end;
  PGotTileData = ^TGotTileData;

  { TMainForm }

  TMainForm = class(TForm)
    Panel1: TPanel;
    mMap: TScrollBox;
    mLog: TMemo;
    Panel2: TPanel;
    Panel3: TPanel;
    lblZoom: TLabel;
    btnZoomIn: TSpeedButton;
    btnZoomOut: TSpeedButton;
    Panel4: TPanel;
    Label3: TLabel;
    btnMouseModePan: TSpeedButton;
    btnMouseModeSel: TSpeedButton;
    Panel5: TPanel;
    rgProxy: TRadioGroup;
    eProxyAddr: TEdit;
    cbProvider: TComboBox;
    Panel6: TPanel;
    Label6: TLabel;
    btnSaveView: TButton;
    btnAddRandomMapMarks: TButton;
    btnTest: TButton;
    chbLayer1: TCheckBox;
    chbLayer2: TCheckBox;
    chbLayer4: TCheckBox;
    chbLayer3: TCheckBox;
    btnSaveMap: TButton;
    btnAddRoute: TButton;
    chbCustomPaint: TCheckBox;
    Panel7: TPanel;
    Label4: TLabel;
    Label5: TLabel;
    editLatitude: TEdit;
    editLongitude: TEdit;
    btnGoLatLong: TButton;
    Panel8: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    chbCacheUseFiles: TCheckBox;
    chbCacheSaveFiles: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
    procedure btnSaveMapClick(Sender: TObject);
    procedure MsgGotTile(var Message: TMessage); message MSG_GOTTILE;
    procedure NetReqGotTileBgThr(const Tile: TTile; Ms: TMemoryStream; const Error: string);
    procedure mMapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure mMapMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    function mMapGetTile(Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal): TBitmap;
    procedure mMapDrawTile(Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas; var Handled: Boolean);
    procedure mMapZoomChanged(Sender: TObject);
    procedure mMapSelectionBox(Sender: TMapControl; const GeoRect: TGeoRect; Finish: Boolean);
    procedure mMapDrawLayer(Sender: TMapControl; Layer: TMapLayer; Canvas: TCanvas; const CanvasRect, MapInViewRect: TRect);
    procedure btnAddRandomMapMarksClick(Sender: TObject);
    procedure btnMouseModePanClick(Sender: TObject);
    procedure btnMouseModeSelClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure btnGoLatLongClick(Sender: TObject);
    procedure chbCacheUseFilesClick(Sender: TObject);
    procedure chbCacheSaveFilesClick(Sender: TObject);
    procedure chbLayer1Click(Sender: TObject);
    procedure btnSaveViewClick(Sender: TObject);
    procedure cbProviderChange(Sender: TObject);
    procedure btnAddRouteClick(Sender: TObject);
    procedure chbCustomPaintClick(Sender: TObject);
  private
    NetRequest: TNetworkRequestQueue;
    TileStorage: TTileStorage;
    MouseLBMode: TMapMouseMode;
    procedure Log(const s: string);
    procedure SetTilesProvider(TilesProviderClass: TTilesProviderClass);
  end;

  { TMapTestCase }

  TMapTestCase = class(TTestSuite)
  private
    FMap: TMapControl;
  public
    constructor Create(Map: TMapControl; LogProc: TLogProc);
    procedure Setup; override;
    procedure Teardown; override;
    // Tests
    procedure TestZoom;
    procedure TestPosition;
  end;

var
  MainForm: TMainForm;

implementation

// ! This should be (IFDEF FPC => $R *.lfm); (IFDEF DCC => $R *.dfm) but XE2-10.1
// cannot handle it and disables form view. So using ELSE

{$IFDEF FPC}
  {$R *.lfm}
{$ELSE}
  {$R *.dfm}
{$ENDIF}

const
  // Just a random point to init "locate coord" edits
  LocateLong = 115.8570;
  LocateLat = -31.9535;

function RandomGeoPoint: TGeoPoint;
begin
  Result := TGeoPoint.Create(
    RandomRange(Trunc(MinLong), Trunc(MaxLong)),
    RandomRange(Trunc(MinLat), Trunc(MaxLat)))
end;

function RandomColor: TColor;
const
  Colors: array[0..6] of TColor = (clRed, clYellow, clGreen, clBlue, clBlack, clLime, clPurple);
begin
  Result := Colors[Random(High(Colors) + 1)];
end;

{ TTestSuite }

constructor TMapTestCase.Create(Map: TMapControl; LogProc: TLogProc);
begin
  inherited Create(LogProc, [TestZoom, TestPosition]);
  FMap := Map;
end;

procedure TMapTestCase.Setup;
const
  StdMapSize: TSize = (cx: 800; cy: 800); // between zoom 1 and 2
var
  ClRect: TRect;
  Form: TForm;
begin
  // Setup
  FMap.MinZoom := 1;
  FMap.MaxZoom := High(TMapZoomLevel);;
  FMap.SetZoom(1);
  FMap.MapMarkCaptionFont.Style := [];
  FMap.OnDrawTile := nil;
  FMap.OnZoomChanged := nil;
  FMap.OnSelectionBox := nil;

  ClRect := FMap.ClientRect;
  Form := FMap.Owner as TForm;
  Form.Left := 0;
  Form.Top := 0;
  Form.Width := Form.Width - (ClRect.Width - StdMapSize.cx);
  Form.Height := Form.Height - (ClRect.Height - StdMapSize.cy);
end;

// Return all changed values
procedure TMapTestCase.Teardown;
var Form: TMainForm;
begin
  Form := FMap.Owner as TMainForm;
  FMap.OnDrawTile := Form.mMapDrawTile;
  FMap.OnZoomChanged := Form.mMapZoomChanged;
  FMap.OnSelectionBox := Form.mMapSelectionBox;
  FMap.MapMarkCaptionFont.Style := [fsItalic, fsBold];
  FMap.SetZoom(1);

  // TODO Return form bounds, etc...
end;

procedure TMapTestCase.TestZoom;
var
  OldZoom, OldMinZoom, OldMaxZoom: TMapZoomLevel;
begin
  // Save props
  OldZoom := FMap.Zoom;
  OldMinZoom := FMap.MinZoom;
  OldMaxZoom := FMap.MaxZoom;

  // Test Min/max zoom
  try
    FMap.MinZoom := 2;
    Assert(FMap.Zoom = 2);
    FMap.SetZoom(1);
    Assert(FMap.Zoom = 2);

    FMap.SetZoom(4);
    FMap.MaxZoom := 3;
    Assert(FMap.Zoom = 3);
    FMap.SetZoom(4);
    Assert(FMap.Zoom = 3);
  finally
    // Restore props
    FMap.MinZoom := OldMinZoom;
    FMap.MaxZoom := OldMaxZoom;
    FMap.SetZoom(OldZoom);
  end;
end;

procedure TMapTestCase.TestPosition;
var
  OldZoom: TMapZoomLevel;
begin
  // Save props
  OldZoom := FMap.Zoom;

  // Test scrolling and positions
  try
    FMap.SetZoom(3);
    FMap.ScrollMapTo(100, 50);
    Assert(PointsEqual(FMap.ViewRect.TopLeft, Point(100, 50)));
    FMap.ScrollMapBy(100, 50);
    Assert(PointsEqual(FMap.ViewRect.TopLeft, Point(200, 100)));
  finally
    // Restore props
    FMap.ScrollMapTo(0, 0);
    FMap.SetZoom(OldZoom);
  end;
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var tpc: TTilesProviderClass;
begin
  MouseLBMode := mmDragging;
  mMap.SelectionShiftState := [ssLeft, ssShift];
  mMap.DragShiftState := [ssRight];
  mMap.OnDrawTile := mMapDrawTile;
  mMap.OnZoomChanged := mMapZoomChanged;
  mMap.OnSelectionBox := mMapSelectionBox;
  mMap.OnDrawLayer := mMapDrawLayer;
  mMap.MapMarkCaptionFont.Style := [fsItalic, fsBold];
  // Memory/disc cache of tile images
  // You probably won't need it if you have another fast storage (f.e. database)
  TileStorage := TTileStorage.Create(50*1000*1000);
  for tpc in TilesProviders do
    cbProvider.Items.Add(tpc.Name);
  cbProvider.ItemIndex := 0;
  cbProvider.OnChange(cbProvider);
  editLongitude.Text := FloatToStr(LocateLong);
  editLatitude.Text := FloatToStr(LocateLat);
  mMap.SetZoom(1);
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  //...
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(NetRequest);
  FreeAndNil(TileStorage);
end;

procedure TMainForm.Log(const s: string);
begin
  mLog.Lines.Add(DateTimeToStr(Now) + ' ' + s);
  {$IF DECLARED(OutputDebugString)}
  OutputDebugString(PChar(DateTimeToStr(Now) + ' ' + s));
  {$IFEND}
end;

procedure TMainForm.SetTilesProvider(TilesProviderClass: TTilesProviderClass);
var
  s: string;
  provider: TTilesProvider;
begin
  // To check provider features, we have to create an instance
  provider := TilesProviderClass.Create;

  if tpfRequiresAPIKey in provider.Features then
  begin
    provider.APIKey := InputBox('API key required', 'Enter API key', '');
    if provider.APIKey = '' then
    begin
      FreeAndNil(provider);
      Abort;
    end;
  end;

  TileStorage.FileCacheBaseDir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) +
    'Map' + PathDelim + TilesProviderClass.Name;
  // Queuer of tile image network requests
  // You won't need it if you have another source (f.e. database)
  FreeAndNil(NetRequest);
  NetRequest := TNetworkRequestQueue.Create(4, 3, NetworkRequest, provider.Clone);
  NetRequest.RequestProps.HeaderLines := TStringList.Create;
  NetRequest.OnGotTileBgThr := NetReqGotTileBgThr;
  for s in SampleHeaders do
    NetRequest.RequestProps.HeaderLines.Add(s);
  mMap.TilesProvider := provider;
end;

function TMainForm.mMapGetTile(Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal): TBitmap;
var
  Tile: TTile;
begin
  Tile.Zoom := Sender.Zoom;
  Tile.ParameterX := TileHorzNum;
  Tile.ParameterY := TileVertNum;

  // Query tile from storage
  Result := TileStorage.GetTile(Tile);

  // Tile image unavailable - queue network request
  if Result = nil then
  begin
    // Network setup
    case rgProxy.ItemIndex of
      0: NetRequest.RequestProps.Proxy := '';
      1: NetRequest.RequestProps.Proxy := SystemProxy;
      2: NetRequest.RequestProps.Proxy := eProxyAddr.Text;
    end;
    // Set current view area of the map so that tiles inside it will be downloaded first.
    // This could be done in map's OnScroll event as well
    NetRequest.SetCurrentViewRect(Sender.ViewRect);
    NetRequest.RequestTile(Tile);
    // ! Demo logging. Adds visual glitch when doing fast panning so disable it
    // to get smooth performance.
    Log(Format('Queued request from inet %s', [TileToStr(Tile)]));
  end;
end;

// Callback from map control to draw a tile image
// ! This method is here for demo purposes only - it will only be called for
// currently unavailable tiles that likely are queued for download.
procedure TMainForm.mMapDrawTile(Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas; var Handled: Boolean);
var TileBmp: TBitmap;
begin
  TileBmp := mMapGetTile(Sender, TileHorzNum, TileVertNum);
  if TileBmp <> nil then
  begin
    Canvas.Draw(TopLeft.X, TopLeft.Y, TileBmp);
    // Canvas.Draw(TopLeft.X, TopLeft.Y, WatermarkBmp); - draw watermark, or some layer, etc
    Handled := True;
  end;
end;

procedure TMainForm.mMapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  MapPt: TPoint;
  GeoPt: TGeoPoint;
begin
  MapPt := EnsureInMap(mMap.Zoom, mMap.ViewToMap(Point(X, Y)));
  GeoPt := mMap.MapToGeoCoords(MapPt);
  Label1.Caption := Format('Pixels: %d : %d', [MapPt.X, MapPt.Y]);
  Label2.Caption := Format('Geo coords: %.3f : %.3f', [GeoPt.Long, GeoPt.Lat]);
end;

// Start selecting / dragging on LMB press
procedure TMainForm.mMapMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if ShiftStateIs(Shift, [ssLeft]) and (TMapControl(Sender).MouseMode = mmNone) then
    TMapControl(Sender).MouseMode := MouseLBMode;
end;

procedure TMainForm.mMapZoomChanged(Sender: TObject);
begin
  lblZoom.Caption := Format('%d / %d', [TMapControl(Sender).Zoom, High(TMapZoomLevel)]);
end;

// Zoom to show selected region
procedure TMainForm.mMapSelectionBox(Sender: TMapControl; const GeoRect: TGeoRect; Finish: Boolean);
begin
  if Finish then
  begin
    Log(Format('Selected region: (%.3f : %.3f; %.3f : %.3f)',
      [GeoRect.TopLeft.Long, GeoRect.TopLeft.Lat, GeoRect.BottomRight.Long, GeoRect.BottomRight.Lat]));
    Sender.ZoomToArea(GeoRect);
  end;
end;

// Callback from a thread of network requester that request has been done
// To avoid thread access troubles, re-post all the data to form
procedure TMainForm.NetReqGotTileBgThr(const Tile: TTile; Ms: TMemoryStream; const Error: string);
var
  pData: PGotTileData;
begin
  New(pData);
  pData.Tile := Tile;
  pData.Ms := Ms;
  pData.Error := Error;
  if not PostMessage(Handle, MSG_GOTTILE, 0, LPARAM(pData)) then
  begin
    Dispose(pData);
    FreeAndNil(Ms);
  end;
end;

procedure TMainForm.MsgGotTile(var Message: TMessage);
var
  pData: PGotTileData;
begin
  pData := PGotTileData(Message.LParam);
  if pData.Error <> '' then
  begin
    Log(Format('Error getting tile %s: %s', [TileToStr(pData.Tile), pData.Error]));
    FreeAndNil(pData.Ms);
  end
  else
  begin
    Log(Format('Got from inet %s', [TileToStr(pData.Tile)]));
    try
      TileStorage.StoreTile(pData.Tile, pData.Ms);
      mMap.RefreshTile(pData.Tile.ParameterX, pData.Tile.ParameterY);
    except on E: Exception do
      Log(Format('Tile %s data is not PNG: %s', [TileToStr(pData.Tile), E.Message]));
    end;
  end;
  Dispose(pData);
end;

procedure TMainForm.btnZoomInClick(Sender: TObject);
begin
  mMap.SetZoom(mMap.Zoom + 1, mMap.ViewRect.CenterPoint);
end;

procedure TMainForm.btnZoomOutClick(Sender: TObject);
begin
  mMap.SetZoom(mMap.Zoom - 1, mMap.ViewRect.CenterPoint);
end;

procedure TMainForm.btnSaveMapClick(Sender: TObject);
var bmp: TBitmap;
begin
  bmp := mMap.SaveToBitmap([], False);
  bmp.SaveToFile('Map' + IntToStr(mMap.Zoom) + '.bmp');
  ShowMessage('Saved to Map' + IntToStr(mMap.Zoom) + '.bmp');
  FreeAndNil(bmp);
end;

procedure TMainForm.btnAddRandomMapMarksClick(Sender: TObject);
var
  i: Integer;
begin
  Randomize;
  for i := 1 to 20 do
  begin
    with mMap.MapMarks.Add(RandomGeoPoint, 'Mapmark #' + IntToStr(i), Random(MaxLayer) + 1) do
    begin
      CustomProps := [propGlyphStyle, propCaptionStyle];
      GlyphStyle.Shape := TMapMarkGlyphShape(Random(Ord(High(TMapMarkGlyphShape)) + 1));
      CaptionStyle.Color := RandomColor;
    end;
  end;

  mMap.Invalidate;
end;

procedure TMainForm.btnMouseModePanClick(Sender: TObject);
begin
  MouseLBMode := mmDragging;
end;

procedure TMainForm.btnMouseModeSelClick(Sender: TObject);
begin
  MouseLBMode := mmSelecting;
end;

procedure TMainForm.btnGoLatLongClick(Sender: TObject);
var
  LGeoPoint: TGeoPoint;
begin
  LGeoPoint.Long := StrToFloat(editLongitude.Text);
  LGeoPoint.Lat := StrToFloat(editLatitude.Text);
  // Don't set smaller zoom if current is large
  if mMap.Zoom < 10 then
    mMap.SetZoom(10);
  mMap.CenterPoint := LGeoPoint;
end;

procedure TMainForm.btnTestClick(Sender: TObject);
var suite: TMapTestCase;
begin
  TileStorage.ClearCache;
  suite := TMapTestCase.Create(mMap, Log);
  suite.Run;
  FreeAndNil(suite);
  mMap.Refresh;
end;

procedure TMainForm.chbCacheUseFilesClick(Sender: TObject);
begin
  if (Sender as TCheckBox).Checked
    then TileStorage.Options := TileStorage.Options - [tsoNoFileCache]
    else TileStorage.Options := TileStorage.Options + [tsoNoFileCache];
end;

procedure TMainForm.chbCacheSaveFilesClick(Sender: TObject);
begin
  if (Sender as TCheckBox).Checked
    then TileStorage.Options := TileStorage.Options - [tsoReadOnlyFileCache]
    else TileStorage.Options := TileStorage.Options + [tsoReadOnlyFileCache];
end;

procedure TMainForm.chbLayer1Click(Sender: TObject);
begin
  // Change layer visibility defined in ChB.Tag
  with Sender as TCheckBox do
    if Checked then
      mMap.VisibleLayers := mMap.VisibleLayers + [TMapLayer(Tag)]
    else
      mMap.VisibleLayers := mMap.VisibleLayers - [TMapLayer(Tag)]
end;

procedure TMainForm.btnSaveViewClick(Sender: TObject);
var bmp: TBitmap;
begin
  bmp := mMap.SaveToBitmap(mMap.ViewRect, [], True);
  bmp.SaveToFile('View.bmp');
  ShowMessage('Saved to View.bmp');
  FreeAndNil(bmp);
end;

procedure TMainForm.cbProviderChange(Sender: TObject);
begin
  SetTilesProvider(TilesProviders[(Sender as TComboBox).ItemIndex]);
end;

procedure TMainForm.btnAddRouteClick(Sender: TObject);
const
  Points = 30;
var
  Track: TTrack;
  i: Integer;
begin
  // gen track
  Track := TTrack.Create;
  SetLength(Track.Points, Points);
  Randomize;
  for i := 0 to Points - 1 do
    Track.Points[i] := RandomGeoPoint;
  Track.Layer := Random(MaxLayer) + 1;
  Track.LineDrawProps := DefLineDrawProps;
  Track.LineDrawProps.Color := RandomColor;
  mMap.Tracks.Add(Track);
end;

procedure TMainForm.mMapDrawLayer(Sender: TMapControl; Layer: TMapLayer; Canvas: TCanvas; const CanvasRect, MapInViewRect: TRect);
const
  RectSize = 30; // Initial rect size at zoom = 1
var
  MapPt: TPoint;
  MapRect, ViewRect: TRect;
  CurrRectSize: Integer;
begin
  if not chbCustomPaint.Checked then Exit;

  // Convert geo coords to map coords
  MapPt := GeoCoordsToMap(Sender.Zoom, TGeoPoint.Create(0, 0));
  CurrRectSize := (RectSize * MapWidth(Sender.Zoom)) div MapWidth(0);
  MapRect := TRect.Create(MapPt, CurrRectSize, CurrRectSize);

  // Convert map coords to canvas coords
  ViewRect := Sender.MapToCanvas(MapRect, Canvas);

  // Paint
  Canvas.Brush.Color := clGreen;
  Canvas.FrameRect(ViewRect);
end;

procedure TMainForm.chbCustomPaintClick(Sender: TObject);
begin
  mMap.Invalidate;
end;

end.

