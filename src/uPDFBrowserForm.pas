// FreePDF64 - PDFium-only PDF-Anzeige (ohne WebView4Delphi)
unit uPDFBrowserForm;
interface
uses
  uPDFLanguage,
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, System.SysUtils, System.Classes, System.SyncObjs,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.Dialogs, uPDFModernDialogs,
  Vcl.StdCtrls, Vcl.Buttons, Vcl.ComCtrls, Math, IniFiles, System.NetEncoding, Vcl.Imaging.pngimage, uFreePDF64PDFiumView, uFreePDF64PDFiumCore, Menus;
type
  TPDFBackgroundLoad = class
  public
    Thread: TThread;
    Core: TFreePDF64PDFiumCore;
    FileName: string;
    ErrorText: string;
    PasswordRequired: Boolean;
    Finished: Integer;
    destructor Destroy; override;
  end;

  TSplitToolbarControlState = record
    Control: TControl;
    WasVisible: Boolean;
  end;

  TPDFBrowserForm = class(TForm)
    TimerPDF: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure TimerPDFTimer(Sender: TObject);
    procedure FormResize(Sender: TObject);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMMove(var aMessage: TWMMove); message WM_MOVE;
    procedure WMMoving(var aMessage: TMessage); message WM_MOVING;
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
  private
    FPDFiumView: TFreePDF64PDFiumView;
    FBackgroundLoad: TPDFBackgroundLoad;
    FLoadingHintWnd: HWND;
    FLoadingHintFont: HFONT;
    FLoadingHintStartTick: UInt64;
    FLoadRequested: Boolean;
    FPDFLoadInProgress: Boolean;
    FNavigationDone: Boolean;
    FNavigationSucceeded: Boolean;
    FPendingFirstDisplay: Boolean;
    FClosing: Boolean;
    FToolbar: TPanel;
    FToolbarLayoutLocked: Boolean;
    FMergingToolbar: Boolean;
    FFindButton: TBitBtn;
    FOpenPDFButton: TButton;
    FExternalSplitButton: TButton;
    FSplitToolbarStates: array of TSplitToolbarControlState;
    FSplitToolbarIsolated: Boolean;
    FSplitToolbarPanel: TWinControl;
    FSplitToolbarPanelWasVisible: Boolean;
    FSplitButtonOriginalWidth: Integer;
    FSplitButtonOriginalHeight: Integer;
    FWorkspacesButton: TButton;
    FGlobalFindButton: TBitBtn;
    FSearchCountLabel: TLabel;
    FToolbarDesignIndex: Integer;
    FToolbarDesignApplied: Boolean;
    FGlobalSearchActive: Boolean;
    FGlobalSearchCount: Integer;
    FPageNavigationTimer: TTimer;
    FSearchTerm: string;
    FStartPage: Integer;
    FWorkspaceZoom: Double;
    FWorkspaceFit: Boolean;
    FWorkspaceX, FWorkspaceY: Integer;
    FWorkspaceRestorePending: Boolean;
    FWorkspaceLayoutPending: Boolean;
    FWorkspaceViewMode: Integer;
    FWorkspaceTwoPage, FWorkspaceContinuous, FWorkspaceSidebar: Boolean;
    FTabbedPDFMode: Boolean;
    FStandalonePDFMode: Boolean;
    FStandaloneHintShown: Boolean;
    procedure UpdateUnifiedToolbar;
    procedure FinishBackgroundLoad;
    procedure SetLoadingHint(AVisible: Boolean);
    procedure MarkerClick(Sender: TObject);
    procedure BuildNavigationToolbar;
    procedure ReflowNavigationToolbar;
    procedure NumberFieldMouseEnter(Sender: TObject);
    procedure FindTermClick(Sender: TObject);
    procedure OpenPDFToolbarClick(Sender: TObject);
    procedure OpenWorkspacesToolbarClick(Sender: TObject);
    procedure WorkspacesToolbarMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GlobalFindClick(Sender: TObject);
    procedure UpdateSearchCount(Sender: TObject);
    procedure SetSearchTerm(const AValue: string);
    procedure ToggleAttachmentsClick(Sender: TObject);
    procedure PageNavigationTimerTimer(Sender: TObject);
  public
    FAttachmentsButton: TBitBtn;
    FAttachmentSeparator: TBevel;
    FHasPDFEmbeddedAttachments: Boolean;
    OnGlobalSearch: TNotifyEvent;
    OnOpenPDF: TNotifyEvent;
    OnOpenWorkspaces: TNotifyEvent;
    OnSaveWorkspace: TNotifyEvent;
    AttachmentWindowHandle: HWND;
    PDFFileName: string;
    destructor Destroy; override;
    function IsShortCut(var Message: TWMKey): Boolean; override;
    procedure ApplyToolbarDesign(ADesign: Integer);
    procedure RefreshToolbarAfterSplit;
    procedure PlaceSplitButton(AButton: TButton; AVisible: Boolean);
    procedure UpdateAttachmentWindowPosition;
    procedure TogglePageThumbnails;
    procedure ShowRequiredFieldsReport;
    procedure FocusAdjacentFormWidget(ADirection: Integer);
    function HandleFormDialogKey(AKey: Word): Boolean;
    procedure RefreshActiveTabPDF;
    procedure OpenSavedPDF(const AFileName: string; AHasAttachments: Boolean);
    procedure SetAttachmentIndicator(AHasAttachments: Boolean);
    procedure HideLoadingHintForInactiveTab;
    procedure RequestPDFLoad;
    procedure RequestPDFLoadFast;
    procedure ShowPDFSearch;
    function HasPDFSearchHighlights: Boolean;
    procedure ClearPDFSearchHighlights;
    procedure PDFPageClickClearSearch(Sender: TObject);
    function GlobalViewerReady: Boolean;
    function GlobalPageCount: Integer;
    function GlobalFindOnPage(const ATerm: string; APage: Integer): TArray<TPDFTextMatch>;
    function GlobalExcerpt(APage, AChar, ALength: Integer): string;
    procedure GlobalShowMatch(const ATerm: string; const AMatch: TPDFTextMatch);
    procedure SetGlobalSearchCount(ACount: Integer);
    function WorkspaceViewMode: Integer;
    function WorkspaceTwoPage: Boolean;
    function WorkspaceContinuous: Boolean;
    function WorkspaceSidebarVisible: Boolean;
    procedure SetWorkspaceLayout(AViewMode: Integer; ATwoPage, AContinuous, ASidebar: Boolean);
    function WorkspacePage: Integer;
    function WorkspaceZoom: Double;
    function WorkspaceFit: Boolean;
    function WorkspaceScrollX: Integer;
    function WorkspaceScrollY: Integer;
    procedure SetWorkspaceView(AZoom: Double; AFit: Boolean; AX, AY: Integer);
    procedure ApplySplitSync(AZoom: Double; AApplyZoom: Boolean; AX, AY: Integer; AApplyScroll: Boolean);
    procedure NextPDFSearchMatch(ADirection: Integer);
    procedure SelectAllPDFText;
    procedure CopyPDFText;
    function HasUnsavedPDFChanges: Boolean;
    function SaveUnsavedPDFChanges: Boolean;
    procedure SetFullScreenDisplay(AEnabled: Boolean);
    procedure ZoomPDF(AIncrease: Boolean);
    procedure RefreshPDFViewport;
    procedure RefitPDFOnTabActivation;
    procedure RefreshLanguage;
    procedure ReloadCurrentPDF;
    procedure ShowDocumentProperties;
    property PDFNavigationStarted: Boolean read FNavigationDone;
    property PDFNavigationSucceeded: Boolean read FNavigationSucceeded;
    property TabbedPDFMode: Boolean read FTabbedPDFMode write FTabbedPDFMode;
    property SearchTerm: string read FSearchTerm write SetSearchTerm;
    property StartPage: Integer read FStartPage write FStartPage;
    property StandalonePDFMode: Boolean read FStandalonePDFMode write FStandalonePDFMode;
  end;
implementation

uses uPDFPortableAttachments;

type
  TEditDesignAccess = class(TCustomEdit);
  TComboDesignAccess = class(TCustomComboBox);

procedure SaveRecentPageCount(const AFileName: string; APageCount: Integer);
var
  Ini: TIniFile;
  Key, LowerName: string;
  Hash: UInt64;
  I: Integer;
begin
  if (APageCount <= 0) or not FileExists(AFileName) then Exit;
  Hash := UInt64($CBF29CE484222325);
  LowerName := LowerCase(AFileName);
  for I := 1 to Length(LowerName) do
    Hash := (Hash xor Ord(LowerName[I])) * UInt64($100000001B3);
  Key := IntToHex(Hash, 16);
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    Ini.WriteInteger('RecentPDFPageCount', Key, APageCount);
    Ini.WriteString('RecentPDFPageCount', Key + '_Stamp',
      IntToStr(FileAge(AFileName)));
  finally
    Ini.Free;
  end;
end;

function ToolbarHintBrowser(const ADeutsch, AEnglish: string): string;
begin
  if SameText(PDFLanguage, 'en') then Result := AEnglish
  else Result := ADeutsch;
end;


{$R *.dfm}

procedure SetSearchGlyph(AButton: TBitBtn; AAllPDFs: Boolean);
var
  B: TBitmap;
begin
  B := TBitmap.Create;
  try
    B.SetSize(22, 22);
    B.PixelFormat := pf24bit;
    B.Transparent := True;
    B.TransparentColor := clFuchsia;
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, 22, 22));
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := 2;
    B.Canvas.Brush.Style := bsClear;
    if AAllPDFs then
    begin
      // Zwei Dokumentseiten mit einer kleinen Lupe im Vordergrund.
      B.Canvas.Pen.Width := 1;
      B.Canvas.Rectangle(2, 2, 12, 15);
      B.Canvas.Rectangle(5, 5, 15, 18);
      B.Canvas.Pen.Width := 2;
      B.Canvas.Ellipse(11, 9, 18, 16);
      B.Canvas.MoveTo(17, 16);
      B.Canvas.LineTo(21, 20);
    end
    else
    begin
      B.Canvas.Ellipse(3, 2, 15, 14);
      B.Canvas.MoveTo(13, 13);
      B.Canvas.LineTo(20, 20);
    end;
    // Original-Bitmap ohne StretchDraw verwenden: scharfe, schwarze Linien.
    AButton.Glyph.Assign(B);
    AButton.NumGlyphs := 1;
    AButton.Layout := blGlyphTop;
    AButton.Margin := -1;
    AButton.Spacing := 0;
  finally
    B.Free;
  end;
end;

procedure SetAttachmentGlyph(AButton: TBitBtn; AHasAttachments: Boolean);
var
  B: TBitmap;
begin
  B := TBitmap.Create;
  try
    B.SetSize(22, 22);
    B.PixelFormat := pf24bit;
    B.Transparent := True;
    B.TransparentColor := clFuchsia;
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, 22, 22));
    B.Canvas.Brush.Style := bsClear;
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := 2;
    // Schwarz-weisse Bueroklammer, ohne Schriftzeichen oder Emoji.
    B.Canvas.MoveTo(8, 6);
    B.Canvas.LineTo(13, 2);
    B.Canvas.LineTo(18, 2);
    B.Canvas.LineTo(20, 5);
    B.Canvas.LineTo(20, 9);
    B.Canvas.LineTo(11, 19);
    B.Canvas.LineTo(7, 19);
    B.Canvas.LineTo(4, 16);
    B.Canvas.LineTo(4, 12);
    B.Canvas.LineTo(13, 4);
    B.Canvas.LineTo(16, 7);
    B.Canvas.LineTo(8, 15);
    if AHasAttachments then
    begin
      // Freigestelltes Sternchen: nicht mit den Linien der Klammer ueberlagern.
      B.Canvas.Brush.Style := bsSolid;
      B.Canvas.Brush.Color := clWhite;
      B.Canvas.Pen.Color := clWhite;
      B.Canvas.Rectangle(12, 0, 22, 11);
      B.Canvas.Pen.Color := clBlack;
      B.Canvas.Pen.Width := 2;
      B.Canvas.MoveTo(17, 1);
      B.Canvas.LineTo(17, 9);
      B.Canvas.MoveTo(13, 3);
      B.Canvas.LineTo(21, 7);
      B.Canvas.MoveTo(13, 7);
      B.Canvas.LineTo(21, 3);
    end;
    AButton.Glyph.Assign(B);
    AButton.NumGlyphs := 1;
    AButton.Margin := -1;
    AButton.Spacing := 0;
  finally
    B.Free;
  end;
end;

// Originalsymbol fuer Arbeitsbereiche (vom Benutzer bereitgestellte PNG-Datei),
// fest eingebettet: keine externe Bilddatei zur Laufzeit erforderlich.
procedure SetWorkspaceFolderIcon(AButton: TButton);
var
  Stream: TBytesStream;
  Png: TPngImage;
  Img: TImage;
begin
  Stream := TBytesStream.Create(TNetEncoding.Base64.DecodeStringToBytes('iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAAsTAAALEwEAmpwYAAAAeklEQVR4nO2V7QmAIBBA3+9arIRasj1aoC20PQyhQKhMzYMIHwjiB887OA8qCdjC48TlYiZV8EgVyAgUYAAN9BIC4xWRlhDYp0r9fAQKWHdRJyFI4VaQkueD6N80xAgs3mU3HyhAC0yBV7q95o1gjmgs7kw2Nrd7/YcNTKpn6azOZZ0AAAAASUVORK5CYII='));
  Png := TPngImage.Create;
  try
    Png.LoadFromStream(Stream);
    Img := TImage.Create(AButton);
    Img.Parent := AButton;
    Img.SetBounds((AButton.ClientWidth - 24) div 2,
      (AButton.ClientHeight - 24) div 2, 24, 24);
    Img.Picture.Assign(Png);
    Img.Stretch := False;
    Img.Proportional := True;
    Img.Center := True;
    Img.Transparent := True;
    Img.Enabled := False;
  finally
    Png.Free;
    Stream.Free;
  end;
end;

function TPDFBrowserForm.GlobalViewerReady: Boolean;
begin
  // Seitenzahl allein bedeutet noch nicht, dass der Viewer bereit ist.
  Result := not FClosing and FNavigationSucceeded and
    not FPendingFirstDisplay and (FPDFiumView <> nil) and
    FPDFiumView.FirstPageReady;
end;

function TPDFBrowserForm.GlobalPageCount: Integer;
begin
  Result := 0;
  if (FPDFiumView <> nil) and not FClosing then
    Result := FPDFiumView.GlobalPageCount;
end;

function TPDFBrowserForm.GlobalFindOnPage(const ATerm: string;
  APage: Integer): TArray<TPDFTextMatch>;
begin
  SetLength(Result, 0);
  if (FPDFiumView <> nil) and not FClosing then
    Result := FPDFiumView.GlobalFindOnPage(ATerm, APage);
end;

function TPDFBrowserForm.GlobalExcerpt(APage, AChar, ALength: Integer): string;
begin
  Result := '';
  if (FPDFiumView <> nil) and not FClosing then
    Result := FPDFiumView.GlobalExcerpt(APage, AChar, ALength);
end;

procedure TPDFBrowserForm.SetGlobalSearchCount(ACount: Integer);
begin
  FGlobalSearchActive := True;
  FGlobalSearchCount := ACount;
  UpdateSearchCount(Self);
end;

procedure TPDFBrowserForm.GlobalShowMatch(const ATerm: string;
  const AMatch: TPDFTextMatch);
begin
  if (FPDFiumView <> nil) and not FClosing then
  begin
    FPDFiumView.GlobalShowMatch(ATerm, AMatch);
    // Die globale Suche meldet keinen SearchCountChanged-Event.
    // Deshalb die X-Sichtbarkeit unmittelbar nach der Trefferwahl aktualisieren.
    UpdateSearchCount(FPDFiumView);
  end;
end;

destructor TPDFBackgroundLoad.Destroy;
begin
  if Thread <> nil then
  begin
    // Kein Queue/Synchronize: der Worker greift niemals auf VCL-Objekte zu.
    Thread.WaitFor;
    Thread.Free;
  end;
  Core.Free;
  inherited Destroy;
end;

destructor TPDFBrowserForm.Destroy;
begin
  // Der Worker benutzt ausschliesslich seinen eigenen Ladeauftrag.
  // Beim Schliessen muss er fertig sein, bevor dessen Speicher frei wird.
  FreeAndNil(FBackgroundLoad);
  // PDFium vor dem Zerstoeren des Formular-Handles freigeben.
  // Sonst koennen PDFium-Kindcontrols beim Aufraeumen einen bereits
  // ungueltigen Parent-Handle anfordern (EInvalidOperation).
  if FPDFiumView <> nil then
  begin
    FPDFiumView.OnSearchCountChanged := nil;
    FreeAndNil(FPDFiumView);
  end;
  inherited Destroy;
end;

procedure TPDFBrowserForm.FinishBackgroundLoad;
var
  Job: TPDFBackgroundLoad;
begin

  Job := FBackgroundLoad;
  if (Job = nil) or (TInterlocked.CompareExchange(Job.Finished, 0, 0) = 0) then Exit;
  FBackgroundLoad := nil;
  try
    if FClosing or (Job.FileName <> PDFFileName) then
    begin
      FPDFLoadInProgress := False;
      SetLoadingHint(False);
      Job.Free;
      Exit;
    end;
    if Job.PasswordRequired then
    begin
      // Kennwortdialog ausschliesslich im UI-Thread; alter OpenPDF-Pfad.
      FPDFiumView.OpenPDF(PDFFileName);
    end
    else if Job.ErrorText <> '' then
      raise EPDFiumViewer.Create(Job.ErrorText)
    else
    begin

      SetAttachmentIndicator(Job.Core.HasEmbeddedAttachments);
      FPDFiumView.OpenPDFPrepared(Job.Core);

    end;
    if FStartPage > 1 then
    begin
      FPDFiumView.ShowPage(FStartPage - 1);
    end;
    if FWorkspaceRestorePending then
    begin
      FPDFiumView.RestoreWorkspaceView(FWorkspaceZoom, FWorkspaceFit, FWorkspaceX, FWorkspaceY);
      FWorkspaceRestorePending := False;
    end;
    if FWorkspaceLayoutPending then
    begin
      FPDFiumView.RestoreWorkspaceLayout(FWorkspaceViewMode, FWorkspaceTwoPage,
        FWorkspaceContinuous, FWorkspaceSidebar);
      FWorkspaceLayoutPending := False;
    end;
    if Trim(FSearchTerm) <> '' then
    begin

      FPDFiumView.SearchText(FSearchTerm);

    end;
    // After the asynchronous PDF initialization, restore the thumbnail
    // preference for every newly opened PDF (including FreePDF64 launches).
    FPDFiumView.ApplySavedThumbnailsAfterLoad;
    // Seitenzahl erst nach erfolgreichem PDFium-Laden zwischenspeichern.
    // Die Startseite liest nur diesen Cache und oeffnet keine PDFs.
    if (FPDFiumView <> nil) and (FPDFiumView.GlobalPageCount > 0) and
       FileExists(PDFFileName) then
    begin
      SaveRecentPageCount(PDFFileName, FPDFiumView.GlobalPageCount);
    end;
    FNavigationDone := True;
    FNavigationSucceeded := True;
    FPendingFirstDisplay := True;
    TimerPDF.Enabled := True;
  except
    on E: EAbort do
    begin
      FLoadRequested := False;
      FNavigationDone := True;
      FNavigationSucceeded := False;
    end;
    on E: Exception do
    begin
      FLoadRequested := False;
      FNavigationDone := True;
      FNavigationSucceeded := False;
      PDFModernMessageDlg('PDFium konnte die PDF nicht öffnen: ' + E.Message,
        mtError, [mbOK], 0);
    end;
  end;
  SetLoadingHint(False);
  FPDFLoadInProgress := False;
  Job.Free;

end;

function TPDFBrowserForm.HasUnsavedPDFChanges: Boolean;
begin
  Result := (FPDFiumView <> nil) and FPDFiumView.HasUnsavedChanges;
end;

function TPDFBrowserForm.SaveUnsavedPDFChanges: Boolean;
begin
  Result := (FPDFiumView = nil) or FPDFiumView.SaveUnsavedChanges;
end;

function TPDFBrowserForm.WorkspaceViewMode: Integer;
begin
  Result := 1;
  if FWorkspaceLayoutPending then Result := FWorkspaceViewMode
  else if (FPDFiumView <> nil) and FNavigationSucceeded then
    Result := FPDFiumView.WorkspaceViewMode;
end;

function TPDFBrowserForm.WorkspaceTwoPage: Boolean;
begin
  Result := False;
  if FWorkspaceLayoutPending then Result := FWorkspaceTwoPage
  else if (FPDFiumView <> nil) and FNavigationSucceeded then
    Result := FPDFiumView.WorkspaceTwoPage;
end;

function TPDFBrowserForm.WorkspaceContinuous: Boolean;
begin
  Result := True;
  if FWorkspaceLayoutPending then Result := FWorkspaceContinuous
  else if (FPDFiumView <> nil) and FNavigationSucceeded then
    Result := FPDFiumView.WorkspaceContinuous;
end;

function TPDFBrowserForm.WorkspaceSidebarVisible: Boolean;
begin
  Result := False;
  if FWorkspaceLayoutPending then Result := FWorkspaceSidebar
  else if (FPDFiumView <> nil) and FNavigationSucceeded then
    Result := FPDFiumView.WorkspaceSidebarVisible;
end;

procedure TPDFBrowserForm.SetWorkspaceLayout(AViewMode: Integer;
  ATwoPage, AContinuous, ASidebar: Boolean);
begin
  FWorkspaceViewMode := AViewMode;
  FWorkspaceTwoPage := ATwoPage;
  FWorkspaceContinuous := AContinuous;
  FWorkspaceSidebar := ASidebar;
  FWorkspaceLayoutPending := True;
  if FNavigationSucceeded and (FPDFiumView <> nil) then
  begin
    FPDFiumView.RestoreWorkspaceLayout(AViewMode, ATwoPage, AContinuous, ASidebar);
    FWorkspaceLayoutPending := False;
  end;
end;

function TPDFBrowserForm.WorkspacePage: Integer;
begin
  Result := Max(1, FStartPage);
  if (FPDFiumView <> nil) and FNavigationSucceeded then
    Result := Max(1, FPDFiumView.PageIndex + 1);
end;

function TPDFBrowserForm.WorkspaceZoom: Double;
begin
  Result := 1.0;
  if FWorkspaceRestorePending then Result := FWorkspaceZoom
  else if (FPDFiumView <> nil) and FNavigationSucceeded then Result := FPDFiumView.WorkspaceZoom;
end;

function TPDFBrowserForm.WorkspaceFit: Boolean;
begin
  Result := True;
  if FWorkspaceRestorePending then Result := FWorkspaceFit
  else if (FPDFiumView <> nil) and FNavigationSucceeded then Result := FPDFiumView.WorkspaceFitMode;
end;

function TPDFBrowserForm.WorkspaceScrollX: Integer;
begin
  Result := 0;
  if FWorkspaceRestorePending then Result := FWorkspaceX
  else if (FPDFiumView <> nil) and FNavigationSucceeded then Result := FPDFiumView.WorkspaceScrollX;
end;

function TPDFBrowserForm.WorkspaceScrollY: Integer;
begin
  Result := 0;
  if FWorkspaceRestorePending then Result := FWorkspaceY
  else if (FPDFiumView <> nil) and FNavigationSucceeded then Result := FPDFiumView.WorkspaceScrollY;
end;

procedure TPDFBrowserForm.SetWorkspaceView(AZoom: Double; AFit: Boolean; AX, AY: Integer);
begin
  FWorkspaceZoom := AZoom;
  FWorkspaceFit := AFit;
  FWorkspaceX := AX;
  FWorkspaceY := AY;
  FWorkspaceRestorePending := True;
  if FNavigationSucceeded and (FPDFiumView <> nil) then
  begin
    FPDFiumView.RestoreWorkspaceView(FWorkspaceZoom, FWorkspaceFit, FWorkspaceX, FWorkspaceY);
    FWorkspaceRestorePending := False;
  end;
end;

procedure TPDFBrowserForm.ApplySplitSync(AZoom: Double; AApplyZoom: Boolean;
  AX, AY: Integer; AApplyScroll: Boolean);
var
  TargetZoom: Double;
  TargetFit: Boolean;
  TargetX, TargetY: Integer;
begin
  if not AApplyZoom and not AApplyScroll then Exit;
  TargetZoom := WorkspaceZoom;
  TargetFit := WorkspaceFit;
  TargetX := WorkspaceScrollX;
  TargetY := WorkspaceScrollY;
  if AApplyZoom then
  begin
    TargetZoom := AZoom;
    TargetFit := False;
  end;
  if AApplyScroll then
  begin
    TargetX := AX;
    TargetY := AY;
  end;
  SetWorkspaceView(TargetZoom, TargetFit, TargetX, TargetY);
end;

procedure TPDFBrowserForm.ZoomPDF(AIncrease: Boolean);
begin
  if FPDFiumView = nil then Exit;
  if AIncrease then FPDFiumView.ZoomIn
  else FPDFiumView.ZoomOut;
end;

procedure TPDFBrowserForm.ReloadCurrentPDF;
begin
  if FPDFiumView <> nil then
    FPDFiumView.ReloadCurrentPDF;
end;

procedure TPDFBrowserForm.RefreshLanguage;
begin
  TranslatePDFControls(Self);
  if FOpenPDFButton <> nil then
    FOpenPDFButton.Hint := ToolbarHintBrowser('PDF öffnen ... (Strg+O)', 'Open PDF... (Ctrl+O)');
  if FWorkspacesButton <> nil then
  begin
    FWorkspacesButton.Caption := '';
    FWorkspacesButton.Hint := ToolbarHintBrowser('LMB: Arbeitsbereiche verwalten ...' + sLineBreak + 'RMB: Arbeitsbereiche speichern ...', 'LMB: Manage workspaces ...' + sLineBreak + 'RMB: Save workspace ...');
  end;
  if FFindButton <> nil then
    FFindButton.Hint := ToolbarHintBrowser(
      'PDF-Text suchen (Strg+F) - Weitersuchen mit F3',
      'Search PDF text (Ctrl+F) - Find next with F3');
  if FGlobalFindButton <> nil then
    FGlobalFindButton.Hint := ToolbarHintBrowser(
      'Alle geöffneten PDF-Dokumente durchsuchen (Strg+Umschalt+F)',
      'Search all open PDF documents (Ctrl+Shift+F)');
  SetAttachmentIndicator(FHasPDFEmbeddedAttachments);
  if FPDFiumView <> nil then
    FPDFiumView.RefreshLanguage;
end;

procedure TPDFBrowserForm.ShowDocumentProperties;
begin
  if (FPDFiumView <> nil) and not FClosing then
    FPDFiumView.ShowDocumentProperties;
end;

procedure TPDFBrowserForm.RefitPDFOnTabActivation;
begin
  if (FPDFiumView <> nil) and FNavigationSucceeded then
    FPDFiumView.RefitOnTabActivation;
end;

procedure TPDFBrowserForm.RefreshPDFViewport;
begin
  if (FPDFiumView <> nil) and FNavigationSucceeded then
    FPDFiumView.RefreshPDFDisplay;
end;

procedure TPDFBrowserForm.SetFullScreenDisplay(AEnabled: Boolean);
begin
  if FToolbar <> nil then
    FToolbar.Visible := not AEnabled;
  if FPDFiumView <> nil then
    FPDFiumView.SetFullScreenDisplay(AEnabled);
end;

procedure TPDFBrowserForm.UpdateAttachmentWindowPosition;
const
  EdgeGap = 12;
  HeightPercent = 48;
var
  ViewRect, AttachmentRect: TRect;
  NewLeft, NewTop, NewHeight, NewWidth: Integer;
  ViewWidth, ViewHeight: Integer;
  PDFOrigin: TPoint;
begin
  if (AttachmentWindowHandle = 0) or not IsWindow(AttachmentWindowHandle) or
     not Assigned(FPDFiumView) then Exit;
  PDFOrigin := FPDFiumView.ClientToScreen(Point(0, 0));
  ViewRect := Rect(PDFOrigin.X, PDFOrigin.Y,
    PDFOrigin.X + FPDFiumView.ClientWidth,
    PDFOrigin.Y + FPDFiumView.ClientHeight);
  ViewWidth := ViewRect.Right - ViewRect.Left;
  ViewHeight := ViewRect.Bottom - ViewRect.Top;
  if (ViewWidth <= 2 * EdgeGap) or (ViewHeight <= 2 * EdgeGap) then
    Exit;

  if not GetWindowRect(AttachmentWindowHandle, AttachmentRect) then
    Exit;

  NewWidth := Min(AttachmentRect.Right - AttachmentRect.Left,
    ViewWidth - 2 * EdgeGap);
  // Anlagenfenster etwas hoeher positionieren; die TListBox behaelt
  // ihren nativen vertikalen Scrollbalken bei vielen Anlagen.
  NewTop := ViewRect.Top + EdgeGap + MulDiv(40, CurrentPPI, 96);
  NewHeight := Min((ViewHeight * HeightPercent) div 100,
    ViewRect.Bottom - NewTop - EdgeGap);
  // Bei kleinen PDF-Fenstern darf das Anlagenfenster nicht hinausragen.
  NewWidth := Max(1, NewWidth);
  NewHeight := Max(1, NewHeight);
  NewLeft := ViewRect.Left + EdgeGap;

  SetWindowPos(AttachmentWindowHandle, 0,
    NewLeft, NewTop, NewWidth, NewHeight,
    SWP_NOZORDER or SWP_NOACTIVATE);
end;

procedure TPDFBrowserForm.BuildNavigationToolbar;
var
  Dpi, Gap, XPos, ControlHeight, ToolbarHeight: Integer;
  function ScalePx(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Dpi, 96);
  end;
  procedure PlaceControl(C: TControl; DesiredWidth: Integer);
  var
    H: Integer;
  begin
    H := ControlHeight;
    // Beschriftungen auf die vertikale Mitte der Eingabefelder setzen.
    // TLabel.AutoSize laesst die Hoehe nicht wie bei einem TEdit strecken.
    // Eingabefelder und Auswahlliste an die Hoehe der Buttons angleichen.
    // Die Mindesthoehe wird mit der DPI skaliert.
    if (C = FFindButton) or (C = FGlobalFindButton) then
      H := Max(ScalePx(22), ControlHeight - ScalePx(4))
    else if (C = FAttachmentsButton) then
      H := ControlHeight;
    C.SetBounds(XPos, (ToolbarHeight - H) div 2, DesiredWidth, H);
    Inc(XPos, DesiredWidth + Gap);
  end;
begin
  Dpi := CurrentPPI;
  if Dpi < 96 then Dpi := 96;
  FToolbar := TPanel.Create(Self);
  FToolbar.Name := 'PDFNavigationToolbar';
  FToolbar.Caption := '';
  FToolbar.ParentFont := False;
  FToolbar.Font.Assign(Self.Font);
  FToolbar.Parent := Self;
  FToolbar.Align := alTop;
  FToolbar.Height := 42;
  FToolbar.BevelOuter := bvNone;
  FToolbar.DoubleBuffered := True;

  // Datei- und Arbeitsbereichsaktionen vor der Textsuche.
  FOpenPDFButton := TPDFDesignButton.Create(Self);
  FOpenPDFButton.Parent := FToolbar;
  FOpenPDFButton.Caption := '📂';
  FOpenPDFButton.Font.Name := 'Segoe UI Emoji';
  FOpenPDFButton.Width := ScalePx(32);
  FOpenPDFButton.Height := 28;
  FOpenPDFButton.Hint := ToolbarHintBrowser('PDF öffnen ... (Strg+O)', 'Open PDF... (Ctrl+O)');
  FOpenPDFButton.ShowHint := True;
  FOpenPDFButton.OnClick := OpenPDFToolbarClick;

  FWorkspacesButton := TPDFDesignButton.Create(Self);
  FWorkspacesButton.Parent := FToolbar;
  FWorkspacesButton.Caption := '';
  FWorkspacesButton.Width := ScalePx(34);
  FWorkspacesButton.Font.Name := 'Segoe UI Symbol';
  FWorkspacesButton.Font.Size := 12;
  FWorkspacesButton.Height := 28;
  FWorkspacesButton.Hint := ToolbarHintBrowser('LMB: Arbeitsbereiche verwalten ...' + sLineBreak + 'RMB: Arbeitsbereiche speichern ...', 'LMB: Manage workspaces ...' + sLineBreak + 'RMB: Save workspace ...');
  FWorkspacesButton.ShowHint := True;
  FWorkspacesButton.OnClick := OpenWorkspacesToolbarClick;
  FWorkspacesButton.OnMouseUp := WorkspacesToolbarMouseUp;
  SetWorkspaceFolderIcon(FWorkspacesButton);

  // --------------------------------------------------
  // Textsuche
  // --------------------------------------------------
  FFindButton := TPDFThemeBitBtn.Create(Self);
  FFindButton.Parent := FToolbar;
  FFindButton.Caption := '';
  SetSearchGlyph(FFindButton, False);
  FFindButton.ShowHint := True;
  FFindButton.Hint := ToolbarHintBrowser(
    'PDF-Text suchen (Strg+F) - Weitersuchen mit F3',
    'Search PDF text (Ctrl+F) - Find next with F3');
  FFindButton.Left := 178;
  FFindButton.Top := 6;
  FFindButton.Width := 94;
  FFindButton.Height := 28;
  FFindButton.OnClick := FindTermClick;

  FGlobalFindButton := TPDFThemeBitBtn.Create(Self);
  FGlobalFindButton.Parent := FToolbar;
  FGlobalFindButton.Caption := '';
  SetSearchGlyph(FGlobalFindButton, True);
  FGlobalFindButton.ShowHint := True;
  FGlobalFindButton.Hint := ToolbarHintBrowser(
    'Alle geöffneten PDF-Dokumente durchsuchen (Strg+Umschalt+F)',
    'Search all open PDF documents (Ctrl+Shift+F)');
  FGlobalFindButton.OnClick := GlobalFindClick;


  FSearchCountLabel := TLabel.Create(Self);
  FSearchCountLabel.Parent := FToolbar;
  FSearchCountLabel.AutoSize := False;
  FSearchCountLabel.Caption := Format(Tr('Text: %d Treffer'), [0]);
  FSearchCountLabel.Visible := True;
  // Schrift der urspruenglichen oberen Symbolleiste festhalten.
  // Beim Einbetten in die PDFium-Symbolleiste darf die Schrift
  // nicht vom neuen Parent verkleinert werden.
  FSearchCountLabel.ParentFont := False;
  FSearchCountLabel.Font.Assign(Self.Font);
  // Kompakte Trefferanzeige: etwas kleinere Schrift als die uebrige Leiste.
  FSearchCountLabel.Font.Size := 8;
  FSearchCountLabel.Font.Style := [fsBold];
  FSearchCountLabel.Font.Color := clWindowText;
  // TLabel hat bei AutoSize=False keine automatische Hoehenanpassung.
  // Die Texthoehe explizit festlegen, damit Reflow ihn mittig setzt.
  Canvas.Font.Assign(FSearchCountLabel.Font);
  FSearchCountLabel.Height := Canvas.TextHeight('Ag') + ScalePx(2);

  // --------------------------------------------------
  // PDF-Anlagen
  // --------------------------------------------------
  FAttachmentsButton := TPDFThemeBitBtn.Create(Self);
  FAttachmentsButton.Parent := FToolbar;
  FAttachmentsButton.Caption := '';
  SetAttachmentGlyph(FAttachmentsButton, False);
  FAttachmentsButton.ShowHint := True;
  FAttachmentsButton.Hint := ToolbarHintBrowser(
    'PDF-Anlagen anzeigen',
    'Show PDF attachments');
  FAttachmentsButton.Left := 278;
  FAttachmentsButton.Top := 6;
  FAttachmentsButton.Width := ScalePx(38);
  FAttachmentsButton.Height := 28;
  FAttachmentsButton.OnClick := ToggleAttachmentsClick;

  // Dezenter vertikaler Trennstrich zwischen Suche und PDF-Werkzeugen.
  FAttachmentSeparator := TBevel.Create(Self);
  FAttachmentSeparator.Parent := FToolbar;
  FAttachmentSeparator.Shape := bsLeftLine;
  FAttachmentSeparator.Width := ScalePx(2);
  FAttachmentSeparator.Height := 24;
  FAttachmentSeparator.Visible := False;

  // DPI-feste Anordnung: keine 96-DPI-Koordinaten fuer 4K/Skalierung.
  // Alle Breiten orientieren sich am tatsaechlich verwendeten Schriftbild.
  Gap := ScalePx(3);
  ControlHeight := Max(ScalePx(25), Canvas.TextHeight('Ag') + ScalePx(10));
  ToolbarHeight := ControlHeight + ScalePx(8);
  FToolbar.Height := ToolbarHeight;
  XPos := ScalePx(6);

  // Nur eine Textsuche in der oberen Viewer-Leiste.
  PlaceControl(FFindButton, ScalePx(34));
  PlaceControl(FGlobalFindButton, ScalePx(34));
  // Trefferanzeige direkt rechts neben 'Text suchen'.
  // Die Breite bleibt auch bei 0 Treffern reserviert, damit die
  // nachfolgenden Bedienelemente nicht hin- und herspringen.
  FSearchCountLabel.AutoSize := False;
  FSearchCountLabel.Layout := tlCenter;
  Canvas.Font.Assign(FSearchCountLabel.Font);
  FSearchCountLabel.SetBounds(XPos,
    (ToolbarHeight - ControlHeight) div 2,
    Max(ScalePx(70), Max(Canvas.TextWidth(FSearchCountLabel.Caption + '  ...'), Canvas.TextWidth(Tr('Alle PDFs: 99999 Treffer'))) + ScalePx(12)),
    ControlHeight);
  Inc(XPos, FSearchCountLabel.Width + Gap);
  FAttachmentSeparator.Visible := False;
  Inc(XPos, ScalePx(4));
  PlaceControl(FAttachmentsButton, ScalePx(34));

  // --------------------------------------------------
  // Navigationstimer - nur einmal erstellen
  // --------------------------------------------------
  FPageNavigationTimer := TTimer.Create(Self);
  FPageNavigationTimer.Enabled := False;
  FPageNavigationTimer.Interval := 180;
  FPageNavigationTimer.OnTimer := PageNavigationTimerTimer;

  // PDFium fuellt den verbleibenden Platz
  DoubleBuffered := True;

end;

procedure TPDFBrowserForm.NumberFieldMouseEnter(Sender: TObject);
var
  C: TWinControl;
begin
  // Der Pfad-Hint der Registerkarte darf nicht ueber den Zahlenfeldern
  // stehen bleiben. Er wird beim Ueberfahren des Tabs neu gesetzt.
  Application.CancelHint;
  C := Parent;
  while Assigned(C) do
  begin
    if C is TPageControl then
    begin
      C.Hint := '';
      Break;
    end;
    C := C.Parent;
  end;
end;

procedure TPDFBrowserForm.SetAttachmentIndicator(AHasAttachments: Boolean);
begin
  // Die Bueroklammer bleibt immer schwarz, unabhaengig von Anlagen.
  FHasPDFEmbeddedAttachments := AHasAttachments;
  if not Assigned(FAttachmentsButton) then Exit;
  FAttachmentsButton.Caption := '';
  SetAttachmentGlyph(FAttachmentsButton, AHasAttachments);
  FAttachmentsButton.Hint := ToolbarHintBrowser(
    'PDF-Anlagen anzeigen',
    'Show PDF attachments');
end;

procedure TPDFBrowserForm.ToggleAttachmentsClick(Sender: TObject);
var
  I: Integer;
begin
  if (AttachmentWindowHandle = 0) or
     not IsWindow(AttachmentWindowHandle) then
  begin
    // Anlagen erst beim Klick auslesen und das Fenster erzeugen.
    // Auch eine PDF ohne Anlagen erhaelt eine leere Anlagenliste.
    if (PDFFileName = '') or not FileExists(PDFFileName) then Exit;
    ShowPDFEmbeddedAttachments(PDFFileName, Self, FAttachmentsButton);
    if (AttachmentWindowHandle = 0) or
       not IsWindow(AttachmentWindowHandle) then Exit;
  end;

  // Vor dem Anzeigen auch ein bereits vorhandenes, ausgeblendetes Anlagenfenster
  // an die aktuelle Sprache anpassen.
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I].Handle = AttachmentWindowHandle then
    begin
      Screen.Forms[I].Caption := Tr('Eingebettete PDF-Anlagen');
      TranslatePDFControls(Screen.Forms[I]);
      Break;
    end;

  if IsWindowVisible(AttachmentWindowHandle) then
  begin
    // Beim Ausblenden den temporaeren Topmost-Status entfernen.
    ShowWindow(AttachmentWindowHandle, SW_HIDE);
    SetWindowPos(AttachmentWindowHandle, HWND_NOTOPMOST,
      0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  end
  else
  begin
    // Anlagenfenster anzeigen und aktivieren, damit Tastatureingaben
    // ohne einen zusaetzlichen Mausklick direkt dort ankommen.
    SetWindowPos(AttachmentWindowHandle, HWND_TOPMOST,
      0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
    UpdateAttachmentWindowPosition;
    SetForegroundWindow(AttachmentWindowHandle);
    Winapi.Windows.SetFocus(AttachmentWindowHandle);
  end;
end;


procedure TPDFBrowserForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN or WS_CLIPSIBLINGS;
end;

procedure TPDFBrowserForm.FormCreate(Sender: TObject);
var IniDat: TIniFile;
begin
  Position := poDesigned;
  FLoadRequested := False;
  FNavigationDone := False;
  FNavigationSucceeded := False;
  FPendingFirstDisplay := False;
  FClosing := False;
  FLoadingHintWnd := 0;
  FLoadingHintFont := 0;
  FTabbedPDFMode := False;
  FStandalonePDFMode := False;
  FStandaloneHintShown := False;
  AttachmentWindowHandle := 0;
  FStartPage := 1;
  FWorkspaceZoom := 1.0;
  FWorkspaceFit := True;
  FWorkspaceX := 0;
  FWorkspaceY := 0;
  FWorkspaceRestorePending := False;
  FSearchTerm := '';
  BuildNavigationToolbar;
  // Absicherung auch bei einer Form ohne geladenes DFM-Timerobjekt.
  if TimerPDF = nil then
  begin
    TimerPDF := TTimer.Create(Self);
    TimerPDF.Enabled := False;
    TimerPDF.OnTimer := TimerPDFTimer;
  end;
  TimerPDF.Interval := 35;
  TimerPDF.Enabled := False;
  // PDFium erst nach dem Einhaengen des Browserformulars in den Tab
  // erzeugen: sonst koennen Kindfenster ohne gueltiges Parent-HWND entstehen.
  FPDFiumView := nil;
  // Nicht blockierende, animierte Aktivitaetsanzeige unter der Werkzeugleiste.
  IniDat := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
  try
    Left := IniDat.ReadInteger('Position', 'PDFBrowserForm_Left', Left);
    Top := IniDat.ReadInteger('Position', 'PDFBrowserForm_Top', Top);
    Width := IniDat.ReadInteger('Position', 'PDFBrowserForm_Width', Width);
    Height := IniDat.ReadInteger('Position', 'PDFBrowserForm_Height', Height);
  finally IniDat.Free; end;
end;

procedure TPDFBrowserForm.SetLoadingHint(AVisible: Boolean);
var
  HintW, HintH, PPI: Integer;
  Pt: TPoint;
  OwnerWnd: HWND;
begin
  if not AVisible then
  begin
    if FLoadingHintWnd <> 0 then
    begin
      DestroyWindow(FLoadingHintWnd);
      FLoadingHintWnd := 0;
    end;
    if FLoadingHintFont <> 0 then
    begin
      DeleteObject(FLoadingHintFont);
      FLoadingHintFont := 0;
    end;
    Exit;
  end;
  if FClosing or (csDestroying in ComponentState) or not HandleAllocated then Exit;
  if FLoadingHintWnd <> 0 then Exit;

  PPI := CurrentPPI;
  HintW := MulDiv(230, PPI, 96);
  HintH := MulDiv(54, PPI, 96);
  Pt := ClientToScreen(Point((ClientWidth - HintW) div 2,
    (ClientHeight - HintH) div 2));
  // Eigenes, nicht aktivierendes Popup-Fenster. Es ist kein Kindfenster
  // des PDF-Viewers und kann daher nicht von diesem verdeckt werden.
  OwnerWnd := GetAncestor(Handle, GA_ROOT);
  FLoadingHintWnd := CreateWindowEx(WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE,
    'STATIC', 'PDF wird geöffnet ...', WS_POPUP or WS_BORDER or
    SS_CENTER or SS_CENTERIMAGE, Pt.X, Pt.Y, HintW, HintH,
    OwnerWnd, 0, HInstance, nil);
  if FLoadingHintWnd = 0 then Exit;
  FLoadingHintStartTick := GetTickCount64;
  FLoadingHintFont := CreateFont(-MulDiv(10, PPI, 72), 0, 0, 0,
    FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
    CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE,
    'Segoe UI');
  if FLoadingHintFont <> 0 then
    SendMessage(FLoadingHintWnd, WM_SETFONT, WPARAM(FLoadingHintFont), 0);
  // Kein HWND_TOPMOST: sonst kann das Popup einen modalen
  // Kennwortdialog verdecken. Das Fenster bleibt dem Hauptfenster
  // zugeordnet und wird nur innerhalb dessen Fenstergruppe angehoben.
  SetWindowPos(FLoadingHintWnd, HWND_TOP, Pt.X, Pt.Y, HintW, HintH,
    SWP_NOACTIVATE or SWP_SHOWWINDOW);
  UpdateWindow(FLoadingHintWnd);
end;

procedure TPDFBrowserForm.HideLoadingHintForInactiveTab;
begin
  // Das Lade-Popup ist ein eigenes WS_POPUP und wird durch einen
  // TPageControl-Tabwechsel nicht automatisch ausgeblendet.
  SetLoadingHint(False);
end;

procedure TPDFBrowserForm.RequestPDFLoad;
begin
  if FClosing or (csDestroying in ComponentState) then Exit;
  // Nach Abbruch/Fehler nicht durch Tabwechsel oder Timer erneut laden.
  // Ein explizites OpenSavedPDF setzt FNavigationDone wieder zurueck.
  if FNavigationDone and not FNavigationSucceeded then Exit;
  FLoadRequested := True;
  // Auch bei einer sehr fruehen Ladeanforderung keinen nil-Timer verwenden.
  if TimerPDF = nil then
  begin
    TimerPDF := TTimer.Create(Self);
    TimerPDF.Enabled := False;
    TimerPDF.OnTimer := TimerPDFTimer;
  end;
  TimerPDF.Interval := 35;
  // PDFium nicht synchron aus AddPDF/OnShow starten: zuerst muss die
  // VCL die Hauptfenster- und Werkzeugleisten-Paint-Nachrichten abarbeiten.
  // Der kurze 35-ms-Timer startet das Laden im naechsten UI-Durchlauf.
  TimerPDF.Enabled := False;
  TimerPDF.Enabled := True;
end;

procedure TPDFBrowserForm.RequestPDFLoadFast;
begin
  // Beim aktiven Tabwechsel ist die VCL-Tabumschaltung bereits erfolgt.
  // Die kurze Wartezeit des normalen Erststarts ist hier unnoetig.
  // Das Laden selbst bleibt asynchron; keine Blockade des UI-Threads.
  RequestPDFLoad;
  if FLoadRequested and TimerPDF.Enabled then
  begin
    TimerPDF.Enabled := False;
    TimerPDF.Interval := 20;
    TimerPDF.Enabled := True;
  end;
end;

procedure TPDFBrowserForm.RefreshActiveTabPDF;
var
  LoadJob: TPDFBackgroundLoad;
begin
  if FClosing or (FPDFiumView = nil) then Exit;
  if FPDFLoadInProgress then
  begin
    FinishBackgroundLoad;
    Exit;
  end;
  if not FLoadRequested then Exit;
  // Popups nie ueber einem anderen aktiven PDF-Tab stehen lassen.
  if (Parent is TTabSheet) and
     (TTabSheet(Parent).PageControl.ActivePage <> TTabSheet(Parent)) then
  begin
    SetLoadingHint(False);
    TimerPDF.Enabled := False;
    Exit;
  end;
  if FNavigationDone and FNavigationSucceeded then
  begin
    // Erste Seite nach dem Layout aktualisieren.
    if FPDFiumView.FirstPageReady and
       (not FPendingFirstDisplay) then
    begin
      FPDFiumView.Update;
      SetLoadingHint(False);
    end;
    // Erste Darstellung nach dem endgueltigen Layout des TabSheets.
    if FPendingFirstDisplay and Visible and (ClientWidth >= 50) and
       (ClientHeight >= 50) then
    begin

      FPDFiumView.RefreshPDFDisplay;

      FPendingFirstDisplay := False;
    end;
    TimerPDF.Enabled := FPendingFirstDisplay or
      (not FPDFiumView.FirstPageReady);
    Exit;
  end;
  if not Visible or (ClientWidth < 50) or (ClientHeight < 50) then Exit;
  // Sicherstellen, dass der PDFium-Bereich nicht durch das Einbetten
  // unsichtbar oder mit veralteten Abmessungen zurueckbleibt.
  if (FPDFiumView.Parent <> Self) then FPDFiumView.Parent := Self;
  FPDFiumView.Align := alClient;
  FPDFiumView.Visible := True;
  FPDFiumView.BringToFront;
  if (Parent is TTabSheet) and
     (TTabSheet(Parent).PageControl.ActivePage <> TTabSheet(Parent)) then Exit;
  // Hinweis sofort zeichnen, ohne zusaetzlichen Timer-Tick.
  // Keine Application.ProcessMessages: keine rekursiven Ladeaufrufe.
  // Ein modaler Kennwortdialog verarbeitet weiterhin Windows-Nachrichten.
  // Den Ladetimer deshalb vor dem Oeffnen deaktivieren und Rekursion sperren.
  FPDFLoadInProgress := True;
  TimerPDF.Enabled := False;
  // Bereits ausstehende Paint-Nachrichten gezielt abarbeiten, ohne
  // Hauptfenster, Registerkarten und Symbolleisten erneut zu invalidieren.
  // RDW_ALLCHILDREN/UPDATENOW verursachte beim Oeffnen grosser PDFs
  // sichtbare Vollfenster-Neuzeichnungen (Zittern der oberen Leisten).
  // Kein Realign und kein Application.ProcessMessages im Ladepfad.
  if HandleAllocated then
  begin
    if (FToolbar <> nil) and FToolbar.HandleAllocated then
      UpdateWindow(FToolbar.Handle);
    UpdateWindow(Handle);
  end;
  // Sichtbarer, mittiger Hinweis vor dem synchronen PDFium-Aufruf.
  SetLoadingHint(True);
  // PDFium-Datei und Seitenanzahl werden ohne VCL-Zugriffe geladen.
  // Die Uebernahme und der Aufbau der sichtbaren Seiten erfolgen im UI-Thread.

  SetAttachmentIndicator(False);
  FBackgroundLoad := TPDFBackgroundLoad.Create;
  FBackgroundLoad.FileName := PDFFileName;
  LoadJob := FBackgroundLoad;
  FBackgroundLoad.Thread := TThread.CreateAnonymousThread(
    procedure
    var
      Job: TPDFBackgroundLoad;
    begin
      Job := LoadJob;
      try
        Job.Core := TFreePDF64PDFiumCore.Create;

        Job.Core.OpenFile(Job.FileName);

      except
        on E: EPDFiumPasswordRequired do Job.PasswordRequired := True;
        on E: Exception do Job.ErrorText := E.Message;
      end;

      TInterlocked.Exchange(Job.Finished, 1);
    end);
  FBackgroundLoad.Thread.FreeOnTerminate := False;
  try
    FBackgroundLoad.Thread.Start;
  except
    FPDFLoadInProgress := False;
    SetLoadingHint(False);
    FreeAndNil(FBackgroundLoad);
    raise;
  end;
  TimerPDF.Enabled := True;
end;

procedure TPDFBrowserForm.OpenSavedPDF(const AFileName: string;
  AHasAttachments: Boolean);
begin
  if FClosing or not FileExists(AFileName) then Exit;
  FreeAndNil(FBackgroundLoad);
  FPDFLoadInProgress := False;
  PDFFileName := AFileName;
  Caption := AFileName;
  FStartPage := 1;
  FNavigationDone := False;
  FNavigationSucceeded := False;
  FLoadRequested := True;
  SetAttachmentIndicator(AHasAttachments);
  RequestPDFLoad;
end;

procedure TPDFBrowserForm.PageNavigationTimerTimer(Sender: TObject);
begin
  FPageNavigationTimer.Enabled := False;
  RefreshActiveTabPDF;
end;

procedure TPDFBrowserForm.SetSearchTerm(const AValue: string);
begin
  FSearchTerm := AValue;
  // Auch bei bereits geoeffneten PDFs die Suche sofort aktualisieren.
  if (FPDFiumView <> nil) and FNavigationSucceeded then
    FPDFiumView.SearchText(FSearchTerm);
end;

procedure TPDFBrowserForm.NextPDFSearchMatch(ADirection: Integer);
begin
  if (FPDFiumView <> nil) and FNavigationSucceeded then
    FPDFiumView.NextSearchMatch(ADirection);
end;

function TPDFBrowserForm.HasPDFSearchHighlights: Boolean;
begin
  Result := (FPDFiumView <> nil) and FPDFiumView.HasSearchHighlights;
end;

procedure TPDFBrowserForm.ClearPDFSearchHighlights;
begin
  FSearchTerm := '';
  FGlobalSearchActive := False;
  if FPDFiumView <> nil then
    FPDFiumView.SearchText('');
  UpdateSearchCount(Self);
end;

procedure TPDFBrowserForm.PDFPageClickClearSearch(Sender: TObject);
begin
  if (FPDFiumView <> nil) and
     (FGlobalSearchActive or FPDFiumView.HasSearchHighlights) then
    ClearPDFSearchHighlights;
end;

procedure TPDFBrowserForm.ShowPDFSearch;
begin
  FindTermClick(nil);
end;

procedure TPDFBrowserForm.UpdateSearchCount(Sender: TObject);
begin
  if (FSearchCountLabel = nil) or (FPDFiumView = nil) then Exit;
  // Die Trefferzahl bleibt auch bei 0 Treffern und ohne aktive Suche sichtbar.
  FSearchCountLabel.Visible := True;
  if FGlobalSearchActive then
    FSearchCountLabel.Caption := Format(Tr('Alle PDFs: %d Treffer'),
      [FGlobalSearchCount])
  else
  begin
    FSearchCountLabel.Caption := Format(Tr('Text: %d Treffer'),
      [FPDFiumView.SearchMatchCount]);
    if FPDFiumView.SearchRunning then
      FSearchCountLabel.Caption := FSearchCountLabel.Caption + '  ...';
  end;
end;

procedure TPDFBrowserForm.FindTermClick(Sender: TObject);
begin
  FGlobalSearchActive := False;
  UpdateSearchCount(Self);
  if FPDFiumView <> nil then FPDFiumView.ShowSearchDialog;
end;

procedure TPDFBrowserForm.MarkerClick(Sender: TObject);
begin
  if FPDFiumView <> nil then FPDFiumView.ToggleMarker;
end;

procedure TPDFBrowserForm.FormShow(Sender: TObject);
begin
  // FormShow wird erst nach dem Einhaengen in den Tab aufgerufen.
  // Das Parent-HWND muss vor der PDFium-Kindfenstererzeugung existieren.
  if FPDFiumView = nil then
  begin
    if Parent <> nil then Parent.HandleNeeded;
    HandleNeeded;
    FPDFiumView := TFreePDF64PDFiumView.CreateInParent(Self, Self);
    FPDFiumView.Align := alClient;
    FPDFiumView.OnSearchCountChanged := UpdateSearchCount;
    FPDFiumView.OnPDFPageClick := PDFPageClickClearSearch;
    UpdateSearchCount(FPDFiumView);
    FPDFiumView.BringToFront;
    FPDFiumView.PlaceEditButton(FToolbar,
      MulDiv(8, CurrentPPI, 96),
      MulDiv(6, CurrentPPI, 96), MulDiv(28, CurrentPPI, 96));
    FToolbarDesignApplied := False; // Neue Steuerelemente einmalig initialisieren.
    // Bei Lazy Loading existierte die PDFium-Symbolleiste beim ersten
    // Designaufruf noch nicht. Nach dem Erzeugen nachfaerben.
    ApplyToolbarDesign(FToolbarDesignIndex);
  end;
  // Beide Symbolleisten bei ausreichender Breite in einer Zeile anordnen.
  UpdateUnifiedToolbar;
  ReflowNavigationToolbar;
  Caption := PDFFileName;
  // Auch eingebettete PDF-Formulare muessen beim ersten Anzeigen laden.
  // Der Tab-Manager darf nicht der einzige Ausloeser sein.
  if not FNavigationDone then
    FLoadRequested := True;
  if FPDFiumView <> nil then
  begin
    FPDFiumView.Align := alClient;
    FPDFiumView.Visible := True;
    FPDFiumView.BringToFront;
  end;
  // Kein synchroner PDFium-Aufruf aus OnShow: zuerst muessen die
  // Symbolleisten und das neue TabSheet von Windows gezeichnet werden.
  TimerPDF.Enabled := False;
  TimerPDF.Enabled := True;
end;

procedure TPDFBrowserForm.TimerPDFTimer(Sender: TObject);
begin

  RefreshActiveTabPDF;
  // Das Lade-Popup ist ein eigenständiges Windows-Fenster. Bei einem
  // Tabwechsel darf es niemals über der Willkommensseite stehen bleiben.
  if (not Visible) or ((Parent is TTabSheet) and
     (TTabSheet(Parent).PageControl.ActivePage <> TTabSheet(Parent))) then
  begin
    SetLoadingHint(False);
    TimerPDF.Enabled := False;
    Exit;
  end;
  // Keine erneute Toolbar-Positionierung waehrend des PDF-Ladens.
  // Das Layout wurde bereits in FormShow einmalig fixiert.
  if FNavigationSucceeded and (FPDFiumView <> nil) and
     FPDFiumView.FirstPageReady and (not FPendingFirstDisplay) then
  begin
    // Den fertigen Seiteninhalt vor dem Entfernen des Popups zeichnen.
    FPDFiumView.Update;
    SetLoadingHint(False);
  end
  else if FNavigationSucceeded and (FPDFiumView <> nil) and
          (not FPDFiumView.FirstPageReady) then
    TimerPDF.Enabled := True;
end;

procedure TPDFBrowserForm.GlobalFindClick(Sender: TObject);
begin
  if Assigned(OnGlobalSearch) then
    OnGlobalSearch(Self);
end;

procedure TPDFBrowserForm.OpenPDFToolbarClick(Sender: TObject);
begin
  if Assigned(OnOpenPDF) then OnOpenPDF(Self);
end;

procedure TPDFBrowserForm.WorkspacesToolbarMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbRight) and Assigned(OnSaveWorkspace) then
    OnSaveWorkspace(Self);
end;

procedure TPDFBrowserForm.OpenWorkspacesToolbarClick(Sender: TObject);
begin
  if Assigned(OnOpenWorkspaces) then OnOpenWorkspaces(Self);
end;

procedure TPDFBrowserForm.ReflowNavigationToolbar;
var
  I, X, Y, Gap, Margin, RowHeight, RowGap, Required, NewHeight: Integer;
  EditButton: TControl;
  C: TControl;
  OutlineSeparator: TPanel;
  function ScalePx(N: Integer): Integer;
  begin
    Result := MulDiv(N, CurrentPPI, 96);
  end;
  procedure NewRow;
  begin
    X := Margin;
    Inc(Y, RowHeight + RowGap);
  end;
  procedure Reserve(AWidth: Integer);
  begin
    if (X > Margin) and (X + AWidth > FToolbar.ClientWidth - Margin) then
      NewRow;
  end;
  procedure Put(AControl: TControl);
  var
    ImageIndex: Integer;
    IconImage: TImage;
  begin
    if AControl = nil then Exit;
    Reserve(AControl.Width);
    // Labels anhand ihrer tatsaechlichen Schriftmetriken ausrichten.
    if AControl is TLabel then
    begin
      TLabel(AControl).AutoSize := False;
      TLabel(AControl).Layout := tlCenter;
      AControl.Height := RowHeight;
    end;
    AControl.SetBounds(X, Y + (RowHeight - AControl.Height) div 2,
      AControl.Width, AControl.Height);
    // Original-PNGs ohne Interpolation mittig halten.
    // TImage-Kinder nach jedem DPI-/Parent-/Layoutwechsel neu zentrieren.
    // Insbesondere Arbeitsbereiche und Drehen besitzen eigene PNG-Bilder.
    if AControl is TWinControl then
    begin
      for ImageIndex := 0 to TWinControl(AControl).ControlCount - 1 do
        if TWinControl(AControl).Controls[ImageIndex] is TImage then
        begin
          IconImage := TImage(TWinControl(AControl).Controls[ImageIndex]);
          IconImage.Proportional := True;
          IconImage.Stretch := True;
          IconImage.SetBounds((TWinControl(AControl).ClientWidth - ScalePx(22)) div 2,
            (TWinControl(AControl).ClientHeight - ScalePx(22)) div 2,
            ScalePx(22), ScalePx(22));
        end;
    end;
    Inc(X, AControl.Width + Gap);
  end;
begin
  // Die Symbolleiste erst bei endgueltiger Breite einmalig ausrichten.
  // Beim Erzeugen eines PDF-Tabs hat das Formular kurz eine schmale
  // Zwischenbreite; dort duerfen die rechten Buttons nicht umbrechen.
  if FToolbarLayoutLocked then Exit;
  if FToolbar = nil then Exit;
  if FToolbar.ClientWidth <= 0 then Exit;
  // Owner-Suche statt Control-Suche: Im Einzeilenmodus liegen diese
  // Controls im gemeinsamen PDFium-Panel und nicht mehr in FToolbar.
  if FPDFiumView <> nil then EditButton := FPDFiumView.EditToggleButton
  else EditButton := nil;

  Margin := ScalePx(4);
  Gap := ScalePx(2);
  RowGap := ScalePx(3);
  RowHeight := ScalePx(32);
  for I := 0 to FToolbar.ControlCount - 1 do
    if FToolbar.Controls[I].Visible and
       (FToolbar.Controls[I].Height > RowHeight) then
      RowHeight := FToolbar.Controls[I].Height;
  // Einheitliche Metrik in beiden Modi: die PDFium-Leiste ist die
  // Referenz. Keine Groessen-/Schriftaenderung beim Parent-Wechsel.
  // Die DPI-Skalierung erfolgt genau einmal ueber CurrentPPI.
  if (FPDFiumView <> nil) and (FPDFiumView.ToolbarPanel <> nil) then
  begin
    // Die Schrift aller Texte und Zahlen aus der PDFium-Leiste beziehen.
    FToolbar.ParentFont := False;
    FToolbar.Font.Assign(FPDFiumView.Font);
    for I := 0 to FToolbar.ControlCount - 1 do
    begin
      C := FToolbar.Controls[I];
      if C is TLabel then
      begin
        TLabel(C).ParentFont := False;
        TLabel(C).Font.Assign(FPDFiumView.Font);
        if C = FSearchCountLabel then
        begin
          TLabel(C).Font.Size := 8;
          TLabel(C).Font.Style := [fsBold];
        end;
      end
      else if C is TEdit then
      begin
        TEdit(C).ParentFont := False;
        TEdit(C).Font.Assign(FPDFiumView.Font);
      end
      else if C is TComboBox then
      begin
        TComboBox(C).ParentFont := False;
        TComboBox(C).Font.Assign(FPDFiumView.Font);
      end;
    end;
    // Dieselben Schaltflaechenhoehen wie rechts, unabhaengig von alTop/alLeft.
    RowHeight := Max(RowHeight, ScalePx(24));
    for I := 0 to FToolbar.ControlCount - 1 do
    begin
      C := FToolbar.Controls[I];
      // Der Werkzeuge-Button hat in beiden Layoutmodi feste DPI-Masse.
      // Nicht durch die allgemeine TBitBtn-Hoehenkorrektur veraendern.
      if C.Name = 'PDFEditToggleButton' then
        C.SetBounds(C.Left, C.Top, ScalePx(34), ScalePx(28))
      else if C is TPDFDesignButton then
        Continue // Design erfolgt in ApplyToolbarDesign, nicht im Layout
      else if C is TButton then
        C.Height := ScalePx(24)
      else if C is TBitBtn then
        C.Height := ScalePx(28);
    end;
  end;
  // Einheitliche, DPI-abhaengige Hoehe der Symbol-Buttons.
  // Keine Veraenderung der Glyph-Groessen oder Schrift beim Umschalten.
  for I := 0 to FToolbar.ControlCount - 1 do
  begin
    C := FToolbar.Controls[I];
    if C.Name = 'PDFEditToggleButton' then
      C.SetBounds(C.Left, C.Top, ScalePx(34), ScalePx(28))
    else if (C is TButton) or (C is TBitBtn) then
      C.Height := ScalePx(28);
  end;
  // Breite der tatsaechlich verwendeten Controls einschliesslich
  // Abstaenden pruefen, bevor irgendein SetBounds erfolgt.
  if (FPDFiumView <> nil) and (FToolbar.Parent = FPDFiumView.ToolbarPanel) then
    Required := 2 * Margin + 8 * Gap + ScalePx(22)
  else
    Required := 2 * Margin + 16 * Gap + ScalePx(22);
  if (FExternalSplitButton <> nil) and (FExternalSplitButton.Parent = FToolbar) and FExternalSplitButton.Visible then
    Inc(Required, FExternalSplitButton.Width + Gap);
  if FOpenPDFButton <> nil then Inc(Required, FOpenPDFButton.Width);
  if FWorkspacesButton <> nil then Inc(Required, FWorkspacesButton.Width);
  if FFindButton <> nil then Inc(Required, FFindButton.Width);
  if FGlobalFindButton <> nil then Inc(Required, FGlobalFindButton.Width);
  if FSearchCountLabel <> nil then Inc(Required, FSearchCountLabel.Width);
  if (FAttachmentsButton <> nil) and (FAttachmentsButton.Parent = FToolbar) then
    Inc(Required, FAttachmentsButton.Width);
  if (FAttachmentSeparator <> nil) and FAttachmentSeparator.Visible and
     (FAttachmentSeparator.Parent = FToolbar) then Inc(Required, ScalePx(12));
  if (EditButton <> nil) and (EditButton.Parent = FToolbar) then
  begin
    // Auch beim erneuten Layout keine alte Mindestbreite von 52 px anwenden.
    EditButton.SetBounds(EditButton.Left, EditButton.Top,
      ScalePx(34), ScalePx(28));
    Inc(Required, EditButton.Width);
  end;
  // Bei einer neu eingeblendeten Teilungsschaltflaeche darf die alte
  // Geometrie nicht stehenbleiben: sie wuerde den Oeffnen-Button ueberdecken.
  if FToolbar.ClientWidth < Required then
  begin
    if FToolbar.Parent <> Self then
      FToolbar.Width := Required + ScalePx(8);
    if FToolbar.ClientWidth < Required then Exit;
  end;
  X := Margin;
  // Platz fuer den Miniaturansicht-Button im gemeinsamen linken Panel.
  if (FPDFiumView <> nil) and (FToolbar.Parent = FPDFiumView.ToolbarPanel) then
    Inc(X, ScalePx(48));
  // In der gemeinsamen Leiste dieselbe vertikale Mitte wie die PDFium-Buttons.
  // Das alLeft-Panel erbt seine Hoehe vom PDFium-Toolbar-Container.
  if (FPDFiumView <> nil) and (FToolbar.Parent = FPDFiumView.ToolbarPanel) then
    Y := Max(0, (FToolbar.ClientHeight - RowHeight) div 2)
  else
    Y := 0;
  if (FExternalSplitButton <> nil) and (FExternalSplitButton.Parent = FToolbar) and FExternalSplitButton.Visible then
    Put(FExternalSplitButton);
  Put(FOpenPDFButton);
  Put(FWorkspacesButton);
  Inc(X, ScalePx(8));
  Put(FFindButton);
  Put(FGlobalFindButton);
  // Auch bei unsichtbarer Trefferanzeige den Platz beibehalten.
  Put(FSearchCountLabel);
  if FAttachmentSeparator <> nil then
    FAttachmentSeparator.Visible := False;
  if FAttachmentsButton.Parent = FToolbar then
    Inc(X, ScalePx(2));
  if FAttachmentsButton.Parent = FToolbar then
    Put(FAttachmentsButton);
  // Markierungswerkzeuge im zweizeiligen Layout ebenfalls platzieren.
  if (EditButton <> nil) and (EditButton.Parent = FToolbar) then
    Put(EditButton);
  NewHeight := Y + RowHeight + ScalePx(1);
  // Nach Parent-Wechseln die Textzeile mit ihrer echten Font-Hoehe
  // zentrieren (statt die alte Label-Hoehe beizubehalten).
  if FSearchCountLabel <> nil then
  begin
    FSearchCountLabel.AutoSize := False;
    FSearchCountLabel.Layout := tlCenter;
    FSearchCountLabel.Height := RowHeight;
    FSearchCountLabel.Top := Y;
  end;
  // Im zusammengefassten Modus ist die PDFium-Leiste der Hoehengeber.
  // Die linke Leiste darf deren Hoehe nicht eigenstaendig verkleinern.
  if FToolbar.Parent = Self then
  begin
    if FToolbar.Height <> NewHeight then FToolbar.Height := NewHeight;
  end;
  // Nach jedem Reflow den Trenner im tatsaechlichen Browser-Panel
  // wiederherstellen. Beim Wechsel alTop/alLeft kann das PDFium-Layout
  // vor dem abschliessenden Browser-Reflow ausgefuehrt worden sein.
  if FPDFiumView <> nil then
  begin
    OutlineSeparator := TPanel(FPDFiumView.FindComponent('PDFOutlineToolbarSeparator'));
    if OutlineSeparator <> nil then
    begin
      if FToolbar.Parent = FPDFiumView.ToolbarPanel then
      begin
        if OutlineSeparator.Parent <> FToolbar then
          OutlineSeparator.Parent := FToolbar;
        OutlineSeparator.SetBounds(ScalePx(44),
          Max(0, (FToolbar.ClientHeight - ScalePx(24)) div 2) + ScalePx(2),
          Max(1, ScalePx(1)), ScalePx(20));
        OutlineSeparator.Visible := True;
        OutlineSeparator.BringToFront;
        FToolbar.Invalidate;
      end
      else
        OutlineSeparator.Visible := False;
    end;
  end;
  FToolbarLayoutLocked := True;
end;

procedure TPDFBrowserForm.PlaceSplitButton(AButton: TButton; AVisible: Boolean);
var
  I, ButtonLeft, ButtonTop: Integer;
  C: TControl;
  ToolbarPanel: TWinControl;
  function Px(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, CurrentPPI, 96);
  end;
  procedure SaveAndHide(AControl: TControl);
  var
    L: Integer;
  begin
    if (AControl = nil) or (AControl = AButton) or not AControl.Visible then Exit;
    L := Length(FSplitToolbarStates);
    SetLength(FSplitToolbarStates, L + 1);
    FSplitToolbarStates[L].Control := AControl;
    FSplitToolbarStates[L].WasVisible := True;
    AControl.Visible := False;
  end;
begin
  if FToolbar = nil then Exit;

  if AButton <> nil then
  begin
    FExternalSplitButton := AButton;
    if AButton.Parent <> FToolbar then
      AButton.Parent := FToolbar;
  end
  else
    AButton := FExternalSplitButton;

  ToolbarPanel := nil;
  if FPDFiumView <> nil then
    ToolbarPanel := FPDFiumView.ToolbarPanel;

  if AVisible and (AButton <> nil) then
  begin
    if not FSplitToolbarIsolated then
    begin
      SetLength(FSplitToolbarStates, 0);
      FSplitToolbarPanel := nil;
      FSplitToolbarPanelWasVisible := False;

      // Alle anderen Buttons der oberen Symbolleiste ausblenden.
      for I := 0 to FToolbar.ControlCount - 1 do
        SaveAndHide(FToolbar.Controls[I]);

      // Bei getrennter Darstellung auch die komplette untere PDFium-Leiste
      // ausblenden. Bei zusammengefuehrter Darstellung nur deren Controls
      // neben der oberen Leiste ausblenden.
      if ToolbarPanel <> nil then
      begin
        if FToolbar.Parent = ToolbarPanel then
        begin
          for I := 0 to ToolbarPanel.ControlCount - 1 do
          begin
            C := ToolbarPanel.Controls[I];
            if C <> FToolbar then
              SaveAndHide(C);
          end;
        end
        else
        begin
          FSplitToolbarPanel := ToolbarPanel;
          FSplitToolbarPanelWasVisible := ToolbarPanel.Visible;
          ToolbarPanel.Visible := False;
        end;
      end;

      FSplitToolbarIsolated := True;
      FSplitButtonOriginalWidth := AButton.Width;
      FSplitButtonOriginalHeight := AButton.Height;
    end;

    // Die Teilungsschaltflaeche bleibt als einziges sichtbares Symbol.
    AButton.Visible := True;
    AButton.Width := Px(56);
    AButton.Height := Max(Px(24), FSplitButtonOriginalHeight);
    ButtonLeft := Px(4);
    ButtonTop := Max(0, (FToolbar.ClientHeight - AButton.Height) div 2);
    AButton.SetBounds(ButtonLeft, ButtonTop, AButton.Width, AButton.Height);
    AButton.BringToFront;
    FToolbarLayoutLocked := True;
    FToolbar.Invalidate;
    if ToolbarPanel <> nil then
      ToolbarPanel.Invalidate;
    Exit;
  end;

  // Keine Doppelmarkierung mehr: urspruengliche Symbolleisten exakt
  // wiederherstellen, einschliesslich zuvor unsichtbarer Controls.
  if FSplitToolbarIsolated then
  begin
    for I := 0 to High(FSplitToolbarStates) do
    begin
      C := FSplitToolbarStates[I].Control;
      if C <> nil then
        C.Visible := FSplitToolbarStates[I].WasVisible;
    end;
    SetLength(FSplitToolbarStates, 0);

    if FSplitToolbarPanel <> nil then
      FSplitToolbarPanel.Visible := FSplitToolbarPanelWasVisible;
    FSplitToolbarPanel := nil;
    FSplitToolbarPanelWasVisible := False;
    FSplitToolbarIsolated := False;

    if AButton <> nil then
    begin
      AButton.Width := FSplitButtonOriginalWidth;
      AButton.Height := FSplitButtonOriginalHeight;
      AButton.Visible := False;
    end;

    FToolbarLayoutLocked := False;
    UpdateUnifiedToolbar;
    ReflowNavigationToolbar;
    Realign;
  end
  else if AButton <> nil then
    AButton.Visible := False;
end;

procedure TPDFBrowserForm.ApplyToolbarDesign(ADesign: Integer);
var
  BackColor, TextColor, FieldColor: TColor;
  procedure PaintControls(AParent: TWinControl);
  var
    I: Integer;
    C: TControl;
  begin
    if AParent = nil then Exit;
    for I := 0 to AParent.ControlCount - 1 do
    begin
      C := AParent.Controls[I];
      if C is TPanel then
      begin
        TPanel(C).ParentColor := False;
        TPanel(C).ParentBackground := False;
        TPanel(C).Color := BackColor;
        TPanel(C).Font.Color := TextColor;
        if ADesign <> 0 then TPanel(C).Font.Style := [fsBold]
        else TPanel(C).Font.Style := [];
      end
      else if C is TCustomEdit then
      begin
        TEditDesignAccess(C).Color := FieldColor;
        TEditDesignAccess(C).Font.Color := TextColor;
        if ADesign <> 0 then TEditDesignAccess(C).Font.Style := [fsBold]
        else TEditDesignAccess(C).Font.Style := [];
      end
      else if C is TCustomComboBox then
      begin
        TComboDesignAccess(C).Color := FieldColor;
        TComboDesignAccess(C).Font.Color := TextColor;
        if ADesign <> 0 then TComboDesignAccess(C).Font.Style := [fsBold]
        else TComboDesignAccess(C).Font.Style := [];
      end
      else if C is TLabel then
      begin
        TLabel(C).Font.Color := TextColor;
        if ADesign <> 0 then TLabel(C).Font.Style := [fsBold]
        else TLabel(C).Font.Style := [];
      end
      else if C is TPDFDesignButton then
      begin
        TPDFDesignButton(C).Font.Color := TextColor;
        if ADesign <> 0 then TPDFDesignButton(C).Font.Style := [fsBold]
        else TPDFDesignButton(C).Font.Style := [];
        TPDFDesignButton(C).SetDesign(ADesign);
      end
      else if C is TButton then
      begin
        TButton(C).Font.Color := TextColor;
        if ADesign <> 0 then TButton(C).Font.Style := [fsBold]
        else TButton(C).Font.Style := [];
      end
      else if C is TPDFThemeBitBtn then
      begin
        TPDFThemeBitBtn(C).Font.Color := TextColor;
        ApplyPDFGlyphContrast(TPDFThemeBitBtn(C), ADesign);
        if ADesign <> 0 then TPDFThemeBitBtn(C).Font.Style := [fsBold]
        else TPDFThemeBitBtn(C).Font.Style := [];
        TPDFThemeBitBtn(C).SetDesign(ADesign);
      end
      else if C is TBitBtn then
      begin
        TBitBtn(C).Font.Color := TextColor;
        ApplyPDFGlyphContrast(TBitBtn(C), ADesign);
        if ADesign <> 0 then TBitBtn(C).Font.Style := [fsBold]
        else TBitBtn(C).Font.Style := [];
      end;
      if C is TWinControl then
        PaintControls(TWinControl(C));
    end;
  end;
begin
  // Nur bei Designwechsel oder erstmaliger Initialisierung anwenden.
  if FToolbarDesignApplied and (FToolbarDesignIndex = ADesign) then Exit;
  FToolbarDesignIndex := ADesign;
  FToolbarDesignApplied := True;
  if FPDFiumView <> nil then
    FPDFiumView.ApplyPDFBackgroundDesign(ADesign);
  // Ausschliesslich Darstellung: keine Aenderung an Position, Groesse,
  // Symbolen, Ereignissen oder der PDFium-Zeichenflaeche.
  case ADesign of
    1: begin BackColor := RGB(225, 232, 241); TextColor := RGB(35, 48, 65); FieldColor := clWhite; end;
    2: begin BackColor := RGB(54, 58, 65); TextColor := clWhite; FieldColor := RGB(65, 70, 79); end;
    3: begin BackColor := RGB(192, 192, 192); TextColor := clBlack; FieldColor := clWhite; end;
    4: begin BackColor := RGB(34, 36, 40); TextColor := clWhite; FieldColor := RGB(45, 48, 54); end;
    5: begin BackColor := RGB(190, 214, 237); TextColor := RGB(24, 55, 88); FieldColor := RGB(205, 225, 245); end;
  else
    begin BackColor := clBtnFace; TextColor := clWindowText; FieldColor := clWindow; end;
  end;
  if FOpenPDFButton is TPDFDesignButton then
    TPDFDesignButton(FOpenPDFButton).SetDesign(ADesign);
  if FWorkspacesButton is TPDFDesignButton then
    TPDFDesignButton(FWorkspacesButton).SetDesign(ADesign);
  if ADesign <> 0 then
  begin
    if FOpenPDFButton <> nil then FOpenPDFButton.Font.Style := [fsBold];
    if FWorkspacesButton <> nil then FWorkspacesButton.Font.Style := [fsBold];
  end
  else
  begin
    if FOpenPDFButton <> nil then FOpenPDFButton.Font.Style := [];
    if FWorkspacesButton <> nil then FWorkspacesButton.Font.Style := [];
  end;
  if FToolbar <> nil then
  begin
    FToolbar.ParentColor := False;
    FToolbar.ParentBackground := False;
    FToolbar.Color := BackColor;
    FToolbar.Font.Color := TextColor;
    if ADesign <> 0 then FToolbar.Font.Style := [fsBold]
    else FToolbar.Font.Style := [];
    PaintControls(FToolbar);
    if FSearchCountLabel <> nil then
    begin
      FSearchCountLabel.ParentFont := False;
      FSearchCountLabel.Font.Color := TextColor;
      FSearchCountLabel.Transparent := False;
      FSearchCountLabel.Color := BackColor;
    end;
    FToolbar.Invalidate;
  end;
  if (FPDFiumView <> nil) and (FPDFiumView.ToolbarPanel <> nil) then
  begin
    if FPDFiumView.ToolbarPanel is TPanel then
    begin
      TPanel(FPDFiumView.ToolbarPanel).ParentColor := False;
      TPanel(FPDFiumView.ToolbarPanel).ParentBackground := False;
      TPanel(FPDFiumView.ToolbarPanel).Color := BackColor;
      TPanel(FPDFiumView.ToolbarPanel).Font.Color := TextColor;
    end;
    PaintControls(FPDFiumView.ToolbarPanel);
    FPDFiumView.ApplyButtonDesign(ADesign);
  end;
end;

procedure TPDFBrowserForm.RefreshToolbarAfterSplit;
begin
  // Nach dem Reparenting aus der Split-Ansicht die zuvor fixierte
  // Toolbar-Geometrie fuer die volle Registerkartenbreite neu bestimmen.
  FToolbarLayoutLocked := False;
  UpdateUnifiedToolbar;
  ReflowNavigationToolbar;
  Realign;
  if FPDFiumView <> nil then
    FPDFiumView.RefreshToolbarAfterSplit;
end;

procedure TPDFBrowserForm.UpdateUnifiedToolbar;
var
  CanMerge: Boolean;
  ReserveWidth: Integer;
  SavedBounds: array of TRect;
  I: Integer;
  LeftRequired, RightRequired, Gap, Margin, ExtraWidth: Integer;
  EditButton: TControl;
  function Px(N: Integer): Integer;
  begin
    Result := MulDiv(N, CurrentPPI, 96);
  end;
begin
  if FMergingToolbar or FSplitToolbarIsolated or
     (FToolbar = nil) or (FPDFiumView = nil) then Exit;
  if FPDFiumView.ToolbarPanel = nil then Exit;
  // Bei schmalen Fenstern und in der Zweifensteransicht bleibt das
  // bisherige responsive Layout erhalten; keine Bedienelemente abschneiden.
  // Tatsächlichen Platzbedarf statt einer festen Fensterbreite ermitteln.
  // Die linke Gruppe verwendet dieselben Abstände wie ReflowNavigationToolbar.
  Gap := Px(2);
  Margin := Px(4);
  // Owner-Suche: Im Einzeilenmodus liegen diese Controls im PDFium-Panel.
  if FPDFiumView <> nil then EditButton := FPDFiumView.EditToggleButton
  else EditButton := nil;
  // Trefferanzeige vor der Breitenberechnung kompakt setzen.
  // So wird beim Zusammenfuehren keine veraltete, zu grosse Labelbreite
  // als Leerraum zwischen Browser- und PDF-Werkzeuggruppe reserviert.
  if FSearchCountLabel <> nil then
  begin
    Canvas.Font.Assign(FSearchCountLabel.Font);
    ExtraWidth := 0;
    if not FPDFiumView.SearchRunning then
      ExtraWidth := Canvas.TextWidth('  ...');
    FSearchCountLabel.Width := Max(Px(70),
      Max(Canvas.TextWidth(FSearchCountLabel.Caption) + ExtraWidth,
          Canvas.TextWidth(Tr('Alle PDFs: 99999 Treffer'))) + Px(12));
  end;

  LeftRequired := 2 * Margin + 8 * Gap + Px(22);
  if (FExternalSplitButton <> nil) and
     (FExternalSplitButton.Parent = FToolbar) and FExternalSplitButton.Visible then
    Inc(LeftRequired, FExternalSplitButton.Width + Gap);
  if FOpenPDFButton <> nil then Inc(LeftRequired, FOpenPDFButton.Width);
  if FWorkspacesButton <> nil then Inc(LeftRequired, FWorkspacesButton.Width);
  if FFindButton <> nil then Inc(LeftRequired, FFindButton.Width);
  if FGlobalFindButton <> nil then Inc(LeftRequired, FGlobalFindButton.Width);
  if FSearchCountLabel <> nil then
    Inc(LeftRequired, FSearchCountLabel.Width + Gap); // tatsaechlicher Textbedarf inkl. Suchstatus
  Inc(LeftRequired, Px(8)); // Sicherheitsabstand für linke Gruppe
  Inc(LeftRequired, Px(48)); // Miniaturansicht und Trennstrich links im gemeinsamen Panel

  // Rechte PDFium-Gruppe: alle Controls inklusive Trenner und Zwischenräume.
  // Die Breiten entsprechen LayoutToolbar in uFreePDF64PDFiumView.
  RightRequired := Px(36 + 2 + 44 + 42 + 30 + 30 + 2 +
    36 + 36 + 38 + 48 + 2 + 38 + 116 + 2 + 32 + 2 +
    32 + 2 + 52 + 34 + 34 + 40);
  Inc(RightRequired, 24 * Gap + 2 * Margin);
  // Die bisherige Browser-Endgruppe wird im Einzeilenmodus hinter die
  // PDF-Navigationsgruppe verschoben und deshalb hier mit reserviert.
  if FAttachmentSeparator <> nil then
    Inc(RightRequired, FAttachmentSeparator.Width + Gap);
  if FAttachmentsButton <> nil then
    Inc(RightRequired, FAttachmentsButton.Width + Gap);
  // Der Zoomwert benötigt mindestens 38 px; der Seitenstatus kann
  // je nach Sprache/Schrift breiter sein.
  Inc(RightRequired, Max(Px(38),
    Canvas.TextWidth('Seite:') + Px(4)));
  // Keine pauschalen Zusatzreserven: Die tatsaechlichen Controlbreiten,
  // Abstaende und DPI-Skalierung sind bereits in den Gruppenbreiten enthalten.
  // Die PDFium-Leiste enthaelt weitere Abstaende, Theme-Raender und
  // dynamische Beschriftungen. Bei knapper Breite besser zweizeilig
  // bleiben, statt die obere Zeile in eine ueberfuellte Zeile zu ziehen.
  // Keine pauschale Zusatzreserve: die Breiten der Steuerelemente,
  // Zwischenraeume und Grundabstaende sind oben bereits eingerechnet.
  CanMerge := FPDFiumView.ToolbarPanel.ClientWidth >=
    LeftRequired + RightRequired;
  FMergingToolbar := True;
  try
    if CanMerge then
    begin
      // Kompakte Trefferanzeige: keine Breite fuer fuenfstellige Trefferzahlen
      // reservieren. Die vollstaendige Information bleibt im Hint erhalten.
      FSearchCountLabel.Hint := FSearchCountLabel.Caption;
      FSearchCountLabel.ShowHint := True;
      // Die Browser-Endgruppe wird im Einzeilenmodus hinter die
      // PDF-Navigationsgruppe verschoben.
      FPDFiumView.SetMergedToolbarTrailingControls(
        [FAttachmentSeparator, FAttachmentsButton, EditButton], FPDFiumView.ToolbarPanel);
      if FAttachmentSeparator <> nil then
        FAttachmentSeparator.Visible := True;
      // Schrift und Hoehe werden zentral in ReflowNavigationToolbar
      // fuer beide Layoutmodi identisch gesetzt.
      ReserveWidth := LeftRequired;
      if FToolbar.Parent <> FPDFiumView.ToolbarPanel then
      begin
        // VCL kann beim Wechsel zwischen Formular und PDFium-Panel
        // die Kindsteuerelemente automatisch skalieren. Ihre bisherigen
        // Groessen deshalb vor dem Parent-Wechsel sichern und danach
        // wiederherstellen; nur die Positionen werden neu berechnet.
        SetLength(SavedBounds, FToolbar.ControlCount);
        for I := 0 to FToolbar.ControlCount - 1 do
          SavedBounds[I] := FToolbar.Controls[I].BoundsRect;
        FToolbar.Align := alNone;
        FToolbar.Parent := FPDFiumView.ToolbarPanel;
        FToolbar.Align := alLeft;
        for I := 0 to High(SavedBounds) do
          FToolbar.Controls[I].BoundsRect := SavedBounds[I];
      end;
      FToolbar.Width := ReserveWidth;
      // Gleiche Hoehe wie der gemeinsame Container; alLeft fuellt ihn.
      FToolbarLayoutLocked := False;
      ReflowNavigationToolbar;
      FPDFiumView.SetMergedToolbarWidth(ReserveWidth);
    end
    else
    begin
      // In der Zweizeilenansicht bleibt die Browser-Endgruppe oben.
      FPDFiumView.SetMergedToolbarTrailingControls(
        [FAttachmentSeparator, FAttachmentsButton, EditButton], FToolbar);
      if FAttachmentSeparator <> nil then
        FAttachmentSeparator.Visible := True;
      if FToolbar.Parent <> Self then
      begin
        FPDFiumView.SetMergedToolbarWidth(0);
        Canvas.Font.Assign(FSearchCountLabel.Font);
        ExtraWidth := 0;
        if not FPDFiumView.SearchRunning then
          ExtraWidth := Canvas.TextWidth('  ...');
        FSearchCountLabel.Width := Max(Px(70),
          Max(Canvas.TextWidth(FSearchCountLabel.Caption) + ExtraWidth,
              Canvas.TextWidth(Tr('Alle PDFs: 99999 Treffer'))) + Px(12));
        SetLength(SavedBounds, FToolbar.ControlCount);
        for I := 0 to FToolbar.ControlCount - 1 do
          SavedBounds[I] := FToolbar.Controls[I].BoundsRect;
        FToolbar.Align := alNone;
        FToolbar.Parent := Self;
        FToolbar.Align := alTop;
        for I := 0 to High(SavedBounds) do
          FToolbar.Controls[I].BoundsRect := SavedBounds[I];
        FToolbar.Height := MulDiv(36, CurrentPPI, 96);
      end;
      FToolbarLayoutLocked := False;
      ReflowNavigationToolbar;
    end;
  finally
    FMergingToolbar := False;
    // Reparenting veraendert keine Designpalette: kein erneutes Einfaerben.
    // Die OwnerDraw-Buttons zeichnen sich bei Bedarf selbst.
  end;
end;

procedure TPDFBrowserForm.FormResize(Sender: TObject);
begin
  UpdateUnifiedToolbar;
  ReflowNavigationToolbar;
  UpdateAttachmentWindowPosition;
end;

procedure TPDFBrowserForm.FormClose(Sender: TObject; var Action: TCloseAction);
var IniDat: TIniFile;
begin
  FClosing := True;
  SetLoadingHint(False);
  TimerPDF.Enabled := False;
  if Assigned(FPageNavigationTimer) then FPageNavigationTimer.Enabled := False;
  if not FTabbedPDFMode then
  begin
    IniDat := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'FreePDFViewer.ini');
    try
      IniDat.WriteInteger('Position', 'PDFBrowserForm_Left', Left);
      IniDat.WriteInteger('Position', 'PDFBrowserForm_Top', Top);
      IniDat.WriteInteger('Position', 'PDFBrowserForm_Width', Width);
      IniDat.WriteInteger('Position', 'PDFBrowserForm_Height', Height);
    finally IniDat.Free; end;
  end;
  Action := caFree;
end;

procedure TPDFBrowserForm.WMMove(var aMessage: TWMMove);
begin
  inherited;
  UpdateAttachmentWindowPosition;
end;

procedure TPDFBrowserForm.WMMoving(var aMessage: TMessage);
begin
  inherited;
  UpdateAttachmentWindowPosition;
end;


procedure TPDFBrowserForm.SelectAllPDFText;
begin
  if FPDFiumView <> nil then FPDFiumView.SelectAllText;
end;

procedure TPDFBrowserForm.CopyPDFText;
begin
  if FPDFiumView <> nil then FPDFiumView.CopySelectedText;
end;

function TPDFBrowserForm.HandleFormDialogKey(AKey: Word): Boolean;
var
  FocusWnd: HWND;
begin
  Result := False;
  if (FPDFiumView = nil) or not FPDFiumView.HasActiveFormWidget then Exit;
  FocusWnd := GetFocus;
  if (FocusWnd = 0) or
     ((FocusWnd <> FPDFiumView.Handle) and
      not IsChild(FPDFiumView.Handle, FocusWnd)) then Exit;
  if (GetKeyState(VK_CONTROL) < 0) or (GetKeyState(VK_MENU) < 0) then Exit;
  if AKey = VK_TAB then
  begin
    if GetKeyState(VK_SHIFT) < 0 then FocusAdjacentFormWidget(-1)
    else FocusAdjacentFormWidget(1);
    Exit(True);
  end;
  if AKey = VK_SPACE then
  begin
    FPDFiumView.ActivateFocusedFormChoice;
    Exit(True);
  end;
end;

procedure TPDFBrowserForm.CMDialogKey(var Message: TCMDialogKey);
begin
  if HandleFormDialogKey(Message.CharCode) then
  begin
    Message.Result := 1;
    Exit;
  end;
  inherited;
end;

procedure TPDFBrowserForm.FocusAdjacentFormWidget(ADirection: Integer);
begin
  if FPDFiumView <> nil then FPDFiumView.FocusAdjacentFormWidget(ADirection);
end;

procedure TPDFBrowserForm.ShowRequiredFieldsReport;
begin
  if FPDFiumView <> nil then
    FPDFiumView.ShowRequiredFieldsReport;
end;

function TPDFBrowserForm.IsShortCut(var Message: TWMKey): Boolean;
begin
  // Keine Tastenkombinationen pauschal verschlucken.
  // Insbesondere muss Strg+F an den FreePDF64-Viewer gelangen können.
  if HandleFormDialogKey(Message.CharCode) then
  begin
    Result := True;
    Exit;
  end;
  if Message.CharCode = VK_F8 then
  begin
    if GetKeyState(VK_SHIFT) < 0 then
      FocusAdjacentFormWidget(-1)
    else
      FocusAdjacentFormWidget(1);
    Result := True;
    Exit;
  end;
  if Message.CharCode = VK_F7 then
  begin
    ShowRequiredFieldsReport;
    Result := True;
    Exit;
  end;
  Result := inherited IsShortCut(Message);
end;
procedure TPDFBrowserForm.TogglePageThumbnails;
begin
  if FPDFiumView <> nil then FPDFiumView.TogglePageThumbnails;
end;

end.
