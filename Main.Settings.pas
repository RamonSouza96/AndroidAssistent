unit Main.Settings;

interface

uses
 System.SysUtils,
 System.Types,
 System.UITypes,
 System.Classes,
 FireDAC.Comp.Client,
 System.Threading,
 System.IOUtils,
 Fmx.Dialogs,
 System.Net.HttpClient,
 System.SyncObjs,
 FMX.Objects,
 FMX.Types,
 FMX.Skia,
 FMX.Forms,
 FMX.Ani,
 FMX.StdCtrls;

type
  TMain_Settings = class
  Private
  Public
    class var FADBPath: string;
    class var FCurrentDevice: string;
    class procedure UpdateStatusSafe(const AMessage: string; ALabel: TLabel);
  end;

implementation

{ TMain_Settings }

class procedure TMain_Settings.UpdateStatusSafe(const AMessage: string; ALabel: TLabel);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      ALabel.Text := AMessage;
    end);
end;

end.
