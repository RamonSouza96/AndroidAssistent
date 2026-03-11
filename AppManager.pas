unit AppManager;

interface

uses
  System.Classes, System.SysUtils, System.Threading, System.StrUtils,
  FMX.StdCtrls, FMX.Edit, FMX.Memo, FMX.ListBox, FMX.SearchBox, FMX.Dialogs,
  Winapi.Windows, Winapi.Messages;

type
  TAppInfo = record
    PackageName: string;
    DisplayName: string;
    IsSystemApp: boolean;
  end;

  TAppManager = class
  private
    FADBPath: string;
    FCurrentDevice: string;
    FAppList: TArray<TAppInfo>;
    FFilteredAppList: TArray<TAppInfo>;
    
    // Componentes UI
    FSearchBoxApps: TSearchBox;
    FButtonRefreshApps: TButton;
    FButtonUninstallApp: TButton;
    FButtonAppInfo: TButton;
    FCheckBoxSystemApps: TCheckBox;
    FListBoxApps: TListBox;
    FMemoAppDetails: TMemo;
    FLabelAppDetailsTitle: TLabel;
    
    // Eventos
    FOnStatusUpdate: procedure(const AMessage: string) of object;
    FOnLogMessage: procedure(const AMessage: string) of object;
    FOnShowMessage: procedure(const AMessage: string) of object;
    FOnShowConfirmation: function(const AMessage: string): Boolean of object;
    
    function ExecuteADBCommand(const ACommand: string): string;
    function GetAppDisplayName(const APackageName: string): string;
    function IsSystemApp(const APackageName: string): Boolean;
    procedure SetButtonsEnabled(AEnabled: Boolean);
    procedure FilterAppList;
    procedure ShowAppDetails(const APackageName: string);
    
  public
    constructor Create(const AADBPath: string;
                      ASearchBoxApps: TSearchBox;
                      AButtonRefreshApps: TButton;
                      AButtonUninstallApp: TButton;
                      AButtonAppInfo: TButton;
                      ACheckBoxSystemApps: TCheckBox;
                      AListBoxApps: TListBox;
                      AMemoAppDetails: TMemo;
                      ALabelAppDetailsTitle: TLabel);
    destructor Destroy; override;
    
    procedure SetCurrentDevice(const ADevice: string);
    procedure RefreshAppList;
    procedure UninstallSelectedApp;
    procedure ShowSelectedAppInfo;
    procedure HandleSearchChange;
    procedure HandleSystemAppsToggle;
    procedure HandleAppSelection;
  end;

implementation

{ TAppManager }

constructor TAppManager.Create(const AADBPath: string;
                              ASearchBoxApps: TSearchBox;
                              AButtonRefreshApps: TButton;
                              AButtonUninstallApp: TButton;
                              AButtonAppInfo: TButton;
                              ACheckBoxSystemApps: TCheckBox;
                              AListBoxApps: TListBox;
                              AMemoAppDetails: TMemo;
                              ALabelAppDetailsTitle: TLabel);
begin
  inherited Create;
  
  FADBPath := AADBPath;
  
  // Armazenar referências dos componentes UI
  FSearchBoxApps := ASearchBoxApps;
  FButtonRefreshApps := AButtonRefreshApps;
  FButtonUninstallApp := AButtonUninstallApp;
  FButtonAppInfo := AButtonAppInfo;
  FCheckBoxSystemApps := ACheckBoxSystemApps;
  FListBoxApps := AListBoxApps;
  FMemoAppDetails := AMemoAppDetails;
  FLabelAppDetailsTitle := ALabelAppDetailsTitle;
  
  // Configurar estado inicial
  FButtonUninstallApp.Enabled := False;
  FButtonAppInfo.Enabled := False;
  
  // Inicializar arrays
  SetLength(FAppList, 0);
  SetLength(FFilteredAppList, 0);
end;

destructor TAppManager.Destroy;
begin
  inherited;
end;

procedure TAppManager.SetCurrentDevice(const ADevice: string);
begin
  FCurrentDevice := ADevice;
end;

procedure TAppManager.SetButtonsEnabled(AEnabled: Boolean);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      FButtonRefreshApps.Enabled := AEnabled;
      FButtonUninstallApp.Enabled := AEnabled and (FListBoxApps.ItemIndex >= 0);
      FButtonAppInfo.Enabled := AEnabled and (FListBoxApps.ItemIndex >= 0);
    end);
end;

function TAppManager.ExecuteADBCommand(const ACommand: string): string;
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

procedure TAppManager.RefreshAppList;
begin
  if FCurrentDevice = '' then
  begin
    if Assigned(FOnShowMessage) then
      FOnShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  SetButtonsEnabled(False);
  
  if Assigned(FOnStatusUpdate) then
    FOnStatusUpdate('Carregando lista de aplicativos...');

  TTask.Run(
    procedure
    var
      Output: string;
      Lines: TArray<string>;
      I: Integer;
      PackageName: string;
      AppInfo: TAppInfo;
      TempAppList: TArray<TAppInfo>;
    begin
      try
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
            
            if Assigned(FOnStatusUpdate) then
              FOnStatusUpdate(Format('Carregados %d aplicativos', [Length(FAppList)]));
          end);

      finally
        SetButtonsEnabled(True);
      end;
    end);
end;

procedure TAppManager.FilterAppList;
var
  I: Integer;
  SearchText: string;
  ShowSystemApps: Boolean;
  Item: TListBoxItem;
begin
  FListBoxApps.Clear;
  SetLength(FFilteredAppList, 0);

  SearchText := FSearchBoxApps.Text.ToLower;
  ShowSystemApps := FCheckBoxSystemApps.IsChecked;

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
        Item := TListBoxItem.Create(FListBoxApps);
        Item.Parent := FListBoxApps;
        Item.Text := FAppList[I].DisplayName + ' (' + FAppList[I].PackageName + ')';
        Item.Tag := High(FFilteredAppList); // Índice no array filtrado
      end;
    end;
  end;
end;

procedure TAppManager.HandleSearchChange;
begin
  FilterAppList;
end;

procedure TAppManager.HandleSystemAppsToggle;
begin
  FilterAppList;
end;

procedure TAppManager.HandleAppSelection;
var
  SelectedIndex: Integer;
  PackageName: string;
begin
  if FListBoxApps.ItemIndex >= 0 then
  begin
    SelectedIndex := FListBoxApps.ListItems[FListBoxApps.ItemIndex].Tag;
    PackageName := FFilteredAppList[SelectedIndex].PackageName;

    ShowAppDetails(PackageName);
    
    TThread.Synchronize(nil,
      procedure
      begin
        FButtonUninstallApp.Enabled := not FFilteredAppList[SelectedIndex].IsSystemApp;
        FButtonAppInfo.Enabled := True;
      end);
  end
  else
  begin
    TThread.Synchronize(nil,
      procedure
      begin
        FButtonUninstallApp.Enabled := False;
        FButtonAppInfo.Enabled := False;
      end);
  end;
end;

procedure TAppManager.ShowAppDetails(const APackageName: string);
var
  I: Integer;
begin
  FMemoAppDetails.Lines.Clear;

  // Mostrar informações básicas
  for I := 0 to High(FFilteredAppList) do
  begin
    if FFilteredAppList[I].PackageName = APackageName then
    begin
      FMemoAppDetails.Lines.Add('Pacote: ' + FFilteredAppList[I].PackageName);
      FMemoAppDetails.Lines.Add('Nome: ' + FFilteredAppList[I].DisplayName);
      FMemoAppDetails.Lines.Add('Tipo: ' + IfThen(FFilteredAppList[I].IsSystemApp, 'Sistema', 'Usuário'));
      FMemoAppDetails.Lines.Add('');
      FMemoAppDetails.Lines.Add('Clique em "Obter Informações Detalhadas" para mais dados...');
      Break;
    end;
  end;
end;

procedure TAppManager.ShowSelectedAppInfo;
var
  SelectedIndex: Integer;
  PackageName: string;
begin
  if FListBoxApps.ItemIndex >= 0 then
  begin
    SelectedIndex := FListBoxApps.ListItems[FListBoxApps.ItemIndex].Tag;
    PackageName := FFilteredAppList[SelectedIndex].PackageName;

    SetButtonsEnabled(False);
    
    if Assigned(FOnStatusUpdate) then
      FOnStatusUpdate('Obtendo informações detalhadas...');

    TTask.Run(
      procedure
      var
        DetailedInfo: string;
      begin
        try
          DetailedInfo := ExecuteADBCommand('-s ' + FCurrentDevice + ' shell dumpsys package ' + PackageName);

          TThread.Synchronize(nil,
            procedure
            begin
              FMemoAppDetails.Lines.Clear;
              FMemoAppDetails.Lines.Add('=== INFORMAÇÕES DETALHADAS ===');
              FMemoAppDetails.Lines.Add('Pacote: ' + PackageName);
              FMemoAppDetails.Lines.Add('');
              FMemoAppDetails.Lines.Add(DetailedInfo);
              
              if Assigned(FOnStatusUpdate) then
                FOnStatusUpdate('Informações detalhadas carregadas');
            end);
            
        finally
          SetButtonsEnabled(True);
        end;
      end);
  end;
end;

procedure TAppManager.UninstallSelectedApp;
var
  SelectedIndex: Integer;
  PackageName: string;
  AppName: string;
begin
  if FListBoxApps.ItemIndex >= 0 then
  begin
    SelectedIndex := FListBoxApps.ListItems[FListBoxApps.ItemIndex].Tag;
    PackageName := FFilteredAppList[SelectedIndex].PackageName;
    AppName := FFilteredAppList[SelectedIndex].DisplayName;

    if Assigned(FOnShowConfirmation) and
       FOnShowConfirmation('Deseja realmente desinstalar o aplicativo?' + sLineBreak +
                          AppName + ' (' + PackageName + ')') then
    begin
      SetButtonsEnabled(False);
      
      if Assigned(FOnStatusUpdate) then
        FOnStatusUpdate('Desinstalando aplicativo...');

      TTask.Run(
        procedure
        var
          Result: string;
        begin
          try
            Result := ExecuteADBCommand('-s ' + FCurrentDevice + ' uninstall ' + PackageName);

            TThread.Synchronize(nil,
              procedure
              begin
                if Result.Contains('Success') then
                begin
                  if Assigned(FOnShowMessage) then
                    FOnShowMessage('Aplicativo desinstalado com sucesso!');
                    
                  RefreshAppList;
                end
                else
                begin
                  if Assigned(FOnShowMessage) then
                    FOnShowMessage('Erro ao desinstalar aplicativo: ' + Result);
                end;

                if Assigned(FOnStatusUpdate) then
                  FOnStatusUpdate('Pronto');
              end);
              
          finally
            SetButtonsEnabled(True);
          end;
        end);
    end;
  end;
end;

function TAppManager.GetAppDisplayName(const APackageName: string): string;
var
  Parts: TArray<string>;
begin
  Result := APackageName; // Padrão: usar o nome do pacote

  try
    // Tentar obter o nome legível do app (versão simplificada para performance)
    if APackageName.Contains('.') then
    begin
      Parts := APackageName.Split(['.']);
      Result := Parts[High(Parts)];
      Result := Result.Substring(0, 1).ToUpper + Result.Substring(1); // Primeira letra maiúscula
    end;
  except
    // Em caso de erro, manter o nome do pacote
  end;
end;

function TAppManager.IsSystemApp(const APackageName: string): Boolean;
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

end. 