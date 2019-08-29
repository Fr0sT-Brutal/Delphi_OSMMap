{
  Implements blocking HTTP request with WinInet.
  Windows-only

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit WinInetRequest;

{$IFNDEF MSWINDOWS} {$MESSAGE FATAL 'This unit is Windows-only'} {$ENDIF}

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  SysUtils, Classes, Windows, WinInet,
  OSM.NetworkRequest;

// Function executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestFunc type.@br
function NetworkRequest(const RequestProps: THttpRequestProps;
  const ResponseStm: TStream; out ErrMsg: string): Boolean;

implementation

function NetworkRequest(const RequestProps: THttpRequestProps;
  const ResponseStm: TStream; out ErrMsg: string): Boolean;
var
  hInet: HINTERNET;
  Headers: string;
  Buf: array[0..1024-1] of Byte;
  read: DWORD;
  hFile: HINTERNET;
begin
  ErrMsg := ''; Result := False; hInet := nil; hFile := nil;

  try try
    // Init WinInet
    hInet := InternetOpen('Foo', INTERNET_OPEN_TYPE_DIRECT, nil, nil, 0);
    if hInet = nil then
      raise Exception.Create(SysErrorMessage(GetLastError));
    // Open address
    if RequestProps.HeaderLines <> nil then
      Headers := RequestProps.HeaderLines.Text;
    hFile := InternetOpenUrl(hInet, PChar(RequestProps.URL), PChar(Headers), 0,
                             INTERNET_FLAG_NO_CACHE_WRITE or INTERNET_FLAG_NO_COOKIES or INTERNET_FLAG_NO_UI,
                             0);
    if hFile = nil then
      raise Exception.Create(SysErrorMessage(GetLastError));

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
