unit uPDFGlobalSearch;

interface

uses
  uPDFLanguage,
  System.SysUtils, System.Classes, System.Generics.Collections, Winapi.Windows, Winapi.Messages,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Graphics,
  uPDFBrowserForm, uFreePDF64PDFiumCore;

type
  TGlobalSearchHit = class
  public
    PDF: TPDFBrowserForm;
    FileName: string;
    Match: TPDFTextMatch;
    Term: string;
  end;

  TPDFGlobalSearchForm = class(TForm)
  private
    FTabs: TPageControl;
    FTerm: TEdit;
    FMatchCase, FWholeWords: TCheckBox;
    FSearchFlags: Cardinal;
    FSearchBar: TPanel;
    FSearchHeader: TPanel;
    FSearchFooter: TPanel;
    FResults: TListBox;
    FStatus: TLabel;
    FTitle: TLabel;
    FSubtitle: TLabel;
    FStart: TButton;
    FStop: TButton;
    FTimer: TTimer;
    FHits: TObjectList<TGlobalSearchHit>;
    FPendingResults: TStringList;
    FLastUIUpdate: UInt64;
    FTabIndex: Integer;
    FPageIndex: Integer;
    FTermValue: string;
    FRunning: Boolean;
    FTotalPages: Integer;
    FScannedPages: Integer;
    FOfflineCore: TFreePDF64PDFiumCore;
    FOfflineTab: Integer;
    FPendingHit: TGlobalSearchHit;
    FPendingLoadRequested: Boolean;
    FPendingLoadStarted: UInt64;
    procedure ReleaseOfflineCore;
    procedure AdvanceToNextTab;
    procedure FinishHitNavigation;
    procedure FlushResults;
    function FindPDF(ATab: TTabSheet): TPDFBrowserForm;
    function StillOpen(APDF: TPDFBrowserForm; const AFileName: string): Boolean;
    procedure StartClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure SearchTick(Sender: TObject);
    procedure ResultChoose(Sender: TObject);
    procedure ResultMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure SearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Closing(Sender: TObject; var Action: TCloseAction);
    procedure SaveWindowSize;
    procedure WMExitSizeMove(var Message: TMessage); message WM_EXITSIZEMOVE;
    procedure SetStatus;
    procedure LayoutSearchControls(Sender: TObject);
  public
    constructor CreateForTabs(AOwner: TComponent; ATabs: TPageControl);
    destructor Destroy; override;
    procedure ShowSearch;
  end;

implementation

uses
  System.Math, System.Types, System.IniFiles;

constructor TPDFGlobalSearchForm.CreateForTabs(AOwner: TComponent; ATabs: TPageControl);
var
  Bar, Header, Footer: TPanel;
  D: Integer;
  function Px(N: Integer): Integer;
  begin
    Result := MulDiv(N, D, 96);
  end;
begin
  inherited CreateNew(AOwner);
  D := 96;
  if (AOwner is TCustomForm) and (TCustomForm(AOwner).CurrentPPI > 0) then
    D := TCustomForm(AOwner).CurrentPPI
  else if Screen.PixelsPerInch > 0 then
    D := Screen.PixelsPerInch;
  if D < 96 then D := 96;
  FTabs := ATabs;
  FOfflineTab := -1;
  FHits := TObjectList<TGlobalSearchHit>.Create(True);
  FPendingResults := TStringList.Create;
  Caption := Tr('Globale PDF-Suche');
  Position := poDesigned;
  Scaled := False;
  PixelsPerInch := D;
  ClientWidth := Px(900);
  Height := Px(650);
  Constraints.MinWidth := Px(650);
  Constraints.MinHeight := Px(450);
  BorderStyle := bsSizeable;
  Color := clWhite;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  PopupMode := pmExplicit;
  if AOwner is TCustomForm then PopupParent := TCustomForm(AOwner);
  OnClose := Closing;
  OnResize := LayoutSearchControls;

  Header := TPanel.Create(Self);
  FSearchHeader := Header;
  Header.Parent := Self;
  Header.Align := alTop;
  Header.Height := 100;
  Header.BevelOuter := bvNone;
  Header.Color := $00F7F4F0;
  Header.ParentBackground := False;
  FTitle := TLabel.Create(Self);
  FTitle.Parent := Header;
  FTitle.ParentFont := False;
  FTitle.Left := 20;
  FTitle.Top := 12;
  FTitle.AutoSize := False;
  FTitle.WordWrap := True;
  FTitle.Caption := Tr('Alle geöffneten PDFs durchsuchen');
  FTitle.Font.Name := 'Segoe UI Semibold';
  FTitle.Font.Size := 10;
  FTitle.Font.Color := $00412B20;
  FSubtitle := TLabel.Create(Self);
  FSubtitle.Parent := Header;
  FSubtitle.ParentFont := False;
  FSubtitle.Left := 21;
  FSubtitle.Top := Px(66);
  FSubtitle.AutoSize := False;
  FSubtitle.WordWrap := True;
  FSubtitle.Caption := Tr('Ein Klick auf eine Fundstelle öffnet die entsprechende PDF-Seite. Über „Alle PDFs durchsuchen“ erscheint das Suchfenster erneut.');
  FTitle.SetBounds(Px(20), Px(12), Px(860), Px(24));
  FSubtitle.SetBounds(Px(21), Px(40), Px(858), Px(36));
  Header.Height := Px(80);
  FSubtitle.Font.Size := 9;
  FSubtitle.Font.Color := clGray;

  Bar := TPanel.Create(Self);
  FSearchBar := Bar;
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 62;
  Bar.BevelOuter := bvNone;
  Bar.Padding.Left := 18;
  Bar.Padding.Right := 18;
  Bar.Padding.Top := 12;
  Bar.Padding.Bottom := 12;
  Bar.Color := clWhite;
  Bar.ParentBackground := False;

  FStart := TButton.Create(Self);
  FStart.Parent := Bar;
  FStart.Align := alNone;
  FStart.Width := 110;
  FStart.Caption := Tr('Suchen');
  FStart.OnClick := StartClick;
  FStart.Default := True;
  FStart.ShowHint := True;
  FStart.Hint := Tr('Alle geöffneten PDFs nach dem eingegebenen Text durchsuchen');

  FStop := TButton.Create(Self);
  FStop.Parent := Bar;
  FStop.Align := alNone;
  FStop.Width := 110;
  FStop.Caption := Tr('Abbrechen');
  FStop.OnClick := StopClick;
  FStop.ShowHint := True;
  FStop.Hint := Tr('Laufende Suche abbrechen');

  FTerm := TEdit.Create(Self);
  FTerm.Parent := Bar;
  FTerm.ParentFont := True;
  FTerm.Align := alNone;
  FTerm.AutoSize := False;
  FTerm.TextHint := Tr('Suchbegriff eingeben ...');
  FTerm.OnKeyDown := SearchKeyDown;

  FMatchCase := TCheckBox.Create(Self);
  FMatchCase.Parent := Bar;
  FMatchCase.Caption := Tr('Groß-/Kleinschreibung beachten');
  FWholeWords := TCheckBox.Create(Self);
  FWholeWords.Parent := Bar;
  FWholeWords.Caption := Tr('Ganze Wörter');

  Footer := TPanel.Create(Self);
  FSearchFooter := Footer;
  Footer.Parent := Self;
  Footer.Align := alBottom;
  Footer.Height := 39;
  Footer.BevelOuter := bvNone;
  Footer.Color := $00F7F4F0;
  Footer.ParentBackground := False;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Footer;
  FStatus.ParentFont := False;
  FStatus.Font.Assign(Font);
  FStatus.Align := alClient;
  FStatus.Layout := tlCenter;
  FStatus.Margins.Left := 18;
  FStatus.AlignWithMargins := True;
  FStatus.Caption := Tr('Suchbegriff eingeben und Enter drücken.');
  FStatus.Font.Color := $00645448;

  FResults := TListBox.Create(Self);
  FResults.Parent := Self;
  FResults.ParentFont := False;
  FResults.Align := alClient;
  FResults.BorderStyle := bsNone;
  FResults.ItemHeight := 25;
  FResults.Font.Name := 'Segoe UI';
  FResults.Font.Size := 9;
  FResults.DoubleBuffered := True;
  FResults.OnMouseUp := ResultMouseUp;
  FResults.OnKeyDown := SearchKeyDown;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 15;
  FTimer.OnTimer := SearchTick;
  LayoutSearchControls(nil);
  TranslatePDFControls(Self);
  ApplyPDFDialogDesign(Self);
end;

// All measurements are derived from the current monitor DPI and font metrics.
// Avoid alRight/alClient on an auto-sized edit: it can collapse at 4K scaling.
procedure TPDFGlobalSearchForm.LayoutSearchControls(Sender: TObject);
var
  D, Gap, Side, ControlH, TopY, BW1, BW2, X, RowH, CheckH, CheckGap: Integer;
  W, TitleH, SubtitleH: Integer;
  R: TRect;
  MeasureBitmap: TBitmap;
begin
  if (FSearchBar = nil) or (FTerm = nil) or (FStop = nil) or
     (FStart = nil) or (FMatchCase = nil) or (FWholeWords = nil) or (FSearchHeader = nil) or (FSearchFooter = nil) then Exit;
  D := CurrentPPI;
  if D < 96 then D := 96;
  Gap := MulDiv(6, D, 96);
  Side := MulDiv(12, D, 96);
  MeasureBitmap := TBitmap.Create;
  try
    MeasureBitmap.Canvas.Font.Assign(FTerm.Font);
    ControlH := Max(MulDiv(28, D, 96),
      MeasureBitmap.Canvas.TextHeight('ÄgjQ') + MulDiv(8, D, 96));
    RowH := ControlH + MulDiv(12, D, 96);
    TopY := (RowH - ControlH) div 2;
    MeasureBitmap.Canvas.Font.Assign(FStart.Font);
    BW1 := Max(MulDiv(82, D, 96),
      MeasureBitmap.Canvas.TextWidth(FStart.Caption) + MulDiv(16, D, 96));
    MeasureBitmap.Canvas.Font.Assign(FStop.Font);
    BW2 := Max(MulDiv(90, D, 96),
      MeasureBitmap.Canvas.TextWidth(FStop.Caption) + MulDiv(16, D, 96));
    W := FSearchBar.ClientWidth;
    if W < Side * 2 + BW1 + BW2 + Gap * 2 + MulDiv(180, D, 96) then
    begin
      // Bei schmalem effektivem Fenster die Eingabezeile nicht auf wenige
      // Pixel zusammendruecken: Suchfeld oben, Schaltflaechen darunter.
      TopY := Side;
      FTerm.SetBounds(Side, TopY, Max(1, W - 2 * Side), ControlH);
      TopY := TopY + ControlH + Side;
      FStart.SetBounds(Side, TopY, BW1, ControlH);
      FStop.SetBounds(W - Side - BW2, TopY, BW2, ControlH);
    end
    else
    begin
      X := W - Side - BW2;
      FStop.SetBounds(X, TopY, BW2, ControlH);
      X := X - Gap - BW1;
      FStart.SetBounds(X, TopY, BW1, ControlH);
      FTerm.SetBounds(Side, TopY, Max(1, X - Gap - Side), ControlH);
    end;
    TopY := Max(FTerm.Top + FTerm.Height, FStart.Top + FStart.Height) + Gap;
    MeasureBitmap.Canvas.Font.Assign(FMatchCase.Font);
    CheckH := Max(MulDiv(18, D, 96), Max(Abs(FMatchCase.Font.Height),
      MeasureBitmap.Canvas.TextHeight('ÄgjQ')) + MulDiv(2, D, 96));
    MeasureBitmap.Canvas.Font.Assign(FWholeWords.Font);
    CheckH := Max(CheckH, Max(Abs(FWholeWords.Font.Height),
      MeasureBitmap.Canvas.TextHeight('ÄgjQ')) + MulDiv(2, D, 96));
    CheckGap := MulDiv(2, D, 96);
    FSearchBar.Height := TopY + 2 * CheckH + CheckGap + Gap;
    FMatchCase.SetBounds(Side, TopY, Max(1, W - 2 * Side), CheckH);
    FWholeWords.SetBounds(Side, TopY + CheckH + CheckGap,
      Max(1, W - 2 * Side), CheckH);
  finally
    MeasureBitmap.Free;
  end;

  FStatus.Margins.Left := Side;
  MeasureBitmap := TBitmap.Create;
  try
    MeasureBitmap.Canvas.Font.Assign(FTitle.Font);
    TitleH := Max(Abs(FTitle.Font.Height), MeasureBitmap.Canvas.TextHeight('ÄgjQ')) + MulDiv(4, D, 96);
    FTitle.SetBounds(Side, Gap, Max(1, FSearchHeader.ClientWidth - 2 * Side), TitleH);
    MeasureBitmap.Canvas.Font.Assign(FSubtitle.Font);
    R := Rect(0, 0, Max(1, FSearchHeader.ClientWidth - 2 * Side), 0);
    DrawText(MeasureBitmap.Canvas.Handle, PChar(FSubtitle.Caption), -1, R,
      DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
    SubtitleH := Max(R.Bottom - R.Top, MeasureBitmap.Canvas.TextHeight('ÄgjQ')) + MulDiv(4, D, 96);
    FSubtitle.SetBounds(Side, FTitle.Top + TitleH + Gap, Max(1, FSearchHeader.ClientWidth - 2 * Side), SubtitleH);
    FSearchHeader.Height := FSubtitle.Top + SubtitleH + Gap;
    MeasureBitmap.Canvas.Font.Assign(FStatus.Font);
    FSearchFooter.Height := Max(MulDiv(28, D, 96),
      Max(Abs(FStatus.Font.Height), MeasureBitmap.Canvas.TextHeight('ÄgjQ')) +
      FStatus.Margins.Top + FStatus.Margins.Bottom + MulDiv(6, D, 96));
    MeasureBitmap.Canvas.Font.Assign(FResults.Font);
    FResults.ItemHeight := Max(MulDiv(25, D, 96),
      MeasureBitmap.Canvas.TextHeight('ÄgjQ') + MulDiv(8, D, 96));
  finally
    MeasureBitmap.Free;
  end;
end;

destructor TPDFGlobalSearchForm.Destroy;
begin
  if Visible then SaveWindowSize;
  FTimer.Enabled := False;
  ReleaseOfflineCore;
  FPendingResults.Free;
  FHits.Free;
  inherited;
end;

procedure TPDFGlobalSearchForm.ReleaseOfflineCore;
begin
  FreeAndNil(FOfflineCore);
  FOfflineTab := -1;
end;

// Wechsel zum naechsten Dokument: alle drei bisherigen Aufrufstellen
// verwenden dieselbe Freigabe- und Fortschrittsreihenfolge.
procedure TPDFGlobalSearchForm.AdvanceToNextTab;
begin
  ReleaseOfflineCore;
  Inc(FTabIndex);
  FPageIndex := 0;
  FTimer.Enabled := True;
end;

procedure TPDFGlobalSearchForm.FinishHitNavigation;
begin
  if FPendingHit = nil then Exit;
  if not StillOpen(FPendingHit.PDF, FPendingHit.FileName) then
  begin
    FPendingHit := nil;
    FStatus.Caption := Tr('Das Dokument wurde inzwischen geschlossen.');
    Exit;
  end;
  if not FPendingHit.PDF.GlobalViewerReady then
  begin
    // RequestPDFLoad setzt den 150-ms-Ladetimer zurueck. Wird es
    // alle 15 ms erneut aufgerufen, startet das PDF niemals.
    if not FPendingLoadRequested then
    begin
      FPendingLoadRequested := True;
      FPendingLoadStarted := GetTickCount64;
      FPendingHit.PDF.Show;
      FPendingHit.PDF.RequestPDFLoadFast;
    end;
    if GetTickCount64 - FPendingLoadStarted > 30000 then
    begin
      FPendingHit := nil;
      FStatus.Caption := Tr('Treffer-PDF konnte nicht rechtzeitig geladen werden.');
      Exit;
    end;
    FTimer.Enabled := True;
    Exit;
  end;
  FPendingHit.PDF.SetGlobalSearchCount(FHits.Count);
  FPendingHit.PDF.GlobalShowMatch(FPendingHit.Term, FPendingHit.Match);
  FPendingHit := nil;
  FPendingLoadRequested := False;
  Close;
end;

procedure TPDFGlobalSearchForm.ShowSearch;
var
  Viewer: TCustomForm;
  Flags: Cardinal;
  Ini: TIniFile;
  D, W, H: Integer;
  Area: TRect;
  TargetMonitor: TMonitor;
begin
  Flags := LoadPDFSearchFlags('GlobalPDFSearch');
  FMatchCase.Checked := (Flags and 1) <> 0;
  FWholeWords.Checked := (Flags and 2) <> 0;
  FMatchCase.Caption := Tr('Groß-/Kleinschreibung beachten');
  FWholeWords.Caption := Tr('Ganze Wörter');
  if Owner is TCustomForm then
  begin
    Viewer := TCustomForm(Owner);
    TargetMonitor := Viewer.Monitor;
    D := Max(96, Viewer.CurrentPPI);
  end
  else
  begin
    Viewer := nil;
    TargetMonitor := Screen.MonitorFromWindow(Handle);
    D := Max(96, CurrentPPI);
  end;
  Area := TargetMonitor.WorkareaRect;
  WindowState := wsNormal;
  Show;
  D := Max(96, CurrentPPI);
  Area := Monitor.WorkareaRect;
  W := MulDiv(Width, 96, Max(96, CurrentPPI));
  H := MulDiv(Height, 96, Max(96, CurrentPPI));
  try
    Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
    try
      W := Ini.ReadInteger('GlobalPDFSearch', 'WindowWidth96', W);
      H := Ini.ReadInteger('GlobalPDFSearch', 'WindowHeight96', H);
    finally
      Ini.Free;
    end;
  except
    on E: Exception do begin end;
  end;
  Constraints.MinWidth := Min(MulDiv(650, D, 96), Area.Right - Area.Left);
  Constraints.MinHeight := Min(MulDiv(450, D, 96), Area.Bottom - Area.Top);
  W := Min(Area.Right - Area.Left, Max(Constraints.MinWidth, MulDiv(EnsureRange(W, 1, 32767), D, 96)));
  H := Min(Area.Bottom - Area.Top, Max(Constraints.MinHeight, MulDiv(EnsureRange(H, 1, 32767), D, 96)));
  if Viewer <> nil then
    SetBounds(EnsureRange(Viewer.Left + (Viewer.Width - W) div 2, Area.Left, Area.Right - W),
      EnsureRange(Viewer.Top + (Viewer.Height - H) div 2, Area.Top, Area.Bottom - H), W, H)
  else
    SetBounds(Area.Left + (Area.Right - Area.Left - W) div 2,
      Area.Top + (Area.Bottom - Area.Top - H) div 2, W, H);
  LayoutSearchControls(nil);
  BringToFront;
  FTerm.SetFocus;
  FTerm.SelectAll;
end;

procedure TPDFGlobalSearchForm.WMExitSizeMove(var Message: TMessage);
begin
  inherited;
  SaveWindowSize;
end;

procedure TPDFGlobalSearchForm.SaveWindowSize;
var
  Ini: TIniFile;
  D: Integer;
  W, H: Integer;
begin
  D := Max(96, CurrentPPI);
  W := Width;
  H := Height;
  if WindowState <> wsNormal then Exit;
  if (W <= 0) or (H <= 0) then Exit;
  try
    Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
    try
      Ini.WriteInteger('GlobalPDFSearch', 'WindowWidth96', MulDiv(W, 96, D));
      Ini.WriteInteger('GlobalPDFSearch', 'WindowHeight96', MulDiv(H, 96, D));
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do begin end;
  end;
end;

procedure TPDFGlobalSearchForm.Closing(Sender: TObject; var Action: TCloseAction);
begin
  SaveWindowSize;
  FTimer.Enabled := False;
  FRunning := False;
  FPendingHit := nil;
  FPendingLoadRequested := False;
  ReleaseOfflineCore;
  Action := caHide;
end;

function TPDFGlobalSearchForm.FindPDF(ATab: TTabSheet): TPDFBrowserForm;
var I: Integer;
begin
  Result := nil;
  if ATab = nil then Exit;
  for I := 0 to ATab.ControlCount - 1 do
    if ATab.Controls[I] is TPDFBrowserForm then
      Exit(TPDFBrowserForm(ATab.Controls[I]));
end;

function TPDFGlobalSearchForm.StillOpen(APDF: TPDFBrowserForm;
  const AFileName: string): Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to FTabs.PageCount - 1 do
    if FindPDF(FTabs.Pages[I]) = APDF then
      Exit(SameText(APDF.PDFFileName, AFileName));
end;

procedure TPDFGlobalSearchForm.FlushResults;
var
  SavedTop, SavedSelection: Integer;
begin
  if FPendingResults.Count = 0 then Exit;
  // Eine aktive Mausauswahl darf nicht durch das Anhaengen neuer Treffer
  // unterbrochen werden. Auch nach einem einfachen Klick bleibt die Liste
  // waehrend der laufenden Suche stabil; am Suchende wird alles nachgetragen.
  if FRunning and
    (((GetKeyState(VK_LBUTTON) and $8000) <> 0) or
     ((GetKeyState(VK_RBUTTON) and $8000) <> 0) or
     (FResults.Focused and (FResults.ItemIndex >= 0))) then Exit;
  SavedTop := FResults.TopIndex;
  SavedSelection := FResults.ItemIndex;
  FResults.Items.BeginUpdate;
  try
    FResults.Items.AddStrings(FPendingResults);
    FPendingResults.Clear;
    // Neue Treffer sollen weder die Auswahl noch die Scrollposition bewegen.
    if SavedSelection >= 0 then FResults.ItemIndex := SavedSelection;
    if SavedTop >= 0 then FResults.TopIndex := SavedTop;
  finally
    FResults.Items.EndUpdate;
  end;
  FLastUIUpdate := GetTickCount64;
end;

procedure TPDFGlobalSearchForm.SetStatus;
var
  I: Integer;
  PDF: TPDFBrowserForm;
begin
  if FTabs <> nil then
    for I := 0 to FTabs.PageCount - 1 do
    begin
      PDF := FindPDF(FTabs.Pages[I]);
      if PDF <> nil then PDF.SetGlobalSearchCount(FHits.Count);
    end;
  if FRunning then
    FStatus.Caption := Format(Tr('%d Treffer – %d von %d Seiten durchsucht'),
      [FHits.Count, FScannedPages, FTotalPages])
  else
    FStatus.Caption := Format(Tr('Fertig / angehalten: %d Treffer in %d durchsuchten Seiten'),
      [FHits.Count, FScannedPages]);
  FStop.Enabled := FRunning;
end;

procedure TPDFGlobalSearchForm.StartClick(Sender: TObject);
var I: Integer; PDF: TPDFBrowserForm;
begin
  FTimer.Enabled := False;
  FRunning := False;
  FPendingHit := nil;
  ReleaseOfflineCore;
  FPendingResults.Clear;
  FResults.Items.Clear;
  FHits.Clear;
  FLastUIUpdate := GetTickCount64;
  FTermValue := Trim(FTerm.Text);
  if FTermValue = '' then Exit;
  FSearchFlags := 0;
  if FMatchCase.Checked then FSearchFlags := FSearchFlags or 1;
  if FWholeWords.Checked then FSearchFlags := FSearchFlags or 2;
  SavePDFSearchFlags('GlobalPDFSearch', FSearchFlags);
  FTabIndex := 0;
  FOfflineTab := -1;
  FPageIndex := 0;
  FScannedPages := 0;
  FTotalPages := 0;
  for I := 0 to FTabs.PageCount - 1 do
  begin
    PDF := FindPDF(FTabs.Pages[I]);
    if PDF <> nil then Inc(FTotalPages, PDF.GlobalPageCount);
  end;
  FRunning := True;
  FTimer.Enabled := True;
  SetStatus;
end;

procedure TPDFGlobalSearchForm.StopClick(Sender: TObject);
begin
  FTimer.Enabled := False;
  FRunning := False;
  ReleaseOfflineCore;
  FlushResults;
  SetStatus;
end;

procedure TPDFGlobalSearchForm.SearchTick(Sender: TObject);
var
  PDF: TPDFBrowserForm;
  Matches: TArray<TPDFTextMatch>;
  M: TPDFTextMatch;
  Hit: TGlobalSearchHit;
  TextSnippet: string;
begin
  if FPendingHit <> nil then
  begin
    FTimer.Enabled := False;
    FinishHitNavigation;
    Exit;
  end;
  if not FRunning then Exit;
  FTimer.Enabled := False;
  if FTabIndex >= FTabs.PageCount then
  begin
    FRunning := False;
    ReleaseOfflineCore;
    FlushResults;
    SetStatus;
    Exit;
  end;
  PDF := FindPDF(FTabs.Pages[FTabIndex]);
  if PDF = nil then
  begin
    AdvanceToNextTab;
    Exit;
  end;
  // Noch nicht angezeigte Tabs sind absichtlich nicht geladen.
  // Statt sie sichtbar zu aktivieren, wird eine separate PDFium-Core-Instanz
  // nur fuer die Suche verwendet. Die Tab-Auswahl bleibt unveraendert.
  if PDF.GlobalPageCount = 0 then
  begin
    if FOfflineTab <> FTabIndex then
    begin
      ReleaseOfflineCore;
      try
        FOfflineCore := TFreePDF64PDFiumCore.Create;
        FOfflineCore.OpenFile(PDF.PDFFileName);
        FOfflineTab := FTabIndex;
        Inc(FTotalPages, FOfflineCore.PageCount);
      except
        on E: Exception do
        begin
          FStatus.Caption := Tr('PDF nicht durchsuchbar: ') + ExtractFileName(PDF.PDFFileName);
          AdvanceToNextTab;
          Exit;
        end;
      end;
    end;
  end
  else if FOfflineCore <> nil then
    ReleaseOfflineCore;
  if ((FOfflineCore <> nil) and (FPageIndex >= FOfflineCore.PageCount)) or
     ((FOfflineCore = nil) and (FPageIndex >= PDF.GlobalPageCount)) then
  begin
    AdvanceToNextTab;
    Exit;
  end;
  try
    if FOfflineCore <> nil then
      Matches := FOfflineCore.FindTextMatchesOnPage(FTermValue, FPageIndex, FSearchFlags)
    else
      Matches := PDF.GlobalFindOnPage(FTermValue, FPageIndex, FSearchFlags);
    Inc(FScannedPages);
    for M in Matches do
    begin
        if FHits.Count >= 3000 then
        begin
          FRunning := False;
          FStatus.Caption := Tr('Trefferlimit 3000 erreicht. Suche angehalten.');
          Break;
        end;
        Hit := TGlobalSearchHit.Create;
        Hit.PDF := PDF;
        Hit.FileName := PDF.PDFFileName;
        Hit.Match := M;
        Hit.Term := FTermValue;
        if FOfflineCore <> nil then
          TextSnippet := StringReplace(StringReplace(
            FOfflineCore.TextRange(M.PageIndex, Max(0, M.CharIndex - 35),
              Min(512, M.CharCount + 477)), #13, ' ', [rfReplaceAll]),
              #10, ' ', [rfReplaceAll])
        else
          TextSnippet := PDF.GlobalExcerpt(M.PageIndex, M.CharIndex, M.CharCount);
        FHits.Add(Hit);
        FPendingResults.Add(Format('%s  |  Seite %d  |  %s',
          [ExtractFileName(Hit.FileName), M.PageIndex + 1, TextSnippet]));
    end;
    Inc(FPageIndex);
  except
    on E: Exception do
    begin
      FRunning := False;
      FStatus.Caption := Tr('Suche angehalten: ') + E.Message;
    end;
  end;
  // Die Liste und Statuszeile nicht nach jeder Seite neu zeichnen.
  if (not FRunning) or (GetTickCount64 - FLastUIUpdate >= 120) then
  begin
    FlushResults;
    if FRunning then SetStatus;
  end;
  if FRunning then FTimer.Enabled := True;
  if not FRunning and (FHits.Count >= 3000) then
    FStatus.Caption := Tr('Trefferlimit 3000 erreicht. Suche angehalten.')
  else if not FRunning then
    SetStatus;
end;

procedure TPDFGlobalSearchForm.ResultMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var I: Integer;
begin
  if Button <> mbLeft then Exit;
  I := FResults.ItemAtPos(Point(X, Y), True);
  if I < 0 then Exit;
  FResults.ItemIndex := I;
  ResultChoose(Sender);
end;

procedure TPDFGlobalSearchForm.ResultChoose(Sender: TObject);
var Hit: TGlobalSearchHit; I: Integer;
begin
  // Kein Flush bei der Trefferwahl: das wuerde die Liste unter dem
  // Mauszeiger neu zeichnen und kann einen Doppelklick stoeren.
  if FPendingHit <> nil then Exit;
  I := FResults.ItemIndex;
  if (I < 0) or (I >= FHits.Count) then Exit;
  Hit := FHits[I];
  if not StillOpen(Hit.PDF, Hit.FileName) then
  begin
    FStatus.Caption := Tr('Das Dokument wurde inzwischen geschlossen oder gewechselt.');
    Exit;
  end;
  FTimer.Enabled := False;
  FRunning := False;
  ReleaseOfflineCore;
  for I := 0 to FTabs.PageCount - 1 do
    if FindPDF(FTabs.Pages[I]) = Hit.PDF then
    begin
      FTabs.ActivePage := FTabs.Pages[I];
      Break;
    end;
  // Die manuelle Tab-Auswahl zeigt das eingebettete Formular explizit an.
  // Bei der globalen Trefferwahl muss das ebenso geschehen.
  Hit.PDF.Show;
  if not Hit.PDF.GlobalViewerReady then
  begin
    // Nach der Auswahl wird nur der Ziel-Tab geladen; keine Tabwechsel
    // waehrend des Suchlaufs. Der Treffer wird nach Ladeende markiert.
    FRunning := False;
    ReleaseOfflineCore;
    FPendingHit := Hit;
    FPendingLoadRequested := True;
    FPendingLoadStarted := GetTickCount64;
    Hit.PDF.RequestPDFLoadFast;
    FStatus.Caption := Tr('Treffer-PDF wird geladen ...');
    FTimer.Enabled := True;
    Exit;
  end;
  Hit.PDF.SetGlobalSearchCount(FHits.Count);
  Hit.PDF.GlobalShowMatch(Hit.Term, Hit.Match);
  Close;
end;

procedure TPDFGlobalSearchForm.SearchKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    if Sender = FResults then ResultChoose(Sender)
    else StartClick(Sender);
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    Close;
    Key := 0;
  end;
end;

end.
