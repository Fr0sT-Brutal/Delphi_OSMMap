program OSMMapDemo;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

uses
  {$IFDEF FPC}
    {$IFDEF UNIX}{$IFDEF UseCThreads}
    cthreads, cmem, // the c memory manager is on some systems much faster for multi-threading
    {$ENDIF}{$ENDIF}
    Interfaces,
  {$ENDIF}
  Forms,
  MainUnit in 'MainUnit.pas' {MainForm};

{$R *.res}

begin
  {$IF DECLARED(ReportMemoryLeaksOnShutdown)}
  ReportMemoryLeaksOnShutdown := True;
  {$IFEND}
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
