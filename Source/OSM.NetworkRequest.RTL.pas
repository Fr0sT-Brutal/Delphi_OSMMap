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
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient, StrUtils,
  {$ENDIF}
  OSM.NetworkRequest;

const
  // Capabilities of RTL engine
  {$IFDEF FPC}
  EngineCapabilities = [htcProxy, htcDirect, htcProxyAuth, htcAuth, htcAuthURL,
    htcHeaders, htcTimeout];
  {$ENDIF}
  {$IFDEF DCC}
  // Direct connection is only available on Windows
  EngineCapabilities = [htcProxy, {$IFDEF MSWINDOWS} htcDirect, {$ENDIF} htcSystemProxy,
    htcProxyAuth, htcAuth, htcAuthURL, htcHeaders, htcTimeout, htcTLS];
  {$ENDIF}

// Function executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestFunc type.@br
function NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; out ErrMsg: string): Boolean;

implementation

const
  SEMsg_HTTPErr = 'HTTP error: %d %s';
  {$IFDEF DCC}
    {$IFDEF MSWINDOWS}
    DirectConnection = 'http://direct'; // Magic constant to bypass proxy for Delphi on Windows
    {$ENDIF}
  {$ENDIF}

function NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; out ErrMsg: string): Boolean;
var
  uri: TURI;
  {$IFDEF FPC}
  httpCli: TFPHTTPClient;
  {$ENDIF}
  {$IFDEF DCC}
  httpCli: TNetHTTPClient;
  HdrArr: TArray<string>;
  s, User, Pass: string;
  Resp: IHttpResponse;
  {$ENDIF}
begin
  ErrMsg := ''; Result := False;

  try try
    {$IFDEF FPC}
    httpCli := TFPHTTPClient.Create(nil);
    httpCli.ConnectTimeout := ReqTimeout;
    httpCli.IOTimeout := ReqTimeout;

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

    if RequestProps.HeaderLines <> nil then
      httpCli.RequestHeaders.Assign(RequestProps.HeaderLines);

    if RequestProps.Proxy <> '' then
    begin
      uri := ParseURI(RequestProps.Proxy);
      httpCli.Proxy.Host := uri.Host;
      httpCli.Proxy.Port := uri.Port;
      httpCli.Proxy.UserName := uri.Username;
      httpCli.Proxy.Password := uri.Password;
    end;

    httpCli.Get(RequestProps.URL, ResponseStm);

    // check HTTP error
    if httpCli.ResponseStatusCode >= 400 then
    begin
      ErrMsg := Format(SEMsg_HTTPErr, [httpCli.ResponseStatusCode, httpCli.ResponseStatusText]);
      Exit(False);
    end;
    {$ENDIF}
    {$IFDEF DCC}
    httpCli := TNetHTTPClient.Create(nil);
    httpCli.ConnectionTimeout := ReqTimeout;
    httpCli.ResponseTimeout := ReqTimeout;

    // Ensure URL requisites have priority over field requisites
    uri := TURI.Create(RequestProps.URL);
    User := IfThen(uri.Username <> '', uri.Username, RequestProps.HttpUserName);
    Pass := IfThen(uri.Password <> '', uri.Password, RequestProps.HttpPassword);
    if (User <> '') and (Pass <> '') then
      httpCli.CredentialsStorage.AddCredential(TCredentialsStorage.TCredential.Create(
        TAuthTargetType.Server, '', '', User, Pass));

    if RequestProps.HeaderLines <> nil then
    begin
      for s in RequestProps.HeaderLines do
      begin
        HdrArr := SplitString(s, ':');
        httpCli.CustomHeaders[HdrArr[0]] := HdrArr[1];
      end;
    end;

    // http://docwiki.embarcadero.com/RADStudio/Sydney/en/Using_an_HTTP_Client#Sending_a_Request_Behind_a_Proxy
    // '' means system, bypassing only allowed for Windows: to bypass the system proxy settings, create proxy settings
    // for the HTTP Client and specify http://direct as the URL
    // So:
    //   - '' => Direct (Windows only)
    //   - SYSTEM => ''
    if RequestProps.Proxy = '' then
      {$IFDEF MSWINDOWS}
      httpCli.ProxySettings := TProxySettings.Create(DirectConnection)
      {$ENDIF}
    else if RequestProps.Proxy <> SystemProxy then
      httpCli.ProxySettings := TProxySettings.Create(RequestProps.Proxy);

    Resp := httpCli.Get(RequestProps.URL, ResponseStm);

    // check HTTP error
    if Resp.StatusCode >= 400 then
    begin
      ErrMsg := Format(SEMsg_HTTPErr, [Resp.StatusCode, Resp.StatusText]);
      Exit(False);
    end;
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
