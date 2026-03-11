unit ToolsManager;

interface

uses
  System.Classes, System.SysUtils, System.Threading, System.IOUtils,
  System.Generics.Collections, System.TypInfo,
  FMX.StdCtrls, FMX.Edit, FMX.Memo, FMX.Dialogs,
  Winapi.Windows, Winapi.Messages;

type
  TToolsManager = class
  private

  public
    class function ExecuteADBCommand(const AADBPath, ACommand: string): string;
    class procedure RebootDevice(const AADBPath, ADevice: string; 
                                AOnStatusUpdate: TProc<string>;
                                AOnShowConfirmation: TFunc<string, Boolean>);
    class procedure RebootToBootloader(const AADBPath, ADevice: string;
                                      AOnStatusUpdate: TProc<string>;
                                      AOnShowConfirmation: TFunc<string, Boolean>);
    class procedure RebootToRecovery(const AADBPath, ADevice: string;
                                    AOnStatusUpdate: TProc<string>;
                                    AOnShowConfirmation: TFunc<string, Boolean>);
    class procedure TakeScreenshot(const AADBPath, ADevice: string; ASaveDialog: TSaveDialog;
                                  AOnStatusUpdate: TProc<string>;
                                  AOnShowMessage: TProc<string>);
    class procedure ClearSystemCache(const AADBPath, ADevice: string;
                                    AOnStatusUpdate: TProc<string>;
                                    AOnShowMessage: TProc<string>;
                                    AOnShowConfirmation: TFunc<string, Boolean>);
    class procedure ExecuteCustomCommand(const AADBPath, ADevice, ACommand: string; AMemoOutput: TMemo;
                                        AOnStatusUpdate: TProc<string>;
                                        AOnShowMessage: TProc<string>);
    class procedure ExecuteShellCommand(const AADBPath, ADevice, ACommand: string; AMemoOutput: TMemo; AEditCommand: TEdit;
                                       AOnStatusUpdate: TProc<string>;
                                       AOnShowMessage: TProc<string>);
  end;

implementation

{ TToolsManager }

class function TToolsManager.ExecuteADBCommand(const AADBPath, ACommand: string): string;
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
    CmdLine := '"' + AADBPath + '" ' + ACommand;

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
    end;

  finally
    if WritePipe <> 0 then CloseHandle(WritePipe);
    CloseHandle(ReadPipe);
  end;
end;

class procedure TToolsManager.RebootDevice(const AADBPath, ADevice: string; 
                                          AOnStatusUpdate: TProc<string>;
                                          AOnShowConfirmation: TFunc<string, Boolean>);
begin
  if ADevice = '' then Exit;

  if Assigned(AOnShowConfirmation) and 
     AOnShowConfirmation('Deseja reiniciar o dispositivo?') then
  begin
    TTask.Run(
      procedure
      begin
        ExecuteADBCommand(AADBPath, '-s ' + ADevice + ' reboot');
        
        if Assigned(AOnStatusUpdate) then
          AOnStatusUpdate('Comando de reinicialização enviado');
      end);
  end;
end;

class procedure TToolsManager.RebootToBootloader(const AADBPath, ADevice: string;
                                                AOnStatusUpdate: TProc<string>;
                                                AOnShowConfirmation: TFunc<string, Boolean>);
begin
  if ADevice = '' then Exit;

  if Assigned(AOnShowConfirmation) and 
     AOnShowConfirmation('Deseja reiniciar no modo Bootloader?') then
  begin
    TTask.Run(
      procedure
      begin
        ExecuteADBCommand(AADBPath, '-s ' + ADevice + ' reboot bootloader');
        
        if Assigned(AOnStatusUpdate) then
          AOnStatusUpdate('Comando de reinicialização para bootloader enviado');
      end);
  end;
end;

class procedure TToolsManager.RebootToRecovery(const AADBPath, ADevice: string;
                                              AOnStatusUpdate: TProc<string>;
                                              AOnShowConfirmation: TFunc<string, Boolean>);
begin
  if ADevice = '' then Exit;

  if Assigned(AOnShowConfirmation) and 
     AOnShowConfirmation('Deseja reiniciar no modo Recovery?') then
  begin
    TTask.Run(
      procedure
      begin
        ExecuteADBCommand(AADBPath, '-s ' + ADevice + ' reboot recovery');
        
        if Assigned(AOnStatusUpdate) then
          AOnStatusUpdate('Comando de reinicialização para recovery enviado');
      end);
  end;
end;

class procedure TToolsManager.TakeScreenshot(const AADBPath, ADevice: string; ASaveDialog: TSaveDialog;
                                            AOnStatusUpdate: TProc<string>;
                                            AOnShowMessage: TProc<string>);
var
  TempFile: string;
  SavePath: string;
begin
  if ADevice = '' then
  begin
    if Assigned(AOnShowMessage) then
      AOnShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  if ASaveDialog.Execute then
  begin
    SavePath := ASaveDialog.FileName;
    TempFile := '/sdcard/screenshot.png';

    if Assigned(AOnStatusUpdate) then
      AOnStatusUpdate('Capturando screenshot...');

    TTask.Run(
      procedure
      var
        Result1, Result2: string;
      begin
        // Capturar screenshot no dispositivo
        Result1 := ExecuteADBCommand(AADBPath, '-s ' + ADevice + ' shell screencap -p ' + TempFile);

        // Transferir para o PC
        Result2 := ExecuteADBCommand(AADBPath, '-s ' + ADevice + ' pull ' + TempFile + ' "' + SavePath + '"');

        // Limpar arquivo temporário
        ExecuteADBCommand(AADBPath, '-s ' + ADevice + ' shell rm ' + TempFile);

        TThread.Synchronize(nil,
          procedure
          begin
            if FileExists(SavePath) then
            begin
              if Assigned(AOnShowMessage) then
                AOnShowMessage('Screenshot salvo com sucesso em: ' + SavePath);
                
              if Assigned(AOnStatusUpdate) then
                AOnStatusUpdate('Screenshot capturado');
            end
            else
            begin
              if Assigned(AOnShowMessage) then
                AOnShowMessage('Erro ao capturar screenshot');
                
              if Assigned(AOnStatusUpdate) then
                AOnStatusUpdate('Erro no screenshot');
            end;
          end);
      end);
  end;
end;

class procedure TToolsManager.ClearSystemCache(const AADBPath, ADevice: string;
                                              AOnStatusUpdate: TProc<string>;
                                              AOnShowMessage: TProc<string>;
                                              AOnShowConfirmation: TFunc<string, Boolean>);
begin
  if ADevice = '' then
  begin
    if Assigned(AOnShowMessage) then
      AOnShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  if Assigned(AOnShowConfirmation) and 
     AOnShowConfirmation('Deseja limpar o cache do sistema?' + sLineBreak +
                        'Esta operação pode demorar alguns minutos.') then
  begin
    if Assigned(AOnStatusUpdate) then
      AOnStatusUpdate('Limpando cache do sistema...');

    TTask.Run(
      procedure
      var
        Result: string;
      begin
        Result := ExecuteADBCommand(AADBPath, '-s ' + ADevice + ' shell pm trim-caches 1000000000');

        TThread.Synchronize(nil,
          procedure
          begin
            if Assigned(AOnShowMessage) then
              AOnShowMessage('Cache do sistema limpo');
              
            if Assigned(AOnStatusUpdate) then
              AOnStatusUpdate('Cache limpo com sucesso');
          end);
      end);
  end;
end;

class procedure TToolsManager.ExecuteCustomCommand(const AADBPath, ADevice, ACommand: string; AMemoOutput: TMemo;
                                                  AOnStatusUpdate: TProc<string>;
                                                  AOnShowMessage: TProc<string>);
begin
  if ACommand.Trim = '' then
  begin
    if Assigned(AOnShowMessage) then
      AOnShowMessage('Digite um comando primeiro');
    Exit;
  end;

  if ADevice = '' then
  begin
    if Assigned(AOnShowMessage) then
      AOnShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  if Assigned(AOnStatusUpdate) then
    AOnStatusUpdate('Executando comando personalizado...');

  TThread.Synchronize(nil,
    procedure
    begin
      AMemoOutput.Lines.Add('> ' + ACommand);
    end);

  TTask.Run(
    procedure
    var
      Result: string;
      FullCommand: string;
    begin
      // Se o comando não começar com -s, adicionar o dispositivo
      if not ACommand.StartsWith('-s') then
        FullCommand := '-s ' + ADevice + ' ' + ACommand
      else
        FullCommand := ACommand;

      Result := ExecuteADBCommand(AADBPath, FullCommand);

      TThread.Synchronize(nil,
        procedure
        begin
          AMemoOutput.Lines.Add(Result);
          AMemoOutput.Lines.Add('---');
          AMemoOutput.GoToTextEnd;
          
          if Assigned(AOnStatusUpdate) then
            AOnStatusUpdate('Comando executado');
        end);
    end);
end;

class procedure TToolsManager.ExecuteShellCommand(const AADBPath, ADevice, ACommand: string; AMemoOutput: TMemo; AEditCommand: TEdit;
                                                 AOnStatusUpdate: TProc<string>;
                                                 AOnShowMessage: TProc<string>);
begin
  if ACommand.Trim = '' then
  begin
    if Assigned(AOnShowMessage) then
      AOnShowMessage('Digite um comando shell primeiro');
    Exit;
  end;

  if ADevice = '' then
  begin
    if Assigned(AOnShowMessage) then
      AOnShowMessage('Selecione um dispositivo primeiro');
    Exit;
  end;

  if Assigned(AOnStatusUpdate) then
    AOnStatusUpdate('Executando comando shell...');

  TTask.Run(
    procedure
    var
      Result: string;
      FullCommand: string;
    begin
      FullCommand := '-s ' + ADevice + ' shell ' + ACommand;
      Result := ExecuteADBCommand(AADBPath, FullCommand);

      TThread.Synchronize(nil,
        procedure
        begin
          AMemoOutput.Lines.Add('Shell> ' + ACommand);
          AMemoOutput.Lines.Add(Result);
          AMemoOutput.Lines.Add('---');
          AMemoOutput.GoToTextEnd;
          
          if Assigned(AOnStatusUpdate) then
            AOnStatusUpdate('Comando shell executado');
            
          AEditCommand.Text := '';
        end);
    end);
end;

end. 