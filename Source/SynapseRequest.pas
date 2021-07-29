{
  Implements blocking HTTP request with Synapse framework.

    based on code by Simon Kroik, 06.2018, kroiksm@@gmx.de

  For HTTPS-Support:
    1) USES ssl_openssl;
    2) copy libeay32.dll
    3) copy ssleay32.dll

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Simon Kroik (kroiksm@gmx.de))
  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit SynapseRequest;

interface

uses
  SysUtils, Classes,
  HTTPSend, SynaUtil,
  OSM.NetworkRequest;

const
  // Capabilities of Synapse engine
  EngineCapabilities = [htcProxy, htcDirect, htcProxyAuth, htcAuth, htcAuthURL,
    htcHeaders, htcTimeout
    {$IF DECLARED(TSSLOpenSSL)} , htcTLS {$ENDIF} ];

// Function executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestFunc type.@br
function NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; out ErrMsg: string): Boolean;

implementation

const
  SEMsg_HTTPErr = 'HTTP error: %d %s';

function NetworkRequest(RequestProps: THttpRequestProps;
  ResponseStm: TStream; out ErrMsg: string): Boolean;
var
  HTTP: THTTPSend;
  User, Pass, ProxyUser, ProxyPass, ProxyHost, ProxyPort, Dummy: string;
begin
  ErrMsg := '';

  HTTP := THTTPSend.Create;
  try
    HTTP.Timeout := ReqTimeout;
    // Ensure URL requisites have priority over field requisites
    ParseURL(RequestProps.URL, Dummy, User, Pass, Dummy, Dummy, Dummy, Dummy);
    if (User <> '') and (Pass <> '') then
    begin
      HTTP.UserName := User;
      HTTP.Password := Pass;
    end
    else
    begin
      HTTP.UserName := RequestProps.HttpUserName;
      HTTP.Password := RequestProps.HttpPassword;
    end;

    if RequestProps.Proxy <> '' then
    begin
      ParseURL(RequestProps.Proxy, Dummy, ProxyUser, ProxyPass, ProxyHost, ProxyPort, Dummy, Dummy);
      HTTP.ProxyHost := ProxyHost;
      HTTP.ProxyPort := ProxyPort;
      HTTP.ProxyUser := ProxyUser;
      HTTP.ProxyPass := ProxyPass;
    end;

    if RequestProps.HeaderLines <> nil then
      HTTP.Headers.AddStrings(RequestProps.HeaderLines);

    Result := HTTP.HTTPMethod('GET', RequestProps.URL);

    // check network error
    if not Result then
    begin
      ErrMsg := HTTP.Sock.LastErrorDesc;
      Exit;
    end;
    // check HTTP error
    if HTTP.ResultCode >= 400 then
    begin
      ErrMsg := Format(SEMsg_HTTPErr, [HTTP.ResultCode, HTTP.ResultString]);
      Exit(False);
    end;
    // OK
    ResponseStm.CopyFrom(HTTP.Document, 0);
  finally
    FreeAndNil(HTTP);
  end;
end;

end.
