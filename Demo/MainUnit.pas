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
  //, SynapseRequest // Use Synapse for HTTP requests
  {$IFDEF HAS_RTL_HTTP}
  , RTLInetRequest // Use stock RTL classes for HTTP requests
  {$ELSE}
  , WinInetRequest // Use WinInet (Windows only) for HTTP requests
  {$ENDIF}
  , TestSuite;

const
  {$IF NOT DECLARED(WM_APP)}
  WM_APP = $8000;
  {$IFEND}
  MSG_GOTTILE = WM_APP + 200;

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
    Panel2: TPanel;
    Splitter1: TSplitter;
    btnZoomIn: TSpeedButton;
    btnZoomOut: TSpeedButton;
    Button1: TButton;
    mMap: TScrollBox;
    mLog: TMemo;
    Label1: TLabel;
    Label2: TLabel;
    lblZoom: TLabel;
    Button2: TButton;
    Button3: TButton;
    btnMouseModePan: TSpeedButton;
    btnMouseModeSel: TSpeedButton;
    Label3: TLabel;
    btnTest: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure MsgGotTile(var Message: TMessage); message MSG_GOTTILE;
    procedure NetReqGotTileBgThr(const Tile: TTile; Ms: TMemoryStream; const Error: string);
    procedure mMapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure mMapDrawTile(Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas; var Handled: Boolean);
    procedure mMapZoomChanged(Sender: TObject);
    procedure mMapSelectionBox(Sender: TMapControl; const GeoRect: TGeoRect);
    procedure Button2Click(Sender: TObject);
    procedure btnMouseModePanClick(Sender: TObject);
    procedure btnMouseModeSelClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
  private
    NetRequest: TNetworkRequestQueue;
    TileStorage: TTileStorage;
    procedure Log(const s: string);
    procedure InitMap;
  end;

  { TMapTestCase }

  TMapTestCase = class(TTestSuite)
  private
    FMap: TMapControl;
  public
    constructor Create(Map: TMapControl; LogProc: TLogProc);
    procedure Setup; override;
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

{ TTestSuite }

constructor TMapTestCase.Create(Map: TMapControl; LogProc: TLogProc);
begin
  inherited Create(LogProc,
    [
      TestZoom,
      TestPosition
    ]);
  FMap := Map;
end;

procedure TMapTestCase.Setup;
const
  StdMapSize: TSize = (cx: 800; cy: 800);  // between zoom 1 and 2
var
  ClRect: TRect;
  Form: TForm;
begin
  // Setup
  FMap.MinZoom := 1;
  FMap.MaxZoom := 10;
  FMap.SetZoom(1);
  FMap.MapMarkCaptionFont.Style := [];
  FMap.MouseMode := mmDrag;
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
begin
  // Memory/disc cache of tile images
  // You probably won't need it if you have another fast storage (f.e. database)
  TileStorage := TTileStorage.Create(50*1000*1000);
  TileStorage.FileCacheBaseDir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'Map';
  // Queuer of tile image network requests
  // You won't need it if you have another source (f.e. database)
  NetRequest := TNetworkRequestQueue.Create(4, 3, NetworkRequest, NetReqGotTileBgThr);
  InitMap;
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
  mLog.Lines.Add(DateTimeToStr(Now)+' '+s);
  {$IF DECLARED(OutputDebugString)}
  OutputDebugString(PChar(DateTimeToStr(Now)+' '+s));
  {$IFEND}
end;

// Extracted to separate method to re-init the control after test
procedure TMainForm.InitMap;
begin
  mMap.OnDrawTile := mMapDrawTile;
  mMap.OnZoomChanged := mMapZoomChanged;
  mMap.OnSelectionBox := mMapSelectionBox;
  mMap.SetZoom(1);
  mMap.MaxZoom := 10;
  mMap.MapMarkCaptionFont.Style := [fsItalic, fsBold];
end;

// Callback from map control to draw a tile image
procedure TMainForm.mMapDrawTile(Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal; const TopLeft: TPoint; Canvas: TCanvas; var Handled: Boolean);
var
  Tile: TTile;
  TileBmp: TBitmap;
begin
  Tile.Zoom := Sender.Zoom;
  Tile.ParameterX := TileHorzNum;
  Tile.ParameterY := TileVertNum;

  // Query tile from storage
  TileBmp := TileStorage.GetTile(Tile);

  // Tile image unavailable - queue network request
  if TileBmp = nil then
  begin
    NetRequest.RequestTile(Tile);
    Log(Format('Queued request from inet %s', [TileToStr(Tile)]));
  end
  else
  begin
    Canvas.Draw(TopLeft.X, TopLeft.Y, TileBmp);
    Handled := True;
  end;
end;

procedure TMainForm.mMapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  MapPt: TPoint;
  GeoPt: TGeoPoint;
begin
  MapPt := mMap.ViewToMap(Point(X, Y));
  MapPt.X := EnsureRange(MapPt.X, 0, MapWidth(mMap.Zoom));
  MapPt.Y := EnsureRange(MapPt.Y, 0, MapHeight(mMap.Zoom));
  GeoPt := mMap.MapToGeoCoords(MapPt);
  Label1.Caption := Format('Pixels: %d : %d', [MapPt.X, MapPt.Y]);
  Label2.Caption := Format('Geo coords: %.3f : %.3f', [GeoPt.Long, GeoPt.Lat]);
end;

procedure TMainForm.mMapZoomChanged(Sender: TObject);
begin
  lblZoom.Caption := Format('%d / %d', [TMapControl(Sender).Zoom, High(TMapZoomLevel)]);
end;

// Zoom to show selected region
procedure TMainForm.mMapSelectionBox(Sender: TMapControl; const GeoRect: TGeoRect);
begin
  Log(Format('Selected region: (%.3f : %.3f; %.3f : %.3f)',
    [GeoRect.TopLeft.Long, GeoRect.TopLeft.Lat, GeoRect.BottomRight.Long, GeoRect.BottomRight.Lat]));

  Sender.ZoomToArea(GeoRect);
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
  end
  else
  begin
    Log(Format('Got from inet %s', [TileToStr(pData.Tile)]));
    TileStorage.StoreTile(pData.Tile, pData.Ms);
    mMap.RefreshTile(pData.Tile.ParameterX, pData.Tile.ParameterY);
  end;
  Dispose(pData);
end;

procedure TMainForm.btnZoomInClick(Sender: TObject);
begin
  mMap.SetZoom(mMap.Zoom + 1);
end;

procedure TMainForm.btnZoomOutClick(Sender: TObject);
begin
  mMap.SetZoom(mMap.Zoom - 1);
end;

procedure TMainForm.Button1Click(Sender: TObject);
var
  bmp, bmTile: TBitmap;
  col, row: Integer;
  tile: TTile;
  imgAbsent: Boolean;
begin
  bmp := TBitmap.Create;
  bmp.Height := TileCount(mMap.Zoom)*TILE_IMAGE_HEIGHT;
  bmp.Width := TileCount(mMap.Zoom)*TILE_IMAGE_WIDTH;

  try
    imgAbsent := False;
    for col := 0 to TileCount(mMap.Zoom) - 1 do
      for row := 0 to TileCount(mMap.Zoom) - 1 do
      begin
        tile.Zoom := mMap.Zoom;
        tile.ParameterX := col;
        tile.ParameterY := row;
        bmTile := TileStorage.GetTile(tile);
        if bmTile = nil then
        begin
          NetRequest.RequestTile(tile);
          imgAbsent := True;
          Continue;
        end;
        bmp.Canvas.Draw(col*TILE_IMAGE_WIDTH, row*TILE_IMAGE_HEIGHT, bmTile);
      end;

    if imgAbsent then
    begin
      ShowMessage('Some images were absent');
      Exit;
    end;

    bmp.SaveToFile('Map'+IntToStr(mMap.Zoom)+'.bmp');
    ShowMessage('Saved to Map'+IntToStr(mMap.Zoom)+'.bmp');
  finally
    FreeAndNil(bmp);
  end;
end;

procedure TMainForm.Button2Click(Sender: TObject);
const
  Colors: array[0..6] of TColor = (clRed, clYellow, clGreen, clBlue, clBlack, clLime, clPurple);
var
  i: Integer;
begin
  Randomize;
  for i := 1 to 100 do
  begin
    with mMap.MapMarks.Add(TGeoPoint.Create(RandomRange(-180, 180), RandomRange(-85, 85)), 'Mapmark #' + IntToStr(i)) do
    begin
      CustomProps := [propGlyphStyle, propCaptionStyle];
      GlyphStyle.Shape := TMapMarkGlyphShape(Random(Ord(High(TMapMarkGlyphShape)) + 1));
      CaptionStyle.Color := Colors[Random(High(Colors) + 1)];
    end;
  end;

  mMap.Invalidate;
end;

procedure TMainForm.btnMouseModePanClick(Sender: TObject);
begin
  mMap.MouseMode := mmDrag;
end;

procedure TMainForm.btnMouseModeSelClick(Sender: TObject);
begin
  mMap.MouseMode := mmSelect;
end;

procedure TMainForm.btnTestClick(Sender: TObject);
var suite: TMapTestCase;
begin
  TileStorage.ClearCache;
  suite := TMapTestCase.Create(mMap, Log);
  suite.Run;
  FreeAndNil(suite);
  InitMap;
  mMap.Refresh;
end;

end.

