unit uPDFMergeTabs;

interface

uses System.Classes, Vcl.Forms;

procedure MergeOpenPDFTabs(AOwner: TCustomForm; AFiles: TStrings);

implementation

uses Winapi.Windows, System.SysUtils, System.Math, Vcl.Controls, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Dialogs, Vcl.Graphics, uPDFLanguage, uPDFTabsForm;

type
  // OnMouseWheel ist bei einigen VCL-Steuerelementen protected.
  // Abgeleitete Klassen machen das Ereignis fuer die Zuweisung zugaenglich.
  TMergeWheelPanel = class(TPanel)
  public
    property OnMouseWheel;
  end;
  TMergeWheelCheckBox = class(TCheckBox)
  public
    property OnMouseWheel;
  end;
  TMergeWheelLabel = class(TLabel)
  public
    property OnMouseWheel;
  end;
  TMergeWheelEdit = class(TEdit)
  public
    property OnMouseWheel;
  end;
  TMergeWheelScrollBox = class(TScrollBox)
  public
    property OnMouseWheel;
  end;

  TMergeEntry = class
    FileName: string;
    Pages: string;
    Selected: Boolean;
  end;
  TMergeDialog = class(TForm)
  private
    Entries: TList;
    Rows: TScrollBox;
    FSelectedRowIndex: Integer;
    procedure RowsMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure RebuildRows;
    procedure SelectRow(Sender: TObject);
    procedure PagesChanged(Sender: TObject);
    procedure CheckChanged(Sender: TObject);
    procedure MoveUp(Sender: TObject);
    procedure MoveDown(Sender: TObject);
    procedure ShowMergeHelp(Sender: TObject);
    procedure MergeHelpMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure MoveItem(Delta: Integer);
  end;
  PPDFFileWrite = ^TPDFFileWrite;
  TPDFWriteBlock = function(AWriter: PPDFFileWrite; AData: Pointer;
    ASize: Cardinal): Integer; cdecl;
  TPDFFileWrite = record
    Version: Integer;
    WriteBlock: TPDFWriteBlock;
  end;
  POutputWriter = ^TOutputWriter;
  TOutputWriter = record
    Base: TPDFFileWrite;
    Stream: TFileStream;
  end;

function FPDF_CreateNewDocument: Pointer; stdcall; external 'pdfium.dll';
function FPDF_LoadDocument(FileName, Password: PAnsiChar): Pointer; stdcall; external 'pdfium.dll';
procedure FPDF_CloseDocument(Doc: Pointer); stdcall; external 'pdfium.dll';
function FPDF_GetPageCount(Doc: Pointer): Integer; stdcall; external 'pdfium.dll';
function FPDF_ImportPages(DestDoc, SrcDoc: Pointer; PageRange: PAnsiChar;
  Index: Integer): Integer; stdcall; external 'pdfium.dll';
function FPDF_SaveAsCopy(Doc: Pointer; Writer: PPDFFileWrite;
  Flags: Integer): Integer; stdcall; external 'pdfium.dll';

procedure TMergeDialog.RowsMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
var
  NewPos: Integer;
begin
  if (Rows = nil) or (Rows.VertScrollBar.Range <= Rows.ClientHeight) then Exit;
  NewPos := Rows.VertScrollBar.Position - (WheelDelta div 120) * 60;
  if NewPos < 0 then NewPos := 0;
  Rows.VertScrollBar.Position := NewPos;
  Handled := True;
end;

procedure TMergeDialog.RebuildRows;
var
  I, RowTop, RowHeight: Integer;
  Panel: TPanel;
  Check: TCheckBox;
  Edit: TEdit;
  NameLabel: TLabel;
  Entry: TMergeEntry;
  D: Integer;
  function Px(N: Integer): Integer;
  begin
    Result := MulDiv(N, D, 96);
  end;
begin
  // Den tatsaechlichen Monitor-DPI-Wert benutzen, nicht den
  // Designzeit-Wert PixelsPerInch (kann 96 bleiben).
  D := GetDpiForWindow(Handle);
  if D < 96 then D := 96;
  while Rows.ControlCount > 0 do Rows.Controls[0].Free;
  RowTop := 0;
  for I := 0 to Entries.Count - 1 do
  begin
    Entry := TMergeEntry(Entries[I]);
    Panel := TMergeWheelPanel.Create(Rows);
    Panel.Parent := Rows;
    Panel.SetBounds(0, RowTop, Rows.ClientWidth - Px(22), Px(34));
    Panel.BevelOuter := bvNone;
    Panel.Color := clBtnFace;
    Panel.ParentBackground := False;
    Panel.Tag := I;
    Panel.OnClick := SelectRow;
    TMergeWheelPanel(Panel).OnMouseWheel := RowsMouseWheel;
    Check := TMergeWheelCheckBox.Create(Panel);
    Check.Parent := Panel;
    Check.SetBounds(Px(4), Px(5), Px(22), Px(22));
    Check.Checked := Entry.Selected;
    Check.Tag := I;
    Check.OnClick := CheckChanged;
    TMergeWheelCheckBox(Check).OnMouseWheel := RowsMouseWheel;
    NameLabel := TMergeWheelLabel.Create(Panel);
    NameLabel.Parent := Panel;
    // Keine automatische Breitenberechnung anhand des langen Dateipfads:
    // die gesamte Spalte bis kurz vor dem Seitenfeld verwenden.
    NameLabel.AutoSize := False;
    NameLabel.WordWrap := False;
    NameLabel.ParentFont := True;
    NameLabel.Layout := tlCenter;
    NameLabel.EllipsisPosition := epPathEllipsis;
    NameLabel.SetBounds(Px(30), Px(3), Px(380), Px(29));
    NameLabel.Caption := Entry.FileName;
    NameLabel.Hint := Entry.FileName;
    NameLabel.ShowHint := True;
    NameLabel.Tag := I;
    NameLabel.OnClick := SelectRow;
    TMergeWheelLabel(NameLabel).OnMouseWheel := RowsMouseWheel;
    Edit := TMergeWheelEdit.Create(Panel);
    Edit.Parent := Panel;
    Edit.ParentFont := True;
    // Genuegend Abstand zum rechten Rand: keine Abschneidung beim Scrollen.
    // Einheitliche Breite auch bei hoher DPI und VCL-Autoskalierung.
    Edit.AutoSize := False;
    Edit.Anchors := [akLeft, akTop];
    Edit.SetBounds(Px(420), Px(3), Px(118), Px(29));
    Edit.Constraints.MinWidth := Px(118);
    Edit.Constraints.MaxWidth := Px(118);
    Edit.Text := Entry.Pages;
    Edit.Hint := Tr('Alle oder z. B. 1-3, 8, 12-15');
    Edit.ShowHint := True;
    Edit.Tag := I;
    Edit.OnEnter := SelectRow;
    Edit.OnChange := PagesChanged;
    TMergeWheelEdit(Edit).OnMouseWheel := RowsMouseWheel;
    // Kompakte Zeilen: Hoehe nach realer Edit-Hoehe, ohne
    // die Schrift nochmals mit DPI zu multiplizieren.
    RowHeight := Max(Px(32), Max(Edit.Height, NameLabel.Height) + Px(3));
    Panel.Height := RowHeight - Px(1);
    NameLabel.Top := (Panel.Height - NameLabel.Height) div 2;
    Check.Top := (Panel.Height - Check.Height) div 2;
    Edit.Top := (Panel.Height - Edit.Height) div 2;
    Inc(RowTop, RowHeight);
    if I = FSelectedRowIndex then
      Panel.Color := $00F4E5D4;
  end;
  Rows.VertScrollBar.Range := RowTop;
end;

procedure TMergeDialog.SelectRow(Sender: TObject);
begin
  FSelectedRowIndex := TControl(Sender).Tag;
  // Nicht während der Bearbeitung die Eingabefelder neu erstellen.
end;

procedure TMergeDialog.PagesChanged(Sender: TObject);
var I: Integer;
begin
  I := TControl(Sender).Tag;
  if (I >= 0) and (I < Entries.Count) then
    TMergeEntry(Entries[I]).Pages := TEdit(Sender).Text;
end;

procedure TMergeDialog.CheckChanged(Sender: TObject);
var I: Integer;
begin
  I := TControl(Sender).Tag;
  if (I >= 0) and (I < Entries.Count) then
    TMergeEntry(Entries[I]).Selected := TCheckBox(Sender).Checked;
  FSelectedRowIndex := I;
end;

procedure TMergeDialog.MoveItem(Delta: Integer);
var J: Integer;
begin
  J := FSelectedRowIndex + Delta;
  if (FSelectedRowIndex < 0) or (J < 0) or (J >= Entries.Count) then Exit;
  Entries.Exchange(FSelectedRowIndex, J);
  FSelectedRowIndex := J;
  RebuildRows;
end;

procedure TMergeDialog.MoveUp(Sender: TObject);
begin MoveItem(-1); end;

procedure TMergeDialog.MoveDown(Sender: TObject);
begin MoveItem(1); end;

procedure TMergeDialog.MergeHelpMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
var
  SB: TScrollBox;
  P: Integer;
begin
  SB := nil;
  if Sender is TScrollBox then
    SB := TScrollBox(Sender)
  else if (Sender is TForm) and (TForm(Sender).Tag <> 0) then
    SB := TScrollBox(TForm(Sender).Tag);
  if SB <> nil then
  begin
    P := SB.VertScrollBar.Position - (WheelDelta div 120) * 60;
    if P < 0 then P := 0;
    SB.VertScrollBar.Position := P;
    Handled := True;
  end;
end;

procedure TMergeDialog.ShowMergeHelp(Sender: TObject);
begin
  // Exakt dasselbe Dialogfenster wie "Hilfe / Über FreePDF64-Viewer".
  // Nur Titel, Untertitel und Hilfetexte werden umgeschaltet.
  if Owner is TPDFTabsForm then
    TPDFTabsForm(Owner).ShowPDFMergeHelp;
end;

// Erlaubt Einzelzahlen und aufsteigende Bereiche; die Eingabereihenfolge bleibt erhalten.
function NormalizePages(const Input: string; MaxPage: Integer): AnsiString;
var
  Parts: TStringList;
  I, K, A, B, P, Dash: Integer;
  Token, OutText: string;
begin
  Token := Trim(Input);
  if SameText(Token, 'Alle') or SameText(Token, 'All') or (Token = '') then
    Exit('');
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ',';
    Parts.DelimitedText := StringReplace(Token, ';', ',', [rfReplaceAll]);
    OutText := '';
    for I := 0 to Parts.Count - 1 do
    begin
      Token := Trim(Parts[I]);
      Dash := Pos('-', Token);
      if Dash > 0 then
      begin
        if (not TryStrToInt(Trim(Copy(Token, 1, Dash-1)), A)) or
           (not TryStrToInt(Trim(Copy(Token, Dash+1, MaxInt)), B)) then
          raise Exception.CreateFmt(Tr('Ungültige Seitenangabe: %s'), [Token]);
      end
      else
      begin
        if not TryStrToInt(Token, A) then
          raise Exception.CreateFmt(Tr('Ungültige Seitenangabe: %s'), [Token]);
        B := A;
      end;
      if (A < 1) or (B < A) or (B > MaxPage) then
        raise Exception.CreateFmt(Tr('Seiten außerhalb des gültigen Bereichs (1-%d): %s'),
          [MaxPage, Token]);
      for P := A to B do
      begin
        if OutText <> '' then OutText := OutText + ',';
        OutText := OutText + IntToStr(P);
      end;
    end;
    Result := AnsiString(OutText);
  finally
    Parts.Free;
  end;
end;

function WritePDFBlock(AWriter: PPDFFileWrite; AData: Pointer;
  ASize: Cardinal): Integer; cdecl;
begin
  try
    Result := Ord(POutputWriter(AWriter).Stream.Write(AData^, ASize) = Integer(ASize));
  except
    Result := 0;
  end;
end;

procedure MergeFiles(AFiles: TStrings; const AOutput: string);
var
  Dest, Src: Pointer;
  I, Count: Integer;
  Utf8Name: UTF8String;
  W: TOutputWriter;
  Written: Boolean;
  TempOutput: string;
  Range: AnsiString;
  Entry: TMergeEntry;
begin
  Dest := FPDF_CreateNewDocument;
  if Dest = nil then
    raise Exception.Create(Tr('Das Zieldokument konnte nicht erstellt werden.'));
  Written := False;
  TempOutput := AOutput + '.merging.tmp';
  try
    for I := 0 to AFiles.Count - 1 do
    begin
      Entry := TMergeEntry(AFiles.Objects[I]);
      Utf8Name := UTF8String(Entry.FileName);
      Src := FPDF_LoadDocument(PAnsiChar(Utf8Name), nil);
      if Src = nil then
        raise Exception.CreateFmt(Tr('PDF konnte nicht geöffnet werden: %s'), [Entry.FileName]);
      try
        Count := FPDF_GetPageCount(Src);
        if Count < 1 then
          raise Exception.CreateFmt(Tr('PDF enthält keine Seiten: %s'), [Entry.FileName]);
        Range := NormalizePages(Entry.Pages, Count);
        if Range = '' then
        begin
          if FPDF_ImportPages(Dest, Src, nil, FPDF_GetPageCount(Dest)) = 0 then
            raise Exception.CreateFmt(Tr('PDF-Seiten konnten nicht übernommen werden: %s'), [Entry.FileName]);
        end
        else if FPDF_ImportPages(Dest, Src, PAnsiChar(Range),
          FPDF_GetPageCount(Dest)) = 0 then
          raise Exception.CreateFmt(Tr('PDF-Seiten konnten nicht übernommen werden: %s'), [Entry.FileName]);
      finally
        FPDF_CloseDocument(Src);
      end;
    end;
    FillChar(W, SizeOf(W), 0);
    W.Base.Version := 1;
    W.Base.WriteBlock := WritePDFBlock;
    W.Stream := TFileStream.Create(TempOutput, fmCreate);
    try
      if FPDF_SaveAsCopy(Dest, @W.Base, 0) = 0 then
        raise Exception.Create(Tr('Die zusammengeführte PDF konnte nicht gespeichert werden.'));
      Written := True;
    finally
      W.Stream.Free;
    end;
  finally
    FPDF_CloseDocument(Dest);
    if not Written and FileExists(TempOutput) then
      DeleteFile(TempOutput);
  end;
  // Die vorhandene Zieldatei erst nach erfolgreichem Schreiben ersetzen.
  if not MoveFileEx(PChar(TempOutput), PChar(AOutput),
    MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
  begin
    DeleteFile(TempOutput);
    RaiseLastOSError;
  end;
end;

procedure MergeOpenPDFTabs(AOwner: TCustomForm; AFiles: TStrings);
var
  Dialog: TMergeDialog;
  UpButton, DownButton, HelpButton, OKButton, CancelButton: TButton;
  Info, NameHeader, PageHeader: TLabel;
  Entry: TMergeEntry;
  SaveDlg: TSaveDialog;
  Selected: TStringList;
  I, N, D: Integer;
  function Px(V: Integer): Integer;
  begin
    Result := MulDiv(V, D, 96);
  end;
begin
  if (AFiles = nil) or (AFiles.Count < 1) then
  begin
    MessageDlg(Tr('Bitte mindestens eine PDF-Datei öffnen.'), mtInformation, [mbOK], 0);
    Exit;
  end;
  Dialog := TMergeDialog.CreateNew(AOwner);
  Dialog.Entries := TList.Create;
  try
    Dialog.Caption := Tr('PDFs zusammenführen ...');
    Dialog.Position := poOwnerFormCenter;
    Dialog.BorderStyle := bsDialog;
    Dialog.Scaled := False;
    // DPI vom tatsaechlichen Fenster/Monitor ermitteln, nicht vom
    // eventuell anders skalierten Hauptfenster.
    D := GetDpiForWindow(Dialog.Handle);
    if D < 96 then D := 96;
    Dialog.Font.Name := 'Segoe UI';
    Dialog.Font.Height := -MulDiv(10, D, 72);
    Dialog.ClientWidth := Px(720);
    Dialog.ClientHeight := Px(470);
    Info := TLabel.Create(Dialog);
    Info.Parent := Dialog;
    Info.SetBounds(Px(16), Px(14), Px(720), Px(40));
    Info.Caption := Tr('PDFs auswählen und die Reihenfolge mit den Pfeilen festlegen.');
    NameHeader := TLabel.Create(Dialog);
    NameHeader.Parent := Dialog;
    NameHeader.SetBounds(Px(42), Px(60), Px(380), Px(30));
    NameHeader.Caption := Tr('PDF-Datei');
    PageHeader := TLabel.Create(Dialog);
    PageHeader.Parent := Dialog;
    PageHeader.SetBounds(Px(436), Px(60), Px(130), Px(30));
    PageHeader.Caption := Tr('Seiten');
    Dialog.Rows := TMergeWheelScrollBox.Create(Dialog);
    Dialog.Rows.Parent := Dialog;
    Dialog.Rows.SetBounds(Px(16), Px(98), Px(575), Px(310));
    Dialog.Rows.VertScrollBar.Tracking := True;
    // Keine horizontale Verschiebung bzw. Abschneidung der Seitenfelder.
    Dialog.Rows.HorzScrollBar.Visible := False;
    TMergeWheelScrollBox(Dialog.Rows).OnMouseWheel := Dialog.RowsMouseWheel;
    Dialog.OnMouseWheel := Dialog.RowsMouseWheel;
    Dialog.FSelectedRowIndex := 0;
    for I := 0 to AFiles.Count - 1 do
    begin
      Entry := TMergeEntry.Create;
      Entry.FileName := AFiles[I];
      Entry.Pages := Tr('Alle');
      Entry.Selected := True;
      Dialog.Entries.Add(Entry);
    end;
    Dialog.RebuildRows;
    UpButton := TButton.Create(Dialog);
    UpButton.Parent := Dialog;
    UpButton.SetBounds(Px(610), Px(98), Px(90), Px(44));
    UpButton.Caption := '▲';
    UpButton.OnClick := Dialog.MoveUp;
    DownButton := TButton.Create(Dialog);
    DownButton.Parent := Dialog;
    DownButton.SetBounds(Px(610), Px(152), Px(90), Px(44));
    DownButton.Caption := '▼';
    DownButton.OnClick := Dialog.MoveDown;
    HelpButton := TButton.Create(Dialog);
    HelpButton.Parent := Dialog;
    HelpButton.SetBounds(Px(634), Px(250), Px(56), Px(44));
    HelpButton.Caption := '?';
    HelpButton.Hint := Tr('Hilfe');
    HelpButton.ShowHint := True;
    HelpButton.OnClick := Dialog.ShowMergeHelp;
    OKButton := TButton.Create(Dialog);
    OKButton.Parent := Dialog;
    OKButton.SetBounds(Px(380), Px(420), Px(180), Px(42));
    OKButton.Caption := Tr('Zusammenführen');
    OKButton.ModalResult := mrOk;
    CancelButton := TButton.Create(Dialog);
    CancelButton.Parent := Dialog;
    CancelButton.SetBounds(Px(570), Px(420), Px(130), Px(42));
    CancelButton.Caption := Tr('Abbrechen');
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True; // ESC schließt den Dialog wie Abbrechen
    if Dialog.ShowModal <> mrOk then Exit;
    Selected := TStringList.Create;
    try
      for I := 0 to Dialog.Entries.Count - 1 do
      begin
        Entry := TMergeEntry(Dialog.Entries[I]);
        if Entry.Selected then
          Selected.AddObject(Entry.FileName, Entry);
      end;
      if Selected.Count < 1 then
      begin
        MessageDlg(Tr('Bitte mindestens eine PDF-Datei auswählen.'), mtInformation, [mbOK], 0);
        Exit;
      end;
      SaveDlg := TSaveDialog.Create(Dialog);
      try
        SaveDlg.Title := Tr('Zusammengeführte PDF speichern');
        SaveDlg.Filter := 'PDF (*.pdf)|*.pdf';
        SaveDlg.DefaultExt := 'pdf';
        SaveDlg.Options := [ofOverwritePrompt, ofPathMustExist, ofEnableSizing];
        SaveDlg.FileName := 'Zusammengefuehrt.pdf';
        if not SaveDlg.Execute then Exit;
        for N := 0 to Selected.Count - 1 do
          if SameText(ExpandFileName(SaveDlg.FileName),
            ExpandFileName(TMergeEntry(Selected.Objects[N]).FileName)) then
          begin
            MessageDlg(Tr('Die Zieldatei darf keine der Quelldateien überschreiben.'), mtError, [mbOK], 0);
            Exit;
          end;
        try
          MergeFiles(Selected, SaveDlg.FileName);
          MessageBox(Dialog.Handle,
            PChar(Tr('Die PDF-Dateien wurden erfolgreich zusammengeführt.') +
              sLineBreak + sLineBreak + ExpandFileName(SaveDlg.FileName)),
            PChar(Tr('PDFs zusammenführen ...')), MB_OK or MB_ICONINFORMATION);
        except
          on E: Exception do
            MessageDlg(E.Message, mtError, [mbOK], 0);
        end;
      finally
        SaveDlg.Free;
      end;
    finally
      Selected.Free;
    end;
  finally
    for I := 0 to Dialog.Entries.Count - 1 do
      TObject(Dialog.Entries[I]).Free;
    Dialog.Entries.Free;
    Dialog.Free;
  end;
end;

end.
