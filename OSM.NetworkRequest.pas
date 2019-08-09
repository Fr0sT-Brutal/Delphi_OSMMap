{
  Generic (no real network implementation) classes and declarations for
  requesting OSM tile images from network.
  Real network function from any network must be supplied to actually execute request.
}
unit OSM.NetworkRequest;

interface

uses
  SysUtils, Classes, Contnrs,
  OSM.SlippyMapUtils;

type
  THttpRequestType = (reqPost, reqGet);

  THttpRequestProps = record
    RequestType: THttpRequestType;
    URL: string;
    POSTData: string;
    HttpUserName: string;
    HttpPassword: string;
    HeaderLines: TStrings;
    Additional: Pointer;
  end;

  // Generic type of blocking network request function
  //   RequestProps - all details regarding a request
  //   ResponseStm - stream that accepts response data
  //   ErrMsg - error description if any.
  // Returns: success flag
  TBlockingNetworkRequestFunc = function (const RequestProps: THttpRequestProps;
    const ResponseStm: TStream; out ErrMsg: string): Boolean;

  // Generic type of method to call when request is completed
  // ! Called from the context of a background thread !
  TGotTileFromNetworkCallback = procedure (const Tile: TTile; Ms: TMemoryStream; const Error: string) of object;

  // Queuer of network requests
  TNetworkRequestQueue = class
  strict private
    FTaskQueue: TQueue;   // list of tiles to be requested
    FThreads: TList;
    FCurrentTasks: TList; // list of tiles that are requested but not yet received
    FNotEmpty: Boolean;

    FMaxTasksPerThread: Cardinal;
    FMaxThreads: Cardinal;
    FGotTileCb: TGotTileFromNetworkCallback;
    FRequestFunc: TBlockingNetworkRequestFunc;
    procedure Lock;
    procedure Unlock;
    procedure AddThread;
  private
    // for access from TNetworkRequestThread
    procedure DoRequestComplete(Sender: TThread; const Tile: TTile; Ms: TMemoryStream; const Error: string);
    function PopTask: Pointer;

    property NotEmpty: Boolean read FNotEmpty;
    property RequestFunc: TBlockingNetworkRequestFunc read FRequestFunc;
  public
    constructor Create(MaxTasksPerThread, MaxThreads: Cardinal;
      RequestFunc: TBlockingNetworkRequestFunc;
      GotTileCb: TGotTileFromNetworkCallback);
    destructor Destroy; override;

    procedure RequestTile(const Tile: TTile);
  end;

implementation

type
  // Thread that consumes tasks from owner's queue and executes them
  // When there are no tasks in the queue, it finishes and must be destroyed
  TNetworkRequestThread = class(TThread)
  strict private
    FOwner: TNetworkRequestQueue;
  public
    constructor Create(Owner: TNetworkRequestQueue);
    procedure Execute; override;
  end;

{ TNetworkRequestThread }

constructor TNetworkRequestThread.Create(Owner: TNetworkRequestQueue);
begin
  FOwner := Owner;
  inherited Create(False);
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
  ReqProps.RequestType := reqGet;

  while not Terminated do
  begin
    pT := PTile(FOwner.PopTask);
    if pT <> nil then
    begin
      tile := pT^;
      sURL := TileToFullSlippyMapFileURL(tile);
      ms := TMemoryStream.Create;
      ReqProps.URL := sURL;
      if not FOwner.RequestFunc(ReqProps, ms, sErrMsg) then
        FreeAndNil(ms)
      else
        ms.Position := 0;

      FOwner.DoRequestComplete(Self, tile, ms, sErrMsg);
    end;
  end;
end;

{ TNetworkRequestQueue }

//   MaxTasksPerThread - if TaskCount > MaxTasksPerThread*ThreadCount, add one more thread
//   MaxThreads - limit the number of threads
//   GotTileCb - method to call when request is completed
constructor TNetworkRequestQueue.Create(MaxTasksPerThread, MaxThreads: Cardinal;
  RequestFunc: TBlockingNetworkRequestFunc; GotTileCb: TGotTileFromNetworkCallback);
begin
  FTaskQueue := TQueue.Create;
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
end;

procedure TNetworkRequestQueue.Lock;
begin
  System.TMonitor.Enter(Self);
end;

procedure TNetworkRequestQueue.Unlock;
begin
  System.TMonitor.Exit(Self);
end;

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
var
  pT: PTile;
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

procedure TNetworkRequestQueue.AddThread;
begin
  Lock;
  try
    FThreads.Add(TNetworkRequestThread.Create(Self));
  finally
    Unlock;
  end;
end;

// Extract next item from queue
// ! Executed from bg threads
function TNetworkRequestQueue.PopTask: Pointer;
begin
  // Fast check
  if not NotEmpty then
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
var
  idx: Integer;
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
  FGotTileCb(Tile, Ms, Error);
end;

end.
