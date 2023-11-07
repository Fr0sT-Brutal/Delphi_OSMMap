{
  Generic (no real network implementation) classes and declarations for
  requesting OSM tile images from network.
  Real network function from any framework must be supplied to actually execute request.

  DEFINES:
    - OSM_Trace - print request trace messages to Windows debug log

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.NetworkRequest;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  {$IFDEF MSWINDOWS}
    Windows, WinInet,
  {$ENDIF}
  SysUtils, Classes, Contnrs, SyncObjs, Types, TypInfo,
  OSM.SlippyMapUtils, OSM.TilesProvider;

const
  HTTPProto = 'http';
  HTTPTLSProto = 'https';
  ProtoSep = '://';
  // Prefix to add to proxy URLs if it only contains `host:port` - some URL parsers
  // handle such inputs as `proto:path`
  HTTPProxyProto = HTTPProto + ProtoSep;
  // Internal constant to designate OS-wide proxy
  SystemProxy = HTTPProxyProto + 'SYSTEM';
  // Timeout for connect and request
  ReqTimeout = 5*MSecsPerSec;

type
  // Capabilities that a network engine has
  THttpRequestCapability =
  (
    htcProxy,        // Support HTTP proxy
    // Support direct connect bypassing OS-wide proxy. In fact,
    // only WinInet-based engines (WinInet, RTL in Windows) use
    // OS-wide proxy by default. In other engines and in Linux the proxy
    // must be set explicitly so this cap is actual for all engines.
    htcDirect,
    htcSystemProxy,  // Can use OS-wide proxy
    htcProxyAuth,    // Support auth to proxy defined in URL
    htcAuth,         // Support auth to host
    htcAuthURL,      // Support auth to host defined in URL
    htcHeaders,      // Support sending custom headers
    htcTimeout,      // Support request timeout
    htcTLS           // Support HTTPS
  );
  THttpRequestCapabilities = set of THttpRequestCapability;

  // Generic properties of request. All of them except URL are **common** - assigned once
  // and applied to all requests in current queue. Changing the properties won't take
  // effect until queue gets empty.
  THttpRequestProps = class
  public
    // HTTP URL to access.                                                          @br
    // Could contain login in the form `proto://user:pass@url` overriding `HttpUserName`
    // and `HttpPassword` fields.                                                   @br
    // Used only in TBlockingNetworkRequestProc, ignored in TNetworkRequestQueue.
    URL: string;
    // `[http://]host:port` Address of HTTP (CONNECT) proxy, protocol is optional.  @br
    // Direct connection if empty. If equals to SystemProxy, OS-wide value is used.
    // Could contain login in the form `user:pass@@host:port`.
    Proxy: string;
    // Access login name.
    HttpUserName: string;
    // Access login pass.
    HttpPassword: string;
    // HTTP header.
    HeaderLines: TStrings;
    // Any data that request function could use. Note that data MUST not change
    // as it is not copied in @link(Clone) and is being accessed from multiple threads.
    // Alternatively, @classname descendant could implement proper copying
    // in overridden @link(Clone).
    Additional: Pointer;

    destructor Destroy; override;
    // Create modifiable copy
    function Clone: THttpRequestProps; virtual;
  end;

  // Base class for network client object. Used when request queue is performed
  // through the same connection. Destructor of the object is called when the
  // queue is empty and it must free all allocated resources.
  TNetworkClient = TObject;

  // Generic type of blocking network request procedure.
  // Procedure must:
  //
  //   - Ensure URL requisites have priority over field requisites
  //   - Set timeouts for request to ReqTimeout
  //   - Raise exception on validation/connection/request error
  //   - Free all resources it has allocated
  //
  //   @param RequestProps - all details regarding a request
  //   @param ResponseStm - stream that accepts response data
  //   @param Client - [IN/OUT] If the engine supports multiple requests inside       \
  //     the same client, this parameter is the current client object. Request        \
  //     properties are supposed to remain unchanged throughout the whole queue       \
  //     (only [URL](#THttpRequestProps.URL) changes) so it's enough to assign     \
  //     them at client creation only @br \
  //     IN: client object to use for requests.                                   @br \
  //     OUT: newly created client object if `Client` was @nil at input.
  //   @raises exception on error
  TBlockingNetworkRequestProc = procedure (RequestProps: THttpRequestProps;
    ResponseStm: TStream; var Client: TNetworkClient);

  // Generic type of method to call when request is completed @br
  // ! **Called from the context of a background thread** !
  //   @param Tile - tile that has been received
  //   @param Ms - stream with tile image data. In case of error, it could be @nil even if `Error` is empty
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
    FRequestProc: TBlockingNetworkRequestProc;
    FTilesProvider: TTilesProvider;
    FDumbQueueOrder: Boolean;
    FCurrTileNumbersRect: TRect; // rect of current view set in tile numbers

    procedure Lock;
    procedure Unlock;
    procedure AddThread;
    procedure DoRequestComplete(Sender: TThread; const Tile: TTile; Ms: TMemoryStream; const Error: string);
  private // for access from TNetworkRequestThread
    function PopTask(out Tile: TTile): Boolean;
  public
    // Constructor
    //   @param MaxTasksPerThread - if number of tasks becomes more than            \
    //     `MaxTasksPerThread*%currentThreadCount%`, add one more thread
    //   @param MaxThreads - limit of the number of threads
    //   @param RequestProc - implementator of network request
    //   @param TilesProvider - object holding properties of current tile provider. \
    //     Object takes ownership on this object and destroys it on release.
    constructor Create(MaxTasksPerThread, MaxThreads: Cardinal;
      RequestProc: TBlockingNetworkRequestProc;
      TilesProvider: TTilesProvider);
    destructor Destroy; override;

    // Add request for an image for `Tile` to the request queue
    procedure RequestTile(const Tile: TTile);
    // Set current view rect in absolute map coords.
    // If smart ordering facilities are enabled, tiles inside current view have
    // priority when extracted from request queue.
    procedure SetCurrentViewRect(const ViewRect: TRect);

    // Common network request props applied to all requests in current queue.
    // Changing the properties won't take effect until queue gets empty.
    // [URL](#THttpRequestProps.URL) field is ignored.
    property RequestProps: THttpRequestProps read FRequestProps write FRequestProps;
    // If set: disable all smart ordering facilities. Queue will retrieve all added tiles
    // one by one.
    // If not set (default):
    //   - When RequestTile adds a tile, all queued items with another zoom level
    //     are cancelled (use case: user quickly zooms in/out by multiple steps -
    //     no sense to wait for all of them to download)
    //   - If current view area is set via SetCurrentViewRect, the tiles inside this
    //     rect are downloaded first (priority of visible area)
    property DumbQueueOrder: Boolean read FDumbQueueOrder write FDumbQueueOrder;
    // Handler to call when request is completed (executed in the context of background thread!)
    property OnGotTileBgThr: TGotTileCallbackBgThr read FGotTileCb write FGotTileCb;
  end;

const
  SampleUserAgent = 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:51.0) Gecko/20100101 Firefox/51.0';
  // Headers that you could add to [TNetworkRequestQueue.RequestProps.HeaderLines](#THttpRequestProps.HeaderLines).
  // F.ex., openstreetmap.org dislikes requests without user-agent.
  SampleHeaders: array[0..2] of string =
  (
    'User-Agent: ' + SampleUserAgent,
    'Accept-Language: en-US;q=0.7,en;q=0.3',
    'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
  );

// Check if capability is in set of capabilities and raise exception if not
procedure CheckEngineCap(NeededCap: THttpRequestCapability; Caps: THttpRequestCapabilities);
// Check if a network engine is capable of handling all the request properties.
// Checks for: htcProxy, htcSystemProxy, htcProxyAuth, htcAuth, htcAuthURL, htcTLS, htcHeaders.
procedure CheckEngineCaps(RequestProps: THttpRequestProps; EngineCapabilities: THttpRequestCapabilities);
// Return true if response code means HTTP error
function IsHTTPError(ResponseCode: Word): Boolean;
// Check if response code means HTTP error, raise exception then
procedure CheckHTTPError(ResponseCode: Word; const ResponseText: string);
// Retrieve system proxy for given URL (http, https). Only returns HTTP proxies (not Socks).
// On Windows uses InternetQueryOption, on Linux takes env variables `HTTP(S)_PROXY`.
// Returns addresses for direct connection in Bypass array.
function GetSystemProxy(const URL: string; out Bypass: TArray<string>): string; overload;
// Overload when addresses to bypass proxy are not of interest
function GetSystemProxy(const URL: string): string; overload;

implementation

resourcestring
  S_EMsg_UnsuppCap = 'Required capability "%s" is not supported by network engine';
  S_EMsg_HTTPErr = 'HTTP error: %d %s';
  S_EMsg_ThreadWasNotFinished = 'Thread was not finished';

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
    FRequestProc: TBlockingNetworkRequestProc;
    FTilesProvider: TTilesProvider;
    FRequestProps: THttpRequestProps;
  public
    //   @param TilesProvider - object holding properties of current tile provider. \
    //     Object takes ownership on this object and destroys it on release.
    //     This must be a clone of Owner's object
    //   @param RequestProps - object holding properties of current network request. \
    //     Object takes ownership on this object and destroys it on release.
    //     This must be a clone of Owner's object
    constructor Create(Owner: TNetworkRequestQueue; RequestProc: TBlockingNetworkRequestProc;
      TilesProvider: TTilesProvider; RequestProps: THttpRequestProps);
    destructor Destroy; override;

    procedure Execute; override;

    property OnRequestComplete: TOnRequestComplete read FOnRequestComplete write FOnRequestComplete;
  end;

function ExtractProtocol(const URL: string): string;
begin
  Result := Copy(URL, 1, Pos(ProtoSep, URL) - 1);
end;

procedure CheckEngineCap(NeededCap: THttpRequestCapability; Caps: THttpRequestCapabilities);
begin
  if not (NeededCap in Caps) then
    raise Exception.CreateFmt(S_EMsg_UnsuppCap, [GetEnumName(TypeInfo(THttpRequestCapability), Ord(NeededCap))]);
end;

procedure CheckEngineCaps(RequestProps: THttpRequestProps; EngineCapabilities: THttpRequestCapabilities);
begin
  if ExtractProtocol(RequestProps.URL) = HTTPTLSProto then
    CheckEngineCap(htcTLS, EngineCapabilities);

  if (RequestProps.HttpUserName <> '') and (RequestProps.HttpPassword <> '') then
    CheckEngineCap(htcAuth, EngineCapabilities);

  // Does URL contain auth info? "http://user:pass@host/path"
  if Pos('@', RequestProps.URL) <> 0 then
    CheckEngineCap(htcAuthURL, EngineCapabilities);

  if RequestProps.Proxy <> '' then
  begin
    CheckEngineCap(htcProxy, EngineCapabilities);
    if RequestProps.Proxy = SystemProxy then
      CheckEngineCap(htcSystemProxy, EngineCapabilities);
    // Does proxy URL contain auth info? "http://user:pass@host/path"
    if Pos('@', RequestProps.Proxy) <> 0 then
      CheckEngineCap(htcProxyAuth, EngineCapabilities);
  end;

  if RequestProps.HeaderLines <> nil then
    CheckEngineCap(htcHeaders, EngineCapabilities);
end;

function IsHTTPError(ResponseCode: Word): Boolean;
begin
  Result := ResponseCode >= 400;
end;

procedure CheckHTTPError(ResponseCode: Word; const ResponseText: string);
begin
  if IsHTTPError(ResponseCode) then
    raise Exception.CreateFmt(S_EMsg_HTTPErr, [ResponseCode, ResponseText]);
end;

function GetSystemProxy(const URL: string; out Bypass: TArray<string>): string;

  {$IFDEF UNIX}
    // Get env var either by lowercase name (argument) or uppercase name
    function GetEnvVarLoHiCase(const Name: string): string;
    begin
      Result := GetEnvironmentVariable(Name);
      if Result = '' then
        Result := GetEnvironmentVariable(UpperCase(Name));
    end;

    const
      ProxyEnvVarNames: array[Boolean] of string =
        ('http_proxy', 'https_proxy'); // key is "secure" flag
      BypassEnvVarName = 'no_proxy';
  {$ENDIF}

var
  sl: TStringList;
  i: Integer;
  prot: string;
{$IFDEF MSWINDOWS}
  Success: Boolean;
  Len: DWORD;
  Buffer: TBytes;
  pProxyInfo: PInternetProxyInfo;
{$ENDIF}
{$IFDEF UNIX}
  ignore: string;
{$ENDIF}
begin
  Result := '';
  SetLength(Bypass, 0);

  // Extract proto from URL. Only 'http' and 'https' allowed here
  prot := ExtractProtocol(URL);
  if (prot <> HTTPProto) and (prot <> HTTPTLSProto) then Exit;

  {$IFDEF MSWINDOWS}
  // First get the length of required buffer by calling function with 0 length.
  // Expect failure and ERROR_INSUFFICIENT_BUFFER, other results are weird - exiting
  Len := 0;
  Success := InternetQueryOption(nil, INTERNET_OPTION_PROXY, nil, Len);
  if not (not Success and (GetLastError = ERROR_INSUFFICIENT_BUFFER)) then Exit;

  // Now Len contains required buffer length
  SetLength(Buffer, Len);
  Success := InternetQueryOption(nil, INTERNET_OPTION_PROXY, Buffer, Len);
  if not Success then Exit;

  pProxyInfo := PInternetProxyInfo(Buffer);
  if pProxyInfo^.dwAccessType <> INTERNET_OPEN_TYPE_PROXY then Exit; // no proxy defined

  // lpszProxy:
  //   "<proto1>=<addr1> <proto2>=<addr2>" if individual proxies for each protocol
  //   "addr" if one proxy for all
  //   nil if no proxy
  // lpszProxyBypass:
  //   space-separated list of addresses that ignore proxy, including the copy of
  //   lpszProxy (WTF?)
  if pProxyInfo^.lpszProxy = nil then Exit; // no proxy defined

  sl := TStringList.Create;
  try
    sl.Delimiter := ' ';
    sl.DelimitedText := string(AnsiString(pProxyInfo^.lpszProxy));
    if sl.Count = 1 then // global proxy
      Result := sl[0]
    else // protocol-specific proxies
    begin
      // Search for "prot=addr" string where "prot" equals to URL's protocol
      for i := 0 to sl.Count - 1 do
        if sl.Names[i] = prot then
        begin
          Result := sl.ValueFromIndex[i];
          Break;
        end;
    end;

    if pProxyInfo.lpszProxyBypass = nil then
    else
    begin
      sl.DelimitedText := string(AnsiString(pProxyInfo^.lpszProxyBypass));
      SetLength(Bypass, sl.Count);
      for i := 0 to sl.Count - 1 do
        Bypass[i] := sl[i];
    end;
  finally
    sl.Free;
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  // If prot is HTTPS, try secure settings first
  if prot = HTTPTLSProto then
    Result := GetEnvVarLoHiCase(ProxyEnvVarNames[True]);
  // Now try generic settings
  if Result = '' then
    Result := GetEnvVarLoHiCase(ProxyEnvVarNames[False]);
  if Result = '' then Exit;

  // Check bypass list
  ignore := GetEnvVarLoHiCase(BypassEnvVarName);
  if ignore = '' then Exit;

  sl := TStringList.Create;
  try
    sl.Delimiter := ',';
    sl.DelimitedText := ignore;
    SetLength(Bypass, sl.Count);
    for i := 0 to sl.Count - 1 do
      Bypass[i] := sl[i];
  finally
    sl.Free;
  end;
  {$ENDIF}

  // Add the protocol prefix
  Result := HTTPProxyProto + Result;
end;

function GetSystemProxy(const URL: string): string;
var arr: TArray<string>;
begin
  Result := GetSystemProxy(URL, arr);
end;

procedure DebugLog(const s: string);
begin
  {$IF DECLARED(OutputDebugString)}
  OutputDebugString(PChar(DateTimeToStr(Now) + ' [NetReq] ' + s));
  {$IFEND}
end;

{~ THttpRequestProps }

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

{~ TNetworkRequestThread }

constructor TNetworkRequestThread.Create(Owner: TNetworkRequestQueue;
  RequestProc: TBlockingNetworkRequestProc; TilesProvider: TTilesProvider;
  RequestProps: THttpRequestProps);
begin
  inherited Create(True);
  FOwner := Owner;
  FRequestProc := RequestProc;
  FTilesProvider := TilesProvider;
  FRequestProps := RequestProps;
end;

destructor TNetworkRequestThread.Destroy;
begin
  FreeAndNil(FRequestProps);
  FreeAndNil(FTilesProvider);
  inherited;
end;

// Extracts tiles to bу downloaded from the queue, finishes when there are no more tiles
procedure TNetworkRequestThread.Execute;
var
  Tile: TTile;
  ErrMsg: string;
  ms: TMemoryStream;
  cli: TNetworkClient;
begin
  cli := nil;
  // Ensure proxy URL starts with HTTP proto for parsers to handle it correctly
  if (FRequestProps.Proxy <> '') and (Pos(HTTPProxyProto, FRequestProps.Proxy) = 0) then
    FRequestProps.Proxy := HTTPProxyProto + FRequestProps.Proxy;

  while not Terminated do
  begin
    // Queue empty - finish thread
    if not FOwner.PopTask(Tile) then
      Break;

    FRequestProps.URL := FTilesProvider.GetTileURL(Tile);
    ms := TMemoryStream.Create;
    ErrMsg := '';

    {$IFDEF OSM_Trace}
    DebugLog('Getting tile ' + TileToStr(Tile) + ' from ' + FRequestProps.URL);
    {$ENDIF}

    try
      FRequestProc(FRequestProps, ms, cli);
      ms.Position := 0;
    except on E: Exception do
      begin
        ErrMsg := E.Message;
        FreeAndNil(ms);
        FreeAndNil(cli);
      end;
    end;

    {$IFDEF OSM_Trace}
    if ErrMsg = '' then
      DebugLog('Tile ' + TileToStr(Tile) + ' OK')
    else
      DebugLog('Error getting tile ' + TileToStr(Tile) + ': ' + ErrMsg);
    {$ENDIF}

    if Assigned(FOnRequestComplete) then
      FOnRequestComplete(Self, Tile, ms, ErrMsg)
    else // unlikely but possible
      FreeAndNil(ms)
  end; // while

  FreeAndNil(cli);
end;

{~ TNetworkRequestQueue }

constructor TNetworkRequestQueue.Create(MaxTasksPerThread, MaxThreads: Cardinal;
  RequestProc: TBlockingNetworkRequestProc; TilesProvider: TTilesProvider);
begin
  FTaskQueue := TQueue.Create;
  FCS := TCriticalSection.Create;
  FThreads := TList.Create;
  FCurrentTasks := TList.Create;
  FMaxTasksPerThread := MaxTasksPerThread;
  FMaxThreads := MaxThreads;
  FRequestProc := RequestProc;
  FRequestProps := THttpRequestProps.Create;
  FTilesProvider := TilesProvider;
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
        raise Exception.Create(S_EMsg_ThreadWasNotFinished);
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
  FreeAndNil(FTilesProvider);
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

// Search for tile by value in TList
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

    // Cancel all tiles with another zoom level. Only check the current queue head.
    if not FDumbQueueOrder then
      while (FTaskQueue.Count > 0) and (PTile(FTaskQueue.Peek).Zoom <> Tile.Zoom) do
        Dispose(FTaskQueue.Pop);

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

    // Cast to signed to get rid of warning
    if (FTaskQueue.Count > Integer(FMaxTasksPerThread)*FThreads.Count) and
      (FThreads.Count < Integer(FMaxThreads)) then
      AddThread;
  finally
    Unlock;
  end;
end;

procedure TNetworkRequestQueue.SetCurrentViewRect(const ViewRect: TRect);
begin
  Lock;
  try
    // Coord rect aligned to tile sizes
    FCurrTileNumbersRect := ToTileBoundary(ViewRect);
    // Convert coords to tile numbers
    FCurrTileNumbersRect := Rect(
      FCurrTileNumbersRect.Left div TILE_IMAGE_WIDTH,
      FCurrTileNumbersRect.Top div TILE_IMAGE_HEIGHT,
      FCurrTileNumbersRect.Right div TILE_IMAGE_WIDTH,
      FCurrTileNumbersRect.Bottom div TILE_IMAGE_HEIGHT
    );
    {$IFDEF OSM_Trace}
    DebugLog(Format('Set view rect to [%d : %d] - [%d : %d]',
      [FCurrTileNumbersRect.Left, FCurrTileNumbersRect.Top,
       FCurrTileNumbersRect.Right, FCurrTileNumbersRect.Bottom]));
    {$ENDIF}
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
    thr := TNetworkRequestThread.Create(Self, FRequestProc, FTilesProvider.Clone, FRequestProps.Clone);
    thr.OnRequestComplete := DoRequestComplete;
    thr.Start;
    FThreads.Add(thr);
  finally
    Unlock;
  end;
end;

// Extract next item from queue along with request properties, add item to list of current tasks
// ! Executed from bg threads
//   @param Tile - tile to be requested
//   @param RequestProps - personal copy of request properties that a thread must dispose
//   @returns @True if a task was returned, @False if queue is empty
function TNetworkRequestQueue.PopTask(out Tile: TTile): Boolean;

  // Search for tiles in list and return the 1st one that falls into given rect of tile numbers
  // (!) Numbers, not coords (!)
  function ExtractTileInView(List: TList; const ViewTileNumbersRect: TRect): OSM.SlippyMapUtils.PTile;
  var idx: Integer;
  begin
    // Queue's list has Tail at index 0 and Head at index Count so loop accodringly
    // to keep order of queued items.
    for idx := List.Count - 1 downto 0 do
    begin
      Result := PTile(List[idx]);
      if ViewTileNumbersRect.Contains(Point(Result.ParameterX, Result.ParameterY)) then
      begin
        List.Delete(idx);
        Exit;
      end;
    end;
    Result := nil;
  end;

var pT: PTile;
begin
  // Fast check
  if not FNotEmpty then
    Exit(False);

  pT := nil;

  Lock;
  try
    if FTaskQueue.Count > 0 then
    begin
      // First try to extract tiles currenly in view if smart ordering is enabled
      // and current view is set
      if not FDumbQueueOrder and (FCurrTileNumbersRect.Right <> 0) and (FCurrTileNumbersRect.Bottom <> 0) then
        pT := ExtractTileInView(TQueueHack(FTaskQueue).List, FCurrTileNumbersRect);
      // Not found yet - just extract head
      if pT = nil then
        pT := FTaskQueue.Pop;
    end;
    Result := pT <> nil;
    if Result then
    begin
      FCurrentTasks.Add(pT);
      Tile := pT^;
    end;

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

  if Assigned(FGotTileCb) then
    FGotTileCb(Tile, Ms, Error)
  else
    FreeAndNil(Ms);
end;

end.
