unit LogcatManager;

interface

uses
  System.Classes, System.SysUtils, System.Threading, System.SyncObjs,
  System.UITypes, System.DateUtils, System.StrUtils, System.Generics.Collections,
  FMX.Memo, FMX.ComboEdit, FMX.Edit, FMX.StdCtrls, FMX.Controls,
  Winapi.Windows, Winapi.Messages, FMX.ListBox, FMX.Dialogs,
  FMX.Types, System.Math;

type
  // Enum para níveis de log
  TLogLevel = (llAll, llVerbose, llDebug, llInfo, llWarning, llError);

  // Tipo para caractere de log
  TLogType = (ltVerbose, ltDebug, ltInfo, ltWarning, ltError, ltFatal, ltUnknown);

  // Record para configurações do logcat
  TLogcatConfig = record
    LogLevel: TLogLevel;
    FilterText: string;
    MaxLines: Integer;
    UpdateInterval: Integer; // em milissegundos
    DeviceId: string;
    ADBPath: string;
  end;

  // Record para um item de log
  TLogItem = record
    Text: string;
    LogType: TLogType;
    Color: TAlphaColor;
    Timestamp: TDateTime;
  end;

  // Interface para callback de eventos
  ILogcatEventHandler = interface
    ['{8B2F5C91-4A2E-4F2A-9B8E-1C5D7E9F3A4B}']
    procedure OnLogReceived(const LogItem: TLogItem);
    procedure OnStatusChanged(const Status: string);
    procedure OnError(const ErrorMsg: string);
    procedure OnFilterChanged;
  end;

  // Classe principal do gerenciador de logcat
  TLogcatManager = class
  private
    class var FInstance: TLogcatManager;
    class var FInstanceLock: TCriticalSection;

    // Variáveis de controle de instância
    FLogcatProcess: THandle;
    FLogcatRunning: Boolean;
    FCriticalSection: TCriticalSection;
    FFilterTimer: TTimer;
    FConfig: TLogcatConfig;
    FEventHandler: ILogcatEventHandler;
    FOutputBuffer: TStringBuilder;
    FLastUpdate: TDateTime;

    // Lista completa de logs (para filtro)
    FAllLogItems: TList<TLogItem>;

    // Métodos privados
    constructor Create;
    destructor Destroy; override;

    function BuildLogcatCommand: string;
    function ExtractLogType(const Line: string): TLogType;
    function GetLogColor(LogType: TLogType): TAlphaColor;
    function ShouldFilterLine(const LogItem: TLogItem): Boolean;
    function PassesLogLevelFilter(LogType: TLogType): Boolean;

    procedure ProcessLogOutput(const Output: string);
    procedure UpdateUI(const Lines: TArray<string>);
    procedure CleanupProcess;
    procedure StartReadingThread;

    // Getters e Setters para propriedades
    function GetIsRunning: Boolean;
    function GetConfig: TLogcatConfig;
    procedure SetConfig(const Value: TLogcatConfig);
    function GetEventHandler: ILogcatEventHandler;
    procedure SetEventHandler(const Value: ILogcatEventHandler);

  public
    // Singleton
    class function GetInstance: TLogcatManager;
    class procedure ReleaseInstance;

    // Propriedades
    property IsRunning: Boolean read GetIsRunning;
    property Config: TLogcatConfig read GetConfig write SetConfig;
    property EventHandler: ILogcatEventHandler read GetEventHandler write SetEventHandler;

    // Métodos principais
    procedure StartLogcat;
    procedure StopLogcat;
    procedure SetFilter(const FilterText: string);
    procedure SetLogLevel(Level: TLogLevel);
    procedure ApplyFilters;
    procedure ClearLogs;
    procedure ClearFilters;

    // Acesso à lista completa de logs
    function GetAllLogItems: TArray<TLogItem>;
    function GetFilteredLogItems: TArray<TLogItem>;

    // Métodos utilitários
    class procedure UpdateStatus(const AMessage: string; ALabel: TLabel);
  end;

  // Implementação da interface de eventos para integração com a UI
  TLogcatUIHandler = class(TInterfacedObject, ILogcatEventHandler)
  private
    FListBox: TListBox;
    FStatusLabel: TLabel;
    FStartButton: TButton;
    FStopButton: TButton;
    FComboLogLevel: TComboBox;
    FEditFilter: TEdit;

    // Timer para filtro em tempo real
    FFilterTimer: TTimer;

    procedure FilterTimerTimer(Sender: TObject);
    procedure UpdateListBox;

  public
    constructor Create(AListBox: TListBox; AStatusLabel: TLabel;
                     AStartButton, AStopButton: TButton;
                     AComboLogLevel: TComboBox; AEditFilter: TEdit);
    destructor Destroy; override;

    // ILogcatEventHandler
    procedure OnLogReceived(const LogItem: TLogItem);
    procedure OnStatusChanged(const Status: string);
    procedure OnError(const ErrorMsg: string);
    procedure OnFilterChanged;
  end;

implementation

uses Main.Settings;

{ TLogcatManager }

constructor TLogcatManager.Create;
begin
  inherited;
  FLogcatProcess := 0;
  FLogcatRunning := False;
  FCriticalSection := TCriticalSection.Create;
  FOutputBuffer := TStringBuilder.Create;
  FLastUpdate := Now;
  FAllLogItems := TList<TLogItem>.Create;

  // Configurações padrão
  FConfig.LogLevel := llAll;
  FConfig.FilterText := '';
  FConfig.MaxLines := 3000;
  FConfig.UpdateInterval := 200;
end;

destructor TLogcatManager.Destroy;
begin
  StopLogcat;

  if Assigned(FFilterTimer) then
    FFilterTimer.Free;

  FCriticalSection.Free;
  FOutputBuffer.Free;
  FAllLogItems.Free;
  inherited;
end;

class function TLogcatManager.GetInstance: TLogcatManager;
begin
  if not Assigned(FInstanceLock) then
    FInstanceLock := TCriticalSection.Create;

  FInstanceLock.Enter;
  try
    if not Assigned(FInstance) then
      FInstance := TLogcatManager.Create;
    Result := FInstance;
  finally
    FInstanceLock.Leave;
  end;
end;

class procedure TLogcatManager.ReleaseInstance;
begin
  if Assigned(FInstanceLock) then
  begin
    FInstanceLock.Enter;
    try
      if Assigned(FInstance) then
      begin
        FInstance.Free;
        FInstance := nil;
      end;
    finally
      FInstanceLock.Leave;
    end;

    FInstanceLock.Free;
    FInstanceLock := nil;
  end;
end;

// Getters e Setters
function TLogcatManager.GetIsRunning: Boolean;
begin
  Result := FLogcatRunning;
end;

function TLogcatManager.GetConfig: TLogcatConfig;
begin
  Result := FConfig;
end;

procedure TLogcatManager.SetConfig(const Value: TLogcatConfig);
begin
  FConfig := Value;
end;

function TLogcatManager.GetEventHandler: ILogcatEventHandler;
begin
  Result := FEventHandler;
end;

procedure TLogcatManager.SetEventHandler(const Value: ILogcatEventHandler);
begin
  FEventHandler := Value;
end;

function TLogcatManager.BuildLogcatCommand: string;
begin
  // Sempre capturar todos os níveis - filtro será aplicado na interface
  Result := '-s ' + FConfig.DeviceId + ' logcat';
end;

function TLogcatManager.ExtractLogType(const Line: string): TLogType;
var
  LineParts: TArray<string>;
  I: Integer;
begin
  Result := ltUnknown;

  try
    // Método 1: Formato padrão do logcat
    LineParts := Line.Split([' '], TStringSplitOptions.ExcludeEmpty);

    // Procurar por uma letra isolada que seja um nível de log válido
    for I := 0 to Min(High(LineParts), 10) do
    begin
      if (Length(LineParts[I]) = 1) and (LineParts[I][1] in ['V', 'D', 'I', 'W', 'E', 'F']) then
      begin
        case LineParts[I][1] of
          'V': Result := ltVerbose;
          'D': Result := ltDebug;
          'I': Result := ltInfo;
          'W': Result := ltWarning;
          'E': Result := ltError;
          'F': Result := ltFatal;
        end;
        Exit;
      end;
    end;

    // Método 2: Busca por padrões comuns
    if Line.Contains(' V ') or Line.Contains('/V(') or Line.Contains(') V ') then
      Result := ltVerbose
    else if Line.Contains(' D ') or Line.Contains('/D(') or Line.Contains(') D ') then
      Result := ltDebug
    else if Line.Contains(' I ') or Line.Contains('/I(') or Line.Contains(') I ') then
      Result := ltInfo
    else if Line.Contains(' W ') or Line.Contains('/W(') or Line.Contains(') W ') then
      Result := ltWarning
    else if Line.Contains(' E ') or Line.Contains('/E(') or Line.Contains(') E ') then
      Result := ltError
    else if Line.Contains(' F ') or Line.Contains('/F(') or Line.Contains(') F ') then
      Result := ltFatal
    else
      Result := ltInfo; // Default para Info

  except
    Result := ltInfo; // Em caso de erro, assumir Info
  end;
end;

function TLogcatManager.GetLogColor(LogType: TLogType): TAlphaColor;
begin
  case LogType of
    ltVerbose: Result := $FF808080;  // Cinza
    ltDebug:   Result := $FF0066CC;  // Azul
    ltInfo:    Result := $FF009900;  // Verde
    ltWarning: Result := $FFFF6600;  // Laranja
    ltError:   Result := $FFCC0000;  // Vermelho
    ltFatal:   Result := $FF800000;  // Vermelho escuro
  else
    Result := $FF000000;             // Preto
  end;
end;

function TLogcatManager.PassesLogLevelFilter(LogType: TLogType): Boolean;
begin
  case FConfig.LogLevel of
    llAll:     Result := True;
    llVerbose: Result := LogType = ltVerbose;
    llDebug:   Result := LogType in [ltVerbose, ltDebug];
    llInfo:    Result := LogType in [ltVerbose, ltDebug, ltInfo];
    llWarning: Result := LogType in [ltVerbose, ltDebug, ltInfo, ltWarning];
    llError:   Result := LogType in [ltVerbose, ltDebug, ltInfo, ltWarning, ltError];
  else
    Result := True;
  end;
end;

function TLogcatManager.ShouldFilterLine(const LogItem: TLogItem): Boolean;
begin
  Result := True;

  // Filtro de texto
  if FConfig.FilterText <> '' then
    Result := Result and LogItem.Text.ToLower.Contains(FConfig.FilterText.ToLower);

  // Filtro de nível de log
  if Result then
    Result := PassesLogLevelFilter(LogItem.LogType);
end;

procedure TLogcatManager.ProcessLogOutput(const Output: string);
var
  Lines: TArray<string>;
begin
  FOutputBuffer.Append(Output);

  // Atualizar UI conforme intervalo configurado
  if MilliSecondsBetween(Now, FLastUpdate) > FConfig.UpdateInterval then
  begin
    FLastUpdate := Now;
    Lines := FOutputBuffer.ToString.Split([#13#10, #10, #13]);
    UpdateUI(Lines);
    FOutputBuffer.Clear;
  end;
end;

procedure TLogcatManager.UpdateUI(const Lines: TArray<string>);
var
  I: Integer;
  LogLine: string;
  LogItem: TLogItem;
begin
  FCriticalSection.Enter;
  try
    for I := 0 to High(Lines) do
    begin
      LogLine := Lines[I].Trim;
      if LogLine <> '' then
      begin
        LogItem.Text := LogLine;
        LogItem.LogType := ExtractLogType(LogLine);
        LogItem.Color := GetLogColor(LogItem.LogType);
        LogItem.Timestamp := Now;

        // Adicionar à lista completa
        FAllLogItems.Add(LogItem);

        // Notificar handler se disponível
        if Assigned(FEventHandler) then
          FEventHandler.OnLogReceived(LogItem);

        // Limpeza de performance
        if FAllLogItems.Count > FConfig.MaxLines then
        begin
          while FAllLogItems.Count > (FConfig.MaxLines - 500) do
            FAllLogItems.Delete(0);
        end;
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TLogcatManager.StartReadingThread;
begin
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
      Output: string;
    begin
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

          CmdLine := '"' + FConfig.ADBPath + '" ' + BuildLogcatCommand;

          if CreateProcess(nil, PChar(CmdLine), nil, nil, True,
                           CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
          try
            FLogcatProcess := ProcessInfo.hProcess;
            CloseHandle(WritePipe);
            WritePipe := 0;

            // Ler saída continuamente
            while FLogcatRunning and ReadFile(ReadPipe, Buffer, SizeOf(Buffer), BytesRead, nil) and (BytesRead > 0) do
            begin
              Output := string(AnsiString(Copy(Buffer, 0, BytesRead)));
              ProcessLogOutput(Output);
            end;

          finally
            CloseHandle(ProcessInfo.hThread);
          end;

        finally
          if WritePipe <> 0 then CloseHandle(WritePipe);
          CloseHandle(ReadPipe);
        end;

      except
        on E: Exception do
        begin
          if Assigned(FEventHandler) then
            FEventHandler.OnError('Erro no logcat: ' + E.Message);
        end;
      end;

      // Limpeza final
      CleanupProcess;
    end
  ).Start;
end;

procedure TLogcatManager.CleanupProcess;
begin
  TThread.Synchronize(nil,
    procedure
    begin
      FLogcatRunning := False;
      FLogcatProcess := 0;

      if Assigned(FEventHandler) then
        FEventHandler.OnStatusChanged('Logcat finalizado');
    end);
end;

procedure TLogcatManager.StartLogcat;
begin
  if FLogcatRunning then
  begin
    if Assigned(FEventHandler) then
      FEventHandler.OnError('Logcat já está em execução');
    Exit;
  end;

  if FConfig.DeviceId.IsEmpty then
  begin
    if Assigned(FEventHandler) then
      FEventHandler.OnError('Nenhum dispositivo selecionado');
    Exit;
  end;

  // Limpar logs anteriores
  ClearLogs;

  FLogcatRunning := True;

  if Assigned(FEventHandler) then
  begin
    FEventHandler.OnStatusChanged('Iniciando logcat...');
  end;

  StartReadingThread;
end;

procedure TLogcatManager.StopLogcat;
begin
  if not FLogcatRunning then
    Exit;

  FLogcatRunning := False;

  if FLogcatProcess <> 0 then
  begin
    TerminateProcess(FLogcatProcess, 0);
    CloseHandle(FLogcatProcess);
    FLogcatProcess := 0;
  end;

  if Assigned(FEventHandler) then
    FEventHandler.OnStatusChanged('Logcat parado pelo usuário');
end;

procedure TLogcatManager.SetFilter(const FilterText: string);
begin
  FConfig.FilterText := FilterText;
  if Assigned(FEventHandler) then
    FEventHandler.OnFilterChanged;
end;

procedure TLogcatManager.SetLogLevel(Level: TLogLevel);
begin
  FConfig.LogLevel := Level;
  if Assigned(FEventHandler) then
    FEventHandler.OnFilterChanged;
end;

procedure TLogcatManager.ApplyFilters;
begin
  if Assigned(FEventHandler) then
    FEventHandler.OnFilterChanged;
end;

procedure TLogcatManager.ClearLogs;
begin
  FCriticalSection.Enter;
  try
    FAllLogItems.Clear;
  finally
    FCriticalSection.Leave;
  end;

  if Assigned(FEventHandler) then
    FEventHandler.OnFilterChanged;
end;

procedure TLogcatManager.ClearFilters;
begin
  FConfig.FilterText := '';
  FConfig.LogLevel := llAll;

  if Assigned(FEventHandler) then
    FEventHandler.OnFilterChanged;
end;

function TLogcatManager.GetAllLogItems: TArray<TLogItem>;
begin
  FCriticalSection.Enter;
  try
    Result := FAllLogItems.ToArray;
  finally
    FCriticalSection.Leave;
  end;
end;

function TLogcatManager.GetFilteredLogItems: TArray<TLogItem>;
var
  I: Integer;
  FilteredItems: TList<TLogItem>;
begin
  FilteredItems := TList<TLogItem>.Create;
  try
    FCriticalSection.Enter;
    try
      for I := 0 to FAllLogItems.Count - 1 do
      begin
        if ShouldFilterLine(FAllLogItems[I]) then
          FilteredItems.Add(FAllLogItems[I]);
      end;
    finally
      FCriticalSection.Leave;
    end;

    Result := FilteredItems.ToArray;
  finally
    FilteredItems.Free;
  end;
end;

class procedure TLogcatManager.UpdateStatus(const AMessage: string; ALabel: TLabel);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      ALabel.Text := AMessage;
    end);
end;

{ TLogcatUIHandler }

constructor TLogcatUIHandler.Create(AListBox: TListBox; AStatusLabel: TLabel;
  AStartButton, AStopButton: TButton; AComboLogLevel: TComboBox; AEditFilter: TEdit);
begin
  inherited Create;
  FListBox := AListBox;
  FStatusLabel := AStatusLabel;
  FStartButton := AStartButton;
  FStopButton := AStopButton;
  FComboLogLevel := AComboLogLevel;
  FEditFilter := AEditFilter;

  // Criar timer para filtro em tempo real
  FFilterTimer := TTimer.Create(nil);
  FFilterTimer.Interval := 200; // 200ms para resposta rápida
  FFilterTimer.Enabled := False;
  FFilterTimer.OnTimer := FilterTimerTimer;
end;

destructor TLogcatUIHandler.Destroy;
begin
  if Assigned(FFilterTimer) then
    FFilterTimer.Free;
  inherited;
end;

procedure TLogcatUIHandler.FilterTimerTimer(Sender: TObject);
begin
  FFilterTimer.Enabled := False;
  UpdateListBox;
end;

procedure TLogcatUIHandler.UpdateListBox;
var
  LogManager: TLogcatManager;
  FilteredItems: TArray<TLogItem>;
  I: Integer;
  ListBoxItem: TListBoxItem;
  WasAtEnd: Boolean;
  FilteredCount, TotalCount: Integer;
  StatusMsg: string;
begin
  LogManager := TLogcatManager.GetInstance;

  TThread.Synchronize(nil,
    procedure
      var
        I: Integer;
    begin
      WasAtEnd := (FListBox.ItemIndex = FListBox.Count - 1) or (FListBox.ItemIndex = -1);

      FListBox.BeginUpdate;
      try
        FListBox.Clear;

        FilteredItems := LogManager.GetFilteredLogItems;
        FilteredCount := Length(FilteredItems);
        TotalCount := Length(LogManager.GetAllLogItems);

        for I := 0 to High(FilteredItems) do
        begin
          ListBoxItem := TListBoxItem.Create(FListBox);
          ListBoxItem.Parent := FListBox;
          ListBoxItem.Text := FilteredItems[I].Text;
          ListBoxItem.Height := 18;
          ListBoxItem.TextSettings.FontColor := FilteredItems[I].Color;
          ListBoxItem.StyledSettings := ListBoxItem.StyledSettings - [TStyledSetting.FontColor];

          // Formatação especial
          case FilteredItems[I].LogType of
            ltError, ltFatal: ListBoxItem.TextSettings.Font.Style := [TFontStyle.fsBold];
            ltWarning: ListBoxItem.TextSettings.Font.Style := [TFontStyle.fsItalic];
          end;

          FListBox.AddObject(ListBoxItem);
        end;

        // Scroll automático se estava no final
        if WasAtEnd and (FListBox.Count > 0) then
          FListBox.ItemIndex := FListBox.Count - 1;

      finally
        FListBox.EndUpdate;
      end;

      // Atualizar status
      StatusMsg := Format('Filtro aplicado - %d/%d itens mostrados', [FilteredCount, TotalCount]);
      if LogManager.Config.FilterText <> '' then
        StatusMsg := StatusMsg + ' | Texto: "' + LogManager.Config.FilterText + '"';
      if LogManager.Config.LogLevel <> llAll then
        StatusMsg := StatusMsg + ' | Nível: ' + FComboLogLevel.Items[Integer(LogManager.Config.LogLevel)];

      FStatusLabel.Text := StatusMsg;
    end);
end;

procedure TLogcatUIHandler.OnLogReceived(const LogItem: TLogItem);
var
  LogManager: TLogcatManager;
  ListBoxItem: TListBoxItem;
  WasAtEnd: Boolean;
begin
  // Se o item passa no filtro atual, adicionar diretamente
  LogManager := TLogcatManager.GetInstance;

  if LogManager.ShouldFilterLine(LogItem) then
  begin
    TThread.Synchronize(nil,
      procedure
      begin
        WasAtEnd := (FListBox.ItemIndex = FListBox.Count - 1) or (FListBox.ItemIndex = -1);

        ListBoxItem := TListBoxItem.Create(FListBox);
        ListBoxItem.Parent := FListBox;
        ListBoxItem.Text := LogItem.Text;
        ListBoxItem.Height := 18;
        ListBoxItem.TextSettings.FontColor := LogItem.Color;
        ListBoxItem.StyledSettings := ListBoxItem.StyledSettings - [TStyledSetting.FontColor];

        // Formatação especial
        case LogItem.LogType of
          ltError, ltFatal: ListBoxItem.TextSettings.Font.Style := [TFontStyle.fsBold];
          ltWarning: ListBoxItem.TextSettings.Font.Style := [TFontStyle.fsItalic];
        end;

        FListBox.AddObject(ListBoxItem);

        // Scroll automático se estava no final
        if WasAtEnd then
          FListBox.ItemIndex := FListBox.Count - 1;

        // Limpeza de performance
        if FListBox.Count > 1500 then
        begin
          FListBox.BeginUpdate;
          try
            while FListBox.Count > 1000 do
              FListBox.Items.Delete(0);
          finally
            FListBox.EndUpdate;
          end;
        end;
      end);
  end;
end;

procedure TLogcatUIHandler.OnStatusChanged(const Status: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      FStatusLabel.Text := Status;

      // Atualizar botões conforme status
      if Status.Contains('iniciado') or Status.Contains('Iniciando') then
      begin
        FStartButton.Enabled := False;
        FStopButton.Enabled := True;
      end
      else if Status.Contains('parado') or Status.Contains('finalizado') then
      begin
        FStartButton.Enabled := True;
        FStopButton.Enabled := False;
      end;
    end);
end;

procedure TLogcatUIHandler.OnError(const ErrorMsg: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      FStatusLabel.Text := ErrorMsg;
      ShowMessage(ErrorMsg);
    end);
end;

procedure TLogcatUIHandler.OnFilterChanged;
begin
  // Reiniciar timer para aplicar filtro
  FFilterTimer.Enabled := False;
  FFilterTimer.Enabled := True;
end;

// Inicialização e finalização
initialization

finalization
  TLogcatManager.ReleaseInstance;

end.
