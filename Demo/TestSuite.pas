{
  Elementary test suite class
}
unit TestSuite;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses SysUtils;

type
  TLogProc = procedure (const s: string) of object;
  TTestProc = procedure of object;

  TTestSuite = class
  protected
    FLogProc: TLogProc;
    FTestMethods: array of TTestProc;
  public
    constructor Create(LogProc: TLogProc; const TestMethods: array of TTestProc);
    procedure Run;
    procedure Setup; virtual;
    procedure Teardown; virtual;
  end;

implementation

{ TTestSuite }

constructor TTestSuite.Create(LogProc: TLogProc; const TestMethods: array of TTestProc);

  procedure FillTestMethods(const TestMethods: array of TTestProc);
  var i: Integer;
  begin
    SetLength(FTestMethods, Length(TestMethods));
    for i := Low(FTestMethods) to High(FTestMethods) do
      FTestMethods[i] := TestMethods[i];
  end;

begin
  inherited Create;
  FLogProc := LogProc;
  FillTestMethods(TestMethods);
end;

procedure TTestSuite.Run;
var
  i, FailCnt: Integer;
  TestName: string;
begin
  Setup;

  FLogProc('== Test suite started ==');
  FailCnt := 0;

  for i := Low(FTestMethods) to High(FTestMethods) do
  begin
    TestName := string(Self.MethodName(@FTestMethods[i]));
    TestName := Format('Test #%.2d/%.2d - %s. ', [i + 1, Length(FTestMethods), TestName]);
    try
      FTestMethods[i]();
      FLogProc(TestName + 'Success');
    except on E: Exception do
      begin
        Inc(FailCnt);
        FLogProc(TestName + 'FAIL: ' + E.Message);
      end;
    end;
  end; // for

  if FailCnt = 0 then
    FLogProc('== Test suite finished, all tests OK ==')
  else
    FLogProc(Format('== Test suite finished, %d/%d tests failed ==', [FailCnt, Length(FTestMethods)]));

  Teardown;
end;

procedure TTestSuite.Setup;
begin
end;

procedure TTestSuite.Teardown;
begin
end;

end.

