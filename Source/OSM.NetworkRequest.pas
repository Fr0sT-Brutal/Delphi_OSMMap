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

const
  // Prefix to add to proxy URLs if it only contains host:port - some URL parsers
  // handle such inputs as proto:path
  HTTPProxyProto = 'http://';
  // Internal constant to designate OS-wide proxy
  SystemProxy = HTTPProxyProto + 'SYSTEM';
  // Timeout for connect and request
  ReqTimeout = 5*MSecsPerSec;

type
  // Capabilities that a network engine has
  THttpRequestCapabilities =
  (
    htcProxy,        // Can use custom HTTP CONNECT proxy
    htcDirect,       // Can force direct connect bypassing OS-wide proxy
    htcSystemProxy,  // Can use OS-wide proxy
    htcProxyAuth,    // Support auth to proxy defined in URL
    htcAuth,         // Support auth to host
    htcAuthURL,      // Support auth to host defined in URL
    htcHeaders,      // Support sending custom headers
    htcTimeout,      // Support request timeout
    htcTLS           // Support HTTPS
  );

  // Generic properties of request. All of them except URL are **common** - could be set once
  // and applied to all requests
  THttpRequestProps = class
  public
    // `[http://]host:port` Address of HTTP (CONNECT) proxy, protocol is optional.         @br
    // Direct connection if empty. If equals to SystemProxy, OS-wide value is used.        @br
    // Could contain login in the form `user:pass@@host:port`.
    Proxy: string;
    // HTTP URL to access.
    // Could contain login in the form `proto://user:pass@@url` overriding `HttpUserName`
    // and `HttpPassword` fields.
    URL: string;
    // Access login name.
    HttpUserName: string;
    // Access login pass.
    HttpPassword: string;
    // HTTP header.
    HeaderLines: TStrings;
    // Any data that request function could use
    Additional: Pointer;

    destructor Destroy; override;
    // Create modifiable copy
    function Clone: THttpRequestProps; virtual;
  end;

  // Generic type of blocking network request function.
  // Function must:
  //
  //   - Ensure URL requisites have priority over field requisites
  //   - Set timeouts for request to ReqTimeout
  //   - Not raise any exception
  //   - Check response code
  //
  //   @param RequestProps - all details regarding a request
  //   @param ResponseStm - stream that accepts response data
  //   @param ErrMsg - [OUT] error description if any
  //   @returns success flag
  TBlockingNetworkRequestFunc = function (RequestProps: THttpRequestProps;
    ResponseStm: TStream; out ErrMsg: string): Boolean;

  // Generic type of method to call when request is completed @br
  // ! **Called from the context of a background thread** !
  //   @param Tile - tile that has been received
  //   @param Ms - stream with tile image data. In case of error, it could be @nil even if Error is empty
  //   @param Error - error description if any
  TGotTileCallbackBgThr = procedure (const Tile: TTile; Ms: TMemoryStream; const Error: string) of object;

  // Queuer of network requests. Under the hood uses multiple background threads
  // to execute several blocking requests at the same time.
  TNetworkRequestQueue = class
  strict private
    FTaskQueue: TQueue;   // list of tiles to be requested
    FRequestProps: THttpRequestProps;
    FCS: TCriticalSection;
    FThreads: TList;
    FCurrentTasks: TList; // list of tiles that are requested but not yet received
    FNotEmpty: Boolean;   // flag that queue is not empty for quick check
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
    function PopTask(out pTile: PTile; out RequestProps: THttpRequestProps): Boolean;
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

    property RequestProps: THttpRequestProps read FRequestProps write FRequestProps;
  end;

const
  // Headers that you could add to TNetworkRequestQueue. F.ex., openstreetmap.org
  // dislikes requests without user-agent.
  SampleHeaders: array[0..2] of string =
  (
    'User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; rv:51.0) Gecko/20100101 Firefox/51.0',
    'Accept-Language: en-US;q=0.7,en;q=0.3',
    'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
  );

implementation

type
  // Thread has completed a request.
  // Ms could be nil or empty even if Error is not set
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

{ THttpRequestProps }

destructor THttpRequestProps.Destroy;
begin
  FreeAndNil(HeaderLines);
  inherited;
end;

function THttpRequestProps.Clone: THttpRequestProps;
begin
  Result := THttpRequestProps.Create;
  Result.Proxy := Proxy;
  Result.URL := URL;
  Result.HttpUserName := HttpUserName;
  Result.HttpPassword := HttpPassword;
  if HeaderLines <> nil then
  begin
    Result.HeaderLines := TStringList.Create;
    Result.HeaderLines.Assign(HeaderLines);
  end;
  Result.Additional := Additional;
end;

{ TNetworkRequestThread }

constructor TNetworkRequestThread.Create(Owner: TNetworkRequestQueue; RequestFunc: TBlockingNetworkRequestFunc);
begin
  inherited Create(True);
  FOwner := Owner;
  FRequestFunc := RequestFunc;
end;

// Extracts tiles to bу downloaded from the queue, finishes when there are no more tiles
procedure TNetworkRequestThread.Execute;
var
  pT: PTile;
  tile: TTile;
  sErrMsg: string;
  ms: TMemoryStream;
  ReqProps: THttpRequestProps;
begin
  while not Terminated do
  begin
    // Queue empty - finish thread
    if not FOwner.PopTask(pT, ReqProps) then
      Break;

    tile := pT^;
    ReqProps.URL := TileToFullSlippyMapFileURL(tile);
    // Ensure proxy URL starts with HTTP proto for parsers to handle it correctly
    if (ReqProps.Proxy <> '') and (Pos(HTTPProxyProto, ReqProps.Proxy) = 0) then
      ReqProps.Proxy := HTTPProxyProto + ReqProps.Proxy;
    ms := TMemoryStream.Create;
    if not FRequestFunc(ReqProps, ms, sErrMsg) then
      FreeAndNil(ms)
    else
      ms.Position := 0;
    FreeAndNil(ReqProps);

    if Assigned(FOnRequestComplete) then
      FOnRequestComplete(Self, tile, ms, sErrMsg)
    else // unlikely but possible
      FreeAndNil(ms)
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
  FRequestProps := THttpRequestProps.Create;
end;

destructor TNetworkRequestQueue.Destroy;
var i: Integer;
begin
  FDestroying := True;
  Lock;
  try
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
  finally
    Unlock;
  end;

  // Data cleanup
  while FTaskQueue.Count > 0 do
    Dispose(PTile(FTaskQueue.Pop));
  FreeAndNil(FTaskQueue);
  for i := 0 to FCurrentTasks.Count - 1 do
    Dispose(PTile(FCurrentTasks[i]));
  FreeAndNil(FCurrentTasks);
  FreeAndNil(FCS);
  FreeAndNil(FRequestProps);
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
var
  pT: PTile;
  i: Integer;
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

    // check if some thread has finished
    for i := FThreads.Count - 1 downto 0 do
      if TThread(FThreads[i]).Finished then
      begin
        TThread(FThreads[i]).Free;
        FThreads.Delete(i);
      end;

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

// Extract next item from queue along with request properties.
// ! Executed from bg threads
//   @param pTile - pointer to tile to request
//   @param RequestProps - personal copy of request properties that a thread must dispose
//   @returns @True if a task was returned, @False if queue is empty
function TNetworkRequestQueue.PopTask(out pTile: PTile; out RequestProps: THttpRequestProps): Boolean;
begin
  // Fast check
  if not FNotEmpty then
    Exit(False);

  Lock;
  try
    if FTaskQueue.Count > 0 then
    begin
      pTile := FTaskQueue.Pop;
      FCurrentTasks.Add(pTile);
    end
    else
      pTile := nil;
    Result := pTile <> nil;
    if Result then
      RequestProps := FRequestProps.Clone
    else
      RequestProps := nil;
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
  // Emergency destroy - just free resources and exit to avoid deadlocks
  if FDestroying then
  begin
    FreeAndNil(Ms);
    Exit;
  end;

  Lock;
  try
    idx := IndexOfTile(Tile, FCurrentTasks);
    Dispose(PTile(FCurrentTasks[idx]));
    FCurrentTasks.Delete(idx);
  finally
    Unlock;
  end;

  FGotTileCb(Tile, Ms, Error);
end;

end.
