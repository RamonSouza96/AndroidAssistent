program Project1;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  MainForm in 'MainForm.pas' {FormMain},
  LogcatManager in 'LogcatManager.pas',
  ToolsManager in 'ToolsManager.pas',
  Main.Settings in 'Main.Settings.pas';

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
