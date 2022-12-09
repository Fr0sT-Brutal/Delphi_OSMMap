{
  Implements blocking HTTP request with WinInet.
  Windows-only

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.NetworkRequest.WinInet;

{$IFNDEF MSWINDOWS} {$MESSAGE FATAL 'This unit is Windows-only'} {$ENDIF}

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  SysUtils, Classes, Windows, WinInet,
  OSM.NetworkRequest;

const
  // Capabilities of WinInet engine
  EngineCapabilities = [htcProxy, htcDirect, htcSystemProxy, htcHeaders,
    htcTimeout, htcTLS];

// Procedure executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestProc type.
procedure NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; var Client: TNetworkClient);

implementation

type
  TWinInetClient = class(TNetworkClient)
  private
    hInet: HINTERNET;
    const
    Agent = 'OSMMap.WinInet.Agent';
  public
    constructor Create(RequestProps: THttpRequestProps);
    destructor Destroy; override;
  end;

// Advanced SysErrorMessage version that handles WinInet errors
function SysErrorMessageEx(ErrorCode: Cardinal): string;
var
  Buffer: PChar;
  Len: Integer;
begin
  // WinInet specific
  if (ErrorCode >= INTERNET_ERROR_BASE) and (ErrorCode <= INTERNET_ERROR_LAST) then
    { Obtain the formatted message for the given Win32 ErrorCode from wininet lib.
      Let the OS initialize the Buffer variable. Need to LocalFree it afterward.
    }
    Len := FormatMessage(
      FORMAT_MESSAGE_FROM_HMODULE or
      FORMAT_MESSAGE_IGNORE_INSERTS or
      FORMAT_MESSAGE_ARGUMENT_ARRAY or
      FORMAT_MESSAGE_ALLOCATE_BUFFER, Pointer(GetModuleHandle('wininet.dll')), ErrorCode, 0, @Buffer, 0, nil)
  else
    { Obtain the formatted message for the given Win32 ErrorCode
      Let the OS initialize the Buffer variable. Need to LocalFree it afterward.
    }
    Len := FormatMessage(
      FORMAT_MESSAGE_FROM_SYSTEM or
      FORMAT_MESSAGE_IGNORE_INSERTS or
      FORMAT_MESSAGE_ARGUMENT_ARRAY or
      FORMAT_MESSAGE_ALLOCATE_BUFFER, nil, ErrorCode, 0, @Buffer, 0, nil);

  try
    { Remove the undesired line breaks and '.' char }
    while (Len > 0) and (CharInSet(Buffer[Len - 1], [#0..#32, '.'])) do Dec(Len);
    { Convert to Delphi string }
    SetString(Result, Buffer, Len);
  finally
    { Free the OS allocated memory block }
    LocalFree(HLOCAL(Buffer));
  end;
end;

function WinInetErr: Exception;
var errCode: DWORD;
begin
  errCode := GetLastError;
  Result := Exception.CreateFmt('%s [%d]', [SysErrorMessageEx(errCode), errCode]);
end;

{~ TWinInetClient }

constructor TWinInetClient.Create(RequestProps: THttpRequestProps);
var
  Proxy: string;
  dwAccessType, opt: DWORD;
begin
  CheckEngineCaps(RequestProps, EngineCapabilities);
  // Init WinInet
  Proxy := '';
  if RequestProps.Proxy <> '' then
    if RequestProps.Proxy = SystemProxy then
      dwAccessType := INTERNET_OPEN_TYPE_PRECONFIG
    else
    begin
      dwAccessType := INTERNET_OPEN_TYPE_PROXY;
      Proxy := RequestProps.Proxy;
    end
  else
    dwAccessType := INTERNET_OPEN_TYPE_DIRECT;
  hInet := InternetOpen(Agent, dwAccessType, PChar(Proxy), nil, 0);
  if hInet = nil then
    raise WinInetErr;
  // Set options
  if htcTimeout in EngineCapabilities then
  begin
    opt := ReqTimeout;
    InternetSetOption(hInet, INTERNET_OPTION_CONNECT_TIMEOUT, @opt, SizeOf(opt));
    InternetSetOption(hInet, INTERNET_OPTION_RECEIVE_TIMEOUT, @opt, SizeOf(opt));
    InternetSetOption(hInet, INTERNET_OPTION_SEND_TIMEOUT, @opt, SizeOf(opt));
  end;
end;

destructor TWinInetClient.Destroy;
begin
  InternetCloseHandle(hInet);
  inherited;
end;

procedure NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; var Client: TNetworkClient);
const
  Flags = INTERNET_FLAG_EXISTING_CONNECT or INTERNET_FLAG_KEEP_CONNECTION or // Try to prolong the connection
    INTERNET_FLAG_IGNORE_REDIRECT_TO_HTTPS or  // transparently redirects from HTTP to HTTPS URLs
    INTERNET_FLAG_NO_CACHE_WRITE or // Don't need tiles cached
    INTERNET_FLAG_NO_UI;            // No dialogs
var
  Headers: string;
  hFile: HINTERNET;
  Buf: array[0..8192-1] of Byte;
  read: DWORD;
begin
  hFile := nil;

  try
    if Client = nil then
      Client := TWinInetClient.Create(RequestProps);

    if RequestProps.HeaderLines <> nil then
      Headers := RequestProps.HeaderLines.Text;

    // Open address
    hFile := InternetOpenUrl(TWinInetClient(Client).hInet, PChar(RequestProps.URL),
      PChar(Headers), 0, Flags, 0);
    if hFile = nil then
      raise WinInetErr;

    // Read the URL
    repeat
      if not InternetReadFile(hFile, @Buf, SizeOf(Buf), read) then
        raise WinInetErr;
      if read = 0 then Break;
      ResponseStm.Write(Buf, read);
    until False;
  finally
    InternetCloseHandle(hFile);
  end;
end;

end.
