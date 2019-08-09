program OSMMapDemo;

uses
  FastMM4,
  Forms,
  MainUnit in 'MainUnit.pas' {MainForm};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
