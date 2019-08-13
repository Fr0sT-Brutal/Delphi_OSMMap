unit MainUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Buttons, Vcl.StdCtrls, Math, Types,
  OSM.SlippyMapUtils, OSM.MapControl, OSM.TileStorage,
  OSM.NetworkRequest, {SynapseRequest,} WinInetRequest;

const
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
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure mMapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);

    procedure mMapGetTile(Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal; out TileBmp: TBitmap);
    procedure MsgGotTile(var Message: TMessage); message MSG_GOTTILE;
    procedure NetReqGotTile(const Tile: TTile; Ms: TMemoryStream; const Error: string);
    procedure mMapZoomChanged(Sender: TObject);
    procedure mMapSelectionBox(Sender: TMapControl; const GeoRect: TGeoRect);
    procedure Button2Click(Sender: TObject);
    procedure btnMouseModePanClick(Sender: TObject);
    procedure btnMouseModeSelClick(Sender: TObject);
  private
    NetworkRequest: TNetworkRequestQueue;
    TileStorage: TTileStorage;
    procedure Log(const s: string);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  // Memory/disc cache of tile images
  // You probably won't need it if you have another fast storage (f.e. database)
  TileStorage := TTileStorage.Create(30);
  TileStorage.FileCacheBaseDir := ExpandFileName('..\Map\');
  // Queuer of tile image network requests
  // You won't need it if you have another source (f.e. database)
  NetworkRequest := TNetworkRequestQueue.Create(4, 3, {}{SynapseRequest.}WinInetRequest.NetworkRequest, NetReqGotTile);

  mMap.OnGetTile := mMapGetTile;
  mMap.OnZoomChanged := mMapZoomChanged;
  mMap.OnSelectionBox := mMapSelectionBox;
  mMap.SetZoom(1);
  mMap.MaxZoom := 10;
  mMap.MapMarkCaptionFont.Style := [fsItalic, fsBold];
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  //...
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(NetworkRequest);
  FreeAndNil(TileStorage);
end;

procedure TMainForm.Log(const s: string);
begin
  mLog.Lines.Add(DateTimeToStr(Now)+' '+s);
  OutputDebugString(PChar(DateTimeToStr(Now)+' '+s));
end;

// Callback from map control to receive a tile image
procedure TMainForm.mMapGetTile(Sender: TMapControl; TileHorzNum, TileVertNum: Cardinal; out TileBmp: TBitmap);
var
  Tile: TTile;
begin
  Tile.Zoom := Sender.Zoom;
  Tile.ParameterX := TileHorzNum;
  Tile.ParameterY := TileVertNum;

  // Query tile from storage
  TileBmp := TileStorage.GetTile(Tile);

  // Tile image unavailable - queue network request
  if TileBmp = nil then
  begin
    NetworkRequest.RequestTile(Tile);
    Log(Format('Queued request from inet %s', [TileToStr(Tile)]));
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
procedure TMainForm.NetReqGotTile(const Tile: TTile; Ms: TMemoryStream; const Error: string);
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
  FreeAndNil(pData.Ms);
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
          NetworkRequest.RequestTile(tile);
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

end.

