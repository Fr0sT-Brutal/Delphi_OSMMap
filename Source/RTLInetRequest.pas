{
  Implements blocking HTTP request with HTTP class from RTL.

  FPC: **fphttpclient.TFPCustomHTTPClient** class

  Delphi: **System.Net.HttpClientComponent.TNetHTTPRequest** (since XE8). Older versions must use other engines

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap
}
unit RTLInetRequest;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  SysUtils, Classes,
  {$IFDEF FPC}
  fphttpclient,
  {$ENDIF}
  {$IFDEF DCC}
  System.Net.HttpClientComponent,
  {$ENDIF}
  OSM.NetworkRequest;

// Function executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestFunc type.@br
function NetworkRequest(const RequestProps: THttpRequestProps;
  const ResponseStm: TStream; out ErrMsg: string): Boolean;

implementation

function NetworkRequest(const RequestProps: THttpRequestProps;
  const ResponseStm: TStream; out ErrMsg: string): Boolean;
var
  {$IFDEF FPC}
  httpCli: TFPCustomHTTPClient;
  {$ENDIF}
  {$IFDEF DCC}
  httpCli: TNetHTTPClient;
  httpReq: TNetHTTPRequest;
  {$ENDIF}
begin
  ErrMsg := ''; Result := False;

  try try
    {$IFDEF FPC}
    httpCli := TFPCustomHTTPClient.Create(nil);
    httpCli.SimpleGet(RequestProps.URL, ResponseStm);
    {$ENDIF}
    {$IFDEF DCC}
    httpCli := TNetHTTPClient.Create(nil);
    httpReq := TNetHTTPRequest.Create(httpCli); // to have it destroyed by client
    httpReq.Client := httpCli;
    httpReq.Get(RequestProps.URL, ResponseStm);
    {$ENDIF}

    Result := ResponseStm.Size > 0;
  except on E: Exception do
    ErrMsg := E.Message;
  end;
  finally
    FreeAndNil(httpCli);
  end;
end;

end.
