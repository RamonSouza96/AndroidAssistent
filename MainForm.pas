unit MainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils, System.Threading, System.JSON, System.RegularExpressions,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.TabControl,
  FMX.StdCtrls, FMX.Edit, FMX.Memo, FMX.ListBox, FMX.Layouts, FMX.Objects,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.SearchBox, FMX.ComboEdit,
  FMX.Memo.Types, FMX.EditBox, FMX.SpinBox,
  Winapi.Windows, Winapi.Messages, System.Win.ComObj,
  System.StrUtils, DateUtils, System.SyncObjs, FMX.Effects, System.Skia,
  FMX.Skia, System.ImageList, FMX.ImgList;

type
  TAppInfo = record
    PackageName: string;
    DisplayName: string;
    IsSystemApp: boolean;
  end;

  TFormMain = class(TForm)
    // === LAYOUTS PRINCIPAIS ===
    LayoutMain: TLayout;
    LayoutTop: TLayout;
    LayoutContent: TLayout;
    LayoutBottom: TLayout;

    // === CABEÇALHO ===
    RectHeader: TRectangle;
    LabelTitle: TLabel;
    ButtonRefreshDevices: TButton;
    ComboDevices: TComboBox;
    LabelDeviceStatus: TLabel;

    // === CONTROLE DE ABAS ===
    TabControl: TTabControl;
    TabApps: TTabItem;
    TabInstall: TTabItem;
    TabTools: TTabItem;
    TabConsole: TTabItem;

    // === ABA APLICATIVOS ===
    LayoutApps: TLayout;
    LayoutAppsTop: TLayout;
    LayoutAppsList: TLayout;
    LayoutAppsDetails: TLayout;

    // Controles da aba aplicativos
    SearchBoxApps: TSearchBox;
    ButtonRefreshApps: TButton;
    ButtonUninstallApp: TButton;
    CheckBoxSystemApps: TCheckBox;

    // Lista e detalhes dos aplicativos
    ListBoxApps: TListBox;
    RectAppDetails: TRectangle;
    LabelAppDetailsTitle: TLabel;
    MemoAppDetails: TMemo;
    ButtonAppInfo: TButton;

    // === ABA INSTALAR APK ===
    LayoutInstall: TLayout;
    LayoutInstallTop: TLayout;
    LayoutInstallCenter: TLayout;
    LayoutInstallBottom: TLayout;

    // Controles de instalação
    EditAPKPath: TEdit;
    ButtonSelectAPK: TButton;
    ButtonInstallAPK: TButton;
    ProgressBarInstall: TProgressBar;
    LabelInstallStatus: TLabel;

    // Área de arrastar e soltar
    RectDropArea: TRectangle;
    LabelDropArea: TLabel;

    // === ABA FERRAMENTAS ===
    LayoutTools: TLayout;
    LayoutToolsLeft: TLayout;
    LayoutToolsRight: TLayout;

    // Ferramentas rápidas
    GroupBoxQuickTools: TGroupBox;
    ButtonReboot: TButton;
    ButtonRebootBootloader: TButton;
    ButtonRebootRecovery: TButton;
    ButtonScreenshot: TButton;
    ButtonClearCache: TButton;

    // Shell ADB
    GroupBoxShell: TGroupBox;
    EditShellCommand: TEdit;
    ButtonExecuteShell: TButton;

    // Comandos personalizados
    GroupBoxCustomCommands: TGroupBox;
    EditCustomCommand: TEdit;
    ButtonExecuteCustom: TButton;
    MemoCustomOutput: TMemo;

    // === ABA CONSOLE/LOG ===
    LayoutConsole: TLayout;
    LayoutConsoleTop: TLayout;
    LayoutConsoleContent: TLayout;

    // Controles do console
    ButtonStartLogcat: TButton;
    ButtonStopLogcat: TButton;
    ButtonClearLog: TButton;
    ComboLogLevel: TComboBox;
    EditLogFilter: TEdit;
    MemoConsole: TMemo;

    // === BARRA DE STATUS ===
    RectStatusBar: TRectangle;
    LabelStatus: TLabel;

    // === DIÁLOGOS ===
    OpenDialogAPK: TOpenDialog;
    SaveDialogScreenshot: TSaveDialog;
    ListBoxConsole: TListBox;
    BtnFiltrar: TButton;
    ShadowEffect1: TShadowEffect;
    Image1: TImage;
    LayoutSplash: TLayout;
    RectSplash: TRectangle;
    Label1: TLabel;
    ShadowEffect2: TShadowEffect;
    LabelStatusG: TLabel;
    SkAnimatedImage1: TSkAnimatedImage;
    ImageList1: TImageList;

    procedure FormDestroy(Sender: TObject);
    procedure ButtonRefreshDevicesClick(Sender: TObject);
    procedure ComboDevicesChange(Sender: TObject);
    procedure ButtonRefreshAppsClick(Sender: TObject);
    procedure SearchBoxAppsChangeTracking(Sender: TObject);
    procedure ListBoxAppsChange(Sender: TObject);
    procedure ButtonUninstallAppClick(Sender: TObject);
    procedure ButtonAppInfoClick(Sender: TObject);
    procedure ButtonSelectAPKClick(Sender: TObject);
    procedure ButtonInstallAPKClick(Sender: TObject);
    procedure ButtonRebootClick(Sender: TObject);
    procedure ButtonRebootBootloaderClick(Sender: TObject);
    procedure ButtonRebootRecoveryClick(Sender: TObject);
    procedure ButtonScreenshotClick(Sender: TObject);
    procedure ButtonClearCacheClick(Sender: TObject);
    procedure ButtonExecuteCustomClick(Sender: TObject);
    procedure ButtonExecuteShellClick(Sender: TObject);
    procedure ButtonStartLogcatClick(Sender: TObject);
    procedure ButtonStopLogcatClick(Sender: TObject);
    procedure ButtonClearLogClick(Sender: TObject);
    procedure CheckBoxSystemAppsChange(Sender: TObject);
    procedure RectDropAreaDragOver(Sender: TObject; const Data: TDragObject;
      const Point: TPointF; var Operation: TDragOperation);
    procedure RectDropAreaDragDrop(Sender: TObject; const Data: TDragObject;
      const Point: TPointF);
    procedure FormShow(Sender: TObject);
    procedure BtnFiltrarClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SkAnimatedImage1AnimationFinish(Sender: TObject);

  private
    FADBPath: string;
    FCurrentDevice: string;
    FLogcatProcess: THandle;
    FLogcatRunning: Boolean;
    FAppList: TArray<TAppInfo>;
    FFilteredAppList: TArray<TAppInfo>;
    FCriticalSection: TCriticalSection;

    // Métodos internos
    procedure InitializeADB;
    procedure UpdateStatusSafe(const AMessage: string);
    procedure LogToConsoleSafe(const AMessage: string);
    function ExecuteADBCommand(const ACommand: string): string;
    procedure RefreshDeviceListAsync;
    procedure RefreshAppListAsync;
    procedure FilterAppList;
    procedure ShowAppDetails(const APackageName: string);
    procedure InstallAPKAsync(const AFilePath: string);
    procedure StartLogcat;
    procedure StopLogcat;
    function GetAppDisplayName(const APackageName: string): string;
    function IsSystemApp(const APackageName: string): Boolean;
    function IsValidAPKFile(const AFilePath: string): Boolean;
    procedure SetButtonsEnabled(AEnabled: Boolean);
  public

  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

// ===== INICIALIZAÇÃO =====

procedure TFormMain.FormCreate(Sender: TObject);
begin
  LayoutSplash.Visible := True;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  if FLogcatRunning then
    StopLogcat;

  if Assigned(FCriticalSection) then
    FCriticalSection.Free;
end;

procedure TFormMain.FormShow(Sender: TObject);
begin
  FLogcatRunning := False;
  FLogcatProcess := 0;
  FCriticalSection := TCriticalSection.Create;

  InitializeADB;

  // Configurar ComboBox de nível de log
  ComboLogLevel.ItemIndex := 0;

  // Inicializar na aba de aplicativos
  TabControl.ActiveTab := TabApps;

  UpdateStatusSafe('ADB Assistant iniciado - Pronto para uso');

  // Carregar dispositivos automaticamente
  RefreshDeviceListAsync;
end;

function GetADBPath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'adb\adb.exe';
end;

procedure TFormMain.InitializeADB;
begin
  // Definir caminho do ADB (relativo ao executável)
  FADBPath := GetADBPath;

  if not FileExists(FADBPath) then
  begin
    ShowMessage('ADB não encontrado em: ' + FADBPath + sLineBreak +
                'Certifique-se de que o adb.exe está na pasta "adb" do projeto.');
    FADBPath := 'adb.exe'; // Tentar usar ADB do PATH do sistema
  end;

  LogToConsoleSafe('ADB inicializado: ' + FADBPath);
end;

// ===== UTILITÁRIOS THREAD-SAFE =====

procedure TFormMain.UpdateStatusSafe(const AMessage: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      LabelStatus.Text := AMessage;
    end);
end;

procedure TFormMain.LogToConsoleSafe(const AMessage: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      FCriticalSection.Enter;
      try
        MemoConsole.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + AMessage);
        MemoConsole.GoToTextEnd;

        // Limitar linhas para performance
        if MemoConsole.Lines.Count > 1000 then
        begin
          while MemoConsole.Lines.Count > 800 do
            MemoConsole.Lines.Delete(0);
        end;
      finally
        FCriticalSection.Leave;
      end;
    end);
end;

procedure TFormMain.SetButtonsEnabled(AEnabled: Boolean);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      ButtonRefreshDevices.Enabled := AEnabled;
      ButtonRefreshApps.Enabled := AEnabled;
      ButtonUninstallApp.Enabled := AEnabled and (ListBoxApps.ItemIndex >= 0);
      ButtonInstallAPK.Enabled := AEnabled and (EditAPKPath.Text <> '');
    end);
end;

function TFormMain.ExecuteADBCommand(const ACommand: string): string;
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

    LogToConsoleSafe('Executando: ' + CmdLine);

    // Executar comando
    if CreateProcess(nil, PChar(CmdLine), nil, nil, True,
                     CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
    try
      CloseHandle(WritePipe);
      WritePipe := 0;

      // Aguardar conclusão com timeout
      WaitForSingleObject(ProcessInfo.hProcess, 30000); // 30 segundos timeout

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
      LogToConsoleSafe('Erro ao executar comando ADB');

  finally
    if WritePipe <> 0 then CloseHandle(WritePipe);
    CloseHandle(ReadPipe);
  end;

  LogToConsoleSafe('Resultado obtido (' + IntToStr(Length(Result)) + ' chars)');
end;

// ===== GERENCIAMENTO DE DISPOSITIVOS =====

procedure TFormMain.ButtonRefreshDevicesClick(Sender: TObject);
begin
  RefreshDeviceListAsync;
end;

procedure TFormMain.RefreshDeviceListAsync;
begin
  SetButtonsEnabled(False);
  UpdateStatusSafe('Atualizando lista de dispositivos...');

  TThread.CreateAnonymousThread(
    procedure
    var
      Output: string;
      Lines: TArray<string>;
      I: Integer;
      DeviceInfo: string;
      DeviceList: TStringList;
    begin
      DeviceList := TStringList.Create;
      try
        Output := ExecuteADBCommand('devices');
        Lines := Output.Split([#13#10, #10]);

        for I := 1 to High(Lines) do // Pular primeira linha "List of devices"
        begin
          if Lines[I].Trim <> '' then
          begin
            DeviceInfo := Lines[I].Trim;
            if DeviceInfo.Contains('device') and not DeviceInfo.Contains('unauthorized') then
            begin
              DeviceList.Add(DeviceInfo.Split([#9])[0]); // Só o ID do dispositivo
            end;
          end;
        end;

        // Atualizar UI na thread principal
        TThread.Synchronize(nil,
          procedure
          begin
            ComboDevices.Clear;
            ComboDevices.Items.AddStrings(DeviceList);

            if ComboDevices.Items.Count > 0 then
            begin
              ComboDevices.ItemIndex := 0;
              ComboDevicesChange(nil);
            end
            else
            begin
              LabelDeviceStatus.Text := 'Nenhum dispositivo conectado';
              UpdateStatusSafe('Nenhum dispositivo Android encontrado');
            end;

            SetButtonsEnabled(True);

          end);

      finally
        DeviceList.Free;
      end;
    end).Start;
end;

procedure TFormMain.ComboDevicesChange(Sender: TObject);
begin
  if ComboDevices.ItemIndex >= 0 then
  begin
    FCurrentDevice := ComboDevices.Selected.Text;
    LabelDeviceStatus.Text := 'Conectado: ' + FCurrentDevice;
    UpdateStatusSafe('Dispositivo selecionado: ' + FCurrentDevice);

    // Atualizar lista de aplicativos automaticamente
    RefreshAppListAsync;
  end;
end;

// ===== GERENCIAMENTO DE APLICATIVOS =====

procedure TFormMain.ButtonRefreshAppsClick(Sender: TObject);
begin
  RefreshAppListAsync;
end;

procedure TFormMain.RefreshAppListAsync;
begin
  if FCurrentDevice = '' then
  begin
    ShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  SetButtonsEnabled(False);
  UpdateStatusSafe('Carregando lista de aplicativos...');

  TThread.CreateAnonymousThread(
    procedure
    var
      Output: string;
      Lines: TArray<string>;
      I: Integer;
      PackageName: string;
      AppInfo: TAppInfo;
      TempAppList: TArray<TAppInfo>;
    begin
      SetLength(TempAppList, 0);

      // Listar todos os pacotes
      Output := ExecuteADBCommand('-s ' + FCurrentDevice + ' shell pm list packages');
      Lines := Output.Split([#13#10, #10]);

      for I := 0 to High(Lines) do
      begin
        if Lines[I].StartsWith('package:') then
        begin
          PackageName := Lines[I].Replace('package:', '').Trim;
          if PackageName <> '' then
          begin
            AppInfo.PackageName := PackageName;
            AppInfo.DisplayName := GetAppDisplayName(PackageName);
            AppInfo.IsSystemApp := IsSystemApp(PackageName);

            SetLength(TempAppList, Length(TempAppList) + 1);
            TempAppList[High(TempAppList)] := AppInfo;
          end;
        end;
      end;

      // Atualizar na thread principal
      TThread.Synchronize(nil,
        procedure
        begin
          FAppList := TempAppList;
          FilterAppList;
          UpdateStatusSafe(Format('Carregados %d aplicativos', [Length(FAppList)]));
          SetButtonsEnabled(True);
        end);
    end).Start;
end;

procedure TFormMain.FilterAppList;
var
  I: Integer;
  SearchText: string;
  ShowSystemApps: Boolean;
  Item: TListBoxItem;
begin
  ListBoxApps.Clear;
  SetLength(FFilteredAppList, 0);

  SearchText := SearchBoxApps.Text.ToLower;
  ShowSystemApps := CheckBoxSystemApps.IsChecked;

  for I := 0 to High(FAppList) do
  begin
    // Filtrar por texto de busca
    if (SearchText = '') or
       FAppList[I].PackageName.ToLower.Contains(SearchText) or
       FAppList[I].DisplayName.ToLower.Contains(SearchText) then
    begin
      // Filtrar apps do sistema
      if ShowSystemApps or not FAppList[I].IsSystemApp then
      begin
        SetLength(FFilteredAppList, Length(FFilteredAppList) + 1);
        FFilteredAppList[High(FFilteredAppList)] := FAppList[I];

        // Adicionar à ListBox
        Item := TListBoxItem.Create(ListBoxApps);
        Item.Parent := ListBoxApps;
        Item.ImageIndex := 0;
        Item.Font.Size := 18;
        Item.Text := FAppList[I].DisplayName + ' (' + FAppList[I].PackageName + ')';
        Item.Tag := High(FFilteredAppList); // Índice no array filtrado
      end;
    end;
  end;
end;

procedure TFormMain.SearchBoxAppsChangeTracking(Sender: TObject);
begin
  FilterAppList;
end;

procedure TFormMain.CheckBoxSystemAppsChange(Sender: TObject);
begin
  FilterAppList;
end;

procedure TFormMain.ListBoxAppsChange(Sender: TObject);
var
  SelectedIndex: Integer;
  PackageName: string;
begin
  if ListBoxApps.ItemIndex >= 0 then
  begin
    SelectedIndex := ListBoxApps.ListItems[ListBoxApps.ItemIndex].Tag;
    PackageName := FFilteredAppList[SelectedIndex].PackageName;

    ShowAppDetails(PackageName);
    ButtonUninstallApp.Enabled := not FFilteredAppList[SelectedIndex].IsSystemApp;
    ButtonAppInfo.Enabled := True;
  end
  else
  begin
    ButtonUninstallApp.Enabled := False;
    ButtonAppInfo.Enabled := False;
  end;
end;

procedure TFormMain.ShowAppDetails(const APackageName: string);
var
  I: Integer;
begin
  MemoAppDetails.Lines.Clear;

  // Mostrar informações básicas
  for I := 0 to High(FFilteredAppList) do
  begin
    if FFilteredAppList[I].PackageName = APackageName then
    begin
      MemoAppDetails.Lines.Add('Pacote: ' + FFilteredAppList[I].PackageName);
      MemoAppDetails.Lines.Add('Nome: ' + FFilteredAppList[I].DisplayName);
      MemoAppDetails.Lines.Add('Tipo: ' + IfThen(FFilteredAppList[I].IsSystemApp, 'Sistema', 'Usuário'));
      MemoAppDetails.Lines.Add('');
      MemoAppDetails.Lines.Add('Clique em "Obter Informações Detalhadas" para mais dados...');
      Break;
    end;
  end;
end;

procedure TFormMain.SkAnimatedImage1AnimationFinish(Sender: TObject);
begin
  LayoutSplash.Visible := False;
end;

procedure TFormMain.BtnFiltrarClick(Sender: TObject);
begin
  if FLogcatRunning then
  begin
    FLogcatRunning := False;

    if FLogcatProcess <> 0 then
    begin
      TerminateProcess(FLogcatProcess, 0);
      CloseHandle(FLogcatProcess);
      FLogcatProcess := 0;
    end;

    LogToConsoleSafe('=== FILTRANDO ===');
  end;

  TThread.CreateAnonymousThread(
   procedure
   begin
    Sleep(1000);
     TThread.Synchronize(nil,
     procedure
     begin
       StartLogcat
     end);
   end
     ).Start;


 { TThread.Synchronize(nil,
  procedure
  begin
    StartLogcat
  end); }
end;

procedure TFormMain.ButtonAppInfoClick(Sender: TObject);
var
  SelectedIndex: Integer;
  PackageName: string;
begin
  if ListBoxApps.ItemIndex >= 0 then
  begin
    SelectedIndex := ListBoxApps.ListItems[ListBoxApps.ItemIndex].Tag;
    PackageName := FFilteredAppList[SelectedIndex].PackageName;

    ButtonAppInfo.Enabled := False;
    UpdateStatusSafe('Obtendo informações detalhadas...');

    TTask.Run(
      procedure
      var
        DetailedInfo: string;
      begin
        DetailedInfo := ExecuteADBCommand('-s ' + FCurrentDevice + ' shell dumpsys package ' + PackageName);

        TThread.Synchronize(nil,
          procedure
          begin
            MemoAppDetails.Lines.Clear;
            MemoAppDetails.Lines.Add('=== INFORMAÇÕES DETALHADAS ===');
            MemoAppDetails.Lines.Add('Pacote: ' + PackageName);
            MemoAppDetails.Lines.Add('');
            MemoAppDetails.Lines.Add(DetailedInfo);
            UpdateStatusSafe('Informações detalhadas carregadas');
            ButtonAppInfo.Enabled := True;
          end);
      end);
  end;
end;

procedure TFormMain.ButtonUninstallAppClick(Sender: TObject);
var
  SelectedIndex: Integer;
  PackageName: string;
  AppName: string;
begin
  if ListBoxApps.ItemIndex >= 0 then
  begin
    SelectedIndex := ListBoxApps.ListItems[ListBoxApps.ItemIndex].Tag;
    PackageName := FFilteredAppList[SelectedIndex].PackageName;
    AppName := FFilteredAppList[SelectedIndex].DisplayName;

    if MessageDlg('Deseja realmente desinstalar o aplicativo?' + sLineBreak +
                  AppName + ' (' + PackageName + ')',
                  TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
    begin
      ButtonUninstallApp.Enabled := False;
      UpdateStatusSafe('Desinstalando aplicativo...');

      TTask.Run(
        procedure
        var
          Result: string;
        begin
          Result := ExecuteADBCommand('-s ' + FCurrentDevice + ' uninstall ' + PackageName);

          TThread.Synchronize(nil,
            procedure
            begin
              if Result.Contains('Success') then
              begin
                ShowMessage('Aplicativo desinstalado com sucesso!');
                RefreshAppListAsync;
              end
              else
                ShowMessage('Erro ao desinstalar aplicativo: ' + Result);

              UpdateStatusSafe('Pronto');
              ButtonUninstallApp.Enabled := True;
            end);
        end);
    end;
  end;
end;

// ===== INSTALAÇÃO DE APK =====

procedure TFormMain.ButtonSelectAPKClick(Sender: TObject);
begin
  if OpenDialogAPK.Execute then
  begin
    EditAPKPath.Text := OpenDialogAPK.FileName;
    ButtonInstallAPK.Enabled := IsValidAPKFile(OpenDialogAPK.FileName);
    LabelInstallStatus.Text := 'Arquivo selecionado: ' + ExtractFileName(OpenDialogAPK.FileName);
  end;
end;

procedure TFormMain.ButtonInstallAPKClick(Sender: TObject);
begin
  if EditAPKPath.Text <> '' then
    InstallAPKAsync(EditAPKPath.Text);
end;

procedure TFormMain.InstallAPKAsync(const AFilePath: string);
begin
  if FCurrentDevice = '' then
  begin
    ShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  if not IsValidAPKFile(AFilePath) then
  begin
    ShowMessage('Arquivo APK inválido');
    Exit;
  end;

  ButtonInstallAPK.Enabled := False;
  UpdateStatusSafe('Instalando APK...');

  TThread.Synchronize(nil,
    procedure
    begin
      LabelInstallStatus.Text := 'Instalando: ' + ExtractFileName(AFilePath);
      ProgressBarInstall.Value := 25;
    end);

  TTask.Run(
    procedure
    var
      Result: string;
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          ProgressBarInstall.Value := 50;
        end);

      Result := ExecuteADBCommand('-s ' + FCurrentDevice + ' install "' + AFilePath + '"');

      TThread.Synchronize(nil,
        procedure
        begin
          ProgressBarInstall.Value := 100;

          if Result.Contains('Success') then
          begin
            LabelInstallStatus.Text := 'Instalação concluída com sucesso!';
            ShowMessage('APK instalado com sucesso!');
            // Atualizar lista de apps
            RefreshAppListAsync;
          end
          else
          begin
            LabelInstallStatus.Text := 'Erro na instalação';
            ShowMessage('Erro ao instalar APK: ' + Result);
          end;

          ProgressBarInstall.Value := 0;
          UpdateStatusSafe('Pronto');
          ButtonInstallAPK.Enabled := True;
        end);
    end);
end;

// ===== DRAG AND DROP =====

procedure TFormMain.RectDropAreaDragOver(Sender: TObject; const Data: TDragObject;
  const Point: TPointF; var Operation: TDragOperation);
begin
  if Length(Data.Files) > 0 then
    Operation := TDragOperation.Copy
  else
    Operation := TDragOperation.None;
end;

procedure TFormMain.RectDropAreaDragDrop(Sender: TObject; const Data: TDragObject;
  const Point: TPointF);
begin
  if Length(Data.Files) > 0 then
  begin
    EditAPKPath.Text := Data.Files[0];
    ButtonInstallAPK.Enabled := IsValidAPKFile(Data.Files[0]);
    LabelInstallStatus.Text := 'Arquivo arrastado: ' + ExtractFileName(Data.Files[0]);
  end;
end;

// ===== FERRAMENTAS =====

procedure TFormMain.ButtonRebootClick(Sender: TObject);
begin
  if FCurrentDevice <> '' then
  begin
    if MessageDlg('Deseja reiniciar o dispositivo?', TMsgDlgType.mtConfirmation,
                  [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
    begin
      TTask.Run(
        procedure
        begin
          ExecuteADBCommand('-s ' + FCurrentDevice + ' reboot');
          UpdateStatusSafe('Comando de reinicialização enviado');
        end);
    end;
  end
  else
    ShowMessage('Selecione um dispositivo primeiro');
end;

procedure TFormMain.ButtonRebootBootloaderClick(Sender: TObject);
begin
  if FCurrentDevice <> '' then
  begin
    if MessageDlg('Deseja reiniciar no modo Bootloader?', TMsgDlgType.mtConfirmation,
                  [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
    begin
      TTask.Run(
        procedure
        begin
          ExecuteADBCommand('-s ' + FCurrentDevice + ' reboot bootloader');
          UpdateStatusSafe('Comando de reinicialização para bootloader enviado');
        end);
    end;
  end
  else
    ShowMessage('Selecione um dispositivo primeiro');
end;

procedure TFormMain.ButtonRebootRecoveryClick(Sender: TObject);
begin
  if FCurrentDevice <> '' then
  begin
    if MessageDlg('Deseja reiniciar no modo Recovery?', TMsgDlgType.mtConfirmation,
                  [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
    begin
      TTask.Run(
        procedure
        begin
          ExecuteADBCommand('-s ' + FCurrentDevice + ' reboot recovery');
          UpdateStatusSafe('Comando de reinicialização para recovery enviado');
        end);
    end;
  end
  else
    ShowMessage('Selecione um dispositivo primeiro');
end;

procedure TFormMain.ButtonScreenshotClick(Sender: TObject);
var
  TempFile: string;
  SavePath: string;
begin
  if FCurrentDevice = '' then
  begin
    ShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  if SaveDialogScreenshot.Execute then
  begin
    SavePath := SaveDialogScreenshot.FileName;
    TempFile := '/sdcard/screenshot.png';

    ButtonScreenshot.Enabled := False;
    UpdateStatusSafe('Capturando screenshot...');

    TTask.Run(
      procedure
      var
        Result1, Result2: string;
      begin
        // Capturar screenshot no dispositivo
        Result1 := ExecuteADBCommand('-s ' + FCurrentDevice + ' shell screencap -p ' + TempFile);

        // Transferir para o PC
        Result2 := ExecuteADBCommand('-s ' + FCurrentDevice + ' pull ' + TempFile + ' "' + SavePath + '"');

        // Limpar arquivo temporário
        ExecuteADBCommand('-s ' + FCurrentDevice + ' shell rm ' + TempFile);

        TThread.Synchronize(nil,
          procedure
          begin
            if FileExists(SavePath) then
            begin
              ShowMessage('Screenshot salvo com sucesso em: ' + SavePath);
              UpdateStatusSafe('Screenshot capturado');
            end
            else
            begin
              ShowMessage('Erro ao capturar screenshot');
              UpdateStatusSafe('Erro no screenshot');
            end;

            ButtonScreenshot.Enabled := True;
          end);
      end);
  end;
end;

procedure TFormMain.ButtonClearCacheClick(Sender: TObject);
begin
  if FCurrentDevice <> '' then
  begin
    if MessageDlg('Deseja limpar o cache do sistema?' + sLineBreak +
                  'Esta operação pode demorar alguns minutos.',
                  TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
    begin
      ButtonClearCache.Enabled := False;
      UpdateStatusSafe('Limpando cache do sistema...');

      TTask.Run(
        procedure
        var
          Result: string;
        begin
          Result := ExecuteADBCommand('-s ' + FCurrentDevice + ' shell pm trim-caches 1000000000');

          TThread.Synchronize(nil,
            procedure
            begin
              ShowMessage('Cache do sistema limpo');
              UpdateStatusSafe('Cache limpo com sucesso');
              ButtonClearCache.Enabled := True;
            end);
        end);
    end;
  end
  else
    ShowMessage('Selecione um dispositivo primeiro');
end;

procedure TFormMain.ButtonExecuteCustomClick(Sender: TObject);
var
  Command: string;
begin
  Command := EditCustomCommand.Text.Trim;

  if Command = '' then
  begin
    ShowMessage('Digite um comando primeiro');
    Exit;
  end;

  if FCurrentDevice = '' then
  begin
    ShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  ButtonExecuteCustom.Enabled := False;
  UpdateStatusSafe('Executando comando personalizado...');

  TThread.Synchronize(nil,
    procedure
    begin
      MemoCustomOutput.Lines.Add('> ' + Command);
    end);

  TTask.Run(
    procedure
    var
      Result: string;
      FullCommand: string;
    begin
      // Se o comando não começar com -s, adicionar o dispositivo
      if not Command.StartsWith('-s') then
        FullCommand := '-s ' + FCurrentDevice + ' ' + Command
      else
        FullCommand := Command;

      Result := ExecuteADBCommand(FullCommand);

      TThread.Synchronize(nil,
        procedure
        begin
          MemoCustomOutput.Lines.Add(Result);
          MemoCustomOutput.Lines.Add('---');
          MemoCustomOutput.GoToTextEnd;
          UpdateStatusSafe('Comando executado');
          ButtonExecuteCustom.Enabled := True;
        end);
    end);
end;

procedure TFormMain.ButtonExecuteShellClick(Sender: TObject);
var
  Command: string;
begin
  Command := EditShellCommand.Text.Trim;

  if Command = '' then
  begin
    ShowMessage('Digite um comando shell primeiro');
    Exit;
  end;

  if FCurrentDevice = '' then
  begin
    ShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  ButtonExecuteShell.Enabled := False;
  UpdateStatusSafe('Executando comando shell...');

  TTask.Run(
    procedure
    var
      Result: string;
      FullCommand: string;
    begin
      FullCommand := '-s ' + FCurrentDevice + ' shell ' + Command;
      Result := ExecuteADBCommand(FullCommand);

      TThread.Synchronize(nil,
        procedure
        begin
          MemoCustomOutput.Lines.Add('Shell> ' + Command);
          MemoCustomOutput.Lines.Add(Result);
          MemoCustomOutput.Lines.Add('---');
          MemoCustomOutput.GoToTextEnd;
          UpdateStatusSafe('Comando shell executado');
          EditShellCommand.Text := '';
          ButtonExecuteShell.Enabled := True;
        end);
    end);
end;

// ===== CONSOLE/LOGCAT =====

procedure TFormMain.ButtonStartLogcatClick(Sender: TObject);
begin
  if FCurrentDevice = '' then
  begin
    ShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  UpdateStatusSafe('Iniciando logcat...');
  LogToConsoleSafe('=== LOGCAT INICIADO ===');
  StartLogcat;
end;

procedure TFormMain.ButtonStopLogcatClick(Sender: TObject);
begin
  StopLogcat;
  LogToConsoleSafe('=== LOGCAT FINALIZADO ===');
  UpdateStatusSafe('Logcat parado');
end;

procedure TFormMain.ButtonClearLogClick(Sender: TObject);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      FCriticalSection.Enter;
      try
        MemoConsole.Lines.Clear;
        ListBoxConsole.Items.Clear;
      finally
        FCriticalSection.Leave;
      end;
    end);
  UpdateStatusSafe('Console limpo');
end;

procedure TFormMain.StartLogcat;
var
  LogLevel: string;
  Filter: string;
  Command: string;
begin
  if FLogcatRunning then
  begin
    ShowMessage('Logcat já está em execução');
    Exit;
  end;

  // Determinar nível de log
  case ComboLogLevel.ItemIndex of
    0: LogLevel := '';          // Todos
    1: LogLevel := '*:V';       // Verbose
    2: LogLevel := '*:D';       // Debug
    3: LogLevel := '*:I';       // Info
    4: LogLevel := '*:W';       // Warning
    5: LogLevel := '*:E';       // Error
  else
    LogLevel := '';
  end;

  // Limpar console antes de iniciar
  ListBoxConsole.Clear;

  // Filtro personalizado
  Filter := EditLogFilter.Text.Trim;

  // Montar comando
  Command := '-s ' + FCurrentDevice + ' logcat';
  if LogLevel <> '' then
    Command := Command + ' ' + LogLevel;

  FLogcatRunning := True;

  TThread.Synchronize(nil,
    procedure
    begin
      ButtonStartLogcat.Enabled := False;
      ButtonStopLogcat.Enabled := True;
    end);

  TThread.CreateAnonymousThread(
   procedure
   var
      StartupInfo: TStartupInfo;
      ProcessInfo: TProcessInformation;
      SecurityAttrs: TSecurityAttributes;
      ReadPipe, WritePipe: THandle;
      Buffer: array[0..4095] of AnsiChar;
      BytesRead: Cardinal;
      CmdLine: string;
      Line: string;
      OutputBuffer: TStringBuilder;
      LastUpdate: TDateTime;
      LineCount: Integer;
      PendingLines: TArray<string>;

   begin
     OutputBuffer := TStringBuilder.Create;
     LineCount := 0;
     LastUpdate := Now;

      try
        // Configurar pipes
        SecurityAttrs.nLength := SizeOf(SecurityAttrs);
        SecurityAttrs.lpSecurityDescriptor := nil;
        SecurityAttrs.bInheritHandle := True;

        if CreatePipe(ReadPipe, WritePipe, @SecurityAttrs, 0) then
        try
          // Configurar processo
          FillChar(StartupInfo, SizeOf(StartupInfo), 0);
          StartupInfo.cb := SizeOf(StartupInfo);
          StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
          StartupInfo.hStdOutput := WritePipe;
          StartupInfo.hStdError := WritePipe;
          StartupInfo.wShowWindow := SW_HIDE;

          CmdLine := '"' + FADBPath + '" ' + Command;

          if CreateProcess(nil, PChar(CmdLine), nil, nil, True,
                           CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
          try
            FLogcatProcess := ProcessInfo.hProcess;
            CloseHandle(WritePipe);
            WritePipe := 0;

            // Ler saída continuamente
            while FLogcatRunning and ReadFile(ReadPipe, Buffer, SizeOf(Buffer), BytesRead, nil) and (BytesRead > 0) do
            begin
              Line := string(AnsiString(Copy(Buffer, 0, BytesRead)));
              OutputBuffer.Append(Line);

              // Processar a cada 10 linhas OU a cada 100ms
              if (LineCount mod 10 = 0) or (MilliSecondsBetween(Now, LastUpdate) > 100) then
              begin
                LastUpdate := Now;

                // Extrair linhas completas
                var TempText := OutputBuffer.ToString;
                var Lines := TempText.Split([#13#10, #10, #13]);

                if Length(Lines) > 1 then
                begin
                  // Manter última linha parcial
                  var LastLine := Lines[High(Lines)];
                  OutputBuffer.Clear;
                  OutputBuffer.Append(LastLine);

                  // Processar apenas linhas completas
                  SetLength(PendingLines, Length(Lines) - 1);
                  for var i := 0 to High(Lines) - 1 do
                    PendingLines[i] := Lines[i];

                  // Processar em lotes pequenos
                  TThread.Synchronize(nil,
                    procedure
                    var
                      I: Integer;
                      FilterText: string;
                      LogLine: string;
                      LogType: Char;
                      TextColor: TAlphaColor;
                      ListBoxItem: TListBoxItem;
                      ProcessedCount: Integer;

                      // Função para processar tipo de log rapidamente
                      function FastGetLogTypeLocal(const Line: string): Char;
                      begin
                        Result := 'I'; // Default
                        if Line.Length > 20 then
                        begin
                          // Busca rápida pelo nível na posição típica
                          if (Line[20] = 'V') or (Line[21] = 'V') or (Line[22] = 'V') then Result := 'V'
                          else if (Line[20] = 'D') or (Line[21] = 'D') or (Line[22] = 'D') then Result := 'D'
                          else if (Line[20] = 'I') or (Line[21] = 'I') or (Line[22] = 'I') then Result := 'I'
                          else if (Line[20] = 'W') or (Line[21] = 'W') or (Line[22] = 'W') then Result := 'W'
                          else if (Line[20] = 'E') or (Line[21] = 'E') or (Line[22] = 'E') then Result := 'E'
                          else if (Line[20] = 'F') or (Line[21] = 'F') or (Line[22] = 'F') then Result := 'F'
                          else
                          begin
                            // Busca alternativa
                            if Line.Contains(' V ') then Result := 'V'
                            else if Line.Contains(' D ') then Result := 'D'
                            else if Line.Contains(' W ') then Result := 'W'
                            else if Line.Contains(' E ') then Result := 'E'
                            else if Line.Contains(' F ') then Result := 'F';
                          end;
                        end;
                      end;

                      // Função para cor rápida
                      function FastGetColorLocal(LogType: Char): TAlphaColor;
                      begin
                        case LogType of
                          'V': Result := $FF808080;  // Cinza
                          'D': Result := $FF0066CC;  // Azul
                          'I': Result := $FF009900;  // Verde
                          'W': Result := $FFFF6600;  // Laranja
                          'E': Result := $FFCC0000;  // Vermelho
                          'F': Result := $FF800000;  // Vermelho escuro
                        else
                          Result := $FF000000;       // Preto
                        end;
                      end;

                    begin
                      FCriticalSection.Enter;
                      try
                        FilterText := EditLogFilter.Text.Trim.ToLower;
                        ProcessedCount := 0;

                        // Usar BeginUpdate para melhor performance
                        ListBoxConsole.BeginUpdate;
                        try
                          for I := 0 to High(PendingLines) do
                          begin
                            if PendingLines[I].Trim <> '' then
                            begin
                              LogLine := PendingLines[I].Trim;

                              // Aplicar filtro
                              if (FilterText = '') or LogLine.ToLower.Contains(FilterText) then
                              begin
                                // Processar tipo e cor
                                LogType := FastGetLogTypeLocal(LogLine);
                                TextColor := FastGetColorLocal(LogType);

                                // Criar item
                                ListBoxItem := TListBoxItem.Create(ListBoxConsole);
                                ListBoxItem.Parent := ListBoxConsole;
                                ListBoxItem.Text := LogLine;
                                ListBoxItem.Height := 18;
                                ListBoxItem.TextSettings.FontColor := TextColor;
                                ListBoxItem.StyledSettings := ListBoxItem.StyledSettings - [TStyledSetting.FontColor];

                                // Formatação especial
                                case LogType of
                                  'E', 'F': ListBoxItem.TextSettings.Font.Style := [TFontStyle.fsBold];
                                  'W': ListBoxItem.TextSettings.Font.Style := [TFontStyle.fsItalic];
                                end;

                                ListBoxConsole.AddObject(ListBoxItem);
                                Inc(ProcessedCount);

                                // Limitar processamento por ciclo
                                if ProcessedCount > 50 then
                                  Break;
                              end;
                            end;
                          end;
                        finally
                          ListBoxConsole.EndUpdate;
                        end;

                        // Scroll automático (apenas se necessário)
                        if ListBoxConsole.Count > 0 then
                        begin
                          ListBoxConsole.ItemIndex := ListBoxConsole.Count - 1;
                        end;

                        // Limpeza de performance
                        if ListBoxConsole.Count > 800 then
                        begin
                          ListBoxConsole.BeginUpdate;
                          try
                            while ListBoxConsole.Count > 600 do
                              ListBoxConsole.Items.Delete(0);
                          finally
                            ListBoxConsole.EndUpdate;
                          end;
                        end;

                      finally
                        FCriticalSection.Leave;
                      end;
                    end);
                end;
              end;

              Inc(LineCount);
            end;

          finally
            CloseHandle(ProcessInfo.hThread);
          end;

        finally
          if WritePipe <> 0 then CloseHandle(WritePipe);
          CloseHandle(ReadPipe);
        end;

        // Finalizar
        TThread.Synchronize(nil,
          procedure
          begin
            FLogcatRunning := False;
            FLogcatProcess := 0;
            ButtonStartLogcat.Enabled := True;
            ButtonStopLogcat.Enabled := False;
          end);

      finally
        OutputBuffer.Free;
      end;
   end
     ).Start;
end;

procedure TFormMain.StopLogcat;
begin
  if FLogcatRunning then
  begin
    FLogcatRunning := False;

    if FLogcatProcess <> 0 then
    begin
      TerminateProcess(FLogcatProcess, 0);
      CloseHandle(FLogcatProcess);
      FLogcatProcess := 0;
    end;

    TThread.Synchronize(nil,
      procedure
      begin
        ButtonStartLogcat.Enabled := True;
        ButtonStopLogcat.Enabled := False;
      end);

    LogToConsoleSafe('=== LOGCAT PARADO ===');
    UpdateStatusSafe('Logcat parado pelo usuário');
  end;
end;

// ===== FUNÇÕES AUXILIARES =====

function TFormMain.GetAppDisplayName(const APackageName: string): string;
var
  Output: string;
  Lines: TArray<string>;
  I: Integer;
begin
  Result := APackageName; // Padrão: usar o nome do pacote

  try
    // Tentar obter o nome legível do app (versão simplificada para performance)
    if APackageName.Contains('.') then
    begin
      var Parts := APackageName.Split(['.']);
      Result := Parts[High(Parts)];
      Result := Result.Substring(0, 1).ToUpper + Result.Substring(1); // Primeira letra maiúscula
    end;
  except
    // Em caso de erro, manter o nome do pacote
  end;
end;

function TFormMain.IsSystemApp(const APackageName: string): Boolean;
var
  Output: string;
begin
  Result := False;

  try
    // Verificação simplificada para melhor performance
    // Apps do sistema geralmente estão em com.android, com.google, android
    Result := APackageName.StartsWith('com.android') or
              APackageName.StartsWith('android') or
              APackageName.StartsWith('com.google.android') or
              APackageName.StartsWith('com.sec.') or  // Samsung
              APackageName.StartsWith('com.samsung') or
              APackageName.StartsWith('com.lge.') or  // LG
              APackageName.StartsWith('com.htc.') or  // HTC
              APackageName.StartsWith('com.miui.');    // Xiaomi
  except
    // Em caso de erro, assumir que não é sistema
    Result := False;
  end;
end;

function TFormMain.IsValidAPKFile(const AFilePath: string): Boolean;
begin
  Result := FileExists(AFilePath) and
            (ExtractFileExt(AFilePath).ToLower = '.apk') and
            (TFile.GetSize(AFilePath) > 1024); // Pelo menos 1KB
end;

end.
