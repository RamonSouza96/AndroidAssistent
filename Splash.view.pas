unit Splash.view;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Effects, FMX.Controls.Presentation, FMX.StdCtrls;

type
  TFormSplash = class(TForm)
    RectHeader: TRectangle;
    LabelTitle: TLabel;
    ShadowEffect1: TShadowEffect;
    Image1: TImage;
    LabelStatusG: TLabel;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormSplash: TFormSplash;

implementation

{$R *.fmx}

end.
