{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit OSMMapLaz;

{$warn 5023 off : no warning about unused units}
interface

uses
  OSM.MapControl, OSM.NetworkRequest, OSM.SlippyMapUtils, OSM.TileStorage, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('OSMMapLaz', @Register);
end.
