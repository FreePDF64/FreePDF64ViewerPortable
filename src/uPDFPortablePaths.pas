unit uPDFPortablePaths;

interface

function IsPAFViewer: Boolean;
function ViewerDataFolder: string;
function ViewerIniFileName: string;

implementation

uses System.SysUtils, System.IOUtils;

var
  DataFolder: string;

function PAFRoot: string;
var AppFolder, ProgramFolder: string;
begin
  Result := '';
  ProgramFolder := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  if not SameText(ExtractFileName(ProgramFolder), 'FreePDF64Viewer') then Exit;
  AppFolder := ExtractFileDir(ProgramFolder);
  if not SameText(ExtractFileName(AppFolder), 'App') then Exit;
  if not FileExists(TPath.Combine(AppFolder, 'AppInfo\appinfo.ini')) then Exit;
  Result := ExtractFileDir(AppFolder);
end;

function IsPAFViewer: Boolean;
begin
  Result := PAFRoot <> '';
end;

procedure CopyMissingTree(const Source, Dest: string);
var Item, Target: string;
begin
  if not DirectoryExists(Source) then Exit;
  if not ForceDirectories(Dest) then
    raise EInOutError.Create('Cannot create directory: ' + Dest);
  for Item in TDirectory.GetFiles(Source) do
  begin
    Target := TPath.Combine(Dest, ExtractFileName(Item));
    if not FileExists(Target) then TFile.Copy(Item, Target, False);
  end;
  for Item in TDirectory.GetDirectories(Source) do
    CopyMissingTree(Item, TPath.Combine(Dest, ExtractFileName(Item)));
end;

function ViewerDataFolder: string;
var Root, Dest, Old, Marker, Item: string;
begin
  if DataFolder <> '' then Exit(DataFolder);
  Old := ExtractFilePath(ParamStr(0));
  Root := PAFRoot;
  if Root = '' then
    DataFolder := Old
  else
  begin
    Dest := TPath.Combine(Root, 'Data\settings');
    if not ForceDirectories(Dest) then
      raise EInOutError.Create('Cannot create directory: ' + Dest);
    Marker := TPath.Combine(Dest, '.viewer-migration-v1');
    if not FileExists(Marker) then
    begin
      for Item in TArray<string>.Create('FreePDFViewer.ini', 'FreePDF_Error.log') do
        if FileExists(Old + Item) and not FileExists(TPath.Combine(Dest, Item)) then
          TFile.Copy(Old + Item, TPath.Combine(Dest, Item), False);
      for Item in TArray<string>.Create('Workspaces', 'Arbeitsbereiche', 'Signaturen', 'Thumbnails') do
        CopyMissingTree(Old + Item, TPath.Combine(Dest, Item));
      TFile.WriteAllText(Marker, '1');
    end;
    DataFolder := IncludeTrailingPathDelimiter(Dest);
  end;
  Result := DataFolder;
end;

function ViewerIniFileName: string;
begin
  Result := ViewerDataFolder + 'FreePDFViewer.ini';
end;

end.
