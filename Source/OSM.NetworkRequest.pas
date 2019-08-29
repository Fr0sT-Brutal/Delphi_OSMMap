{
  Generic (no real network implementation) classes and declarations for
  requesting OSM tile images from network.
  Real network function from any framework must be supplied to actually execute request.

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.NetworkRequest;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  SysUtils, Classes, Contnrs, SyncObjs,
  OSM.SlippyMapUtils;

type
  // Generic properties of request
  THttpRequestProps = record
    URL: string;
    HttpUserName: string;
    HttpPassword: string;
    HeaderLines: TStrings;
    Additional: Pointer;
  end;

  // Generic type of blocking network request function
  //   @param RequestProps - all details regarding a request
  //   @param ResponseStm - stream that accepts response data
  //   @param ErrMsg - [OUT] error description if any
  //   @returns success flag
  TBlockingNetworkRequestFunc = function (const RequestProps: THttpRequestProps;
    const ResponseStm: TStream; out ErrMsg: string): Boolean;

  // Generic type of method to call when request is completed @br
  // ! **Called from the context of a background thread** !
  //   @param Tile - tile that has been received
  //   @param Ms - stream with tile image data
  //   @param Error - error description if any
  TGotTileCallbackBgThr = procedure (const Tile: TTile; Ms: TMemoryStream; const Error: string) of object;

  // Queuer of network requests. Under the hood uses multiple background threads
  // to execute several blocking requests at the same time.
  TNetworkRequestQueue = class
  strict private
    FTaskQueue: TQueue;   // list of tiles to be requested
    FCS: TCriticalSection;
    FThreads: TList;
    FCurrentTasks: TList; // list of tiles that are requested but not yet received
    FNotEmpty: Boolean;
    FDestroying: Boolean; // object is being destroyed, do cleanup, don't call any callbacks

    FMaxTasksPerThread: Cardinal;
    FMaxThreads: Cardinal;
    FGotTileCb: TGotTileCallbackBgThr;
    FRequestFunc: TBlockingNetworkRequestFunc;
    procedure Lock;
    procedure Unlock;
    procedure AddThread;
    procedure DoRequestComplete(Sender: TThread; const Tile: TTile; Ms: TMemoryStream; const Error: string);
  private // for access from TNetworkRequestThread
    function PopTask: Pointer;
  public
    // Constructor
    //   @param(MaxTasksPerThread - if number of tasks becomes more than
    //     `MaxTasksPerThread*%currentThreadCount%`, add one more thread)
    //   @param MaxThreads - limit of the number of threads
    //   @param GotTileCb - method to call when request is completed
    constructor Create(MaxTasksPerThread, MaxThreads: Cardinal;
      RequestFunc: TBlockingNetworkRequestFunc;
      GotTileCb: TGotTileCallbackBgThr);
    destructor Destroy; override;

    // Add request for an image for `Tile` to request queue
    procedure RequestTile(const Tile: TTile);
  end;

implementation

type
  TOnRequestComplete = procedure(Sender: TThread; const Tile: TTile; Ms: TMemoryStream; const Error: string) of object;

  // Thread that consumes tasks from owner's queue and executes them
  // When there are no tasks in the queue, it finishes and must be destroyed
  TNetworkRequestThread = class(TThread)
  strict private
    FOwner: TNetworkRequestQueue;
    FOnRequestComplete: TOnRequestComplete;
    FRequestFunc: TBlockingNetworkRequestFunc;
  public
    constructor Create(Owner: TNetworkRequestQueue; RequestFunc: TBlockingNetworkRequestFunc);
    procedure Execute; override;
    property OnRequestComplete: TOnRequestComplete read FOnRequestComplete write FOnRequestComplete;
  end;

{ TNetworkRequestThread }

constructor TNetworkRequestThread.Create(Owner: TNetworkRequestQueue; RequestFunc: TBlockingNetworkRequestFunc);
begin
  inherited Create(True);
  FOwner := Owner;
  FRequestFunc := RequestFunc;
end;

procedure TNetworkRequestThread.Execute;
var
  pT: PTile;
  tile: TTile;
  sURL, sErrMsg: string;
  ms: TMemoryStream;
  ReqProps: THttpRequestProps;
begin
  ReqProps := Default(THttpRequestProps);

  while not Terminated do
  begin
    pT := PTile(FOwner.PopTask);
    if pT <> nil then
    begin
      tile := pT^;
      sURL := TileToFullSlippyMapFileURL(tile);
      ms := TMemoryStream.Create;
      ReqProps.URL := sURL;
      if not FRequestFunc(ReqProps, ms, sErrMsg) then
        FreeAndNil(ms)
      else
        ms.Position := 0;

      if Assigned(FOnRequestComplete) then
        FOnRequestComplete(Self, tile, ms, sErrMsg);
    end;
  end;
end;

{ TNetworkRequestQueue }

constructor TNetworkRequestQueue.Create(MaxTasksPerThread, MaxThreads: Cardinal;
  RequestFunc: TBlockingNetworkRequestFunc; GotTileCb: TGotTileCallbackBgThr);
begin
  FTaskQueue := TQueue.Create;
  FCS := TCriticalSection.Create;
  FThreads := TList.Create;
  FCurrentTasks := TList.Create;
  FMaxTasksPerThread := MaxTasksPerThread;
  FMaxThreads := MaxThreads;
  FGotTileCb := GotTileCb;
  FRequestFunc := RequestFunc;
end;

destructor TNetworkRequestQueue.Destroy;
var i: Integer;
begin
  FDestroying := True;

  // Command the threads to stop, wait and destroy them
  for i := 0 to FThreads.Count - 1 do
    TThread(FThreads[i]).Terminate;
  for i := 0 to FThreads.Count - 1 do
    TThread(FThreads[i]).WaitFor;
  for i := 0 to FThreads.Count - 1 do
    if TThread(FThreads[i]).Finished then
      TThread(FThreads[i]).Free
    else
      raise Exception.Create('Thread was not finished');
  FreeAndNil(FThreads);

  // Data cleanup
  while FTaskQueue.Count > 0 do
    Dispose(PTile(FTaskQueue.Pop));
  FreeAndNil(FTaskQueue);
  for i := 0 to FCurrentTasks.Count - 1 do
    Dispose(PTile(FCurrentTasks[0]));
  FreeAndNil(FCurrentTasks);
  FreeAndNil(FCS);
end;

procedure TNetworkRequestQueue.Lock;
begin
  FCS.Enter;
end;

procedure TNetworkRequestQueue.Unlock;
begin
  FCS.Leave;
end;

// Search for tile in list
function IndexOfTile(const Tile: TTile; List: TList): Integer;
begin
  for Result := 0 to List.Count - 1 do
    if TilesEqual(Tile, PTile(List[Result])^) then
      Exit;
  Result := -1;
end;

type
  TQueueHack = class(TQueue) end;

procedure TNetworkRequestQueue.RequestTile(const Tile: TTile);
var pT: PTile;
begin
  Lock;
  try
    // check if tile already in process
    if IndexOfTile(Tile, FCurrentTasks) <> -1 then
      Exit;
    // or in queue
    if IndexOfTile(Tile, TQueueHack(FTaskQueue).List) <> -1 then
      Exit;

    New(pT);
    pT^ := Tile;
    FTaskQueue.Push(pT);
    FNotEmpty := True;
    if (FTaskQueue.Count > FMaxTasksPerThread*FThreads.Count) and
      (FThreads.Count < FMaxThreads) then
      AddThread;
  finally
    Unlock;
  end;
end;

// Create new thread and add to list
procedure TNetworkRequestQueue.AddThread;
var thr: TNetworkRequestThread;
begin
  Lock;
  try
    thr := TNetworkRequestThread.Create(Self, FRequestFunc);
    thr.OnRequestComplete := DoRequestComplete;
    thr.Start;
    FThreads.Add(thr);
  finally
    Unlock;
  end;
end;

// Extract next item from queue
// ! Executed from bg threads
function TNetworkRequestQueue.PopTask: Pointer;
begin
  // Fast check
  if not FNotEmpty then
    Exit(nil);

  Lock;
  try
    if FTaskQueue.Count > 0 then
    begin
      Result := FTaskQueue.Pop;
      FCurrentTasks.Add(Result);
    end
    else
      Result := nil;
    FNotEmpty := (FTaskQueue.Count > 0);
  finally
    Unlock;
  end;
end;

// Network request complete
// ! Executed from bg threads
procedure TNetworkRequestQueue.DoRequestComplete(Sender: TThread; const Tile: TTile; Ms: TMemoryStream; const Error: string);
var idx: Integer;
begin
  Lock;
  try
    idx := IndexOfTile(Tile, FCurrentTasks);
    Dispose(PTile(FCurrentTasks[idx]));
    FCurrentTasks.Delete(idx);
    if Sender.Finished then
    begin
      Sender.Free;
      FThreads.Delete(FThreads.IndexOf(Sender));
    end;
  finally
    Unlock;
  end;

  // Run callback or just cleanup
  if not FDestroying
    then FGotTileCb(Tile, Ms, Error)
    else FreeAndNil(Ms);
end;

end.
