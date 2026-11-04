unit uPDFErrorLogger;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs;

type
  TPDFErrorLogger = class
  private
    FCriticalSection: TCriticalSection;
    FLogFileName: string;
    procedure AppendLog(const AText: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure LogException(const AContext: string; E: Exception);
    procedure HandleException(Sender: TObject; E: Exception);
    property LogFileName: string read FLogFileName;
  end;

implementation

uses
  Winapi.Windows,
  Vcl.Forms;

constructor TPDFErrorLogger.Create;
begin
  inherited Create;
  FCriticalSection := TCriticalSection.Create;
  FLogFileName := IncludeTrailingPathDelimiter(
    ExtractFilePath(ParamStr(0))) + 'FreePDF_Error.log';
end;

destructor TPDFErrorLogger.Destroy;
begin
  FCriticalSection.Free;
  inherited Destroy;
end;

procedure TPDFErrorLogger.AppendLog(const AText: string);
var
  Stream: TFileStream;
  Bytes: TBytes;
begin
  // UTF-8 ohne BOM: Die Log-Datei bleibt auch bei mehreren Eintraegen
  // problemlos lesbar und wird bei jedem Fehler nur kurz geoeffnet.
  Bytes := TEncoding.UTF8.GetBytes(AText);
  if Length(Bytes) = 0 then
    Exit;

  FCriticalSection.Acquire;
  try
    try
      if FileExists(FLogFileName) then
      begin
        Stream := TFileStream.Create(FLogFileName,
          fmOpenReadWrite or fmShareDenyNone);
        try
          Stream.Seek(0, soEnd);
          Stream.WriteBuffer(Bytes[0], Length(Bytes));
        finally
          Stream.Free;
        end;
      end
      else
      begin
        Stream := TFileStream.Create(FLogFileName,
          fmCreate or fmShareDenyNone);
        try
          Stream.WriteBuffer(Bytes[0], Length(Bytes));
        finally
          Stream.Free;
        end;
      end;
    except
      // Ein Fehler beim Protokollieren darf niemals einen zweiten
      // Fehler ausloesen oder den Viewer zusaetzlich beeintraechtigen.
    end;
  finally
    FCriticalSection.Release;
  end;
end;

procedure TPDFErrorLogger.LogException(const AContext: string;
  E: Exception);
var
  ContextText: string;
begin
  if E = nil then
    Exit;

  ContextText := Trim(AContext);
  if ContextText = '' then
    ContextText := 'Nicht naeher zugeordneter Programmfehler';

  AppendLog(
    '[' + FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ']' + sLineBreak +
    'Thread-ID: ' + IntToStr(GetCurrentThreadId) + sLineBreak +
    'Kontext: ' + ContextText + sLineBreak +
    'Fehlertyp: ' + E.ClassName + sLineBreak +
    'Meldung: ' + E.Message + sLineBreak +
    StringOfChar('-', 72) + sLineBreak
  );
end;

procedure TPDFErrorLogger.HandleException(Sender: TObject; E: Exception);
var
  SenderText: string;
begin
  SenderText := '';
  if Sender <> nil then
    SenderText := Sender.ClassName;

  try
    LogException(SenderText, E);
  except
    // Die Fehlerbehandlung darf selbst keine Exception nach aussen geben.
  end;

  // VCL-Standarddialog anzeigen. Die Exception ist damit im zentralen
  // Application.OnException-Handler behandelt und wird nicht erneut
  // vom VCL-Standardhandler verarbeitet.
  try
    Application.ShowException(E);
  except
    // Auch ein Fehler beim Anzeigen der Meldung darf nicht eskalieren.
  end;
end;

end.
