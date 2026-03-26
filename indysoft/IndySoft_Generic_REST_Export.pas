{$FORM TDialog1Form, Dialog1.sfm}    

//==============================================================================
// IndySoft → Generic REST API Export Template
// 
// Purpose: A highly agnostic skeleton script for extracting data from IndySoft, 
//          building a nested JSON payload, and POSTing it to a REST API.
//==============================================================================

uses                               
  Classes, Graphics, Controls, Forms, Dialogs, StdCtrls, 
  ipwcore, ipwrest, ipwjson, System;  
     
const     
  // TODO: Replace with your target API endpoint
  API_URL = 'https://api.your-target-system.com/v1'; 

  { JSON Data Types }                   
  jtObject = 0; // Object                                                      
  jtArray = 1;  // Array
  jtString = 2; // String                                                        
  jtNumber = 3; // Number                                
  jtBool = 4;   // Boolean
  jtNull = 5;   // Null                                  
  jtRaw = 6;    // Raw    
  
  { JSON Insert Positions }                                 
  jpBeforeCurrent = 0; 
  jpAfterCurrent = 1; 
  jpFirstChild = 2; 
  jpLastChild = 3;       
                                                                               
var
  // Global Variables
  sAuthToken: String; 
  
  // Globals used to bypass 'out' parameter limitations in this environment.
  // Populated by the ParseDelimitedString function.
  gsParsedString1: String; 
  gsParsedString2: String; 

//==============================================================================
// Helper Functions
//==============================================================================

function GetJSONTime(dDate: TDateTime): String;                         
begin
  Result := CustomDateTimeFormat('yyyy-mm-dd', dDate) + 'T' + CustomDateTimeFormat('hh:mm:ss', dDate); 
end;                            
                                                                    
function Unquote(s1: String): String;
begin                                                     
  Result := s1;
  Result := StringReplace(Result,'"','', 1);                              
end;          
                                                             
function GetJSONValue(pJSON: TipwJSON; sProperty: String; bTrim: Boolean) : String;               
var                                                                
  sVal: String;                                                                  
begin                                                         
  try                                                 
    pJSON.XPath := sProperty;                 
    sVal := Unquote(pJSON.XText);       
    if bTrim then                             
      Result := Trim(sVal);                    
    else                                                             
      Result := sVal;
  except                                              
    raise('Error reading JSON property in path: ' + sProperty + ' Error: ' + LastExceptionMessage);
  end;                                                     
end;                                               
                                           
// Handles the HTTP request to the external API                  
function Fetch(RESTObj: TipwREST; sMethod, sEndpoint, sBody: String): String;                                                                           
var
  sURL: String;                   
begin                                                                                                                                       
  Result := '';                       
  try                                                  
    sURL := API_URL + sEndpoint;
    
    // WARNING: Hardcoded API tokens are a security risk. Consider loading from a secure global variable.
    sAuthToken := 'YOUR_API_TOKEN_HERE';
                                                                                                                                             
    RESTObj.Reset;                                
    RESTObj.Accept := 'application/json';                                        
    RESTObj.ContentType := 'application/json';                     
    RESTObj.OtherHeaders := 'x-api-key: ' + sAuthToken + #13#10;       
                                                                                                                                             
    if sMethod = 'POST' then 
    begin
      RESTObj.PostData := sBody;               
      RESTObj.Post(sURL);                                                         
    end                                                   
    else if sMethod = 'GET' then      
      RESTObj.Get(sURL)                      
    else if sMethod = 'PUT' then 
    begin                                              
      RESTObj.PostData := sBody;                                                    
      RESTObj.Put(sURL);
    end;                                                         
    
    Result := RESTObj.TransferredData;   
  except                                                                                                   
    Raise('REST Request Error: ' + LastExceptionMessage + ' Response: ' + RESTObj.transferredData);
  end;                                     
end;   

function StripQuotes(InputStr: string): string;
var
  i: Integer;
begin
  Result := InputStr;
  for i := Length(Result) downto 1 do
  begin
    if (Result[i] = '"') or (Result[i] = '''') then
      Delete(Result, i, 1);
  end;
end;  

//==============================================================================
// Core Parsing & Validation Logic
// Purpose: Generic parser to split a hyphen-delimited string into parts.
// Sets values to global variables: gsParsedString1, gsParsedString2
//==============================================================================
function ParseDelimitedString(AInput: string): Boolean;      
var                                                                                                                                         
  LParts: TStringList;                                                                                                                      
begin                                                                      
  // 1. Initialize all output global parameters               
  gsParsedString1 := '';                                                                        
  gsParsedString2 := '';    

  // 2. Parse the string using TStringList
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '-';
    LParts.DelimitedText := AInput;

    if LParts.Count > 0 then
      gsParsedString1 := LParts[0];    
    if LParts.Count > 1 then
      gsParsedString2 := LParts[1];    
  finally
    LParts.Free;
  end;                                                                       

  // 3. Example Validation: Ensure part 1 isn't empty. Add your own business rules here.
  Result := True;
  if (gsParsedString1 = '') then  
    Result := False;
end; 

//==============================================================================
// Main Execution Procedure
//==============================================================================
procedure ExportDataToAPI;                              
Var                                                   
    JSON: TipwJSON;                 
    REST: TipwREST;                           
    sWONumber, sRawDelimitedString: String;
    
    // Generic Header Payload Variables
    sPayloadString1, sPayloadString2, sPayloadString3, sPayloadString4, sPayloadString5: String;
    bPayloadBoolean1, bPayloadBoolean2: String; // Stored as 'True'/'False', exported as jtBool
    nPayloadNumeric1, nPayloadNumeric2: String; // Stored as string, exported as jtNumber
    
    // Generic Line Item Variables
    sLineString1, sLineString2, sLineString3: String;
    bLineBoolean1: String;
    nLineNumeric1, nLineNumeric2: String;

    iLineCount, i: Integer;                                                        
    sAPIResponse, sFailureMessage, sJSONBody, sGUID : String;
    today : TDateTime; 
                                                 
begin                                                         
  // ---------------------------------------------------------------------------
  // 1. Gather Work Order & Company Fields  
  // ---------------------------------------------------------------------------
  // DEVELOPER NOTES:
  // - Use LookupOrderFieldText() to get basic fields from the current work order screen.
  // - Use tdDoSQLRecords() to query related tables (COMPANY, EQUIPMENT, etc.).
  // - Assign your extracted data to the generic variables below.
  // ---------------------------------------------------------------------------
  
  // Example: Getting the primary identifier
  sWoNumber := trim(LookupOrderFieldText('JOB_NUMBER'));                                      
  
  // Example: Standard String assignments
  sPayloadString1 := trim(LookupOrderFieldText('CUSTOMER'));
  sPayloadString2 := trim(LookupOrderFieldText('PO_NUMBER'));
  
  // Example: SQL Query Assignment
  // tdDoSQLRecords(1, 'SELECT SOME_FIELD FROM COMPANY WHERE COMPANY_NAME = ''' + sPayloadString1 + ''''); 
  // sPayloadString3 := trim(tdFieldByNameAsString(1, 'SOME_FIELD'));
  
  // Example: Boolean Logic Assignment
  bPayloadBoolean1 := 'False';
  // IF LookupOrderFieldBoolean('WO_STATUS4') = True THEN bPayloadBoolean1 := 'True';    
  
  // Example: Numeric Assignment
  // nPayloadNumeric1 := trim(LookupOrderFieldText('EST_COST'));
  
  // Example: Parsing a combined/delimited string
  // sRawDelimitedString := trim(LookupOrderFieldText('CUSTOM_FIELD'));
  // IF NOT ParseDelimitedString(sRawDelimitedString) THEN  
  // BEGIN                                                                                                         
  //     AbortAction('Validation Error: The string "' + sRawDelimitedString + '" failed validation.');
  //     EXIT;
  // END;                                     

  // ---------------------------------------------------------------------------
  // 2. Build the JSON Payload                      
  // ---------------------------------------------------------------------------
  // DEVELOPER NOTES:
  // - Map your generic variables to the actual JSON property keys expected by your API.
  // - Pay close attention to the data types (jtString, jtBool, jtNumber).
  // ---------------------------------------------------------------------------
  
  JSON := ipwJSON1;                                                        
  REST := ipwREST1;                            
                                                      
  JSON.Reset;                               
  JSON.StartObject;                                                            
    
  // Header Properties
  JSON.PutProperty('apiHeaderKey1', sPayloadString1, jtString);       
  JSON.PutProperty('apiHeaderKey2', sPayloadString2, jtString);    
  JSON.PutProperty('apiHeaderKey3', sPayloadString3, jtString); 
  
  // Outputting Parsed Globals
  JSON.PutProperty('apiParsedKey1', gsParsedString1, jtString); 
  JSON.PutProperty('apiParsedKey2', gsParsedString2, jtString); 
  
  // Booleans and Numerics
  JSON.PutProperty('apiBooleanKey1', bPayloadBoolean1, jtBool);           
  JSON.PutProperty('apiNumericKey1', nPayloadNumeric1, jtNumber);           
  
  // ---------------------------------------------------------------------------
  // 3. Build JSON Lines Array
  // ---------------------------------------------------------------------------
  // DEVELOPER NOTES:
  // - Query your line items (e.g., WORK_ORDER_CHARGES or WORK_ORDER_DETAIL).
  // - Loop through the count, build an object for each line, and add it to the array.
  // ---------------------------------------------------------------------------
  
  // Example: Getting the line count
  // iLineCount := StrToInt(ReturnFromSQL('SELECT COUNT(*) FROM WORK_ORDER_CHARGES WHERE JOB_NUMBER = ''' + sWONumber + ''''));                                                      
  iLineCount := 0; // Replace with actual count query
                                                             
  JSON.PutName('Lines');                                                    
  JSON.StartArray;                                
  
  for i := 1 to iLineCount do 
  begin                  
    // Example: Querying the specific line item
    // tdDoSQLRecords(2, 'SELECT * FROM WORK_ORDER_CHARGES WHERE JOB_NUMBER = ''' + sWONumber + ''' AND SEQUENCE_NUMBER = ''' + IntToStr(i) + '''');  
    
    // Assign line variables
    // sLineString1 := trim(tdFieldByNameAsString(2, 'CHARGE_TYPE'));       
    // nLineNumeric1 := trim(tdFieldByNameAsString(2, 'LINE_TOTAL_COST'));                                                                                              
                                                             
    JSON.StartObject;
    JSON.PutProperty('lineKey1', sLineString1, jtString);
    JSON.PutProperty('lineKey2', sLineString2, jtString);  
    JSON.PutProperty('lineNumeric1', nLineNumeric1, jtNumber);
    JSON.PutProperty('lineBoolean1', bLineBoolean1, jtBool); 
    JSON.EndObject;    
  end;
  
  JSON.EndArray;         
  JSON.EndObject;            
                                                                                                                                                                                                                                                               
  // ---------------------------------------------------------------------------
  // 4. Send API POST Request & Handle Response
  // ---------------------------------------------------------------------------
  // DEVELOPER NOTES:
  // - POST the payload to the endpoint.
  // - Parse the response to grab success IDs or error messages.
  // - Update IndySoft records accordingly using RunSQL.
  // ---------------------------------------------------------------------------
  
   try                                                                          
    Fetch(REST, 'POST', '/your-target-endpoint', JSON.OutputData);
    sJSONBody := JSON.OutputData;
    
    // Parse the successful response
    JSON.Reset; 
    JSON.InputData := REST.TransferredData;
    JSON.Parse;                                                                 
    
    // Example: Grabbing an ID returned by the API
    JSON.XPath := '$.ReturnedExternalID';
    sAPIResponse := Replace(JSON.XText, '"', '');
    
    // Example: Update an IndySoft field with the new external ID
    // RunSQL('UPDATE WORK_ORDER SET WO_CUSTOM_FIELD = ''' + sAPIResponse + ''' WHERE JOB_NUMBER = ''' + sWoNumber + '''');   
        
    CreateAdminLog('API_SYNC','POST SUCCESS', '', '', '', '', '', 'Record ' + sWoNumber + ' synced. JSON sent: ' + #10#13 + sJSONBody);    
    RefreshOrderScreen;
    ShowMessage('Record successfully created in external system! ID: ' + sAPIResponse); 
                                      
   except                             
    // Handle API Failure
    // Example: Update status to indicate failure
    // RunSQL('UPDATE WORK_ORDER SET SUB_STATUS = ''API Failure'' WHERE JOB_NUMBER = ''' + sWoNumber + '''');                                                                                                              
    
    sGUID := MakeGUID;
    today := Now;    
    sFailureMessage := 'Record ' + sWoNumber + ' sync failed: ' + LastExceptionMessage;
    sFailureMessage := StripQuotes(sFailureMessage);
    
    // Example: Write error to history table
    // RunSQL('INSERT INTO WORK_ORDER_HIST (JOB_NUMBER, GLOBAL_ID, USER_NAME, CHANGE_TYPE, CHANGE_DATE_TIME, NOTES) VALUES ( ''' + sWoNumber + ''', ''' + sGUID + ''', ''API_SYNC'', ''API Failure'', ''' + FormatDateTimeForSQL(today) + ''', ''' + sFailureMessage + ''')');
    
    AbortAction('API Sync Failed: ' + LastExceptionMessage + #10#13 + 'Please check data and try again.');  
    RefreshOrderScreen;
    Close;                                                                                                                                                                                     
  end;                                                                                                                                         
 
end;
