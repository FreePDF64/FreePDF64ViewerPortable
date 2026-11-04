unit uPortableViewerLauncher;

interface

procedure OpenPDFPortable(const AFileName: string);
procedure OpenPortableViewer;
function PortableViewerExe: string;

implementation

uses Winapi.Windows, Winapi.ShellAPI, System.SysUtils, Vcl.Dialogs;

function PortableViewerExe: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'FreePDF64ViewerPortable.exe';
end;

procedure LaunchPortable(const AArgument: string);
var
  Exe, Params: string;
begin
  Exe := PortableViewerExe;
  if not FileExists(Exe) then
  begin
    MessageDlg('Der portable PDF-Viewer fehlt:' + sLineBreak + Exe +
      sLineBreak + 'Bitte FreePDF64ViewerPortable.exe in das FreePDF64-Programmverzeichnis kopieren.',
      mtError, [mbOK], 0);
    Exit;
  end;
  Params := AArgument;
  if (Params <> '') and (Params[1] <> '"') then Params := '"' + Params + '"';
  if ShellExecute(0, 'open', PChar(Exe), PChar(Params),
    PChar(ExtractFilePath(Exe)), SW_SHOWNORMAL) <= 32 then
    MessageDlg('Der portable PDF-Viewer konnte nicht gestartet werden: ' + Exe,
      mtError, [mbOK], 0);
end;

procedure OpenPDFPortable(const AFileName: string);
begin
  if SameText(ExtractFileExt(AFileName), '.pdf') and FileExists(AFileName) then
    LaunchPortable(ExpandFileName(AFileName));
end;

procedure OpenPortableViewer;
begin
  LaunchPortable('');
end;

end.
