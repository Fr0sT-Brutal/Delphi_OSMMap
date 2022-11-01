{
  Implements blocking HTTP request with Synapse framework.

    based on code by Simon Kroik, 06.2018, kroiksm@@gmx.de

  For HTTPS-Support:
    1) DEFINE SynapseSSL
    2) copy libeay32.dll and ssleay32.dll near the binary

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Simon Kroik (kroiksm@gmx.de))
  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.NetworkRequest.Synapse;

interface

uses
  SysUtils, Classes,
  HTTPSend, SynaUtil, {$IFDEF SynapseSSL} ssl_openssl, {$ENDIF}
  OSM.NetworkRequest;

const
  // Capabilities of Synapse engine
  EngineCapabilities = [htcProxy, htcDirect, htcProxyAuth, htcAuth, htcAuthURL,
    htcHeaders, htcTimeout {$IF DECLARED(TSSLOpenSSL)} , htcTLS {$IFEND} ];

// Procedure executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestProc type.
procedure NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; var Client: TNetworkClient);

implementation

const
  SUserAgentHdrName = 'User-Agent: ';

// Procedure executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestProc type.
procedure NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; var Client: TNetworkClient);
var
  httpCli: THTTPSend;
  User, Pass, ProxyUser, ProxyPass, ProxyHost, ProxyPort, Dummy: string;
begin
  if Client = nil then
  begin
    CheckEngineCaps(RequestProps, EngineCapabilities);
    Client := THTTPSend.Create;
    httpCli := THTTPSend(Client);
    httpCli.Protocol := '1.1';   // 1.0 by default thus killing keep-alive feature
    if htcTimeout in EngineCapabilities then
      httpCli.Timeout := ReqTimeout;
    // Ensure URL requisites have priority over field requisites
    ParseURL(RequestProps.URL, Dummy, User, Pass, Dummy, Dummy, Dummy, Dummy);
    if (User <> '') and (Pass <> '') then
    begin
      httpCli.UserName := User;
      httpCli.Password := Pass;
    end
    else
    begin
      httpCli.UserName := RequestProps.HttpUserName;
      httpCli.Password := RequestProps.HttpPassword;
    end;

    if RequestProps.Proxy <> '' then
    begin
      ParseURL(RequestProps.Proxy, Dummy, ProxyUser, ProxyPass, ProxyHost, ProxyPort, Dummy, Dummy);
      httpCli.ProxyHost := ProxyHost;
      httpCli.ProxyPort := ProxyPort;
      httpCli.ProxyUser := ProxyUser;
      httpCli.ProxyPass := ProxyPass;
    end;
  end
  else
  begin
    httpCli := THTTPSend(Client);
    // Synapse fills Headers with response headers so we need to clear them and
    // fill again before the new request
    httpCli.Clear;
  end;

  if RequestProps.HeaderLines <> nil then
  begin
    httpCli.Headers.AddStrings(RequestProps.HeaderLines);
    // Synapse doesn't take User agent from headers but from .UserAgent property.
    // So check if we have it defined and set explicitly
    for Dummy in RequestProps.HeaderLines do
      if Pos(SUserAgentHdrName, Dummy) = 1 then
        httpCli.UserAgent := Copy(Dummy, Length(SUserAgentHdrName) + 1, MaxInt);
  end;

  // try to get, check network error
  if not httpCli.HTTPMethod('GET', RequestProps.URL) then
    raise Exception.Create(httpCli.Sock.LastErrorDesc);
  // check httpCli error
  CheckHTTPError(httpCli.ResultCode, httpCli.ResultString);
  // OK
  ResponseStm.CopyFrom(httpCli.Document, 0);
end;

end.
