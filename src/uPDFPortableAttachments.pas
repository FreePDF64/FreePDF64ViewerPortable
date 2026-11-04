unit uPDFPortableAttachments;
interface
uses
  uPDFLanguage,
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.Classes,
  System.JSON, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Dialogs, Vcl.Buttons, uPDFModernDialogs, Vcl.ComCtrls, Vcl.Graphics, Vcl.Menus, Math,
  uPDFBrowserForm, uPDFTabsForm, uPDFAttachmentTemp, System.Threading;

procedure InitPDFTabAttachments(const AFileName: string; APDF: TPDFBrowserForm);
procedure ShowPDFEmbeddedAttachments(const PDFFileName: string;
  PDFForm: TForm; AttachmentsButton: TBitBtn);

implementation
uses System.Types;

type
  TPDFAttachmentNoticeForm = class(TForm)
  private
    FAttachmentList: TListBox;
    FOpenedPDFs: TStringList;
    FCloseButton: TButton;
    FSourcePDF: string;
    FPDFBrowser: TPDFBrowserForm;
    procedure DisplaySavedPDF(const AFileName: string);
    procedure NoticeFormClose(Sender: TObject; var Action: TCloseAction);
    procedure CloseButtonClick(Sender: TObject);
    procedure AttachmentKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure CloseButtonMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ExtractButtonClick(Sender: TObject);
    procedure AttachmentDoubleClick(Sender: TObject);
    procedure HideAfterAttachmentOpen;
    procedure AddButtonClick(Sender: TObject);
    procedure RemoveButtonClick(Sender: TObject);
    procedure UpdatePosition(PDFForm: TForm);
  public
    constructor CreateNotice(AOwner: TComponent; const AttachmentNames: TStrings; PDFForm: TForm; const PDFFileName: string);
    destructor Destroy; override;
  end;


function RunProcess(FileName: string; ShowCmd: DWORD; wait: Boolean;
  ProcID: PDWORD): Longword;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
begin
  Result := WAIT_FAILED;
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  FillChar(ProcessInfo, SizeOf(ProcessInfo), 0);

  if Trim(FileName) = '' then
    Exit;

  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_FORCEONFEEDBACK;
  StartupInfo.wShowWindow := ShowCmd;
  if not CreateProcess(nil, PChar(FileName), nil, nil, False,
    CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, nil, nil, StartupInfo,
    ProcessInfo) then
    Exit
  else
  begin
    if not wait then
    begin
      if ProcID <> NIL then
        ProcID^ := ProcessInfo.dwProcessId;
      // Handles werden auch bei asynchronem Start sofort geschlossen.
      // Der Prozess selbst läuft unabhängig davon weiter.
      CloseHandle(ProcessInfo.hProcess);
      CloseHandle(ProcessInfo.hThread);
      ProcessInfo.hProcess := 0;
      ProcessInfo.hThread := 0;
      Result := WAIT_FAILED;
      Exit;
    end;
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess, Result);
  end;
  if ProcessInfo.hProcess <> 0 then
    CloseHandle(ProcessInfo.hProcess);
  if ProcessInfo.hThread <> 0 then
    CloseHandle(ProcessInfo.hThread);
end;


function PDFTabsQpdfExe: string; forward;
function PDFTabsPdfDetachExe: string; forward;

constructor TPDFAttachmentNoticeForm.CreateNotice(
  AOwner: TComponent;
  const AttachmentNames: TStrings;
  PDFForm: TForm;
  const PDFFileName: string);
var
  InfoLabel: TLabel;
  HeaderPanel: TPanel;
  BottomPanel: TPanel;
  ExtractButton, AddButton, RemoveButton: TButton;
  WorkArea: TRect;
  AvailableHeight: Integer;
  Dpi: Integer;
  function Px(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Dpi, 96);
  end;
begin
  inherited CreateNew(AOwner);
  Scaled := False;
  Dpi := Screen.PixelsPerInch;
  if Assigned(PDFForm) then Dpi := PDFForm.CurrentPPI;
  KeyPreview := True;
  OnKeyDown := AttachmentKeyDown;

  FSourcePDF := PDFFileName;
  FPDFBrowser := nil;
  if PDFForm is TPDFBrowserForm then
    FPDFBrowser := TPDFBrowserForm(PDFForm);

  Caption := Tr('Eingebettete PDF-Anlagen');
  BorderStyle := bsDialog;
  BorderIcons := []; // Kein unzuverlaessiges natives Schliessen-Kreuz
  Position := poDesigned;
  DoubleBuffered := True;
  FormStyle := fsNormal;
  OnClose := NoticeFormClose;

  Width := Px(360);
  Height := Px(310);

  Constraints.MinWidth := Px(220);
  Constraints.MinHeight := Px(160);

  // Separater Kopfbereich: Text und X liegen nebeneinander,
  // damit sich die Steuerelemente nicht gegenseitig ueberdecken.
  HeaderPanel := TPanel.Create(Self);
  HeaderPanel.Parent := Self;
  HeaderPanel.Align := alNone;
  HeaderPanel.BevelOuter := bvNone;
  HeaderPanel.SetBounds(0, 0, ClientWidth, Px(52));
  HeaderPanel.Anchors := [akLeft, akTop, akRight];

  InfoLabel := TLabel.Create(Self);
  InfoLabel.Parent := HeaderPanel;
  InfoLabel.AutoSize := False;
  InfoLabel.WordWrap := True;
  InfoLabel.SetBounds(Px(10), Px(9), ClientWidth - Px(55), Px(38));
  InfoLabel.Anchors := [akLeft, akTop, akRight];
  if (AttachmentNames = nil) or (AttachmentNames.Count = 0) then
    InfoLabel.Caption :=
      Tr('Diese PDF-Datei enthält keine eingebetteten Anlagen.')
  else
    InfoLabel.Caption :=
      Tr('Doppelklick: Anlage öffnen.') + sLineBreak +
      Tr('PDFs im neuen Tab, andere mit Windows öffnen.');

  // Bedienleiste unten.
  BottomPanel := TPanel.Create(Self);
  BottomPanel.Parent := Self;
  BottomPanel.Align := alBottom;
  BottomPanel.Height := Px(44);
  BottomPanel.BevelOuter := bvNone;

  ExtractButton := TButton.Create(Self);
  ExtractButton.Parent := BottomPanel;
  ExtractButton.Caption := Tr('Extrahieren');
  ExtractButton.SetBounds(Px(224), Px(8), Px(100), Px(28));
  ExtractButton.Anchors := [akLeft, akTop];
  ExtractButton.OnClick := ExtractButtonClick;

  AddButton := TButton.Create(Self);
  AddButton.Parent := BottomPanel;
  AddButton.Caption := Tr('Hinzufügen');
  AddButton.SetBounds(Px(8), Px(8), Px(100), Px(28));
  AddButton.Anchors := [akLeft, akTop];
  AddButton.OnClick := AddButtonClick;

  RemoveButton := TButton.Create(Self);
  RemoveButton.Parent := BottomPanel;
  RemoveButton.Caption := Tr('Entfernen');
  RemoveButton.SetBounds(Px(116), Px(8), Px(100), Px(28));
  RemoveButton.Anchors := [akLeft, akTop];
  RemoveButton.OnClick := RemoveButtonClick;

  // Eigenes X im Kopfbereich, nicht auf dem Text.
  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := HeaderPanel;
  FCloseButton.Caption := '×';
  FCloseButton.Hint := Tr('Anlagenfenster schließen');
  FCloseButton.ShowHint := True;
  FCloseButton.SetBounds(ClientWidth - Px(37), Px(10), Px(27), Px(27));
  FCloseButton.Anchors := [akTop, akRight];
  FCloseButton.OnClick := CloseButtonClick;
  FCloseButton.OnMouseDown := CloseButtonMouseDown;

  // Anlagenliste in der Mitte.
  FAttachmentList := TListBox.Create(Self);
  FAttachmentList.Parent := Self;
  FAttachmentList.Align := alClient;
  FAttachmentList.ItemHeight := Px(20);
  FAttachmentList.MultiSelect := True;
  FAttachmentList.ExtendedSelect := True;
  FAttachmentList.OnDblClick := AttachmentDoubleClick;
  FOpenedPDFs := TStringList.Create;

  if AttachmentNames <> nil then
    FAttachmentList.Items.Assign(AttachmentNames);

  // Ausrichtung ausführen und anschließend Kopf- und Fußbereich
  // ausdrücklich vor die alClient-Liste legen. Dadurch können die
  // Liste und ihre Fensterfläche die Schaltflächen nicht überdecken.
  Realign;
  BottomPanel.BringToFront;
  InfoLabel.BringToFront;
  Realign;

  // Extrahieren und Entfernen sind nur bei vorhandenen
  // Listeneinträgen sinnvoll. Hinzufügen bleibt immer möglich.
  ExtractButton.Enabled := FAttachmentList.Items.Count > 0;
  RemoveButton.Enabled := FAttachmentList.Items.Count > 0;
  AddButton.Enabled := True;

  // Verfügbaren Bildschirmarbeitsbereich ermitteln.
  if Assigned(PDFForm) then
    WorkArea := Screen.MonitorFromWindow(
      PDFForm.Handle).WorkareaRect
  else
    WorkArea := Screen.WorkAreaRect;

  // Verfügbaren Bildschirmarbeitsbereich ermitteln.
  if Assigned(PDFForm) then
    WorkArea := Screen.MonitorFromWindow(
      PDFForm.Handle).WorkareaRect
  else
    WorkArea := Screen.WorkAreaRect;

  // Kompakte Ausgangsgeometrie. Beim Einblenden positioniert
  // TPDFBrowserForm.UpdateAttachmentWindowPosition das Fenster exakt
  // innerhalb des PDF-Anzeigebereichs (mit 12 px Innenabstand).
  if Assigned(PDFForm) then
  begin
    Left := PDFForm.Left + 12;
    Top := PDFForm.Top + 30;
  end
  else
  begin
    Left := WorkArea.Left + 12;
    Top := WorkArea.Top + 12;
  end;

  // Explizite Geometrie fuer Liste und Fussleiste.
  HeaderPanel.Align := alNone;
  HeaderPanel.SetBounds(0, 0, ClientWidth, Px(52));
  HeaderPanel.Anchors := [akLeft, akTop, akRight];
  HeaderPanel.BringToFront;
  FCloseButton.BringToFront;

  BottomPanel.Align := alNone;
  BottomPanel.SetBounds(0, ClientHeight - Px(44), ClientWidth, Px(44));
  BottomPanel.Anchors := [akLeft, akRight, akBottom];

  FAttachmentList.Align := alNone;
  FAttachmentList.SetBounds(Px(8), Px(56), ClientWidth - Px(16),
    Max(Px(30), ClientHeight - Px(104)));
  FAttachmentList.Anchors := [akLeft, akTop, akRight, akBottom];

  HeaderPanel.Visible := True;
  BottomPanel.Visible := True;
  FAttachmentList.Visible := True;

end;

procedure TPDFAttachmentNoticeForm.DisplaySavedPDF(const AFileName: string);
var
  Tab: TTabSheet;
begin
  if not Assigned(FPDFBrowser) or not FileExists(AFileName) then Exit;
  // Die neue PDF im vorhandenen Register laden, nicht in einem neuen Tab.
  FPDFBrowser.OpenSavedPDF(AFileName, FAttachmentList.Items.Count > 0);
  if FPDFBrowser.Parent is TTabSheet then
  begin
    Tab := TTabSheet(FPDFBrowser.Parent);
    Tab.Caption := ExtractFileName(AFileName);
    Tab.Hint := AFileName;
  end;
end;

destructor TPDFAttachmentNoticeForm.Destroy;
begin
  FOpenedPDFs.Free;
  inherited;
end;

procedure TPDFAttachmentNoticeForm.AttachmentKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    ShowWindow(Handle, SW_HIDE);
    SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0,
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
    Key := 0;
  end;
end;

procedure TPDFAttachmentNoticeForm.CloseButtonClick(Sender: TObject);
begin
  // Direkt ueber das Windows-Fensterhandle ausblenden.
  ShowWindow(Handle, SW_HIDE);
end;

procedure TPDFAttachmentNoticeForm.CloseButtonMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
    ShowWindow(Handle, SW_HIDE);
end;

procedure TPDFAttachmentNoticeForm.NoticeFormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  // Das Fenster wird über den PDF-Button wieder eingeblendet.
  Action := caHide;
end;

// Fenster nach erfolgreichem Oeffnen zuverlaessig ausblenden.
// Die Instanz bleibt fuer die Anlagen-Schaltflaeche erhalten.
procedure TPDFAttachmentNoticeForm.HideAfterAttachmentOpen;
begin
  ShowWindow(Handle, SW_HIDE);
  Hide;
end;

procedure TPDFAttachmentNoticeForm.AttachmentDoubleClick(Sender: TObject);
var
  Index: Integer;
  Name, Ext, TargetFile, CmdLine, PdfDetachExe, TempBase: string;
  TempDir: array[0..MAX_PATH] of Char;
  TempName: array[0..MAX_PATH] of Char;
  ExitCode: Longword;
  ProcID: Cardinal;
  PDF: TPDFBrowserForm;
  Viewer: TPDFTabsForm;
  OpenResult: HINST;
begin
  Index := FAttachmentList.ItemIndex;
  if (Index < 0) or (FSourcePDF = '') or not FileExists(FSourcePDF) then Exit;
  Name := ExtractFileName(FAttachmentList.Items[Index]);
  Ext := LowerCase(ExtractFileExt(Name));
  Viewer := PDFTabsWindow;

  // Bereits geoeffnete PDF-Anlage nur aktivieren.
  if (Ext = '.pdf') and (Viewer <> nil) and Assigned(FOpenedPDFs) and
     (Index < FOpenedPDFs.Count) and FileExists(FOpenedPDFs[Index]) and
     Viewer.ActivateExistingPDF(FOpenedPDFs[Index]) then
  begin
    HideAfterAttachmentOpen;
    Exit;
  end;

  if (Ext = '.pdf') and ((Viewer = nil) or not Assigned(FPDFBrowser) or
     not (FPDFBrowser.Parent is TTabSheet)) then Exit;

  // Aus PDF-Anlagen niemals Programme oder Skripte direkt ausfuehren.
  if (Ext = '.exe') or (Ext = '.com') or (Ext = '.bat') or
     (Ext = '.cmd') or (Ext = '.ps1') or (Ext = '.vbs') or
     (Ext = '.vbe') or (Ext = '.js') or (Ext = '.jse') or
     (Ext = '.wsf') or (Ext = '.wsh') or (Ext = '.scr') or
     (Ext = '.pif') or (Ext = '.msi') or (Ext = '.msp') or
     (Ext = '.hta') or (Ext = '.lnk') or (Ext = '.url') then
  begin
    PDFModernMessageDlg(Tr('Diese Anlage kann aus Sicherheitsgründen nicht direkt gestartet werden.') +
      sLineBreak + Tr('Verwenden Sie bei Bedarf die Schaltfläche Extrahieren.'),
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if (Ext <> '.pdf') and
     (PDFModernMessageDlg(Tr('Die Anlage öffnen?') + sLineBreak + ' + Name +  ' + Tr('mit dem zugeordneten Windows-Programm öffnen?') +
       sLineBreak + Tr('Öffnen Sie nur Anlagen aus vertrauenswürdigen PDF-Dateien.'),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;

  PdfDetachExe := PDFTabsPdfDetachExe;
  if not FileExists(PdfDetachExe) then
    PdfDetachExe := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'pdfdetach.exe';
  if not FileExists(PdfDetachExe) then
  begin
    PDFModernMessageDlg(Tr('pdfdetach.exe wurde nicht gefunden.'), mtError, [mbOK], 0);
    Exit;
  end;
  if GetTempPath(MAX_PATH, TempDir) = 0 then Exit;
  if GetTempFileName(TempDir, 'FPA', 0, TempName) = 0 then Exit;
  TempBase := IncludeTrailingPathDelimiter(string(TempDir)) +
    'FreePDF64_Attachment_' + ExtractFileName(ChangeFileExt(string(TempName), ''));
  DeleteFile(string(TempName));
  // Die Endung beibehalten, damit Windows die passende Anwendung findet.
  TargetFile := TempBase + Ext;
  if Ext = '' then TargetFile := TempBase + '.bin';
  CmdLine := '"' + PdfDetachExe + '" -save ' + IntToStr(Index + 1) +
    ' -o "' + TargetFile + '" "' + FSourcePDF + '"';
  ProcID := 0;
  ExitCode := RunProcess(CmdLine, SW_HIDE, True, @ProcID);
  if (ExitCode <> 0) or not FileExists(TargetFile) then
  begin
    DeleteFile(TargetFile);
    PDFModernMessageDlg(Tr('Die Anlage konnte nicht extrahiert werden.'), mtError, [mbOK], 0);
    Exit;
  end;

  RegisterPDFAttachmentTemp(TargetFile);

  if Ext <> '.pdf' then
  begin
    OpenResult := ShellExecute(Handle, 'open', PChar(TargetFile), nil, nil, SW_SHOWNORMAL);
    if NativeInt(OpenResult) <= 32 then
    begin
      ReleasePDFAttachmentTemp(TargetFile);
      PDFModernMessageDlg(Tr('Für diese Anlage konnte kein zugeordnetes Windows-Programm gestartet werden.'),
        mtError, [mbOK], 0);
      Exit;
    end;
    HideAfterAttachmentOpen;
    Exit;
  end;

  PDF := TPDFBrowserForm.Create(nil);
  try
    PDF.PDFFileName := TargetFile;
    PDF.StandalonePDFMode := False;
    Viewer.AddAttachmentPDF(PDF, FPDFBrowser);
    if PDF.Parent is TTabSheet then
      TTabSheet(PDF.Parent).Caption := Name;
    while FOpenedPDFs.Count <= Index do FOpenedPDFs.Add('');
    FOpenedPDFs[Index] := TargetFile;
    HideAfterAttachmentOpen;
  except
    PDF.Free;
    ReleasePDFAttachmentTemp(TargetFile);
    raise;
  end;
end;

procedure TPDFAttachmentNoticeForm.ExtractButtonClick(Sender: TObject);
var
  PdfDetachExe, CmdLine, Destination, TargetFile, BaseName: string;
  SaveDialog: TSaveDialog;
  FolderDialog: TFileOpenDialog;
  ExitCode: Longword;
  ProcID: Cardinal;
  I, CountSelected, CountDone: Integer;
begin
  CountSelected := 0;
  for I := 0 to FAttachmentList.Items.Count - 1 do
    if FAttachmentList.Selected[I] then Inc(CountSelected);
  if CountSelected = 0 then
  begin
    PDFModernMessageDlg(Tr('Bitte zuerst eine oder mehrere Anlagen markieren.'), mtInformation, [mbOK], 0);
    Exit;
  end;
  if (FSourcePDF = '') or not FileExists(FSourcePDF) then
  begin
    PDFModernMessageDlg(Tr('Die zugehörige PDF-Datei wurde nicht gefunden.'), mtError, [mbOK], 0);
    Exit;
  end;
  PdfDetachExe := PDFTabsPdfDetachExe;
  if not FileExists(PdfDetachExe) then
    PdfDetachExe := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'pdfdetach.exe';
  if not FileExists(PdfDetachExe) then
  begin
    PDFModernMessageDlg(Tr('pdfdetach.exe wurde nicht gefunden.'), mtError, [mbOK], 0);
    Exit;
  end;

  Destination := '';
  if CountSelected = 1 then
  begin
    SaveDialog := TSaveDialog.Create(Self);
    try
      SaveDialog.Title := Tr('PDF-Anlage extrahieren');
      for I := 0 to FAttachmentList.Items.Count - 1 do
        if FAttachmentList.Selected[I] then
          SaveDialog.FileName := ExtractFileName(FAttachmentList.Items[I]);
      SaveDialog.Filter := Tr('Alle Dateien (*.*)|*.*');
      SaveDialog.Options := SaveDialog.Options + [ofPathMustExist, ofOverwritePrompt, ofEnableSizing];
      if not SaveDialog.Execute then Exit;
      Destination := SaveDialog.FileName;
    finally
      SaveDialog.Free;
    end;
  end
  else
  begin
    FolderDialog := TFileOpenDialog.Create(Self);
    try
      FolderDialog.Title := Tr('Zielordner für markierte PDF-Anlagen wählen');
      FolderDialog.Options := FolderDialog.Options + [fdoPickFolders, fdoPathMustExist];
      if not FolderDialog.Execute then Exit;
      Destination := FolderDialog.FileName;
    finally
      FolderDialog.Free;
    end;
  end;

  CountDone := 0;
  for I := 0 to FAttachmentList.Items.Count - 1 do
  begin
    if not FAttachmentList.Selected[I] then Continue;
    if CountSelected = 1 then
      TargetFile := Destination
    else
    begin
      BaseName := ExtractFileName(FAttachmentList.Items[I]);
      if BaseName = '' then BaseName := 'Anlage_' + IntToStr(I + 1);
      TargetFile := IncludeTrailingPathDelimiter(Destination) + BaseName;
      if FileExists(TargetFile) then
      begin
        if PDFModernMessageDlg(Tr('Datei existiert bereits:') + sLineBreak + TargetFile +
          sLineBreak + Tr('Überschreiben?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
          Continue;
      end;
    end;
    CmdLine := '"' + PdfDetachExe + '" -save ' + IntToStr(I + 1) +
      ' -o "' + TargetFile + '" "' + FSourcePDF + '"';
    ProcID := 0;
    ExitCode := RunProcess(CmdLine, SW_HIDE, True, @ProcID);
    if ExitCode = 0 then
    begin
      Inc(CountDone);

    end
    else
      PDFModernMessageDlg(Tr('Fehler beim Extrahieren von ') + FAttachmentList.Items[I] +
        ' (Fehlercode ' + IntToStr(ExitCode) + ').', mtError, [mbOK], 0);
  end;
  PDFModernMessageDlg(IntToStr(CountDone) + ' von ' + IntToStr(CountSelected) +
    ' markierten Anlagen extrahiert.', mtInformation, [mbOK], 0);
end;

procedure TPDFAttachmentNoticeForm.AddButtonClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
  SaveDialog: TSaveDialog;
  QpdfExe, CmdLine, NewPDF, AttachmentFile: string;
  ProcID: Cardinal;
  ExitCode: Longword;
  I: Integer;
  SelectedFiles: TStringList;
begin
  if (FSourcePDF = '') or not FileExists(FSourcePDF) then
  begin
    PDFModernMessageDlg(Tr('Die zugehörige PDF-Datei wurde nicht gefunden.'),
      mtError, [mbOK], 0);
    Exit;
  end;

  QpdfExe := PDFTabsQpdfExe;
  if (QpdfExe = '') or not FileExists(QpdfExe) then
  begin
    PDFModernMessageDlg(Tr('QPDF wurde nicht gefunden. Bitte prüfen Sie den QPDF-Pfad in den Einstellungen.'),
      mtError, [mbOK], 0);
    Exit;
  end;

  SelectedFiles := TStringList.Create;
  try
    OpenDialog := TOpenDialog.Create(Self);
    try
      OpenDialog.Title := Tr('Dateien als PDF-Anlagen auswählen');
      OpenDialog.InitialDir := ExtractFilePath(FSourcePDF);
      OpenDialog.Filter := Tr('Alle Dateien (*.*)|*.*');
      OpenDialog.Options := OpenDialog.Options +
        [ofAllowMultiSelect, ofFileMustExist, ofPathMustExist, ofEnableSizing];
      if not OpenDialog.Execute then Exit;
      SelectedFiles.Assign(OpenDialog.Files);
    finally
      OpenDialog.Free;
    end;
    if SelectedFiles.Count = 0 then Exit;

    SaveDialog := TSaveDialog.Create(Self);
    try
      SaveDialog.Title := Tr('PDF mit zusätzlichen Anlagen speichern');
      SaveDialog.InitialDir := ExtractFilePath(FSourcePDF);
      if PDFLanguage = 'en' then
        SaveDialog.FileName := ChangeFileExt(ExtractFileName(FSourcePDF), '') + '_with_attachments.pdf'
      else
        SaveDialog.FileName := ChangeFileExt(ExtractFileName(FSourcePDF), '') + '_mit_Anlagen.pdf';
      SaveDialog.Filter := Tr('PDF-Dateien (*.pdf)|*.pdf');
      SaveDialog.DefaultExt := 'pdf';
      SaveDialog.Options := SaveDialog.Options + [ofPathMustExist, ofOverwritePrompt, ofEnableSizing];
      if not SaveDialog.Execute then Exit;
      NewPDF := SaveDialog.FileName;
    finally
      SaveDialog.Free;
    end;

    if SameText(ExpandFileName(NewPDF), ExpandFileName(FSourcePDF)) then
    begin
      PDFModernMessageDlg(Tr('Bitte einen anderen Dateinamen als die Ausgangs-PDF wählen.'),
        mtInformation, [mbOK], 0);
      Exit;
    end;

    // Alle Anlagen in einem QPDF-Aufruf einbetten und die PDF nur einmal speichern.
    CmdLine := '"' + QpdfExe + '"';
    for I := 0 to SelectedFiles.Count - 1 do
    begin
      AttachmentFile := SelectedFiles[I];
      CmdLine := CmdLine + ' --add-attachment "' + AttachmentFile + '" --';
    end;
    CmdLine := CmdLine + ' -- "' + FSourcePDF + '" "' + NewPDF + '"';

    ProcID := 0;
    ExitCode := RunProcess(CmdLine, SW_HIDE, True, @ProcID);
    if ExitCode <> 0 then
    begin
      PDFModernMessageDlg(Tr('Die Anlagen konnten nicht hinzugefügt werden. QPDF meldete Fehlercode ') +
        IntToStr(ExitCode) + '.', mtError, [mbOK], 0);
      Exit;
    end;


    FSourcePDF := NewPDF;
    for I := 0 to SelectedFiles.Count - 1 do
      FAttachmentList.Items.Add(ExtractFileName(SelectedFiles[I]));
    DisplaySavedPDF(NewPDF);
    PDFModernMessageDlg(IntToStr(SelectedFiles.Count) + Tr(' Anlage(n) wurden hinzugefügt:') +
      sLineBreak + NewPDF, mtInformation, [mbOK], 0);
  finally
    SelectedFiles.Free;
  end;
end;

procedure TPDFAttachmentNoticeForm.UpdatePosition(PDFForm: TForm);
var
  WorkArea: TRect;
begin
  if not Assigned(PDFForm) then
    Exit;

  WorkArea := Screen.MonitorFromWindow(
    PDFForm.Handle).WorkareaRect;

  // Linken Rand der PDFForm übernehmen.
  Left := PDFForm.Left;

  // Anlagenfenster innerhalb des Bildschirmbereichs halten.
  if Left < WorkArea.Left then
    Left := WorkArea.Left;

  if Left + Width > WorkArea.Right then
    Left := WorkArea.Right - Width;
end;

procedure TPDFAttachmentNoticeForm.RemoveButtonClick(Sender: TObject);
var
  QpdfExe, CmdLine, NewPDF, AttachmentKey: string;
  SaveDialog: TSaveDialog;
  ProcID: Cardinal;
  ExitCode: Longword;
  I, CountSelected: Integer;
begin
  CountSelected := 0;
  for I := 0 to FAttachmentList.Items.Count - 1 do
    if FAttachmentList.Selected[I] then Inc(CountSelected);
  if CountSelected = 0 then
  begin
    PDFModernMessageDlg(Tr('Bitte zuerst eine oder mehrere Anlagen markieren.'), mtInformation, [mbOK], 0);
    Exit;
  end;
  if (FSourcePDF = '') or not FileExists(FSourcePDF) then
  begin
    PDFModernMessageDlg(Tr('Die zugehörige PDF-Datei wurde nicht gefunden.'), mtError, [mbOK], 0);
    Exit;
  end;
  QpdfExe := PDFTabsQpdfExe;
  if (QpdfExe = '') or not FileExists(QpdfExe) then
  begin
    PDFModernMessageDlg(Tr('QPDF wurde nicht gefunden. Bitte prüfen Sie den QPDF-Pfad in den Einstellungen.'),
      mtError, [mbOK], 0);
    Exit;
  end;
  if PDFModernMessageDlg(IntToStr(CountSelected) + Tr(' markierte Anlage(n) aus der PDF entfernen?'),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.Title := Tr('PDF ohne die markierten Anlagen speichern');
    SaveDialog.InitialDir := ExtractFilePath(FSourcePDF);
    if PDFLanguage = 'en' then
      SaveDialog.FileName := ChangeFileExt(ExtractFileName(FSourcePDF), '') + '_without_attachments.pdf'
    else
      SaveDialog.FileName := ChangeFileExt(ExtractFileName(FSourcePDF), '') + '_ohne_Anlagen.pdf';
    SaveDialog.Filter := Tr('PDF-Dateien (*.pdf)|*.pdf');
    SaveDialog.DefaultExt := 'pdf';
    SaveDialog.Options := SaveDialog.Options + [ofPathMustExist, ofOverwritePrompt, ofEnableSizing];
    if not SaveDialog.Execute then Exit;
    NewPDF := SaveDialog.FileName;
  finally
    SaveDialog.Free;
  end;
  if SameText(ExpandFileName(NewPDF), ExpandFileName(FSourcePDF)) then
  begin
    PDFModernMessageDlg(Tr('Die Quelldatei darf nicht überschrieben werden.'), mtError, [mbOK], 0);
    Exit;
  end;

  CmdLine := '"' + QpdfExe + '"';
  for I := 0 to FAttachmentList.Items.Count - 1 do
    if FAttachmentList.Selected[I] then
    begin
      AttachmentKey := FAttachmentList.Items[I];
      CmdLine := CmdLine + ' --remove-attachment="' +
        StringReplace(AttachmentKey, '"', '\"', [rfReplaceAll]) + '"';
    end;
  CmdLine := CmdLine + ' -- "' + FSourcePDF + '" "' + NewPDF + '"';
  ProcID := 0;
  ExitCode := RunProcess(CmdLine, SW_HIDE, True, @ProcID);
  if ExitCode <> 0 then
  begin
    PDFModernMessageDlg(Tr('Anlagen konnten nicht entfernt werden. QPDF-Fehlercode ') +
      IntToStr(ExitCode) + '.', mtError, [mbOK], 0);
    Exit;
  end;

  FSourcePDF := NewPDF;
  for I := FAttachmentList.Items.Count - 1 downto 0 do
    if FAttachmentList.Selected[I] then FAttachmentList.Items.Delete(I);
  DisplaySavedPDF(NewPDF);
  PDFModernMessageDlg(Tr('PDF mit entfernten Anlagen gespeichert:') + sLineBreak + NewPDF,
    mtInformation, [mbOK], 0);
end;

function PDFTabsQpdfExe: string;
begin
  Result := '';
  if (Result = '') or not FileExists(Result) then
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) +
      'qpdf\bin\qpdf.exe';
end;

function PDFTabsPdfDetachExe: string;
var
  Folder, AppDir: string;
begin
  Result := '';
  AppDir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  if Result <> '' then Exit;
  if FileExists(AppDir + 'pdfdetach.exe') then
    Result := AppDir + 'pdfdetach.exe'
  else if FileExists(AppDir + 'xpdf\bin64\pdfdetach.exe') then
    Result := AppDir + 'xpdf\bin64\pdfdetach.exe'
  else if FileExists(AppDir + 'xpdf\bin\pdfdetach.exe') then
    Result := AppDir + 'xpdf\bin\pdfdetach.exe';
end;

procedure ShowPDFEmbeddedAttachmentsPrepared(const PDFFileName: string;
  PDFForm: TForm; AttachmentsButton: TBitBtn; PreparedNames: TStrings); forward;

procedure InitPDFTabAttachments(const AFileName: string; APDF: TPDFBrowserForm);
var
  BrowserHandle: HWND;
  FileNameCopy: string;
begin
  if (APDF = nil) or (not FileExists(AFileName)) then Exit;
  if (APDF.AttachmentWindowHandle <> 0) and
     IsWindow(APDF.AttachmentWindowHandle) then Exit;

  BrowserHandle := APDF.Handle;
  FileNameCopy := AFileName;
  // Ausschliesslich QPDF und JSON-Auswertung im Worker; keine VCL-Zugriffe.
  TThread.CreateAnonymousThread(
    procedure
    var
      Names: TStringList;
      QpdfExe, TempFile, CmdLine, Name: string;
      TempPath: array[0..MAX_PATH] of Char;
      TempName: array[0..MAX_PATH] of Char;
      JsonText: TStringList;
      Root, Value, Item, Preferred: TJSONValue;
      Pair: TJSONPair;
      PID: Cardinal;
    begin
      Names := TStringList.Create;
      JsonText := TStringList.Create;
      TempFile := '';
      Root := nil;
      try
        try
          QpdfExe := PDFTabsQpdfExe;
          if FileExists(QpdfExe) and
             (GetTempPath(MAX_PATH, TempPath) <> 0) and
             (GetTempFileName(TempPath, 'PFA', 0, TempName) <> 0) then
          begin
            TempFile := string(PChar(@TempName[0]));
            CmdLine := 'cmd.exe /C ""' + QpdfExe +
              '" --json "' + FileNameCopy + '" > "' + TempFile + '" 2>nul"';
            PID := 0;
            RunProcess(CmdLine, SW_HIDE, True, @PID);
            if FileExists(TempFile) then
            begin
              JsonText.LoadFromFile(TempFile, TEncoding.UTF8);
              Root := TJSONObject.ParseJSONValue(JsonText.Text);
              if Root is TJSONObject then
              begin
                Value := TJSONObject(Root).GetValue('attachments');
                if Value is TJSONObject then
                  for Pair in TJSONObject(Value) do
                  begin
                    Name := Pair.JsonString.Value;
                    Item := Pair.JsonValue;
                    if Item is TJSONObject then
                    begin
                      Preferred := TJSONObject(Item).GetValue('preferredname');
                      if (Preferred is TJSONString) and
                         (Trim(Preferred.Value) <> '') then
                        Name := Preferred.Value;
                    end;
                    if Trim(Name) <> '' then Names.Add(Name);
                  end;
              end;
            end;
          end;
        except
          Names.Clear;
        end;
      finally
        Root.Free;
        JsonText.Free;
        if (TempFile <> '') and FileExists(TempFile) then DeleteFile(TempFile);
      end;
      // Kein APDF-Objekt im Callback festhalten: Fenster kann inzwischen
      // geschlossen sein. Handle und Dateiname werden erneut geprueft.
      TThread.Queue(nil,
        procedure
        var
          Ctrl: TWinControl;
          Browser: TPDFBrowserForm;
        begin
          try
            Ctrl := FindControl(BrowserHandle);
            if not (Ctrl is TPDFBrowserForm) then Exit;
            Browser := TPDFBrowserForm(Ctrl);
            if not SameText(Browser.PDFFileName, FileNameCopy) then Exit;
            if (Browser.AttachmentWindowHandle <> 0) and
               IsWindow(Browser.AttachmentWindowHandle) then Exit;
            ShowPDFEmbeddedAttachmentsPrepared(FileNameCopy, Browser,
              Browser.FAttachmentsButton, Names);
          finally
            Names.Free;
          end;
        end);
    end).Start;
end;

// Prüft eine PDF-Datei mit QPDF auf eingebettete Anlagen und zeigt
// deren Namen in einem separaten, nicht-modalen Fenster an.
// Die PDF-Datei kann parallel im PDFForm betrachtet werden.
procedure ShowPDFEmbeddedAttachments(
  const PDFFileName: string;
  PDFForm: TForm;
  AttachmentsButton: TBitBtn);
begin
  ShowPDFEmbeddedAttachmentsPrepared(PDFFileName, PDFForm,
    AttachmentsButton, nil);
end;

procedure ShowPDFEmbeddedAttachmentsPrepared(
  const PDFFileName: string;
  PDFForm: TForm;
  AttachmentsButton: TBitBtn;
  PreparedNames: TStrings);
var
  OldExStyle: Longint;
  QpdfExe, TempFile, CmdLine, AttachmentName: string;
  TempPath: array[0..MAX_PATH] of Char;
  TempName: array[0..MAX_PATH] of Char;
  ProcID: Cardinal;
  ExitCode: Longword;
  JsonText, AttachmentNames: TStringList;
  JsonValue, AttachmentsValue, ItemValue,
    PreferredNameValue: TJSONValue;
  AttachmentsObject: TJSONObject;
  Pair: TJSONPair;
  NoticeForm: TPDFAttachmentNoticeForm;
  SavedLeft, SavedTop: Integer;
begin
  // Nur bei einer existierenden PDF fortfahren.
  if (ExtractFileExt(PDFFileName).ToLower <> '.pdf') or
     not FileExists(PDFFileName) then
    Exit;

  JsonText := TStringList.Create;
  AttachmentNames := TStringList.Create;
  JsonValue := nil;
  TempFile := '';
  ExitCode := 0;
  NoticeForm := nil;

  try
    // Anlageninformationen nach Möglichkeit mit QPDF auslesen.
    // Fehler beim Auslesen verhindern nicht die Anzeige des Formulars.
    if PreparedNames <> nil then
      AttachmentNames.Assign(PreparedNames);
    QpdfExe := PDFTabsQpdfExe;

    if (PreparedNames = nil) and (QpdfExe <> '') and FileExists(QpdfExe) then
    begin
      if GetTempPath(MAX_PATH, TempPath) <> 0 then
      begin
        if GetTempFileName(TempPath, 'PFA', 0, TempName) <> 0 then
        begin
          TempFile := string(PChar(@TempName[0]));

          try
            CmdLine := 'cmd.exe /C ""' + QpdfExe +
              '" --json "' + PDFFileName +
              '" > "' + TempFile + '" 2>nul"';

            ProcID := 0;
            ExitCode := RunProcess(
              CmdLine, SW_HIDE, True, @ProcID);

            // QPDF kann bei Warnungen einen ExitCode ungleich 0 liefern,
            // obwohl die JSON-Ausgabe gültig ist. Daher die Datei auswerten,
            // sobald sie nicht leer ist.
            if FileExists(TempFile) then
            begin
              JsonText.LoadFromFile(TempFile, TEncoding.UTF8);
              JsonValue := TJSONObject.ParseJSONValue(JsonText.Text);

              if JsonValue is TJSONObject then
              begin
                AttachmentsValue :=
                  TJSONObject(JsonValue).GetValue('attachments');

                if AttachmentsValue is TJSONObject then
                begin
                  AttachmentsObject := TJSONObject(AttachmentsValue);
                  for Pair in AttachmentsObject do
                  begin
                    AttachmentName := Pair.JsonString.Value;
                    ItemValue := Pair.JsonValue;

                    if ItemValue is TJSONObject then
                    begin
                      PreferredNameValue :=
                        TJSONObject(ItemValue).GetValue('preferredname');
                      if (PreferredNameValue is TJSONString) and
                         (Trim(PreferredNameValue.Value) <> '') then
                        AttachmentName := PreferredNameValue.Value;
                    end;

                    if Trim(AttachmentName) <> '' then
                      AttachmentNames.Add(AttachmentName);
                  end;
                end;
              end;
            end;
          except
            // Fehler beim Lesen oder Parsen der Metadaten ignorieren.
            // Das Formular wird anschließend mit einer leeren Liste
            // erstellt, sodass Anlagen hinzugefügt werden können.
            AttachmentNames.Clear;
          end;
        end;
      end;
    end;

    // Eine PDF ohne eingebettete Anlagen ist kein Fehler.
    // qpdf kann auch bei einer gueltigen PDF eine leere Anlagenliste liefern.
    // Deshalb hier keine Warnung anzeigen; das Anlagenfenster bleibt
    // zum Hinzufuegen neuer Anlagen verfuegbar.

    // QPDF-Ergebnis nach Abschluss der asynchronen Anlagenerkennung
    // an den PDF-Tab melden. Nur hier steht die tatsaechliche Liste fest.
    if PDFForm is TPDFBrowserForm then
      TPDFBrowserForm(PDFForm).SetAttachmentIndicator(AttachmentNames.Count > 0);

    // Buttontext passend zur Anzahl der erkannten Anlagen setzen.
    if Assigned(AttachmentsButton) then
    begin
      AttachmentsButton.Caption := ''; // Symbol statt Text beibehalten
    end;

    // Das Formular immer erzeugen, auch bei einer leeren Liste.
    if Assigned(PDFForm) then
      NoticeForm := TPDFAttachmentNoticeForm.CreateNotice(
        PDFForm,
        AttachmentNames,
        PDFForm,
        PDFFileName)
    else
      NoticeForm := TPDFAttachmentNoticeForm.CreateNotice(
        Application,
        AttachmentNames,
        PDFForm,
        PDFFileName);


    if NoticeForm <> nil then
    begin
      try
        NoticeForm.Caption := Tr('Eingebettete PDF-Anlagen');
        NoticeForm.DoubleBuffered := True;
        NoticeForm.FormStyle := fsNormal;
        NoticeForm.WindowState := wsNormal;

        // Das Anlagenfenster gehoert zum PDF-Registerkartenfenster,
        // NICHT zum Hauptformular. So bleibt die PDF-Anzeige im Vordergrund,
        // wenn das Anlagenfenster ein- oder ausgeblendet wird.
        if (PDFForm is TPDFBrowserForm) and
           (PDFTabsWindow <> nil) then
        begin
          NoticeForm.PopupMode := pmExplicit;
          NoticeForm.PopupParent := PDFTabsWindow;
        end;

        // Ein Handle allein initialisiert die sichtbaren VCL-Kindfenster
        // nicht zuverlaessig. Die Form einmal regulaer ueber VCL zeigen
        // und sofort wieder verbergen. Dadurch erhalten ListBox und
        // Schaltflaechen ihre Fensterhandles und Sichtbarkeitszustaende.
        // Initialisierung ausserhalb des sichtbaren Desktops:
        // Show/Hide ist fuer die VCL-Kindfenster notwendig, darf aber
        // beim Oeffnen einer PDF nicht kurz auf dem Monitor aufblitzen.
        // Die eigentliche Position fuer den Anlagen-Button bleibt erhalten.
        SavedLeft := NoticeForm.Left;
        SavedTop := NoticeForm.Top;
        try
          NoticeForm.SetBounds(
            Screen.DesktopRect.Left - NoticeForm.Width - 100,
            Screen.DesktopRect.Top - NoticeForm.Height - 100,
            NoticeForm.Width, NoticeForm.Height);
          // Vollstaendig unsichtbar initialisieren: Auch wenn Windows
          // das Popup kurz an seine Owner-Position verschiebt, blitzt
          // durch AlphaBlendValue=0 kein Anlagenfenster auf.
          NoticeForm.AlphaBlend := True;
          NoticeForm.AlphaBlendValue := 0;
          try
            // Wie in der nachweislich funktionierenden aelteren Version:
            // VCL Show/Hide initialisiert ListBox und Buttons vollstaendig.
            // Das Fenster liegt waehrenddessen ausserhalb des sichtbaren Desktops
            // und ist transparent, sodass kein sichtbares Aufblitzen entsteht.
            // WS_EX_NOACTIVATE nur fuer die versteckte Initialisierung.
            // Danach den urspruenglichen Fensterstil wiederherstellen.
            OldExStyle := Winapi.Windows.GetWindowLong(NoticeForm.Handle, GWL_EXSTYLE);
            Winapi.Windows.SetWindowLong(NoticeForm.Handle, GWL_EXSTYLE,
              OldExStyle or WS_EX_NOACTIVATE);
            try
              // Die VCL muss ihre Steuerelemente regulaer initialisieren.
              // Solange die Form deaktiviert ist, kann sie beim Show
              // nicht den Fokus des Hauptfensters uebernehmen.
              NoticeForm.Enabled := False;
              try
                NoticeForm.Show;
                NoticeForm.Hide;
              finally
                NoticeForm.Enabled := True;
              end;
            finally
              Winapi.Windows.SetWindowLong(NoticeForm.Handle, GWL_EXSTYLE,
                OldExStyle);
            end;
          finally
            NoticeForm.AlphaBlend := False;
          end;
        finally
          NoticeForm.SetBounds(SavedLeft, SavedTop,
            NoticeForm.Width, NoticeForm.Height);
        end;

        // Erst nach der Initialisierung dem Browser zuordnen.
        if PDFForm is TPDFBrowserForm then
          TPDFBrowserForm(PDFForm).AttachmentWindowHandle :=
            NoticeForm.Handle;
      except
        NoticeForm.Free;
        NoticeForm := nil;
        raise;
      end;
    end;

  finally
    JsonValue.Free;
    AttachmentNames.Free;
    JsonText.Free;

    if (TempFile <> '') and FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;


end.
