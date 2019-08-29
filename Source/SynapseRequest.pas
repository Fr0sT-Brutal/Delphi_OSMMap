{
  Implements blocking HTTP request with Synapse framework.

    based on code by Simon Kroik, 06.2018, kroiksm@@gmx.de

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

// Function executing a network request. See description of
// OSM.NetworkRequest.TBlockingNetworkRequestFunc type.@br
// `RequestProps.Additional: Boolean` - SendAsMozilla flag
function NetworkRequest(const RequestProps: THttpRequestProps;
  const ResponseStm: TStream; out ErrMsg: string): Boolean;

implementation

const
  SEMsg_HTTPErr = 'HTTP error: %d %s';

procedure PrepareHTTPSendAsMozilla(AHTTP: THTTPSend);
begin
  AHTTP.UserAgent:='Mozilla/5.0 (Windows NT 6.1; WOW64; rv:51.0) Gecko/20100101 Firefox/51.0';
  AHTTP.Headers.Add('Accept-Language: de,en-US;q=0.7,en;q=0.3');
  AHTTP.Headers.Add('Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
end;

//based on Synapse
//For HTTPS-Support:
//  1) USES ssl_openssl;
//  2) copy libeay32.dll
//  3) copy ssleay32.dll
function NetworkRequest(const RequestProps: THttpRequestProps;
  const ResponseStm: TStream; out ErrMsg: string): Boolean;
var
  HTTP: THTTPSend;
begin
  ErrMsg := '';

  HTTP := THTTPSend.Create;
  try
    HTTP.UserName := RequestProps.HttpUserName;
    HTTP.Password := RequestProps.HttpPassword;

    if Boolean(RequestProps.Additional) then
      PrepareHTTPSendAsMozilla(HTTP);

    if Assigned(RequestProps.HeaderLines) then
      HTTP.Headers.AddStrings(RequestProps.HeaderLines);

    Result := HTTP.HTTPMethod('GET', RequestProps.URL);

    // check network error
    if not Result then
    begin
      ErrMsg := HTTP.Sock.LastErrorDesc;
      Exit;
    end;
    // check HTTP error
    if HTTP.ResultCode <> 200 then
    begin
      ErrMsg := Format(SEMsg_HTTPErr, [HTTP.ResultCode, HTTP.ResultString]);
      Exit;
    end;
    // OK
    ResponseStm.CopyFrom(HTTP.Document, 0);
  finally
    FreeAndNil(HTTP);
  end;
end;

end.
