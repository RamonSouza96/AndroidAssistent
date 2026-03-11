unit APKInstaller;

interface

uses
  System.Classes, System.SysUtils, System.Threading, System.IOUtils,
  FMX.StdCtrls, FMX.Edit, FMX.Objects, FMX.Dialogs, FMX.Controls,
  Winapi.Windows, Winapi.Messages, System.Types, FMX.Types;

type
  TAPKInstaller = class
  private
    FADBPath: string;
    FCurrentDevice: string;
    
    // Componentes UI
    FEditAPKPath: TEdit;
    FButtonSelectAPK: TButton;
    FButtonInstallAPK: TButton;
    FProgressBarInstall: TProgressBar;
    FLabelInstallStatus: TLabel;
    FRectDropArea: TRectangle;
    FLabelDropArea: TLabel;
    FOpenDialogAPK: TOpenDialog;
    
    // Eventos
    FOnStatusUpdate: procedure(const AMessage: string) of object;
    FOnLogMessage: procedure(const AMessage: string) of object;
    FOnShowMessage: procedure(const AMessage: string) of object;
    FOnAppListRefresh: procedure of object;
    
    function ExecuteADBCommand(const ACommand: string): string;
    function IsValidAPKFile(const AFilePath: string): Boolean;
    procedure SetButtonsEnabled(AEnabled: Boolean);
    procedure UpdateInstallProgress(AProgress: Integer; const AMessage: string);
    
  public
    constructor Create(const AADBPath: string;
                      AEditAPKPath: TEdit;
                      AButtonSelectAPK: TButton;
                      AButtonInstallAPK: TButton;
                      AProgressBarInstall: TProgressBar;
                      ALabelInstallStatus: TLabel;
                      ARectDropArea: TRectangle;
                      ALabelDropArea: TLabel;
                      AOpenDialogAPK: TOpenDialog);
    destructor Destroy; override;
    
    procedure SetCurrentDevice(const ADevice: string);
    procedure SelectAPKFile;
    procedure InstallAPK(const AFilePath: string = '');
    procedure HandleDragOver(Sender: TObject; const Data: TDragObject;
      const Point: TPointF; var Operation: TDragOperation);
    procedure HandleDragDrop(Sender: TObject; const Data: TDragObject;
      const Point: TPointF);
  end;

implementation

{ TAPKInstaller }

constructor TAPKInstaller.Create(const AADBPath: string;
                                AEditAPKPath: TEdit;
                                AButtonSelectAPK: TButton;
                                AButtonInstallAPK: TButton;
                                AProgressBarInstall: TProgressBar;
                                ALabelInstallStatus: TLabel;
                                ARectDropArea: TRectangle;
                                ALabelDropArea: TLabel;
                                AOpenDialogAPK: TOpenDialog);
begin
  inherited Create;
  
  FADBPath := AADBPath;
  
  // Armazenar referências dos componentes UI
  FEditAPKPath := AEditAPKPath;
  FButtonSelectAPK := AButtonSelectAPK;
  FButtonInstallAPK := AButtonInstallAPK;
  FProgressBarInstall := AProgressBarInstall;
  FLabelInstallStatus := ALabelInstallStatus;
  FRectDropArea := ARectDropArea;
  FLabelDropArea := ALabelDropArea;
  FOpenDialogAPK := AOpenDialogAPK;
  
  // Configurar estado inicial
  FButtonInstallAPK.Enabled := False;
  FProgressBarInstall.Value := 0;
end;

destructor TAPKInstaller.Destroy;
begin
  inherited;
end;

procedure TAPKInstaller.SetCurrentDevice(const ADevice: string);
begin
  FCurrentDevice := ADevice;
end;

procedure TAPKInstaller.SetButtonsEnabled(AEnabled: Boolean);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      FButtonSelectAPK.Enabled := AEnabled;
      FButtonInstallAPK.Enabled := AEnabled and (FEditAPKPath.Text <> '') and IsValidAPKFile(FEditAPKPath.Text);
    end);
end;

procedure TAPKInstaller.UpdateInstallProgress(AProgress: Integer; const AMessage: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      FProgressBarInstall.Value := AProgress;
      FLabelInstallStatus.Text := AMessage;
    end);
end;

function TAPKInstaller.ExecuteADBCommand(const ACommand: string): string;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  SecurityAttrs: TSecurityAttributes;
  ReadPipe, WritePipe: THandle;
  Buffer: array[0..4095] of AnsiChar;
  BytesRead: Cardinal;
  CmdLine: string;
begin
  Result := '';

  // Configurar pipes para capturar saída
  SecurityAttrs.nLength := SizeOf(SecurityAttrs);
  SecurityAttrs.lpSecurityDescriptor := nil;
  SecurityAttrs.bInheritHandle := True;

  if not CreatePipe(ReadPipe, WritePipe, @SecurityAttrs, 0) then
    Exit;

  try
    // Configurar processo
    FillChar(StartupInfo, SizeOf(StartupInfo), 0);
    StartupInfo.cb := SizeOf(StartupInfo);
    StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    StartupInfo.hStdOutput := WritePipe;
    StartupInfo.hStdError := WritePipe;
    StartupInfo.wShowWindow := SW_HIDE;

    // Montar linha de comando
    CmdLine := '"' + FADBPath + '" ' + ACommand;

    if Assigned(FOnLogMessage) then
      FOnLogMessage('Executando: ' + CmdLine);

    // Executar comando
    if CreateProcess(nil, PChar(CmdLine), nil, nil, True,
                     CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
    try
      CloseHandle(WritePipe);
      WritePipe := 0;

      // Aguardar conclusão com timeout
      WaitForSingleObject(ProcessInfo.hProcess, 60000); // 60 segundos para instalação

      // Ler saída
      while ReadFile(ReadPipe, Buffer, SizeOf(Buffer), BytesRead, nil) and (BytesRead > 0) do
      begin
        Result := Result + string(AnsiString(Copy(Buffer, 0, BytesRead)));
      end;

    finally
      CloseHandle(ProcessInfo.hProcess);
      CloseHandle(ProcessInfo.hThread);
    end
    else
    begin
      if Assigned(FOnLogMessage) then
        FOnLogMessage('Erro ao executar comando ADB');
    end;

  finally
    if WritePipe <> 0 then CloseHandle(WritePipe);
    CloseHandle(ReadPipe);
  end;

  if Assigned(FOnLogMessage) then
    FOnLogMessage('Resultado obtido (' + IntToStr(Length(Result)) + ' chars)');
end;

function TAPKInstaller.IsValidAPKFile(const AFilePath: string): Boolean;
begin
  Result := FileExists(AFilePath) and
            (ExtractFileExt(AFilePath).ToLower = '.apk') and
            (TFile.GetSize(AFilePath) > 1024); // Pelo menos 1KB
end;

procedure TAPKInstaller.SelectAPKFile;
begin
  if FOpenDialogAPK.Execute then
  begin
    FEditAPKPath.Text := FOpenDialogAPK.FileName;
    FButtonInstallAPK.Enabled := IsValidAPKFile(FOpenDialogAPK.FileName);
    FLabelInstallStatus.Text := 'Arquivo selecionado: ' + ExtractFileName(FOpenDialogAPK.FileName);
  end;
end;

procedure TAPKInstaller.InstallAPK(const AFilePath: string = '');
var
  FilePath: string;
begin
  // Usar o parâmetro se fornecido, senão usar o campo de texto
  if AFilePath <> '' then
    FilePath := AFilePath
  else
    FilePath := FEditAPKPath.Text;

  if FCurrentDevice = '' then
  begin
    if Assigned(FOnShowMessage) then
      FOnShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  if not IsValidAPKFile(FilePath) then
  begin
    if Assigned(FOnShowMessage) then
      FOnShowMessage('Arquivo APK inválido');
    Exit;
  end;

  SetButtonsEnabled(False);
  
  if Assigned(FOnStatusUpdate) then
    FOnStatusUpdate('Instalando APK...');

  UpdateInstallProgress(25, 'Instalando: ' + ExtractFileName(FilePath));

  TTask.Run(
    procedure
    var
      Result: string;
    begin
      try
        UpdateInstallProgress(50, 'Transferindo arquivo para o dispositivo...');

        Result := ExecuteADBCommand('-s ' + FCurrentDevice + ' install "' + FilePath + '"');

        UpdateInstallProgress(100, '');

        TThread.Synchronize(nil,
          procedure
          begin
            if Result.Contains('Success') then
            begin
              FLabelInstallStatus.Text := 'Instalação concluída com sucesso!';
              
              if Assigned(FOnShowMessage) then
                FOnShowMessage('APK instalado com sucesso!');
                
              // Atualizar lista de apps se o callback estiver disponível
              if Assigned(FOnAppListRefresh) then
                FOnAppListRefresh;
            end
            else
            begin
              FLabelInstallStatus.Text := 'Erro na instalação';
              
              if Assigned(FOnShowMessage) then
                FOnShowMessage('Erro ao instalar APK: ' + Result);
            end;

            FProgressBarInstall.Value := 0;
            
            if Assigned(FOnStatusUpdate) then
              FOnStatusUpdate('Pronto');
          end);
          
      finally
        SetButtonsEnabled(True);
      end;
    end);
end;

procedure TAPKInstaller.HandleDragOver(Sender: TObject; const Data: TDragObject;
  const Point: TPointF; var Operation: TDragOperation);
begin
  if Length(Data.Files) > 0 then
    Operation := TDragOperation.Copy
  else
    Operation := TDragOperation.None;
end;

procedure TAPKInstaller.HandleDragDrop(Sender: TObject; const Data: TDragObject;
  const Point: TPointF);
begin
  if Length(Data.Files) > 0 then
  begin
    FEditAPKPath.Text := Data.Files[0];
    FButtonInstallAPK.Enabled := IsValidAPKFile(Data.Files[0]);
    FLabelInstallStatus.Text := 'Arquivo arrastado: ' + ExtractFileName(Data.Files[0]);
  end;
end;

end. 