{
  Implements blocking HTTP request with HTTP class from RTL.

  FPC: **fphttpclient.TFPCustomHTTPClient** class

  Delphi: **System.Net.HttpClientComponent.TNetHTTPRequest** (since XE8). Older versions must use other engines

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap
}
unit OSM.NetworkRequest.RTL;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  SysUtils, Classes,
  {$IFDEF FPC}
  fphttpclient, URIParser,
  {$ENDIF}
  {$IFDEF DCC}
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient, System.StrUtils, System.Types,
  {$ENDIF}
  OSM.NetworkRequest;

const
  // Capabilities of RTL engine. Some other options vary for compiler and target OS
  EngineCapabilities = [htcProxy, htcProxyAuth, htcAuth, htcAuthURL, htcHeaders, htcTimeout]
  {$IFDEF FPC}
  + [htcDirect]
  {$ENDIF}
  {$IFDEF DCC}
  // Direct connection is only available on Windows
  + [{$IFDEF MSWINDOWS} htcDirect, {$ENDIF} htcSystemProxy, htcTLS]
  {$ENDIF}
  ;

// Procedure executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestProc type.
procedure NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; var Client: TNetworkClient);

implementation

{$IFDEF DCC}
  {$IFDEF MSWINDOWS}
  const
    DirectConnection = 'http://direct'; // Magic constant to bypass proxy for Delphi on Windows
  {$ENDIF}
{$ENDIF}

// Procedure executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestProc type.
procedure NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; var Client: TNetworkClient);
var
  uri: TURI;
  {$IFDEF FPC}
  httpCli: TFPHTTPClient;
  {$ENDIF}
  {$IFDEF DCC}
  httpCli: TNetHTTPClient;
  HdrArr: TStringDynArray;
  s, User, Pass: string;
  Resp: IHttpResponse;
  {$ENDIF}
begin
  {$IFDEF FPC}
  if Client = nil then
  begin
    CheckEngineCaps(RequestProps, EngineCapabilities);
    Client := TFPHTTPClient.Create(nil);
    httpCli := TFPHTTPClient(Client);
    if htcTimeout in EngineCapabilities then
    begin
      httpCli.ConnectTimeout := ReqTimeout;
      httpCli.IOTimeout := ReqTimeout;
    end;

    // Ensure URL requisites have priority over field requisites
    uri := ParseURI(RequestProps.URL);
    if (uri.Username <> '') and (uri.Password <> '') then
    begin
      httpCli.UserName := uri.Username;
      httpCli.Password := uri.Password;
    end
    else
    begin
      httpCli.UserName := RequestProps.HttpUserName;
      httpCli.Password := RequestProps.HttpPassword;
    end;

    if RequestProps.Proxy <> '' then
    begin
      uri := ParseURI(RequestProps.Proxy);
      httpCli.Proxy.Host := uri.Host;
      httpCli.Proxy.Port := uri.Port;
      httpCli.Proxy.UserName := uri.Username;
      httpCli.Proxy.Password := uri.Password;
    end;

    if RequestProps.HeaderLines <> nil then
      httpCli.RequestHeaders.Assign(RequestProps.HeaderLines);
  end
  else
    httpCli := TFPHTTPClient(Client);

  httpCli.Get(RequestProps.URL, ResponseStm);

  // check HTTP error
  CheckHTTPError(httpCli.ResponseStatusCode, httpCli.ResponseStatusText);
  {$ENDIF}

  {$IFDEF DCC}
  if Client = nil then
  begin
    CheckEngineCaps(RequestProps, EngineCapabilities);
    Client := TNetHTTPClient.Create(nil);
    httpCli := TNetHTTPClient(Client);
    if htcTimeout in EngineCapabilities then
    begin
      httpCli.ConnectionTimeout := ReqTimeout;
      httpCli.ResponseTimeout := ReqTimeout;
    end;

    // Ensure URL requisites have priority over field requisites
    uri := TURI.Create(RequestProps.URL);
    User := IfThen(uri.Username <> '', uri.Username, RequestProps.HttpUserName);
    Pass := IfThen(uri.Password <> '', uri.Password, RequestProps.HttpPassword);
    if (User <> '') and (Pass <> '') then
      httpCli.CredentialsStorage.AddCredential(TCredentialsStorage.TCredential.Create(
        TAuthTargetType.Server, '', '', User, Pass));

    // http://docwiki.embarcadero.com/RADStudio/Sydney/en/Using_an_HTTP_Client#Sending_a_Request_Behind_a_Proxy
    // '' means system, bypassing only allowed for Windows: to bypass the system proxy settings, create proxy settings
    // for the HTTP Client and specify http://direct as the URL
    // So:
    //   - '' => Direct (Windows only)
    //   - SYSTEM => ''
    if RequestProps.Proxy = '' then
    begin
      {$IFDEF MSWINDOWS}
      CheckEngineCap(htcDirect, EngineCapabilities);
      httpCli.ProxySettings := TProxySettings.Create(DirectConnection)
      {$ENDIF}
    end
    else if RequestProps.Proxy <> SystemProxy then
      httpCli.ProxySettings := TProxySettings.Create(RequestProps.Proxy);

    if RequestProps.HeaderLines <> nil then
    begin
      for s in RequestProps.HeaderLines do
      begin
        HdrArr := SplitString(s, ':');
        httpCli.CustomHeaders[HdrArr[0]] := HdrArr[1];
      end;
    end;
  end
  else
    httpCli := TNetHTTPClient(Client);

  Resp := httpCli.Get(RequestProps.URL, ResponseStm);

  // check HTTP error
  CheckHTTPError(Resp.StatusCode, Resp.StatusText);
  {$ENDIF}
end;

end.
