{$FORM TDialog1Form, Dialog1.sfm}

uses
  Classes, SysUtils, Graphics, Controls, Forms, Dialogs,
  iphsftp, iphcore, iphtypes;

// =============================================================================
// || 1. GLOBAL CONFIGURATION (Edit these values for your environment)        ||
// =============================================================================
type 
  TExportType = (etCSV, etTab, etSpace);

const
  // --- Delimiter Choice ---
  C_EXPORT_MODE     = etCSV;             // Options: etCSV, etTab, etSpace
  
  // --- File & Notification Settings ---
  C_FILENAME_PREFIX = 'IndySoft_SFTP_Export_';
  C_ERROR_EMAIL_TO  = 'dev-alerts@company.com';
  bDebug            = True;              // Set to False to disable popup messages

  // --- SFTP Credentials & Target ---
  C_SFTP_HOST       = 'sftp.yourserver.com';
  C_SFTP_PORT       = 22;
  C_SFTP_USER       = 'your_username';
  C_SFTP_PASS       = 'your_password';
  C_SFTP_REMOTE_DIR = '/';               // Target directory on the SFTP server (e.g., '/uploads/')

  // --- The Extraction Query ---
  C_SQL_QUERY = 
    'SELECT GAGE_ID, GAGE_SN, COMPANY, GAGE_DESCR, CURRENT_WO_NUMBER ' +
    'FROM GAGES WHERE ISACTIVE = ''1'' AND COMPANY = ''TEST''';

// =============================================================================
// || GLOBAL STATE VARIABLES                                                  ||
// =============================================================================
var
  g_sDelimiter: string;
  g_sState: string;

// =============================================================================
// || 2. HELPER FUNCTIONS                                                     ||
// =============================================================================

// Ensures every field is wrapped in double quotes and internal quotes are escaped.
// Prevents delimiter collisions (e.g., a comma inside a description field breaking a CSV).
function PrepareField(const sValue: string): string;
begin
  Result := '"' + StringReplace(sValue, '"', '""', [rfReplaceAll]) + '"';
end;

// Centralized error logging and notification routing
procedure SendErrorEmail(const sFunction, sState, sError: string);
var
  sLog: string;
begin
  sLog := Format('Error in %s'#13#10'State: %s'#13#10'Details: %s', [sFunction, sState, sError]);
  if bDebug then ShowMessage('--- SCRIPT ERROR ---'#13#10 + sLog);
  
  CreateAdminLog('SFTP Export', 'CRITICAL ERROR', '', '', '', '', '', sLog);
  
  // *** Placeholder: Call your IndySoft email routine here ***
  // SendMail(C_ERROR_EMAIL_TO, 'SFTP Export Failure', sLog);
end;

// =============================================================================
// || 3. CORE EXPORT MODULE                                                   ||
// =============================================================================

function ExportDataToLocalFile(const sFilePath: string): Boolean;
var
  i: Integer;
  sLine, sHeader: string;
  QueryFields, FileBuffer: TStringList;
begin
  Result := False;
  QueryFields := TStringList.Create;
  FileBuffer := TStringList.Create;
  
  // Outer TRY..FINALLY guarantees memory is freed even if an exception occurs
  try
    try
      g_sState := 'Executing SQL Query';
      tdDoSQLRecords(1, C_SQL_QUERY);

      // --- Build Header Row Dynamically ---
      tdGetFieldNames(1, QueryFields);
      sHeader := '';
      for i := 0 to QueryFields.Count - 1 do
      begin
        if i > 0 then sHeader := sHeader + g_sDelimiter;
        sHeader := sHeader + PrepareField(QueryFields[i]);
      end;
      FileBuffer.Add(sHeader);

      // --- Iterate Through Records and Build Lines ---
      g_sState := 'Building File Buffer';
      while tdEOF(1) = '0' do
      begin
        sLine := '';
        for i := 0 to QueryFields.Count - 1 do
        begin
          if i > 0 then sLine := sLine + g_sDelimiter;
          sLine := sLine + PrepareField(tdFieldByIndexAsString(1, i));
        end;
        FileBuffer.Add(sLine);
        tdNext(1);
      end;

      // --- Save as UTF-8 ---
      // Ensures special characters (Ø, °, etc.) are preserved across environments
      g_sState := 'Saving UTF-8 File to ' + sFilePath;
      FileBuffer.SaveToFile(sFilePath, TEncoding.UTF8);
      Result := True;
      
    except
      on E: Exception do 
        SendErrorEmail('ExportDataToLocalFile', g_sState, E.Message);
    end;
  finally
    // Always clean up resources
    QueryFields.Free;
    FileBuffer.Free;
  end;
end;

// =============================================================================
// || 4. SFTP UPLOAD MODULE                                                   ||
// =============================================================================

function UploadToSFTP(const sLocalPath: string): Boolean;
begin
  Result := False;
  g_sState := 'Applying SFTP Configuration';
  
  try
    // Apply credentials from Constants
    iphSFTP1.SSHHost := C_SFTP_HOST;
    iphSFTP1.SSHPort := C_SFTP_PORT;
    iphSFTP1.SSHUser := C_SFTP_USER;
    iphSFTP1.SSHPassword := C_SFTP_PASS;
    
    g_sState := 'Connecting to SFTP server: ' + C_SFTP_HOST;
    iphSFTP1.SSHLogon(iphSFTP1.SSHHost, iphSFTP1.SSHPort);
    
    g_sState := 'Configuring Remote Paths';
    iphSFTP1.LocalFile  := sLocalPath;
    iphSFTP1.RemotePath := C_SFTP_REMOTE_DIR;
    iphSFTP1.RemoteFile := ExtractFileName(sLocalPath);
    
    g_sState := 'Uploading File Data';
    iphSFTP1.Upload;
    
    g_sState := 'Disconnecting';
    iphSFTP1.SSHLogoff;
    Result := True;
    
  except
    on E: Exception do 
    begin
      // Attempt safe logoff if an error occurred mid-transfer
      if iphSFTP1.Connected then 
        iphSFTP1.SSHLogoff;
        
      SendErrorEmail('UploadToSFTP', g_sState, E.Message);
    end;
  end;
end;

// Auto-accept the host key to prevent connection blocks on unknown servers
procedure SFTPSSHServerAuthentication(Sender: TObject; HostKey: string; HostKeyB; Fingerprint, KeyAlgorithm, CertSubject, CertIssuer, Status: string; var Accept: Boolean);
begin
  Accept := True;
end;

// =============================================================================
// || 5. MAIN ORCHESTRATOR                                                    ||
// =============================================================================

procedure Process;
var
  sLocalPath: string;
begin
  g_sState := 'Initializing Process';
  if bDebug then ShowMessage('Process Started...');

  // 1. Resolve the requested delimiter
  case C_EXPORT_MODE of
    etCSV:   g_sDelimiter := ',';
    etTab:   g_sDelimiter := #9;
    etSpace: g_sDelimiter := ' ';
  end;

  // 2. Generate a unique, timestamped local file path
  sLocalPath := GetIndySoftTempDir + C_FILENAME_PREFIX + FormatDateTime('yyyyMMdd_hhnnss', Now) + '.csv';

  // 3. Execute the workflow
  if ExportDataToLocalFile(sLocalPath) then
  begin
    if UploadToSFTP(sLocalPath) then
    begin
      if bDebug then ShowMessage('Process Complete: Export and Upload Successful!');
      CreateAdminLog('SFTP Export', 'Success', '', '', '', '', '', 'Successfully uploaded: ' + sLocalPath);
      
      // Optional: Clean up the local temp file to save space
      if FileExists(sLocalPath) then DeleteFile(sLocalPath);
    end;
  end;
end;

begin
  // Script Entry Point
  Process;
end;
