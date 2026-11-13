// FreePDF64 - PDFium-only PDF-Anzeige (ohne WebView4Delphi)
unit uPDFBrowserForm;
interface
uses
  uPDFLanguage,
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, System.SysUtils, System.Classes, System.SyncObjs,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.Dialogs, uPDFModernDialogs,
  Vcl.StdCtrls, Vcl.Buttons, Vcl.ComCtrls, Vcl.Printers, Vcl.Clipbrd, Math, IniFiles, System.NetEncoding, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, uFreePDF64PDFiumView, uFreePDF64PDFiumCore, Menus;
type
  TPixelRow = array[0..(MaxInt div 4) - 1] of Cardinal;
  PPixelRow = ^TPixelRow;

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
    // M81: einfache Bildansicht ohne PDFium oder neue Grafik-Symbolleiste.
    FImageScroll: TScrollBox;
    FImageDisplay: TImage;
    FImageZoom: Double;
    FImageFitMode: Integer; // 0=manuell, 1=ganze Grafik, 2=Breite
    FImageWorkspacePending: Boolean;
    FImageWorkspaceZoom: Double;
    FImageWorkspaceFitMode: Integer;
    FImageModified: Boolean; // Nur echte Bildaenderungen (Drehen), kein Zoom
    FImagePreviewRevision: Cardinal; // Cache-Version fuer Registerkartenvorschau
    FImageButtons: array[0..8] of TSpeedButton;
    FImageZoomLabel: TLabel; // Berechneter Grafikzoom, nur Anzeige
    FTIFFImage: Pointer;
    FTIFFGDIPlusToken: NativeUInt;
    FTIFFPageCount, FTIFFPageIndex: Cardinal;
    FTIFFPageGuid: TGUID;
    FTIFFRotations: array of Integer; // 0..3 clockwise quarter-turns per page
    FTIFFPrevButton, FTIFFNextButton: TSpeedButton;
    FTIFFPageLabel: TLabel;
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
    procedure ShowBasicImage;
    procedure UpdateImageSaveIndicator;
    procedure ImageMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure CloseTIFFImage;
    procedure ShowTIFFPage(AIndex: Cardinal);
    procedure SaveMultipageTIFF(const AFileName: string);
    procedure TIFFPageButtonClick(Sender: TObject);
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
    procedure ImageToolClick(Sender: TObject);
    procedure ImageContextClick(Sender: TObject);
    procedure UpdateImageLayout;
    procedure CreateImageTools;
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
    function IsBasicImage: Boolean;
    function GraphicPreviewKey: string;
    function SaveGraphicPreview(const ACacheFile: string): Boolean;
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
    function WorkspaceImageZoom: Double;
    function WorkspaceImageFitMode: Integer;
    procedure SetWorkspaceImageView(AZoom: Double; AFitMode: Integer);
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
  TGDIPlusStartupInput = record
    GdiplusVersion: Cardinal;
    DebugEventCallback: Pointer;
    SuppressBackgroundThread: LongBool;
    SuppressExternalCodecs: LongBool;
  end;
function GdiplusStartup(out Token: NativeUInt; const Input: TGDIPlusStartupInput;
  Output: Pointer): Integer; stdcall; external 'gdiplus.dll';
procedure GdiplusShutdown(Token: NativeUInt); stdcall; external 'gdiplus.dll';
function GdipLoadImageFromFile(Filename: PWideChar; out Image: Pointer): Integer;
  stdcall; external 'gdiplus.dll';
function GdipDisposeImage(Image: Pointer): Integer; stdcall; external 'gdiplus.dll';
function GdipImageGetFrameCount(Image: Pointer; const DimensionID: TGUID;
  out Count: Cardinal): Integer; stdcall; external 'gdiplus.dll';
function GdipImageSelectActiveFrame(Image: Pointer; const DimensionID: TGUID;
  FrameIndex: Cardinal): Integer; stdcall; external 'gdiplus.dll';
function GdipCreateHBITMAPFromBitmap(Bitmap: Pointer; out HBitmap: HBITMAP;
  Background: Cardinal): Integer; stdcall; external 'gdiplus.dll';
function GdipCreateBitmapFromHBITMAP(HBitmap: HBITMAP; HPalette: HPALETTE;
  out Bitmap: Pointer): Integer; stdcall; external 'gdiplus.dll';
function GdipImageRotateFlip(Image: Pointer; RotateFlipType: Integer): Integer;
  stdcall; external 'gdiplus.dll';
function GdipSaveImageToFile(Image: Pointer; Filename: PWideChar;
  const ClsidEncoder: TGUID; EncoderParams: Pointer): Integer;
  stdcall; external 'gdiplus.dll';
function GdipSaveAddImage(Image, NewImage: Pointer; EncoderParams: Pointer): Integer;
  stdcall; external 'gdiplus.dll';
function GdipSaveAdd(Image: Pointer; EncoderParams: Pointer): Integer;
  stdcall; external 'gdiplus.dll';

type
  TTIFFEncoderParameter = record
    Guid: TGUID;
    NumberOfValues: Cardinal;
    ValueType: Cardinal;
    Value: Pointer;
  end;
  TTIFFEncoderParameters = record
    Count: Cardinal;
    Parameter: TTIFFEncoderParameter;
  end;

procedure SetTIFFSaveFlag(var Params: TTIFFEncoderParameters;
  var FlagValue: Cardinal; AFlag: Cardinal);
begin
  FlagValue := AFlag;
  Params.Count := 1;
  Params.Parameter.Guid := StringToGUID('{292266FC-AC40-47BF-8CFC-A85B89A655DE}');
  Params.Parameter.NumberOfValues := 1;
  Params.Parameter.ValueType := 4; // EncoderParameterValueTypeLong
  Params.Parameter.Value := @FlagValue;
end;


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
  IconSize, Dpi: Integer;
  function P(N: Integer): Integer;
  begin
    Result := MulDiv(N, IconSize, 22);
  end;
begin
  // Bei 4K/hoher DPI groessere Symbole, bei WQHD die bisherige Groesse.
  Dpi := AButton.CurrentPPI;
  if Dpi >= 192 then IconSize := MulDiv(30, Dpi, 96)
  else IconSize := 22;
  B := TBitmap.Create;
  try
    B.SetSize(IconSize, IconSize);
    B.PixelFormat := pf24bit;
    B.Transparent := True;
    B.TransparentColor := clFuchsia;
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, IconSize, IconSize));
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := Max(1, P(2));
    B.Canvas.Brush.Style := bsClear;
    if AAllPDFs then
    begin
      B.Canvas.Pen.Width := Max(1, P(1));
      B.Canvas.Rectangle(P(2), P(2), P(12), P(15));
      B.Canvas.Rectangle(P(5), P(5), P(15), P(18));
      B.Canvas.Pen.Width := Max(1, P(2));
      B.Canvas.Ellipse(P(11), P(9), P(18), P(16));
      B.Canvas.MoveTo(P(17), P(16));
      B.Canvas.LineTo(P(21), P(20));
    end
    else
    begin
      B.Canvas.Ellipse(P(3), P(2), P(15), P(14));
      B.Canvas.MoveTo(P(13), P(13));
      B.Canvas.LineTo(P(20), P(20));
    end;
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
  Dpi: Integer;
  function P(N: Integer): Integer;
  begin
    Result := MulDiv(N, Dpi, 96);
  end;
begin
  Dpi := AButton.CurrentPPI;
  if Dpi < 96 then Dpi := 96;
  B := TBitmap.Create;
  try
    B.SetSize(P(24), P(24));
    B.PixelFormat := pf24bit;
    B.Transparent := True;
    B.TransparentColor := clFuchsia;
    B.TransparentMode := tmFixed;
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, P(24), P(24)));
    B.Canvas.Brush.Style := bsClear;
    SetViewportOrgEx(B.Canvas.Handle, P(1), P(1), nil);
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := Max(1, P(2));
    // Schwarz-weisse Bueroklammer, ohne Schriftzeichen oder Emoji.
    B.Canvas.MoveTo(P(8), P(6));
    B.Canvas.LineTo(P(13), P(2));
    B.Canvas.LineTo(P(18), P(2));
    B.Canvas.LineTo(P(20), P(5));
    B.Canvas.LineTo(P(20), P(9));
    B.Canvas.LineTo(P(11), P(19));
    B.Canvas.LineTo(P(7), P(19));
    B.Canvas.LineTo(P(4), P(16));
    B.Canvas.LineTo(P(4), P(12));
    B.Canvas.LineTo(P(13), P(4));
    B.Canvas.LineTo(P(16), P(7));
    B.Canvas.LineTo(P(8), P(15));
    if AHasAttachments then
    begin
      // Freigestelltes Sternchen: nicht mit den Linien der Klammer ueberlagern.
      B.Canvas.Brush.Style := bsSolid;
      // Keine weisse Flaeche: Statusmarkierung direkt auf transparentem Grund.
      B.Canvas.Pen.Color := clBlack;
      B.Canvas.Pen.Width := Max(1, P(2));
      B.Canvas.MoveTo(P(17), P(1));
      B.Canvas.LineTo(P(17), P(9));
      B.Canvas.MoveTo(P(13), P(3));
      B.Canvas.LineTo(P(21), P(7));
      B.Canvas.MoveTo(P(13), P(7));
      B.Canvas.LineTo(P(21), P(3));
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
  CloseTIFFImage;
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
    // Seitenlayout zuerst wiederherstellen, da es den Zoom aendern kann.
    if FWorkspaceLayoutPending then
    begin
      FPDFiumView.RestoreWorkspaceLayout(FWorkspaceViewMode, FWorkspaceTwoPage,
        FWorkspaceContinuous, FWorkspaceSidebar);
      FWorkspaceLayoutPending := False;
    end;
    // Arbeitsbereich-Zoom erst nach dem ersten gueltigen Tab-Layout anwenden.
    // RefreshPDFDisplay beim ersten Anzeigen kann zuvor gespeicherte
    // Zoom-/Scrollwerte sonst wieder durch die Standardansicht ersetzen.
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

function TPDFBrowserForm.WorkspaceImageZoom: Double;
begin
  Result := FImageZoom;
  if FImageWorkspacePending then Result := FImageWorkspaceZoom;
end;

function TPDFBrowserForm.WorkspaceImageFitMode: Integer;
begin
  Result := FImageFitMode;
  if FImageWorkspacePending then Result := FImageWorkspaceFitMode;
end;

procedure TPDFBrowserForm.SetWorkspaceImageView(AZoom: Double; AFitMode: Integer);
begin
  FImageWorkspaceZoom := EnsureRange(AZoom, 0.05, 16.0);
  FImageWorkspaceFitMode := EnsureRange(AFitMode, 0, 2);
  FImageWorkspacePending := True;
  if FImageDisplay <> nil then
  begin
    FImageZoom := FImageWorkspaceZoom;
    FImageFitMode := FImageWorkspaceFitMode;
    FImageWorkspacePending := False;
    UpdateImageLayout;
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
    FOpenPDFButton.Hint := ToolbarHintBrowser('PDFs und Bilder öffnen ... (Strg+O)', 'Open PDFs and images... (Ctrl+O)');
  if FWorkspacesButton <> nil then
  begin
    FWorkspacesButton.Caption := '';
    FWorkspacesButton.Hint := ToolbarHintBrowser('LMB: Arbeitsbereiche verwalten ...' + sLineBreak + 'RMB: Arbeitsbereich speichern ...', 'LMB: Manage workspaces ...' + sLineBreak + 'RMB: Save workspace ...');
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
  if FImageButtons[0] <> nil then
  begin
    FImageButtons[0].Hint := ToolbarHintBrowser('Bild verkleinern', 'Zoom image out');
    FImageButtons[1].Hint := ToolbarHintBrowser('Bild vergrößern', 'Zoom image in');
    FImageButtons[2].Hint := ToolbarHintBrowser('Bild 90° nach links drehen', 'Rotate image 90° left');
    FImageButtons[3].Hint := ToolbarHintBrowser('Bild 90° nach rechts drehen', 'Rotate image 90° right');
    FImageButtons[4].Hint := ToolbarHintBrowser('Ganze Bild', 'Fit image');
    FImageButtons[5].Hint := ToolbarHintBrowser('Bildbreite anpassen', 'Fit image width');
    FImageButtons[6].Hint := ToolbarHintBrowser('Originalgröße (100 %)', 'Actual size (100%)');
    FImageButtons[7].Hint := ToolbarHintBrowser('Bild speichern unter ...', 'Save image as...');
    FImageButtons[8].Hint := ToolbarHintBrowser('Bild drucken ...', 'Print image...');
    if FImageZoomLabel <> nil then
      FImageZoomLabel.Hint := ToolbarHintBrowser('Aktueller Bildzoom', 'Current image zoom');
  end;
end;

procedure TPDFBrowserForm.ShowDocumentProperties;
begin
  if (FPDFiumView <> nil) and not FClosing then
    FPDFiumView.ShowDocumentProperties;
end;

procedure TPDFBrowserForm.RefitPDFOnTabActivation;
begin
  if IsBasicImage then Exit;
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
  // Emoji-Schrift bei 4K nicht proportional zur riesigen Schaltflaeche skalieren.
  FOpenPDFButton.Font.Size := 10;
  FOpenPDFButton.Width := ScalePx(32);
  FOpenPDFButton.Height := 28;
  FOpenPDFButton.Hint := ToolbarHintBrowser('PDFs und Bilder öffnen ... (Strg+O)', 'Open PDFs and images... (Ctrl+O)');
  FOpenPDFButton.ShowHint := True;
  FOpenPDFButton.OnClick := OpenPDFToolbarClick;

  FWorkspacesButton := TPDFDesignButton.Create(Self);
  FWorkspacesButton.Parent := FToolbar;
  FWorkspacesButton.Caption := '';
  FWorkspacesButton.Width := ScalePx(34);
  FWorkspacesButton.Font.Name := 'Segoe UI Symbol';
  FWorkspacesButton.Font.Size := 12;
  FWorkspacesButton.Height := 28;
  FWorkspacesButton.Hint := ToolbarHintBrowser('LMB: Arbeitsbereiche verwalten ...' + sLineBreak + 'RMB: Arbeitsbereich speichern ...', 'LMB: Manage workspaces ...' + sLineBreak + 'RMB: Save workspace ...');
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
  FAttachmentsButton.Width := ScalePx(34);
  FAttachmentsButton.Height := ScalePx(28);
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
  // Grafikregister besitzen keinen PDFium-Ladeauftrag.
  if FClosing or (csDestroying in ComponentState) then Exit;
  if IsBasicImage then
  begin
    // Grafik-Symbolleiste auch beim Ladeauftrag initialisieren.
    if TimerPDF <> nil then TimerPDF.Enabled := False;
    ShowBasicImage;
    Exit;
  end;
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
  // Beim Zurueckschalten auf eine bereits geladene PDF keinen zweiten
  // asynchronen Ladevorgang und keinen neuen Timer ausloesen.
  if FClosing or (csDestroying in ComponentState) then Exit;
  if IsBasicImage then
  begin
    if FImageButtons[0] = nil then ShowBasicImage;
    Exit;
  end;
  if FNavigationSucceeded then Exit;
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
  if FClosing or IsBasicImage or (FPDFiumView = nil) then Exit;
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
      if FWorkspaceRestorePending then
      begin
        FPDFiumView.RestoreWorkspaceView(FWorkspaceZoom, FWorkspaceFit,
          FWorkspaceX, FWorkspaceY);
        FWorkspaceRestorePending := False;
      end;

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

function TPDFBrowserForm.IsBasicImage: Boolean;
var
  Ext, FilePath: string;
begin
  // In einem Register ist der unveraenderliche Dateipfad im Tab gespeichert.
  // Bei einem schnellen Wechsel PDF <-> Grafik nicht die gerade wechselnde
  // BrowserForm-Dateinamenreferenz fuer die Typpruefung dereferenzieren.
  if (Parent is TTabSheet) and (TTabSheet(Parent).Hint <> '') then
    FilePath := TTabSheet(Parent).Hint
  else
    FilePath := PDFFileName;
  Ext := LowerCase(ExtractFileExt(FilePath));
  Result := (Ext = '.jpg') or (Ext = '.jpeg') or
    (Ext = '.png') or (Ext = '.bmp') or
    (Ext = '.tif') or (Ext = '.tiff');
end;

procedure SetCrispImageGlyph(AButton: TSpeedButton; AKind: Integer;
  AColor: TColor = clBlack);
var
  B: TBitmap;
  S, C, R, Stroke: Integer;
  Step, Steps, CX, CY, Rad, PX, PY, Direction: Integer;
  Angle: Double;
  Arrow: array[0..2] of TPoint;

begin
  S := Max(16, MulDiv(20, Max(96, AButton.CurrentPPI), 96));
  B := TBitmap.Create;
  try
    B.PixelFormat := pf24bit;
    B.SetSize(S, S);
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, S, S));
    B.Canvas.Pen.Color := AColor;
    Stroke := Max(2, MulDiv(2, Max(96, AButton.CurrentPPI), 96));
    B.Canvas.Pen.Width := Stroke;
    B.Canvas.Pen.Style := psSolid;
    B.Canvas.Brush.Style := bsClear;
    C := S div 2;
    if AKind >= 4 then
    begin
      // Einfache monochrome Piktogramme fuer die Grafik-Werkzeuge.
      B.Canvas.Pen.Width := Max(1, MulDiv(2, Max(96, AButton.CurrentPPI), 96));
      case AKind of
        4: begin // Ganze Seite: Dokument mit vier Eckmarkierungen
          B.Canvas.Rectangle(S div 4, S div 6, 3*S div 4, 5*S div 6);
          B.Canvas.MoveTo(S div 3, S div 3);
          B.Canvas.LineTo(2*S div 3, S div 3);
          B.Canvas.MoveTo(S div 3, 2*S div 3);
          B.Canvas.LineTo(2*S div 3, 2*S div 3);
        end;
        5: begin // Seitenbreite: horizontale Doppelpfeile
          B.Canvas.MoveTo(S div 5, S div 2);
          B.Canvas.LineTo(4*S div 5, S div 2);
          B.Canvas.MoveTo(S div 5, S div 2);
          B.Canvas.LineTo(S div 3, S div 3);
          B.Canvas.MoveTo(S div 5, S div 2);
          B.Canvas.LineTo(S div 3, 2*S div 3);
          B.Canvas.MoveTo(4*S div 5, S div 2);
          B.Canvas.LineTo(2*S div 3, S div 3);
          B.Canvas.MoveTo(4*S div 5, S div 2);
          B.Canvas.LineTo(2*S div 3, 2*S div 3);
        end;
        6: begin // Originalgroesse: 100%
          B.Canvas.Font.Name := 'Segoe UI';
          B.Canvas.Font.Color := AColor;
          B.Canvas.Font.Style := [fsBold];
          B.Canvas.Font.Height := -Max(9, S div 2);
          while (B.Canvas.TextWidth('100%') > S - 2) and
                (B.Canvas.Font.Height < -7) do
            B.Canvas.Font.Height := B.Canvas.Font.Height + 1;
          B.Canvas.TextOut(Max(0, (S-B.Canvas.TextWidth('100%')) div 2),
            Max(0, (S-B.Canvas.TextHeight('100%')) div 2), '100%');
        end;
        7: begin // Speichern: Diskette
          B.Canvas.Rectangle(S div 5, S div 6, 4*S div 5, 5*S div 6);
          B.Canvas.Rectangle(S div 3, S div 6, 2*S div 3, S div 2);
          B.Canvas.Rectangle(S div 3, 2*S div 3, 2*S div 3, 5*S div 6);
        end;
        8: begin // Drucken: Drucker
          B.Canvas.Rectangle(S div 4, S div 6, 3*S div 4, S div 2);
          B.Canvas.Rectangle(S div 6, S div 2, 5*S div 6, 3*S div 4);
          B.Canvas.Rectangle(S div 4, 2*S div 3, 3*S div 4, 5*S div 6);
        end;
      end;
    end
    else if AKind < 2 then
    begin
      // Lupe: ein Kreis, ein Griff und ein Plus/Minus, ohne doppelte Konturen.
      R := Max(4, S div 3);
      B.Canvas.Ellipse(C-R-2, C-R-2, C+R-1, C+R-1);
      B.Canvas.MoveTo(C+R-2, C+R-2);
      B.Canvas.LineTo(S-2, S-2);
      B.Canvas.MoveTo(C-R div 2-2, C-2);
      B.Canvas.LineTo(C+R div 2-1, C-2);
      if AKind = 1 then
      begin
        B.Canvas.MoveTo(C-2, C-R div 2-2);
        B.Canvas.LineTo(C-2, C+R div 2-1);
      end;
    end
    else
    begin
      // Eigenes Vektor-Drehsymbol: Kreisbogen mit Pfeilspitze.
      // Keine vertikalen Begrenzungslinien, keine Pixelmasken.
      // Links = gegen den Uhrzeigersinn; rechts = im Uhrzeigersinn.
      CX := S div 2;
      CY := S div 2;
      Rad := Max(5, S * 31 div 100);
      Steps := Max(24, S * 2);
      B.Canvas.Pen.Width := Max(2, S div 10);
      Direction := 1;
      if AKind = 3 then Direction := -1;
      // Der Bogen laeuft von unten ueber die Aussenseite nach oben.
      // Oben endet er jeweils mit einer gut sichtbaren Pfeilspitze.
      for Step := 0 to Steps do
      begin
        Angle := (0.72 + 1.72 * Step / Steps) * Pi;
        if Direction < 0 then Angle := Pi - Angle;
        PX := CX + Round(Rad * Cos(Angle));
        PY := CY - Round(Rad * Sin(Angle));
        if Step = 0 then B.Canvas.MoveTo(PX, PY)
        else B.Canvas.LineTo(PX, PY);
      end;
      // Dreieckige Pfeilspitze am Bogenende, ohne geraden Randstrich.
      Angle := 2.44 * Pi;
      if Direction < 0 then Angle := Pi - Angle;
      PX := CX + Round(Rad * Cos(Angle));
      PY := CY - Round(Rad * Sin(Angle));
      Arrow[0] := Point(PX, PY);
      Arrow[1] := Point(PX + Direction * Max(4, S div 4), PY - Max(2, S div 10));
      Arrow[2] := Point(PX + Direction * Max(2, S div 10), PY + Max(4, S div 4));
      B.Canvas.Brush.Style := bsSolid;
      B.Canvas.Brush.Color := AColor;
      B.Canvas.Pen.Width := 1;
      B.Canvas.Polygon(Arrow);

    end;
    B.TransparentColor := clFuchsia;
    B.Transparent := True;
    AButton.Glyph.Assign(B);
    AButton.NumGlyphs := 1;
    AButton.Caption := '';
    AButton.Margin := -1;
    AButton.Spacing := 0;
  finally
    B.Free;
  end;
end;


procedure SetTIFFArrowGlyph(AButton: TSpeedButton; AForward: Boolean;
  AColor: TColor; APPI: Integer);
var
  B: TBitmap;
  S, C, R: Integer;
  P: array[0..2] of TPoint;
begin
  if AButton = nil then Exit;
  S := Max(16, MulDiv(18, APPI, 96));
  B := TBitmap.Create;
  try
    B.SetSize(S, S);
    B.PixelFormat := pf24bit;
    B.Transparent := True;
    B.TransparentColor := clFuchsia;
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(Rect(0, 0, S, S));
    C := S div 2;
    R := Max(3, S div 4);
    if AForward then
    begin
      P[0] := Point(C - R div 2, C - R);
      P[1] := Point(C + R div 2, C);
      P[2] := Point(C - R div 2, C + R);
    end
    else
    begin
      P[0] := Point(C + R div 2, C - R);
      P[1] := Point(C - R div 2, C);
      P[2] := Point(C + R div 2, C + R);
    end;
    B.Canvas.Pen.Color := AColor;
    B.Canvas.Brush.Color := AColor;
    B.Canvas.Polygon(P);
    AButton.Caption := '';
    AButton.Glyph.Assign(B);
    AButton.NumGlyphs := 1;
    AButton.Margin := -1;
    AButton.Spacing := 0;
  finally
    B.Free;
  end;
end;

procedure TPDFBrowserForm.UpdateImageSaveIndicator;
begin
  if FImageButtons[7] = nil then Exit;
  // Dieselbe orange Warnfarbe fuer ungespeicherte Aenderungen wie bei PDFs.
  // Nur die Diskette neu zeichnen, nicht die gesamte Symbolleiste.
  if FImageModified then
    SetCrispImageGlyph(FImageButtons[7], 7, TColor($0080A5FF))
  else
    SetCrispImageGlyph(FImageButtons[7], 7, FImageButtons[7].Font.Color);
end;

procedure TPDFBrowserForm.CreateImageTools;
var
  I: Integer;
begin
  if FImageButtons[0] <> nil then Exit;
  for I := 0 to High(FImageButtons) do
  begin
    FImageButtons[I] := TSpeedButton.Create(Self);
    FImageButtons[I].Parent := FToolbar;
    FImageButtons[I].Tag := I;
    case I of
      0: SetCrispImageGlyph(FImageButtons[I], 0);
      1: SetCrispImageGlyph(FImageButtons[I], 1);
      2: SetCrispImageGlyph(FImageButtons[I], 2);
      3: SetCrispImageGlyph(FImageButtons[I], 3);
      4: SetCrispImageGlyph(FImageButtons[I], 4);
      5: SetCrispImageGlyph(FImageButtons[I], 5);
      6: begin
           FImageButtons[I].Caption := '100 %';
           FImageButtons[I].Font.Style := [fsBold];
           FImageButtons[I].Font.Size := 9;
         end;
      7: SetCrispImageGlyph(FImageButtons[I], 7);
      8: SetCrispImageGlyph(FImageButtons[I], 8);
    end;
    FImageButtons[I].Width := MulDiv(IfThen(I = 6, 48, 34), CurrentPPI, 96);
    FImageButtons[I].Height := MulDiv(28, CurrentPPI, 96);
    FImageButtons[I].ShowHint := True;
    FImageButtons[I].OnClick := ImageToolClick;
  end;
  FImageZoomLabel := TLabel.Create(Self);
  FImageZoomLabel.Parent := FToolbar;
  FImageZoomLabel.AutoSize := False;
  FImageZoomLabel.Alignment := taCenter;
  FImageZoomLabel.Layout := tlCenter;
  FImageZoomLabel.Width := MulDiv(45, CurrentPPI, 96);
  FImageZoomLabel.Height := MulDiv(28, CurrentPPI, 96);
  FImageZoomLabel.Caption := '100 %';
  FImageZoomLabel.ShowHint := True;
  FImageZoomLabel.Font.Size := 9;
  RefreshLanguage;
  // Bereits gewähltes Design auch auf nachträglich erzeugte Bildbuttons anwenden.
  FToolbarDesignApplied := False;
  ApplyToolbarDesign(FToolbarDesignIndex);
  UpdateImageSaveIndicator;
end;

procedure TPDFBrowserForm.UpdateImageLayout;
var
  W, H: Integer;
  Factor: Double;
begin
  if (FImageDisplay = nil) or (FImageScroll = nil) or
     (FImageDisplay.Picture.Graphic = nil) then Exit;
  W := FImageDisplay.Picture.Width;
  H := FImageDisplay.Picture.Height;
  if (W < 1) or (H < 1) then Exit;
  Factor := FImageZoom;
  if FImageFitMode = 1 then
    Factor := Min(FImageScroll.ClientWidth / W, FImageScroll.ClientHeight / H)
  else if FImageFitMode = 2 then
    Factor := FImageScroll.ClientWidth / W;
  Factor := EnsureRange(Factor, 0.01, 16.0);
  FImageDisplay.AutoSize := False;
  FImageDisplay.Stretch := True;
  FImageDisplay.Proportional := False;
  // Kleinere Grafiken innerhalb der sichtbaren Flaeche zentrieren.
  // Bei groesseren Grafiken bleibt der Ursprung 0,0, damit die
  // Scrollbars unveraendert zum Navigieren verwendet werden koennen.
  W := Max(1, Round(W * Factor));
  H := Max(1, Round(H * Factor));
  FImageDisplay.SetBounds(
    Max(0, (FImageScroll.ClientWidth - W) div 2),
    Max(0, (FImageScroll.ClientHeight - H) div 2), W, H);
  if FImageZoomLabel <> nil then
    FImageZoomLabel.Caption := FormatFloat('0.#', Factor * 100) + ' %';
end;

procedure TPDFBrowserForm.ImageContextClick(Sender: TObject);
var
  Mode: Integer;
begin
  if not (Sender is TMenuItem) or (FImageDisplay = nil) then Exit;
  Mode := TMenuItem(Sender).Tag;
  if Mode = 20 then
  begin
    if (FImageDisplay.Picture.Graphic <> nil) and
       not FImageDisplay.Picture.Graphic.Empty then
      Clipboard.Assign(FImageDisplay.Picture.Graphic);
  end
  else if (Mode >= 0) and (Mode <= 8) and (FImageButtons[Mode] <> nil) then
    ImageToolClick(FImageButtons[Mode]);
end;

procedure TPDFBrowserForm.ImageToolClick(Sender: TObject);
var
  Mode, X, Y, W, H, DestY: Integer;
  Src, Dst: TBitmap;
  SourceRows: array of PCardinal;
  DestPixels: PCardinal;

  SaveDlg: TSaveDialog;
  Ext: string;
  Png: TPngImage;
  Jpg: TJPEGImage;
  PrintDlg: TPrintDialog;
  PrintBmp: TBitmap;
  PrintScale: Double;
  PrintRect: TRect;
begin
  if not IsBasicImage or (FImageDisplay = nil) then Exit;
  Mode := (Sender as TSpeedButton).Tag;
  case Mode of
    0: begin FImageFitMode := 0; FImageZoom := Max(0.05, FImageZoom / 1.25); end;
    1: begin FImageFitMode := 0; FImageZoom := Min(16, FImageZoom * 1.25); end;
    6: begin FImageFitMode := 0; FImageZoom := 1.0; end;
    4: FImageFitMode := 1;
    5: FImageFitMode := 2;
    7: begin
      if FTIFFPageCount > 1 then
      begin
        SaveDlg := TSaveDialog.Create(Self);
        try
          SaveDlg.Filter := 'Mehrseitiges TIFF (*.tif;*.tiff)|*.tif;*.tiff';
          SaveDlg.DefaultExt := 'tif';
          SaveDlg.FileName := ChangeFileExt(ExtractFileName(PDFFileName), '_bearbeitet.tif');
          if SaveDlg.Execute then
          begin
            SaveMultipageTIFF(SaveDlg.FileName);
            FImageModified := False;
            UpdateImageSaveIndicator;
          end;
        finally
          SaveDlg.Free;
        end;
        Exit;
      end;
      SaveDlg := TSaveDialog.Create(Self);
      try
        SaveDlg.Filter := 'PNG (*.png)|*.png|JPEG (*.jpg)|*.jpg|Bitmap (*.bmp)|*.bmp';
        SaveDlg.DefaultExt := 'png';
        SaveDlg.FileName := ChangeFileExt(ExtractFileName(PDFFileName), '.png');
        if SaveDlg.Execute then
        begin
          Ext := LowerCase(ExtractFileExt(SaveDlg.FileName));
          if Ext = '.bmp' then
            FImageDisplay.Picture.Bitmap.SaveToFile(SaveDlg.FileName)
          else if (Ext = '.jpg') or (Ext = '.jpeg') then
          begin
            Jpg := TJPEGImage.Create;
            try
              Jpg.Assign(FImageDisplay.Picture.Graphic);
              Jpg.SaveToFile(SaveDlg.FileName);
            finally Jpg.Free; end;
          end
          else
          begin
            Png := TPngImage.Create;
            try
              Png.Assign(FImageDisplay.Picture.Graphic);
              Png.SaveToFile(ChangeFileExt(SaveDlg.FileName, '.png'));
            finally Png.Free; end;
          end;
          // Nur nach erfolgreich abgeschlossenem Speichern zuruecksetzen.
          FImageModified := False;
          UpdateImageSaveIndicator;
        end;
      finally SaveDlg.Free; end;
    end;
    2, 3: begin
      Src := TBitmap.Create;
      Dst := TBitmap.Create;
      try
        Src.Assign(FImageDisplay.Picture.Graphic);
        Src.PixelFormat := pf32bit;
        W := Src.Width; H := Src.Height;
        Dst.PixelFormat := pf32bit;
        Dst.SetSize(H, W);
        // Zeilenadressen einmal ermitteln: ScanLine innerhalb der inneren
        // Pixelschleife war bei grossen Grafiken extrem teuer.
        SetLength(SourceRows, H);
        for Y := 0 to H - 1 do
          SourceRows[Y] := Src.ScanLine[Y];
        // Jede Zielzeile zusammenhaengend schreiben. Die Bildausrichtung
        // bleibt identisch zur bisherigen Drehfunktion (Mode 2/3).
        for X := 0 to W - 1 do
        begin
          if Mode = 3 then
            DestY := X
          else
            DestY := W - 1 - X;
          DestPixels := Dst.ScanLine[DestY];
          if Mode = 3 then
          begin
            for Y := 0 to H - 1 do
              PPixelRow(DestPixels)^[H - 1 - Y] :=
                PPixelRow(SourceRows[Y])^[X];
          end
          else
          begin
            for Y := 0 to H - 1 do
              PPixelRow(DestPixels)^[Y] :=
                PPixelRow(SourceRows[Y])^[X];
          end;
        end;
        FImageDisplay.Picture.Assign(Dst);
        Inc(FImagePreviewRevision);
        if (FTIFFPageCount > 1) and (FTIFFPageIndex < Cardinal(Length(FTIFFRotations))) then
        begin
          if Mode = 3 then
            FTIFFRotations[FTIFFPageIndex] := (FTIFFRotations[FTIFFPageIndex] + 1) mod 4
          else
            FTIFFRotations[FTIFFPageIndex] := (FTIFFRotations[FTIFFPageIndex] + 3) mod 4;
        end;
        FImageModified := True;
        UpdateImageSaveIndicator;
      finally
        Dst.Free; Src.Free;
      end;
    end;
    8: begin
      PrintDlg := TPrintDialog.Create(Self);
      try
        if not PrintDlg.Execute then Exit;
        PrintBmp := TBitmap.Create;
        try
          PrintBmp.Assign(FImageDisplay.Picture.Graphic);
          PrintScale := Min(Printer.PageWidth / Max(1, PrintBmp.Width),
                            Printer.PageHeight / Max(1, PrintBmp.Height));
          PrintRect := Rect(
            (Printer.PageWidth - Round(PrintBmp.Width * PrintScale)) div 2,
            (Printer.PageHeight - Round(PrintBmp.Height * PrintScale)) div 2,
            (Printer.PageWidth + Round(PrintBmp.Width * PrintScale)) div 2,
            (Printer.PageHeight + Round(PrintBmp.Height * PrintScale)) div 2);
          Printer.BeginDoc;
          try
            Printer.Canvas.StretchDraw(PrintRect, PrintBmp);
            Printer.EndDoc;
          except
            Printer.Abort;
            raise;
          end;
        finally PrintBmp.Free; end;
      finally PrintDlg.Free; end;
    end;
  end;
  UpdateImageLayout;
end;

procedure TPDFBrowserForm.ImageMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  Steps: Integer;
begin
  if (not (ssCtrl in Shift)) or (FImageDisplay = nil) then Exit;
  Steps := Abs(WheelDelta) div WHEEL_DELTA;
  if Steps = 0 then Steps := 1;
  FImageFitMode := 0;
  while Steps > 0 do
  begin
    if WheelDelta > 0 then FImageZoom := Min(16.0, FImageZoom * 1.25)
    else FImageZoom := Max(0.05, FImageZoom / 1.25);
    Dec(Steps);
  end;
  UpdateImageLayout;
  Handled := True;
end;

procedure TPDFBrowserForm.CloseTIFFImage;
begin
  if FTIFFImage <> nil then
  begin
    GdipDisposeImage(FTIFFImage);
    FTIFFImage := nil;
  end;
  if FTIFFGDIPlusToken <> 0 then
  begin
    GdiplusShutdown(FTIFFGDIPlusToken);
    FTIFFGDIPlusToken := 0;
  end;
  FTIFFPageCount := 0;
  FTIFFPageIndex := 0;
  SetLength(FTIFFRotations, 0);
end;

procedure TPDFBrowserForm.SaveMultipageTIFF(const AFileName: string);
var
  Page, SavedPage: Cardinal;
  HB: HBITMAP;
  Frame, FirstFrame: Pointer;
  Params: TTIFFEncoderParameters;
  FlagValue: Cardinal;
  Encoder: TGUID;
  Status: Integer;
  TargetName: string;
begin
  if (FTIFFImage = nil) or (FTIFFPageCount < 2) then Exit;
  if SameText(ExpandFileName(AFileName), ExpandFileName(PDFFileName)) then
    raise Exception.Create(ToolbarHintBrowser(
      'Bitte einen anderen Dateinamen wählen. Das Original bleibt geschützt.',
      'Please choose a different filename. The original is protected.'));
  TargetName := AFileName;
  if not (SameText(ExtractFileExt(TargetName), '.tif') or
          SameText(ExtractFileExt(TargetName), '.tiff')) then
    TargetName := ChangeFileExt(TargetName, '.tif');
  if FileExists(TargetName) then
    raise Exception.Create(ToolbarHintBrowser(
      'Die Zieldatei existiert bereits. Bitte einen anderen Namen wählen.',
      'The destination already exists. Please choose another filename.'));
  Encoder := StringToGUID('{557CF405-1A04-11D3-9A73-0000F81EF32E}');
  SavedPage := FTIFFPageIndex;
  FirstFrame := nil;
  try
    try
      for Page := 0 to FTIFFPageCount - 1 do
    begin
      if GdipImageSelectActiveFrame(FTIFFImage, FTIFFPageGuid, Page) <> 0 then
        raise Exception.Create('TIFF: SelectActiveFrame failed');
      HB := 0;
      if (GdipCreateHBITMAPFromBitmap(FTIFFImage, HB, $FFFFFFFF) <> 0) or (HB = 0) then
        raise Exception.Create('TIFF: bitmap conversion failed');
      Frame := nil;
      try
        Status := GdipCreateBitmapFromHBITMAP(HB, 0, Frame);
      finally
        DeleteObject(HB);
      end;
      if (Status <> 0) or (Frame = nil) then
        raise Exception.Create('TIFF: bitmap creation failed');
      try
        if (Page < Cardinal(Length(FTIFFRotations))) and (FTIFFRotations[Page] <> 0) then
        begin
          // GDI+ RotateFlipType: 1=90°, 2=180°, 3=270° clockwise.
          Status := GdipImageRotateFlip(Frame, FTIFFRotations[Page]);
          if Status <> 0 then raise Exception.Create('TIFF: rotation failed');
        end;
        if Page = 0 then
        begin
          SetTIFFSaveFlag(Params, FlagValue, 18); // MultiFrame
          Status := GdipSaveImageToFile(Frame, PWideChar(TargetName), Encoder, @Params);
          if Status <> 0 then raise Exception.CreateFmt('TIFF: save failed (%d)', [Status]);
          FirstFrame := Frame;
          Frame := nil; // keep first image alive until Flush
        end
        else
        begin
          SetTIFFSaveFlag(Params, FlagValue, 23); // FrameDimensionPage
          Status := GdipSaveAddImage(FirstFrame, Frame, @Params);
          if Status <> 0 then raise Exception.CreateFmt('TIFF: add page failed (%d)', [Status]);
        end;
      finally
        if Frame <> nil then GdipDisposeImage(Frame);
      end;
    end;
    SetTIFFSaveFlag(Params, FlagValue, 20); // Flush
    Status := GdipSaveAdd(FirstFrame, @Params);
    if Status <> 0 then raise Exception.CreateFmt('TIFF: finalize failed (%d)', [Status]);
    except
      if FileExists(TargetName) then Winapi.Windows.DeleteFile(PChar(TargetName));
      raise;
    end;
  finally
    if FirstFrame <> nil then GdipDisposeImage(FirstFrame);
    GdipImageSelectActiveFrame(FTIFFImage, FTIFFPageGuid, SavedPage);
  end;
end;

procedure TPDFBrowserForm.ShowTIFFPage(AIndex: Cardinal);
var
  HB, RotatedHB: HBITMAP;
  B: TBitmap;
  Frame: Pointer;
begin
  if (FTIFFImage = nil) or (AIndex >= FTIFFPageCount) then Exit;
  if GdipImageSelectActiveFrame(FTIFFImage, FTIFFPageGuid, AIndex) <> 0 then Exit;
  HB := 0;
  if (GdipCreateHBITMAPFromBitmap(FTIFFImage, HB, $FFFFFFFF) <> 0) or (HB = 0) then Exit;
  B := TBitmap.Create;
  try
    B.Handle := HB;
    FImageDisplay.Picture.Assign(B);
  finally
    B.Free;
  end;
  if (AIndex < Cardinal(Length(FTIFFRotations))) and (FTIFFRotations[AIndex] <> 0) then
  begin
    // Rotation für diese Seite auch nach einem Seitenwechsel anzeigen.
    GdipImageSelectActiveFrame(FTIFFImage, FTIFFPageGuid, AIndex);
    // Die bereits optimierte Bitmap-Drehung wird nicht erneut aufgerufen;
    // die Seite wird direkt per GDI+ gedreht und als Bitmap angezeigt.
    HB := 0;
    if GdipCreateHBITMAPFromBitmap(FTIFFImage, HB, $FFFFFFFF) = 0 then
    begin
      Frame := nil;
      try
        if GdipCreateBitmapFromHBITMAP(HB, 0, Frame) = 0 then
        begin
          GdipImageRotateFlip(Frame, FTIFFRotations[AIndex]);
          RotatedHB := 0;
          if GdipCreateHBITMAPFromBitmap(Frame, RotatedHB, $FFFFFFFF) = 0 then
          begin
            B := TBitmap.Create;
            try
              B.Handle := RotatedHB;
              FImageDisplay.Picture.Assign(B);
            finally B.Free; end;
          end;
        end;
      finally
        if Frame <> nil then GdipDisposeImage(Frame);
        DeleteObject(HB);
      end;
    end;
  end;
  FTIFFPageIndex := AIndex;
  Inc(FImagePreviewRevision);
  if FTIFFPageLabel <> nil then
    FTIFFPageLabel.Caption := Format('%d / %d', [AIndex + 1, FTIFFPageCount]);
  if FTIFFPrevButton <> nil then FTIFFPrevButton.Enabled := AIndex > 0;
  if FTIFFNextButton <> nil then FTIFFNextButton.Enabled := AIndex + 1 < FTIFFPageCount;
  UpdateImageLayout;
end;

procedure TPDFBrowserForm.TIFFPageButtonClick(Sender: TObject);
begin
  if (FTIFFImage = nil) or (FTIFFPageCount < 2) then Exit;
  if Sender = FTIFFPrevButton then
  begin
    if FTIFFPageIndex > 0 then ShowTIFFPage(FTIFFPageIndex - 1);
  end
  else if FTIFFPageIndex + 1 < FTIFFPageCount then
    ShowTIFFPage(FTIFFPageIndex + 1);
end;

function TPDFBrowserForm.GraphicPreviewKey: string;
begin
  Result := IntToStr(FTIFFPageIndex) + ':' + IntToStr(FImagePreviewRevision);
end;

function TPDFBrowserForm.SaveGraphicPreview(const ACacheFile: string): Boolean;
var
  Source, Thumb: TBitmap;
  W, H: Integer;
  TempFile, Ext, ImageFile: string;
  Input: TGDIPlusStartupInput;
  Token: NativeUInt;
  GImage: Pointer;
  HB: HBITMAP;
  Pic: TPicture;
begin
  Result := False;
  if not IsBasicImage then Exit;
  Source := TBitmap.Create;
  Thumb := TBitmap.Create;
  try
    if (FImageDisplay <> nil) and (FImageDisplay.Picture.Graphic <> nil) and
       (FImageDisplay.Picture.Width > 0) and (FImageDisplay.Picture.Height > 0) then
      Source.Assign(FImageDisplay.Picture.Graphic)
    else
    begin
      // Inaktive Registerkarten sind absichtlich noch nicht initialisiert.
      // Die Vorschau daher direkt aus der Datei lesen, ohne Tab-Aktivierung.
      ImageFile := PDFFileName;
      if (Parent is TTabSheet) and (TTabSheet(Parent).Hint <> '') then
        ImageFile := TTabSheet(Parent).Hint;
      Ext := LowerCase(ExtractFileExt(ImageFile));
      if (Ext = '.tif') or (Ext = '.tiff') then
      begin
        FillChar(Input, SizeOf(Input), 0);
        Input.GdiplusVersion := 1;
        Token := 0;
        if GdiplusStartup(Token, Input, nil) <> 0 then Exit;
        try
          GImage := nil;
          if GdipLoadImageFromFile(PWideChar(ImageFile), GImage) <> 0 then Exit;
          try
            HB := 0;
            if (GdipCreateHBITMAPFromBitmap(GImage, HB, $FFFFFFFF) <> 0) or
               (HB = 0) then Exit;
            // TBitmap übernimmt das Handle und gibt es wieder frei.
            Source.Handle := HB;
          finally
            GdipDisposeImage(GImage);
          end;
        finally
          GdiplusShutdown(Token);
        end;
      end
      else
      begin
        Pic := TPicture.Create;
        try
          Pic.LoadFromFile(ImageFile);
          Source.Assign(Pic.Graphic);
        finally
          Pic.Free;
        end;
      end;
    end;
    W := Source.Width;
    H := Source.Height;
    if (W <= 0) or (H <= 0) then Exit;
    if W >= H then
    begin
      H := Max(1, MulDiv(H, 200, W));
      W := 200;
    end
    else
    begin
      W := Max(1, MulDiv(W, 200, H));
      H := 200;
    end;
    Thumb.PixelFormat := pf24bit;
    Thumb.SetSize(W, H);
    SetStretchBltMode(Thumb.Canvas.Handle, HALFTONE);
    SetBrushOrgEx(Thumb.Canvas.Handle, 0, 0, nil);
    Thumb.Canvas.StretchDraw(Rect(0, 0, W, H), Source);
    ForceDirectories(ExtractFilePath(ACacheFile));
    TempFile := ACacheFile + '.' + IntToStr(GetCurrentThreadId) + '.tmp.bmp';
    Thumb.SaveToFile(TempFile);
    if FileExists(ACacheFile) then Winapi.Windows.DeleteFile(PChar(ACacheFile));
    Result := RenameFile(TempFile, ACacheFile);
    if not Result then Winapi.Windows.DeleteFile(PChar(TempFile));
  finally
    Thumb.Free;
    Source.Free;
  end;
end;

procedure TPDFBrowserForm.ShowBasicImage;
var
  ContextItem: TMenuItem;
  ImagePopup: TPopupMenu;
  ButtonIndex: Integer;
  Input: TGDIPlusStartupInput;
  Ext: string;
begin
  if FImageScroll = nil then
  begin
    FImageScroll := TScrollBox.Create(Self);
    FImageScroll.Parent := Self;
    FImageScroll.Align := alClient;
    FImageScroll.Color := clBtnShadow;
    FImageScroll.DoubleBuffered := True;
    FImageDisplay := TImage.Create(Self);
    FImageDisplay.Parent := FImageScroll;
    FImageDisplay.AutoSize := False;
    FImageDisplay.Stretch := True;
    ImagePopup := TPopupMenu.Create(FImageDisplay);
    ImagePopup.AutoPopup := True;
    FImageDisplay.PopupMenu := ImagePopup;
    // Eigenes Grafik-Kontextmenue, unabhaengig von PDF-Aktionen.
    ContextItem := TMenuItem.Create(ImagePopup); ContextItem.Caption := ToolbarHintBrowser('Bild um 90° nach rechts drehen', 'Rotate image 90° right'); ContextItem.Tag := 3; ContextItem.OnClick := ImageContextClick; ImagePopup.Items.Add(ContextItem);
    ContextItem := TMenuItem.Create(ImagePopup); ContextItem.Caption := ToolbarHintBrowser('Bild um 90° nach links drehen', 'Rotate image 90° left'); ContextItem.Tag := 2; ContextItem.OnClick := ImageContextClick; ImagePopup.Items.Add(ContextItem);
    ContextItem := TMenuItem.Create(ImagePopup); ContextItem.Caption := '-'; ImagePopup.Items.Add(ContextItem);
    ContextItem := TMenuItem.Create(ImagePopup); ContextItem.Caption := ToolbarHintBrowser('Ganze Bild anzeigen', 'Fit whole image'); ContextItem.Tag := 4; ContextItem.OnClick := ImageContextClick; ImagePopup.Items.Add(ContextItem);
    ContextItem := TMenuItem.Create(ImagePopup); ContextItem.Caption := '-'; ImagePopup.Items.Add(ContextItem);
    ContextItem := TMenuItem.Create(ImagePopup); ContextItem.Caption := ToolbarHintBrowser('Bild in Zwischenablage kopieren', 'Copy image to clipboard'); ContextItem.Tag := 20; ContextItem.OnClick := ImageContextClick; ImagePopup.Items.Add(ContextItem);
    ContextItem := TMenuItem.Create(ImagePopup); ContextItem.Caption := ToolbarHintBrowser('Bild speichern unter ...', 'Save image as ...'); ContextItem.Tag := 7; ContextItem.OnClick := ImageContextClick; ImagePopup.Items.Add(ContextItem);
    FImageScroll.PopupMenu := ImagePopup;

    // Mausrad-Ereignis wird vom Formular empfangen (VCL-Ereignisweitergabe).
    OnMouseWheel := ImageMouseWheel;
    FImageZoom := 1.0;
    FImageFitMode := 1;
    if FImageWorkspacePending then
    begin
      FImageZoom := FImageWorkspaceZoom;
      FImageFitMode := FImageWorkspaceFitMode;
      FImageWorkspacePending := False;
    end;
    CreateImageTools;
    FTIFFPrevButton := TSpeedButton.Create(Self);
    FTIFFPrevButton.Parent := FToolbar;
    FTIFFPrevButton.Caption := '';
    FTIFFPrevButton.Margin := -1;
    FTIFFPrevButton.Hint := ToolbarHintBrowser('Vorherige TIFF-Seite', 'Previous TIFF page');
    FTIFFPrevButton.ShowHint := True;
    FTIFFPrevButton.OnClick := TIFFPageButtonClick;
    FTIFFPrevButton.SetBounds(0, 0, MulDiv(30, CurrentPPI, 96), MulDiv(28, CurrentPPI, 96));
    FTIFFNextButton := TSpeedButton.Create(Self);
    FTIFFNextButton.Parent := FToolbar;
    FTIFFNextButton.Caption := '';
    FTIFFNextButton.Margin := -1;
    FTIFFNextButton.Hint := ToolbarHintBrowser('Nächste TIFF-Seite', 'Next TIFF page');
    FTIFFNextButton.ShowHint := True;
    FTIFFNextButton.OnClick := TIFFPageButtonClick;
    FTIFFNextButton.SetBounds(0, 0, MulDiv(30, CurrentPPI, 96), MulDiv(28, CurrentPPI, 96));
    FTIFFPageLabel := TLabel.Create(Self);
    FTIFFPageLabel.Parent := FToolbar;
    FTIFFPageLabel.AutoSize := False;
    FTIFFPageLabel.Alignment := taCenter;
    FTIFFPageLabel.Layout := tlCenter;
    FTIFFPageLabel.SetBounds(0, 0, MulDiv(65, CurrentPPI, 96), MulDiv(28, CurrentPPI, 96));
    FTIFFPrevButton.Visible := False;
    FTIFFNextButton.Visible := False;
    FTIFFPageLabel.Visible := False;
    // Nachträglich angelegte TIFF-Buttons einmalig mit der Designpalette versehen.
    FToolbarDesignApplied := False;
    ApplyToolbarDesign(FToolbarDesignIndex);
    // Bildregister: keine PDF-Such- oder Anlagenbuttons in der Bildleiste.
    if FFindButton <> nil then FFindButton.Visible := False;
    if FGlobalFindButton <> nil then FGlobalFindButton.Visible := False;
    if FSearchCountLabel <> nil then FSearchCountLabel.Visible := False;
    if FAttachmentsButton <> nil then FAttachmentsButton.Visible := False;
  end;
  if (FImageDisplay.Picture.Graphic = nil) or
     (FImageDisplay.Picture.Width = 0) then
  begin
    Ext := LowerCase(ExtractFileExt(PDFFileName));
    if (Ext = '.tif') or (Ext = '.tiff') then
    begin
      CloseTIFFImage;
      FillChar(Input, SizeOf(Input), 0);
      Input.GdiplusVersion := 1;
      if GdiplusStartup(FTIFFGDIPlusToken, Input, nil) <> 0 then
        raise Exception.Create('GDI+ konnte nicht initialisiert werden.');
      try
        if GdipLoadImageFromFile(PWideChar(PDFFileName), FTIFFImage) <> 0 then
          raise Exception.Create('TIFF-Datei konnte nicht geöffnet werden.');
        FTIFFPageGuid := StringToGUID('{7462DC86-6180-4C7E-8E3F-EE7333A7A483}');
        if (GdipImageGetFrameCount(FTIFFImage, FTIFFPageGuid, FTIFFPageCount) <> 0) or
           (FTIFFPageCount = 0) then
          raise Exception.Create('TIFF-Seitenzahl konnte nicht gelesen werden.');
        SetLength(FTIFFRotations, FTIFFPageCount);
        ShowTIFFPage(0);
      except
        CloseTIFFImage;
        raise;
      end;
    end
    else FImageDisplay.Picture.LoadFromFile(PDFFileName);
  end;
  if FTIFFPrevButton <> nil then
  begin
    FTIFFPrevButton.Visible := FTIFFPageCount > 1;
    FTIFFNextButton.Visible := FTIFFPageCount > 1;
    FTIFFPageLabel.Visible := FTIFFPageCount > 1;
  end;
  UpdateImageLayout;
  // Grafikregister besitzen keine PDFium-Symbolleiste. Die eigene Leiste
  // muss daher unabhaengig vom PDFium-Layout sichtbar und oben bleiben.
  if FToolbar <> nil then
  begin
    if FToolbar.Parent <> Self then FToolbar.Parent := Self;
    FToolbar.Align := alTop;
    FToolbar.Visible := True;
    FToolbar.Height := Max(FToolbar.Height, MulDiv(36, CurrentPPI, 96));
    FToolbar.BringToFront;
  end;
  if FImageButtons[0] <> nil then
    for ButtonIndex := 0 to High(FImageButtons) do
      FImageButtons[ButtonIndex].Visible := True;
  // Die normale PDF-Leiste kann bereits als fertig angeordnet markiert sein.
  // Beim ersten Anzeigen einer Grafik wurden die neuen Bildbuttons deshalb
  // bisher nicht mehr positioniert.
  FToolbarLayoutLocked := False;
  ReflowNavigationToolbar;
  if FImageScroll <> nil then FImageScroll.SendToBack;
  if FToolbar <> nil then FToolbar.BringToFront;
  if FOpenPDFButton <> nil then
    FOpenPDFButton.Hint := ToolbarHintBrowser(
      'PDFs und Bilder öffnen ... (Strg+O)',
      'Open PDFs and images... (Ctrl+O)');
  FNavigationDone := True;
  FNavigationSucceeded := True;
  FLoadRequested := False;
  TimerPDF.Enabled := False;
end;

procedure TPDFBrowserForm.FormShow(Sender: TObject);
begin
  if IsBasicImage then
  begin
    ShowBasicImage;
    Exit;
  end;
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

  if IsBasicImage then
  begin
    TimerPDF.Enabled := False;
    Exit;
  end;
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
  ImageSeparator1, ImageSeparator2: TPanel;
  function ScalePx(N: Integer): Integer;
  begin
    Result := MulDiv(N, CurrentPPI, 96);
  end;
  function GetImageSeparator(const AName: string): TPanel;
  begin
    Result := FindComponent(AName) as TPanel;
    if Result = nil then
    begin
      Result := TPanel.Create(Self);
      Result.Name := AName;
      Result.Parent := FToolbar;
      Result.BevelOuter := bvNone;
      Result.ParentBackground := False;
      Result.Color := clGray;
      Result.Enabled := False;
    end;
    Result.Width := Max(1, ScalePx(1));
    Result.Height := ScalePx(20);
    Result.Visible := True;
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
  procedure PutImageSeparator(ASeparator: TPanel);
  begin
    Inc(X, ScalePx(6));
    Put(ASeparator);
    Inc(X, ScalePx(6));
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
  // Anlagen-Button hat exakt dieselbe DPI-Geometrie wie die
  // benachbarten PDFium-Symbolbuttons, auch nach einem Parent-Wechsel.
  if FAttachmentsButton <> nil then
    FAttachmentsButton.SetBounds(FAttachmentsButton.Left,
      FAttachmentsButton.Top, ScalePx(34), ScalePx(28));
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
  if FImageButtons[0] <> nil then
  begin
    Inc(Required, 2 * (ScalePx(13) + Gap)); // zwei Grafik-Trennlinien
    for I := 0 to High(FImageButtons) do
      Inc(Required, FImageButtons[I].Width + Gap);
    if FImageZoomLabel <> nil then
      Inc(Required, FImageZoomLabel.Width + Gap);
  end;
  if (FTIFFPrevButton <> nil) and FTIFFPrevButton.Visible then
    Inc(Required, FTIFFPrevButton.Width + FTIFFNextButton.Width + FTIFFPageLabel.Width + 3 * Gap);
  if (EditButton <> nil) and (EditButton.Parent = FToolbar) then
  begin
    // Auch beim erneuten Layout keine alte Mindestbreite von 52 px anwenden.
    EditButton.SetBounds(EditButton.Left, EditButton.Top,
      ScalePx(34), ScalePx(28));
    Inc(Required, EditButton.Width);
  end;
  // Bei einer neu eingeblendeten Teilungsschaltflaeche darf die alte
  // Geometrie nicht stehenbleiben: sie wuerde den Oeffnen-Button ueberdecken.
  if (FToolbar.ClientWidth < Required) and (FImageButtons[0] = nil) then
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
  if FImageButtons[0] = nil then
  begin
    Put(FFindButton);
    Put(FGlobalFindButton);
  end;
  if FImageButtons[0] <> nil then
  begin
    ImageSeparator1 := GetImageSeparator('ImageToolbarSeparatorBeforeZoom');
    ImageSeparator2 := GetImageSeparator('ImageToolbarSeparatorAfterFit');
    PutImageSeparator(ImageSeparator1);
    for I := 0 to High(FImageButtons) do
    begin
      if I = 7 then PutImageSeparator(ImageSeparator2);
      Put(FImageButtons[I]);
      if (I = 1) and (FImageZoomLabel <> nil) then
        Put(FImageZoomLabel);
    end;
    ImageSeparator1.BringToFront;
    ImageSeparator2.BringToFront;
  end;
  if (FTIFFPrevButton <> nil) and FTIFFPrevButton.Visible then
  begin
    Put(FTIFFPrevButton);
    Put(FTIFFPageLabel);
    Put(FTIFFNextButton);
  end;
  // Auch bei unsichtbarer Trefferanzeige den Platz beibehalten.
  if FImageButtons[0] = nil then Put(FSearchCountLabel);
  if FAttachmentSeparator <> nil then
    FAttachmentSeparator.Visible := False;
  if (FImageButtons[0] = nil) and (FAttachmentsButton.Parent = FToolbar) then
    Inc(X, ScalePx(2));
  if (FImageButtons[0] = nil) and (FAttachmentsButton.Parent = FToolbar) then
    Put(FAttachmentsButton);
  // Markierungswerkzeuge im zweizeiligen Layout ebenfalls platzieren.
  if (FImageButtons[0] = nil) and (EditButton <> nil) and (EditButton.Parent = FToolbar) then
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
  ImageButtonIndex: Integer;
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
  // Die Bildsymbole nur beim echten Designwechsel neu einfärben.
  if FImageButtons[0] <> nil then
  begin
    for ImageButtonIndex := 0 to High(FImageButtons) do
    begin
      FImageButtons[ImageButtonIndex].Flat := ADesign <> 0;
      FImageButtons[ImageButtonIndex].Transparent := ADesign <> 0;
      FImageButtons[ImageButtonIndex].Font.Color := TextColor;
      if ImageButtonIndex = 6 then
      begin
        FImageButtons[ImageButtonIndex].Caption := '100 %';
        FImageButtons[ImageButtonIndex].Font.Style := [fsBold];
        FImageButtons[ImageButtonIndex].Font.Size := 9;
      end
      else
        SetCrispImageGlyph(FImageButtons[ImageButtonIndex],
          ImageButtonIndex, TextColor);
    end;
  end;
  if FImageZoomLabel <> nil then
  begin
    FImageZoomLabel.Font.Color := TextColor;
    FImageZoomLabel.Font.Style := [fsBold];
    FImageZoomLabel.Font.Size := 9;
    FImageZoomLabel.Transparent := True;
  end;
  UpdateImageSaveIndicator;
  // TIFF-Pfeile als zentrierte DPI-Glyphen in der aktuellen Designfarbe.
  // Nur bei der initialen Gestaltung oder einem echten Designwechsel zeichnen.
  if FTIFFPrevButton <> nil then
  begin
    FTIFFPrevButton.Flat := ADesign <> 0;
    FTIFFNextButton.Flat := ADesign <> 0;
    FTIFFPrevButton.Transparent := ADesign <> 0;
    FTIFFNextButton.Transparent := ADesign <> 0;
    SetTIFFArrowGlyph(FTIFFPrevButton, False, TextColor, CurrentPPI);
    SetTIFFArrowGlyph(FTIFFNextButton, True, TextColor, CurrentPPI);
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
  // Anlagen-Button vor der Breitenberechnung in beiden Modi normieren.
  if FAttachmentsButton <> nil then
    FAttachmentsButton.SetBounds(FAttachmentsButton.Left,
      FAttachmentsButton.Top, Px(34), Px(28));
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
  if FImageDisplay <> nil then UpdateImageLayout;
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
