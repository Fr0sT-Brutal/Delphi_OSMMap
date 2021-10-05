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
  EngineCapabilities = [htcProxy, htcDirect, htcSystemProxy, htcHeaders, htcTimeout, htcTLS];

// Function executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestFunc type.@br
function NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; out ErrMsg: string): Boolean;

implementation

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

function NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; out ErrMsg: string): Boolean;
var
  hInet: HINTERNET;
  Proxy, Headers: string;
  Buf: array[0..1024-1] of Byte;
  dwAccessType, read, opt: DWORD;
  hFile: HINTERNET;
begin
  ErrMsg := ''; Result := False; hInet := nil; hFile := nil;

  try try
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
    hInet := InternetOpen('Foo', dwAccessType, PChar(Proxy), nil, 0);
    if hInet = nil then
      raise WinInetErr;
    // Set options
    opt := ReqTimeout;
    InternetSetOption(hInet, INTERNET_OPTION_CONNECT_TIMEOUT, @opt, SizeOf(opt));
    InternetSetOption(hInet, INTERNET_OPTION_RECEIVE_TIMEOUT, @opt, SizeOf(opt));
    InternetSetOption(hInet, INTERNET_OPTION_SEND_TIMEOUT, @opt, SizeOf(opt));
    // Open address
    if RequestProps.HeaderLines <> nil then
      Headers := RequestProps.HeaderLines.Text;
    hFile := InternetOpenUrl(hInet, PChar(RequestProps.URL), PChar(Headers), 0,
                             INTERNET_FLAG_NO_CACHE_WRITE or INTERNET_FLAG_NO_COOKIES or INTERNET_FLAG_NO_UI,
                             0);
    if hFile = nil then
      raise WinInetErr;

    // Read the URL
    while InternetReadFile(hFile, @Buf, SizeOf(Buf), read) do
    begin
      if read = 0 then Break;
      ResponseStm.Write(Buf, read);
    end;

    Result := True;
  except on E: Exception do
    ErrMsg := E.Message;
  end;
  finally
    InternetCloseHandle(hFile);
    InternetCloseHandle(hInet);
  end;
end;

end.
